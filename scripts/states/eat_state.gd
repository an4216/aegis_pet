# 먹기: 케어(feed/snack) 시 2초간 오물오물.
extends "res://scripts/states/state.gd"

var _timer := 0.0


func enter() -> void:
	pet.ps.activity = pet.ps.Activity.IDLE
	_timer = 2.0
	pet.eat_munch()


func update(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		machine.transition_to("Idle")
