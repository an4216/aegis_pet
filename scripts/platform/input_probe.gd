# Plan FR-15 v3 — 전역 키보드/마우스/활성시간 카운터 어댑터.
# 첫 실행 시 counter_helper.cs를 csc로 빌드, 헬퍼가 3초마다 JSON을 갱신하면
# 여기서 델타를 계산해 PetState로 전달한다.
# 헬퍼 실패 시 available=false로 유지 (다른 지표는 정상 동작 — 우아한 저하).
extends Node

signal counter_delta(delta: Dictionary)
signal disguise_toggle_requested()   # Ctrl+Shift+H
signal hide_toggle_requested()       # Shift+Esc

const POLL_SECONDS := 2.0
## 헬퍼 생존 확인 주기(초). 카운터가 죽어도 아무도 몰랐던 결함을 막는다 — 아래 주석 참고.
const HELPER_WATCHDOG_SECONDS := 10.0
const JSON_PATH := "user://input_counts.json"
const HELPER_EXE := "user://counter.exe"
const CSC_PATHS := [
	"C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe",
	"C:/Windows/Microsoft.NET/Framework/v4.0.30319/csc.exe",
]

var available := false
var idle_ms := 0   # 마지막 입력 이후 경과 시간 (자동 재시작 조건 판단용)

var _helper_pid := -1
var _timer := 0.0
var _watchdog := HELPER_WATCHDOG_SECONDS
var _last := {"kb": 0, "mouse": 0, "active_sec": 0.0, "friday_active_sec": 0.0}
var _last_disguise_toggle := 0
var _last_hide_toggle := 0
const HELPER_VERSION := 5   # counter_helper.cs 변경 시 증가 → 낡은 exe 자동 재빌드


func start() -> void:
	var exe := _ensure_helper()
	if exe == "":
		push_warning("input_probe: 헬퍼 빌드 실패 — 키보드/마우스 카운터 없이 동작")
		return
	# 이전 세션의 낡은 카운터가 새 세션에서 유령 hide/disguise 발동시키지 않도록
	# helper 시작 전에 stale 파일을 삭제한다.
	if FileAccess.file_exists(JSON_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(JSON_PATH))
	_helper_pid = _spawn_helper(exe)
	available = _helper_pid > 0


func _spawn_helper(exe: String) -> int:
	return OS.create_process(exe, [
		ProjectSettings.globalize_path(JSON_PATH),
		str(OS.get_process_id()),
	])


## 헬퍼 프로세스가 살아 있는지. `_helper_pid <= 0`이면 애초에 띄우지 못한 것이라 죽은 것으로 본다.
func helper_is_alive() -> bool:
	return _helper_pid > 0 and OS.is_process_running(_helper_pid)


## 헬퍼가 죽었으면 다시 띄운다.
##
## 왜 필요한가: 카운터가 죽어도 `available`은 true로 남고, `_read_and_emit()`은 파일이 없으면
## 조용히 반환하거나(삭제된 경우) 얼어붙은 값을 계속 읽어 델타 0을 내놓는다(남아 있는 경우).
## 어느 쪽이든 **그 세션 내내 키보드·마우스 적산이 멈추고 아무 신호도 나오지 않는다.** 이 앱은
## 며칠씩 켜두는 데스크톱 펫이라 세션이 길고, 진화 조건이 이 카운트라서 "진화가 안 된다"로
## 드러난다. start()는 한 번만 호출되므로 복구 경로가 어디에도 없었다(2026-08-20).
##
## 재기동한 헬퍼는 0부터 다시 세는데, `_read_and_emit()`의 음수 델타 가드가 그 경우를 이미
## "헬퍼 재시작"으로 보고 절대값을 쓴다 — 그래서 여기서 `_last`를 따로 만질 필요가 없다.
func _restart_helper_if_dead() -> void:
	if helper_is_alive():
		return
	var exe := _ensure_helper()
	if exe == "":
		return
	_helper_pid = _spawn_helper(exe)
	available = _helper_pid > 0


