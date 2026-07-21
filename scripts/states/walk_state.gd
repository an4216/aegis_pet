# 걷기: 화면 하단(작업표시줄 위)을 좌우로 이동. 종족별 속도 보정 적용.
extends "res://scripts/states/state.gd"

var _target_x := 0.0


func enter() -> void:
	pet.ps.activity = pet.ps.Activity.ACTIVE
	var margin := 80.0
	_target_x = randf_range(margin, pet.screen_size.x - margin)
	pet.face_towards(_target_x)
	pet.walk_bob(true)


func exit() -> void:
	pet.walk_bob(false)


func update(delta: float) -> void:
	var speed: float = pet.move_speed()
	var dx := _target_x - pet.position.x
	if absf(dx) <= speed * delta:
		pet.position.x = _target_x
		machine.transition_to("Idle")
		return
	pet.position.x += signf(dx) * speed * delta
