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
	# 부화 인사: 캐릭터 첫 대사
	var lines: Array = Dialog.BY_CHARACTER.get(species, [])
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
		var pool: Array = Dialog.COMMON[trigger]
		return pool[randi() % pool.size()]
	# 랜덤: 캐릭터 전용 60% / 공통 40%
	var char_lines: Array = Dialog.BY_CHARACTER.get(_ps.species, [])
	var pool2: Array = char_lines if (randf() < 0.6 and not char_lines.is_empty()) else Dialog.COMMON["random"]
	for i in 8:
		var line: String = pool2[randi() % pool2.size()]
		if line not in _recent:
			return line
	return ""


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
