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
## v0.8.6: 부모 PID 대기 + 최대 60회 재시도 + 로그로 실패 원인 추적 가능하게 강화.
## 교체·재시작 배치를 만든다. 순수 함수라 검사에서 문자열째로 검증할 수 있다.
##
## 배치 텍스트에는 GDScript의 `%` 포맷 연산자를 **쓰지 않는다**. 배치는 `%VAR%`로 변수를
## 참조하는데 `%` 포맷을 섞으면, 포맷 인자를 받는 줄은 `%%`로 써야 하고 받지 않는 줄은 `%`로
## 써야 해서 같은 파일 안에서 규칙이 갈린다. 실제로 갈렸다 — `if %%WPID%% GEQ 30`과
## `if %%CRET%% GEQ 60` 두 줄이 포맷 인자를 받지 못한 채 남았고, 배치에서 `%%`는 리터럴 `%`로
## 줄어들어 비교가 문자열 `%WPID%` vs `30`이 됐다. 즉 **두 상한이 영구히 거짓**이었다:
## 대기 루프는 30초 강제 종료를 못 하고, 복사 루프는 60회 상한에 걸리지 않아 복사가 계속
## 실패하면 영원히 돌면서 마지막 `start` 줄에 끝내 도달하지 못한다 — 업데이트가 끝나도
## 앱이 다시 켜지지 않는 경로가 이것이다(2026-08-20 사용자 신고).
## 그래서 `{키}` 치환만 쓴다. 배치의 `%`는 전부 그대로 남는다.
static func build_apply_script(
	new_exe: String, target: String, log_path: String, parent_pid: int
) -> String:
	var subs := {
		"new_exe": new_exe,
		"target": target,
		"workdir": target.get_base_dir(),
		"log": log_path,
		"pid": str(parent_pid),
	}
	return "
".join([
		"@echo off",
		"setlocal EnableExtensions",
		"echo [%DATE% %TIME%] update start (pid={pid}) >> \"{log}\"",
		# 부모(게임) 프로세스가 확실히 종료될 때까지 대기 — 최대 30초
		"set /a WPID=0",
		":waitparent",
		"tasklist /FI \"PID eq {pid}\" 2>nul | find \"{pid}\" >nul",
		"if errorlevel 1 goto ready",
		"set /a WPID+=1",
		"if %WPID% GEQ 30 (",
		"  echo [%DATE% %TIME%] parent still alive after 30s, forcing kill >> \"{log}\"",
		"  taskkill /F /PID {pid} >nul 2>&1",
		"  goto ready",
		")",
		"timeout /t 1 /nobreak >nul",
		"goto waitparent",
		":ready",
		# 파일 교체 — 최대 60회 재시도 (파일 락 해제 대기)
		"set /a CRET=0",
		":copyloop",
		"copy /y \"{new_exe}\" \"{target}\" >>\"{log}\" 2>&1",
		"if not errorlevel 1 goto done",
		"set /a CRET+=1",
		"if %CRET% GEQ 60 (",
		"  echo [%DATE% %TIME%] copy failed after 60 retries >> \"{log}\"",
		"  exit /b 1",
		")",
		"timeout /t 1 /nobreak >nul",
		"goto copyloop",
		":done",
		"del \"{new_exe}\" >nul 2>&1",
		"echo [%DATE% %TIME%] copy ok, launching >> \"{log}\"",
		# start /D <workdir> 로 작업 디렉토리를 exe 폴더로 맞춰 상대경로 리소스 접근 실패 방지
		"start \"\" /D \"{workdir}\" \"{target}\"",
		"echo [%DATE% %TIME%] update done >> \"{log}\"",
		"exit /b 0",
		"",
	]).format(subs)


func _apply() -> void:
	var new_exe := ProjectSettings.globalize_path(NEW_EXE_PATH).replace("/", "\\")
	var target := OS.get_executable_path().replace("/", "\\")
	var bat_path := ProjectSettings.globalize_path("user://update/apply_update.bat")
	var log_path := ProjectSettings.globalize_path("user://update/update.log").replace("/", "\\")
	var bat := build_apply_script(new_exe, target, log_path, OS.get_process_id())
	var f := FileAccess.open(bat_path, FileAccess.WRITE)
	if f == null:
		update_failed.emit("교체 스크립트 생성 실패")
		return
	f.store_string(bat)
	f.close()
	get_node("/root/SaveManager").save_game()
	OS.create_process("cmd.exe", ["/c", bat_path.replace("/", "\\")])
	get_tree().quit()
