# Design Ref: §5.4 — 대사 트리거·쿨다운 관리.
# 우선순위: 특수일(월급날) > 요일·시간대 > 랜덤 (캐릭터 60% : 공통 40%)
extends Node

const Dialog := preload("res://scripts/data/dialog.gd")

const FREQ_SECONDS := {
	"often": [30.0, 90.0],      # 수다쟁이
	"normal": [60.0, 180.0],    # 심심하면 계속 조잘댐 (기본)
	"rare": [1200.0, 2400.0],   # 조용한 사무실용
}
const RECENT_LIMIT := 5

var bubble: Node          # scenes/ui/speech_bubble.gd
var pet: Node2D
var screen_size := Vector2.ZERO

var _ps: Node
var _sm: Node
var _next_in := 0.0
var _recent: Array = []
var _fired_today := {}    # trigger -> day


func setup(bubble_node: Node, pet_node: Node2D, size: Vector2) -> void:
	bubble = bubble_node
	pet = pet_node
	screen_size = size
	_ps = get_node("/root/PetState")
	_sm = get_node("/root/SaveManager")
	_ps.species_assigned.connect(_on_hatched)
	_schedule()
	# 세션 첫 말풍선은 15~40초 내로 빠르게 (이후 빈도 설정 따름)
	_next_in = minf(_next_in, randf_range(15.0, 40.0))


func _process(delta: float) -> void:
	_next_in -= delta
	if _next_in <= 0.0:
		_schedule()
		if _can_speak():
			var line := _pick_line()
			if line != "":
				_say(line)


func _on_hatched(species: String) -> void:
	# 부화 인사: 캐릭터 첫 대사 (base pool의 첫 줄)
	var lines: Array = _lines_for_species(species)
	if not lines.is_empty():
		await get_tree().create_timer(1.2).timeout
		_say(lines[0])


func _can_speak() -> bool:
	if _sm.settings.get("focus_mode", false):
		return false
	if _sm.pomodoro_work:
		return false  # 집중 시간엔 조용히 (FR-22)
	if _sm.settings.get("bubble_frequency", "normal") == "off":
		return false
	if _ps.activity == _ps.Activity.SLEEPING:
		return false
	return true


func _schedule() -> void:
	var freq: String = _sm.settings.get("bubble_frequency", "normal") if _sm != null else "normal"
	var range_sec: Array = FREQ_SECONDS.get(freq, FREQ_SECONDS["normal"])
	_next_in = randf_range(range_sec[0], range_sec[1])


func _pick_line() -> String:
	if _ps.stage == "egg":
		var egg_pool: Array = Dialog.COMMON["egg"]
		for i in 8:
			var egg_line: String = egg_pool[randi() % egg_pool.size()]
			if egg_line not in _recent:
				return egg_line
		return ""
	var dt := Time.get_datetime_dict_from_system()
	var trigger := _match_trigger(dt)
	if trigger != "":
		_fired_today[trigger] = dt.day
		# 캐릭터별 override 우선 (현재 stage → base 폴백)
		var override_line: String = _char_trigger_override(_ps.species, trigger)
		if override_line != "":
			return override_line
		var pool: Array = Dialog.COMMON[trigger]
		return pool[randi() % pool.size()]
	# 랜덤: 캐릭터 전용 60% / 공통 40% (진화 단계에 맞는 pool 선택)
	var char_lines: Array = _lines_for_species(_ps.species)
	var pool2: Array = char_lines if (randf() < 0.6 and not char_lines.is_empty()) else Dialog.COMMON["random"]
	for i in 8:
		var line: String = pool2[randi() % pool2.size()]
		if line not in _recent:
			return line
	return ""


## 캐릭터의 현재 진화 단계에 맞는 랜덤 대사 pool 반환 (evolved_2 > evolved > base)
## 구조: entry[stage]는 Array(구형) 또는 Dictionary{"random": [...], trigger overrides}
func _lines_for_species(species: String) -> Array:
	var entry = Dialog.BY_CHARACTER.get(species)
	if entry == null:
		return []
	if entry is Array:
		return entry  # 구형(단순 리스트) 호환
	if not (entry is Dictionary):
		return []
	var key: String = _current_stage_key()
	# 현재 stage → base 폴백
	for k in [key, "base"]:
		var stage_data = entry.get(k)
		if stage_data is Array and not (stage_data as Array).is_empty():
			return stage_data
		if stage_data is Dictionary:
			var lines: Array = stage_data.get("random", [])
			if not lines.is_empty():
				return lines
	return []


## 현재 stage의 트리거 override 반환 ("" 이면 폴백 사용)
func _char_trigger_override(species: String, trigger: String) -> String:
	var entry = Dialog.BY_CHARACTER.get(species)
	if not (entry is Dictionary):
		return ""
	# 현재 stage → base 폴백
	for k in [_current_stage_key(), "base"]:
		var stage_data = entry.get(k)
		if not (stage_data is Dictionary):
			continue
		if not stage_data.has(trigger):
			continue
		var val = stage_data[trigger]
		if val is String and val != "":
			return val
		if val is Array and not (val as Array).is_empty():
			return val[randi() % val.size()]
	return ""


func _current_stage_key() -> String:
	if _ps.evolved_2:
		return "e2"
	if _ps.evolved:
		return "e1"
	return "base"


func _match_trigger(dt: Dictionary) -> String:
	var h: int = dt.hour
	var wd: int = dt.weekday  # 0=일요일
	var checks := [
		["payday", dt.day == 25],
		["monday_morning", wd == 1 and h >= 9 and h < 12],
		["before_lunch", h == 11 and dt.minute >= 30],
		["three_pm", h == 15],
		["quitting_time", h == 18],
		["overtime", h >= 20 and h < 24],
		["friday_afternoon", wd == 5 and h >= 14 and h < 18],
		["tuesday", wd == 2 and h >= 9 and h < 18],
		["wednesday", wd == 3 and h >= 9 and h < 18],
		["thursday", wd == 4 and h >= 9 and h < 18],
	]
	for entry in checks:
		if entry[1] and _fired_today.get(entry[0], -1) != dt.day:
			return entry[0]
	return ""


func _say(line: String) -> void:
	print("bubble: ", line)
	_recent.append(line)
	if _recent.size() > RECENT_LIMIT:
		_recent.pop_front()
	bubble.say(line, pet, screen_size)
