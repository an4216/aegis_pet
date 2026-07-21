# 집힘: 마우스를 따라다니며 버둥거림. 놓으면 Fall로.
extends "res://scripts/states/state.gd"


func enter() -> void:
	pet.ps.activity = pet.ps.Activity.ACTIVE
	pet.wiggle(true)


func exit() -> void:
	pet.wiggle(false)


func update(_delta: float) -> void:
	var mouse := pet.get_viewport().get_mouse_position()
	pet.position = pet.position.lerp(mouse, 0.5)
	if not pet.is_mouse_pressed():
		machine.transition_to("Fall")
