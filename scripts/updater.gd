# Plan FR-29 — 반자동 업데이트.
# 시작 15초 후 GitHub Releases 최신 버전 확인 → 새 버전이면 알림 →
# 사용자가 트레이에서 설치 선택 → exe 다운로드 → bat이 교체 후 재시작.
# 저장 데이터(user://)는 exe와 분리되어 있어 업데이트와 무관하게 유지된다.
extends Node

signal update_available(version: String)
signal update_failed(reason: String)

const REPO := "an4216/aegis_pet"
const EXE_ASSET := "aegis-pet.exe"
const CHECK_DELAY_SECONDS := 15.0
const NEW_EXE_PATH := "user://update/aegis-pet-new.exe"

var current_version := "0.0.0"
var latest_version := ""

var _exe_url := ""
var _download: HTTPRequest


func _ready() -> void:
	current_version = str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	get_tree().create_timer(CHECK_DELAY_SECONDS).timeout.connect(_check)


static func is_newer(remote: String, local: String) -> bool:
	var r := remote.lstrip("v").split(".")
	var l := local.lstrip("v").split(".")
	for i in 3:
		var rv := int(r[i]) if i < r.size() else 0
		var lv := int(l[i]) if i < l.size() else 0
		if rv != lv:
			return rv > lv
	return false


func start_update() -> void:
	if _exe_url == "" or _download != null:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://update"))
	_download = HTTPRequest.new()
	_download.download_file = NEW_EXE_PATH
	add_child(_download)
	_download.request_completed.connect(_on_download_done)
	var err := _download.request(_exe_url, ["User-Agent: aegis-pet", "Accept: application/octet-stream"])
	if err != OK:
		_download.queue_free()
		_download = null
		update_failed.emit("다운로드를 시작하지 못했어")


func _check() -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(_on_check_done.bind(req))
	var err := req.request(
		"https://api.github.com/repos/%s/releases/latest" % REPO,
		["User-Agent: aegis-pet", "Accept: application/vnd.github+json"]
	)
	if err != OK:
		req.queue_free()


func _on_check_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, req: HTTPRequest) -> void:
	req.queue_free()
	print("updater: check result=%d http=%d" % [result, code])
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return  # 오프라인/미발행 — 조용히 넘어감 (다음 실행 때 재시도)
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary:
		return
	var tag := String(data.get("tag_name", ""))
	if tag == "" or not is_newer(tag, current_version):
		return
	for asset in data.get("assets", []):
		if asset.get("name", "") == EXE_ASSET:
			_exe_url = String(asset.get("browser_download_url", ""))
			break
	if _exe_url == "":
		return  # exe 에셋이 없는 릴리스는 무시
	latest_version = tag.lstrip("v")
	update_available.emit(latest_version)


func _on_download_done(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	var dl := _download
	_download = null
	dl.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		update_failed.emit("다운로드 실패 (코드 %d)" % code)
		return
	if OS.has_feature("editor"):
		update_failed.emit("에디터 실행 중에는 교체할 수 없어 (익스포트 빌드 전용)")
		return
	_apply()


## 실행 중인 exe는 자신을 덮어쓸 수 없으므로, 종료 후 교체·재시작하는 bat을 남긴다.
func _apply() -> void:
	var new_exe := ProjectSettings.globalize_path(NEW_EXE_PATH).replace("/", "\\")
	var target := OS.get_executable_path().replace("/", "\\")
	var bat_path := ProjectSettings.globalize_path("user://update/apply_update.bat")
	var bat := "\r\n".join([
		"@echo off",
		":wait",
		"ping -n 2 127.0.0.1 >nul",
		"copy /y \"%s\" \"%s\" >nul 2>&1" % [new_exe, target],
		"if errorlevel 1 goto wait",
		"del \"%s\" >nul 2>&1" % new_exe,
		"start \"\" \"%s\"" % target,
		"",
	])
	var f := FileAccess.open(bat_path, FileAccess.WRITE)
	if f == null:
		update_failed.emit("교체 스크립트 생성 실패")
		return
	f.store_string(bat)
	f.close()
	get_node("/root/SaveManager").save_game()
	OS.create_process("cmd.exe", ["/c", bat_path.replace("/", "\\")])
	get_tree().quit()