func _exit_tree() -> void:
	if _helper_pid > 0:
		_read_and_emit()  # 마지막 카운트까지 반영 후 종료
		OS.kill(_helper_pid)


func _process(delta: float) -> void:
	if not available:
		return
	_watchdog -= delta
	if _watchdog <= 0.0:
		_watchdog = HELPER_WATCHDOG_SECONDS
		_restart_helper_if_dead()
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = POLL_SECONDS
	_read_and_emit()


func _read_and_emit() -> void:
	if not FileAccess.file_exists(JSON_PATH):
		return
	var f := FileAccess.open(JSON_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		return
	var current := {
		"kb": int(parsed.get("kb", 0)),
		"mouse": int(parsed.get("mouse", 0)),
		"active_sec": float(parsed.get("active_sec", 0.0)),
		"friday_active_sec": float(parsed.get("friday_active_sec", 0.0)),
	}
	var delta := {
		"kb": current["kb"] - int(_last["kb"]),
		"mouse": current["mouse"] - int(_last["mouse"]),
		"active_sec": current["active_sec"] - float(_last["active_sec"]),
		"friday_active_sec": current["friday_active_sec"] - float(_last["friday_active_sec"]),
	}
	# 헬퍼 재시작 시 카운터가 0으로 리셋되었을 수 있음 → 절대값 사용
	if delta["kb"] < 0 or delta["mouse"] < 0:
		delta = current.duplicate()
	_last = current
	idle_ms = int(parsed.get("idle_ms", 0))
	if delta["kb"] > 0 or delta["mouse"] > 0 or delta["active_sec"] > 0.0:
		counter_delta.emit(delta)
	# 위장/숨김 단축키 edge (헬퍼 재시작 시 counter 리셋 되므로 감소는 무시)
	var dg := int(parsed.get("disguise_toggle", 0))
	if dg > _last_disguise_toggle:
		disguise_toggle_requested.emit()
	_last_disguise_toggle = dg
	var hd := int(parsed.get("hide_toggle", 0))
	if hd > _last_hide_toggle:
		hide_toggle_requested.emit()
	_last_hide_toggle = hd


func _ensure_helper() -> String:
	var exe_abs := ProjectSettings.globalize_path(HELPER_EXE).replace("/", "\\")
	var stamp_path := "user://counter_helper_v%d.stamp" % HELPER_VERSION
	if FileAccess.file_exists(HELPER_EXE) and FileAccess.file_exists(stamp_path):
		return exe_abs
	# 낡은 exe 삭제 → 재빌드 유도
	if FileAccess.file_exists(HELPER_EXE):
		DirAccess.remove_absolute(exe_abs)
	var csc := ""
	for path in CSC_PATHS:
		if FileAccess.file_exists(path):
			csc = path
			break
	if csc == "":
		return ""
	var src := FileAccess.open("res://tools/counter_helper.cs", FileAccess.READ)
	if src == null:
		return ""
	var dst := FileAccess.open("user://counter_helper.cs", FileAccess.WRITE)
	dst.store_string(src.get_as_text())
	dst.close()
	src.close()
	var output: Array = []
	var code := OS.execute(csc, [
		"-nologo", "-optimize", "-target:winexe",
		"-out:" + exe_abs,
		ProjectSettings.globalize_path("user://counter_helper.cs").replace("/", "\\"),
	], output, true)
	if code != 0 or not FileAccess.file_exists(HELPER_EXE):
		push_warning("counter helper build failed (code %d): %s" % [code, str(output)])
		return ""
	# 버전 스탬프 기록 (다음 실행 시 재빌드 안 함)
	var stamp := FileAccess.open("user://counter_helper_v%d.stamp" % HELPER_VERSION, FileAccess.WRITE)
	if stamp != null:
		stamp.store_string("built")
		stamp.close()
	return exe_abs
