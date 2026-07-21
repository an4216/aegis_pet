# Design Ref: §3.1 저장 스키마, §6 오류 처리 — 원자적 쓰기 + 백업 + 마이그레이션.
extends Node

const SCHEMA_VERSION := 1
const SAVE_PATH := "user://save.json"
const TMP_PATH := "user://save.json.tmp"
const BAK_PATH := "user://save.bak"
const AUTOSAVE_SECONDS := 60.0

var settings := {
	"focus_mode": false,
	"sound_enabled": false,     # 기본 꺼짐 (업무 배려 원칙)
	"night_start": 22,
	"night_end": 7,
	"bubble_frequency": "normal",
	"always_on_top": true,
	"autostart": false,
}


func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = AUTOSAVE_SECONDS
	timer.timeout.connect(save_game)
	add_child(timer)
	timer.start()
	load_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func save_game() -> void:
	var pet := get_node_or_null("/root/PetState")
	if pet == null:
		return
	var data := {
		"schema_version": SCHEMA_VERSION,
		"last_saved_at": int(Time.get_unix_time_from_system()),
		"pet": pet.serialize(),
		"settings": settings,
	}
	_atomic_write(JSON.stringify(data, "  "))


func load_game() -> void:
	var pet := get_node_or_null("/root/PetState")
	if pet == null:
		return
	var data := _read_json(SAVE_PATH)
	if data.is_empty():
		data = _read_json(BAK_PATH)  # Design §6: 손상 시 백업 복구
	if data.is_empty():
		save_game()  # 새 게임 (알 상태 기본값)
		return
	data = _migrate(data)
	pet.deserialize(data.get("pet", {}))
	var loaded_settings: Dictionary = data.get("settings", {})
	for key in loaded_settings:
		if settings.has(key):
			settings[key] = loaded_settings[key]
	# 오프라인 경과 반영 (Plan FR-10)
	var TimeM := preload("res://autoload/time_manager.gd")
	var elapsed := Time.get_unix_time_from_system() - float(data.get("last_saved_at", 0))
	var effective_hours := TimeM.compute_offline_hours(elapsed)
	if effective_hours > 0.0:
		pet.advance_minutes(effective_hours * 60.0, {"offline": true})


func _migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("schema_version", 0))
	if version < 1:
		data["schema_version"] = 1  # v0 → v1: 필드 기본값은 deserialize가 보정
	return data


func _atomic_write(text: String) -> void:
	var f := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if f == null:
		push_error("save: tmp 파일 쓰기 실패 (%s)" % FileAccess.get_open_error())
		return
	f.store_string(text)
	f.close()
	var tmp_abs := ProjectSettings.globalize_path(TMP_PATH)
	var save_abs := ProjectSettings.globalize_path(SAVE_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(save_abs, ProjectSettings.globalize_path(BAK_PATH))
	var err := DirAccess.rename_absolute(tmp_abs, save_abs)
	if err != OK:
		push_error("save: rename 실패 (%s)" % err)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}
