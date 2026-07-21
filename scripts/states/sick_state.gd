# 병듦: 이동 정지, 창백한 표정. medicine으로 회복 시 전역 체크가 Idle로 되돌린다.
extends "res://scripts/states/state.gd"


func enter() -> void:
	pet.ps.activity = pet.ps.Activity.IDLE
	pet.set_sprite_tint(Color(0.75, 0.95, 0.78))
	pet.show_sick(true)


func exit() -> void:
	pet.set_sprite_tint(Color.WHITE)
	pet.show_sick(false)
