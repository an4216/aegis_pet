# 응아: 1초 웅크림 (응아 생성은 main이 pooped 시그널로 처리).
extends "res://scripts/states/state.gd"

var _timer := 0.0


func enter() -> void:
	pet.ps.activity = pet.ps.Activity.IDLE
	_timer = 1.0
	pet.squat()


func update(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		machine.transition_to("Idle")
