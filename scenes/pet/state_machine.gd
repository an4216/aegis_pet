# Design Ref: §3.5 — 상태 전이 관리. 우선순위: Dragged > Sick > Sleep(강제) > Sulk > 일반.
extends Node

const STATE_SCRIPTS := {
	"Egg": "res://scripts/states/egg_state.gd",
	"Idle": "res://scripts/states/idle_state.gd",
	"Walk": "res://scripts/states/walk_state.gd",
	"Sleep": "res://scripts/states/sleep_state.gd",
	"Eat": "res://scripts/states/eat_state.gd",
	"Poop": "res://scripts/states/poop_state.gd",
	"Sick": "res://scripts/states/sick_state.gd",
	"Sulk": "res://scripts/states/sulk_state.gd",
	"Dragged": "res://scripts/states/dragged_state.gd",
	"Fall": "res://scripts/states/fall_state.gd",
}
const UNINTERRUPTIBLE := ["Egg", "Dragged", "Fall"]

var states := {}
var current: Node = null
var pet: Node2D


func setup(pet_node: Node2D) -> void:
	pet = pet_node
	for key in STATE_SCRIPTS:
		var state: Node = load(STATE_SCRIPTS[key]).new()
		state.name = key
		state.pet = pet
		state.machine = self
		add_child(state)
		states[key] = state
	transition_to("Egg" if pet.ps.stage == "egg" else "Idle")


func transition_to(key: String) -> void:
	if current == states.get(key):
		return
	if current != null:
		current.exit()
	current = states[key]
	current.enter()


func current_name() -> String:
	return current.name if current != null else ""


func must_sleep() -> bool:
	var tm := get_node("/root/TimeManager")
	var sm := get_node("/root/SaveManager")
	if sm.settings.get("focus_mode", false):
		return true
	var night: bool = tm.is_night(sm.settings["night_start"], sm.settings["night_end"])
	if night and pet.ps.has_special("late_sleep"):
		var h: int = Time.get_datetime_dict_from_system().hour
		night = h >= int(sm.settings["night_start"]) + 1 or h < int(sm.settings["night_end"])
	return night or pet.ps.stats["energy"] <= 15.0


func _process(delta: float) -> void:
	if current == null:
		return
	_check_global()
	current.update(delta)


func _check_global() -> void:
	var state_name := current_name()
	if state_name in UNINTERRUPTIBLE:
		return
	var ps: Node = pet.ps
	# 1) 병듦 (최우선)
	if ps.is_sick:
		if state_name != "Sick":
			transition_to("Sick")
		return
	if state_name == "Sick":
		transition_to("Idle")
		return
	# 2) 수면 (밤/에너지/집중 모드)
	if must_sleep():
		if state_name != "Sleep":
			transition_to("Sleep")
		return
	# 3) 시무룩
	if ps.is_sulking and state_name != "Sulk" and state_name != "Sleep":
		transition_to("Sulk")
		return
	if state_name == "Sulk" and not ps.is_sulking:
		transition_to("Idle")
