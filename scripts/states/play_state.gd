# 놀기: 신나게 뛰어다니는 리액션 (FR: 케어 '놀기' 시각 피드백) 후 Idle 복귀.
extends "res://scripts/states/state.gd"

var _timer := 0.0


func enter() -> void:
	pet.ps.activity = pet.ps.Activity.ACTIVE
	_timer = 2.6
	pet.set_pose("happy")
	pet.play_frolic()


func exit() -> void:
	pet.reset_sprite_pose()
	pet.set_pose("idle")


func update(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		machine.transition_to("Idle")
