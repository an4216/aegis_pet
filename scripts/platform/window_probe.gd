# Design Ref: §4.3 — 창 감지 어댑터 (Phase 2).
# 내장 C# 컴파일러(csc)로 헬퍼를 1회 빌드하고, 헬퍼가 0.5초마다 쓰는 JSON을 읽는다.
# 헬퍼가 없거나 빌드 실패 시 platforms는 빈 배열 = Phase 1과 동일하게 동작(우아한 성능 저하).
extends Node

signal toast_appeared(id: int, rect: Rect2)

const POLL_SECONDS := 0.5
const JSON_PATH := "user://windows.json"
const HELPER_EXE := "user://window_probe.exe"
const CSC_PATHS := [
	"C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe",
	"C:/Windows/Microsoft.NET/Framework/v4.0.30319/csc.exe",
]

var windows: Array = []      # [{id, rect: Rect2, z, toast}] z 낮을수록 위
var available := false

var _helper_pid := -1
var _timer := 0.0
var _known_toasts := {}


func start() -> void:
	var exe := _ensure_helper()
	if exe == "":
		push_warning("window_probe: 헬퍼 빌드 불가 — 창 인식 없이 동작")
		return
	_helper_pid = OS.create_process(exe, [
		ProjectSettings.globalize_path(JSON_PATH),
		str(OS.get_process_id()),
	])
	available = _helper_pid > 0


func _exit_tree() -> void:
	if _helper_pid > 0:
		OS.kill(_helper_pid)


func _process(delta: float) -> void:
	if not available:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = POLL_SECONDS
	if not FileAccess.file_exists(JSON_PATH):
		return
	var f := FileAccess.open(JSON_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	windows = parse_windows(text)
	_detect_toasts()


## 펫이 올라설 수 있는 플랫폼(창 상단) 목록. screen 영역과 겹치는 창만.
func platforms(screen: Rect2, ground_y: float) -> Array:
	var result: Array = []
	for win in windows:
		if win["toast"]:
			continue
		var r: Rect2 = win["rect"]
		var visible_part := r.intersection(screen)
		if visible_part.size.x < 260.0:
			continue  # 화면 안에 충분히 보이는 창만
		if r.position.y < 60.0 or r.position.y > ground_y - 120.0:
			continue  # 너무 높거나(최대화 창) 바닥에 붙은 창 제외
		var clipped: Dictionary = win.duplicate()
		clipped["rect"] = Rect2(visible_part.position.x, r.position.y, visible_part.size.x, r.size.y)
		result.append(clipped)
	return result


static func parse_windows(text: String) -> Array:
	var parsed = JSON.parse_string(text)
	if not parsed is Array:
		return []
	var result: Array = []
	for item in parsed:
		if not item is Dictionary:
			continue
		result.append({
			"id": int(item.get("i", 0)),
			"rect": Rect2(
				float(item.get("x", 0)), float(item.get("y", 0)),
				float(item.get("w", 0)), float(item.get("h", 0))
			),
			"z": int(item.get("z", 0)),
			"toast": int(item.get("t", 0)) == 1,
		})
	return result


func find_by_id(id: int) -> Dictionary:
	for win in windows:
		if win["id"] == id:
			return win
	return {}


func _ensure_helper() -> String:
	var exe_abs := ProjectSettings.globalize_path(HELPER_EXE)
	if FileAccess.file_exists(HELPER_EXE):
		return exe_abs
	var csc := ""
	for path in CSC_PATHS:
		if FileAccess.file_exists(path):
			csc = path
			break
	if csc == "":
		return ""
	# 소스를 user://로 추출 (익스포트 빌드에서는 res://가 pck 내부라 직접 접근 불가)
	var src := FileAccess.open("res://tools/window_probe_helper.cs", FileAccess.READ)
	if src == null:
		return ""
	var dst := FileAccess.open("user://window_probe_helper.cs", FileAccess.WRITE)
	dst.store_string(src.get_as_text())
	dst.close()
	src.close()
	var code := OS.execute(csc, [
		"/nologo", "/optimize", "/target:winexe",
		"/out:" + exe_abs,
		ProjectSettings.globalize_path("user://window_probe_helper.cs"),
	])
	return exe_abs if code == 0 and FileAccess.file_exists(HELPER_EXE) else ""


func _detect_toasts() -> void:
	var current := {}
	for win in windows:
		if win["toast"]:
			current[win["id"]] = win["rect"]
			if not _known_toasts.has(win["id"]):
				toast_appeared.emit(win["id"], win["rect"])
	_known_toasts = current
