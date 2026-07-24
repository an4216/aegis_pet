# Plan FR-15 v3 — 전역 키보드/마우스/활성시간 카운터 어댑터.
# 첫 실행 시 counter_helper.cs를 csc로 빌드, 헬퍼가 3초마다 JSON을 갱신하면
# 여기서 델타를 계산해 PetState로 전달한다.
# 헬퍼 실패 시 available=false로 유지 (다른 지표는 정상 동작 — 우아한 저하).
extends Node

signal counter_delta(delta: Dictionary)

const POLL_SECONDS := 2.0
const JSON_PATH := "user://input_counts.json"
const HELPER_EXE := "user://counter.exe"
const CSC_PATHS := [
	"C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe",
	"C:/Windows/Microsoft.NET/Framework/v4.0.30319/csc.exe",
]

var available := false

var _helper_pid := -1
var _timer := 0.0
var _last := {"kb": 0, "mouse": 0, "active_sec": 0.0, "friday_active_sec": 0.0}


func start() -> void:
	var exe := _ensure_helper()
	if exe == "":
		push_warning("input_probe: 헬퍼 빌드 실패 — 키보드/마우스 카운터 없이 동작")
		return
	_helper_pid = OS.create_process(exe, [
		ProjectSettings.globalize_path(JSON_PATH),
		str(OS.get_process_id()),
	])
	available = _helper_pid > 0


func _exit_tree() -> void:
	if _helper_pid > 0:
		_read_and_emit()  # 마지막 카운트까지 반영 후 종료
		OS.kill(_helper_pid)


func _process(delta: float) -> void:
	if not available:
		return
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
	if delta["kb"] > 0 or delta["mouse"] > 0 or delta["active_sec"] > 0.0:
		counter_delta.emit(delta)


func _ensure_helper() -> String:
	var exe_abs := ProjectSettings.globalize_path(HELPER_EXE).replace("/", "\\")
	if FileAccess.file_exists(HELPER_EXE):
		return exe_abs
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
	return exe_abs
