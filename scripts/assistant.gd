# Plan FR-21~23 — 리마인더 발화 + 뽀모도로 타이머 + 할 일 보상.
# UI는 scenes/ui/notebook.gd, 이 노드는 시간 판정과 보상 로직만 담당한다.
extends Node

signal pomodoro_changed(phase: String, remaining: float)

const WORK_MINUTES := 25.0
const BREAK_MINUTES := 5.0
const REMINDER_BUBBLE_SECONDS := 15.0

var pet: Node2D
var bubble: Node
var screen_size := Vector2.ZERO

var pomodoro_phase := "idle"   # idle | work | break
var pomodoro_left := 0.0

@onready var _sm: Node = get_node("/root/SaveManager")
@onready var _ps: Node = get_node("/root/PetState")

var _clock_accum := 0.0


func setup(pet_node: Node2D, bubble_node: Node, size: Vector2) -> void:
	pet = pet_node
	bubble = bubble_node
	screen_size = size
	_reset_todos_if_new_day()


func _process(delta: float) -> void:
	_tick_pomodoro(delta)
	_clock_accum += delta
	if _clock_accum >= 1.0:
		_clock_accum = 0.0
		_check_reminders()


# --- 리마인더 (FR-21) ---

func add_reminder(text: String, hour: int, minute: int, repeat: String) -> void:
	var reminders: Array = _sm.settings["reminders"]
	reminders.append({
		"text": text, "hour": hour, "minute": minute,
		"repeat": repeat, "last_fired": "",
	})
	_sm.save_game()


func remove_reminder(index: int) -> void:
	var reminders: Array = _sm.settings["reminders"]
	if index >= 0 and index < reminders.size():
		reminders.remove_at(index)
		_sm.save_game()


func _check_reminders() -> void:
	var dt := Time.get_datetime_dict_from_system()
	var today := "%04d-%02d-%02d" % [dt.year, dt.month, dt.day]
	var reminders: Array = _sm.settings["reminders"]
	var fired_once: Array = []
	for r in reminders:
		if int(r["hour"]) != dt.hour or int(r["minute"]) != dt.minute:
			continue
		if r.get("last_fired", "") == today:
			continue
		if r["repeat"] == "weekdays" and (dt.weekday == 0 or dt.weekday == 6):
			continue
		r["last_fired"] = today
		_fire_reminder(String(r["text"]))
		if r["repeat"] == "once":
			fired_once.append(r)
	for r in fired_once:
		reminders.erase(r)
	if not fired_once.is_empty():
		_sm.save_game()


func _fire_reminder(text: String) -> void:
	bubble.say("⏰ %s 시간이야!! 잊지 마!!" % text, pet, screen_size, REMINDER_BUBBLE_SECONDS)
	pet.celebrate()


# --- 뽀모도로 (FR-22) ---

func pomodoro_start() -> void:
	pomodoro_phase = "work"
	pomodoro_left = WORK_MINUTES * 60.0
	_sm.pomodoro_work = true
	bubble.say("좋아, %d분 집중! 나도 옆에서 조용히 응원할게" % int(WORK_MINUTES), pet, screen_size)
	pomodoro_changed.emit(pomodoro_phase, pomodoro_left)


func pomodoro_stop() -> void:
	pomodoro_phase = "idle"
	pomodoro_left = 0.0
	_sm.pomodoro_work = false
	pomodoro_changed.emit(pomodoro_phase, pomodoro_left)


func _tick_pomodoro(delta: float) -> void:
	if pomodoro_phase == "idle":
		return
	pomodoro_left -= delta
	if pomodoro_left > 0.0:
		return
	if pomodoro_phase == "work":
		pomodoro_phase = "break"
		pomodoro_left = BREAK_MINUTES * 60.0
		_sm.pomodoro_work = false
		_ps.reward_happiness(10.0)
		pet.celebrate()
		bubble.say("집중 완료!! 수고했어!! %d분만 쉬자. 기지개 한 번!" % int(BREAK_MINUTES), pet, screen_size, 10.0)
	else:
		pomodoro_phase = "idle"
		bubble.say("휴식 끝~ 다음 라운드 갈래? (수첩에서 시작)", pet, screen_size, 8.0)
	pomodoro_changed.emit(pomodoro_phase, pomodoro_left)


# --- 할 일 (FR-23) ---

func add_todo(text: String) -> bool:
	_reset_todos_if_new_day()
	var todos: Array = _sm.settings["todos"]
	if todos.size() >= 3:
		return false
	todos.append({"text": text, "done": false})
	_sm.save_game()
	return true


func set_todo_done(index: int, done: bool) -> void:
	var todos: Array = _sm.settings["todos"]
	if index < 0 or index >= todos.size():
		return
	var was_done: bool = todos[index]["done"]
	todos[index]["done"] = done
	_sm.save_game()
	if done and not was_done:
		_ps.reward_happiness(15.0)
		pet.celebrate()
		var all_done := true
		for t in todos:
			if not t["done"]:
				all_done = false
				break
		if all_done and todos.size() >= 1:
			_ps.reward_happiness(15.0)
			bubble.say("오늘 할 일 전부 완료!! 네가 제일 대단해!! 🎉", pet, screen_size, 10.0)
		else:
			bubble.say("하나 해치웠다! 잘한다 잘한다~", pet, screen_size)


func remove_todo(index: int) -> void:
	var todos: Array = _sm.settings["todos"]
	if index >= 0 and index < todos.size():
		todos.remove_at(index)
		_sm.save_game()


func _reset_todos_if_new_day() -> void:
	var dt := Time.get_datetime_dict_from_system()
	var today := "%04d-%02d-%02d" % [dt.year, dt.month, dt.day]
	if _sm.settings.get("todos_date", "") != today:
		_sm.settings["todos_date"] = today
		_sm.settings["todos"] = []
		_sm.save_game()
