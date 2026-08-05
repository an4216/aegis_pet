# Short landing state so the landing sprite sheet completes before idle resumes.
extends "res://scripts/states/state.gd"

const LAND_DURATION := 0.45

var _timer := 0.0


func enter() -> void:
	pet.ps.activity = pet.ps.Activity.IDLE
	_timer = LAND_DURATION
	pet.land_squish()


func update(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		machine.transition_to("Idle")
