# 걷기: 화면 하단(작업표시줄 위)을 좌우로 이동. 종족별 속도 보정 적용.
extends "res://scripts/states/state.gd"

const FRAME_SECONDS := 0.22

var _target_x := 0.0
var _anim_t := 0.0
var _frame := 0


func enter() -> void:
	pet.ps.activity = pet.ps.Activity.ACTIVE
	var margin := 80.0
	_target_x = randf_range(margin, pet.screen_size.x - margin)
	pet.face_towards(_target_x)
	pet.walk_bob(true)
	_anim_t = 0.0
	_frame = 0
	pet.set_pose("walk1")


func exit() -> void:
	pet.walk_bob(false)
	pet.set_pose("idle")


func update(delta: float) -> void:
	_anim_t += delta
	if _anim_t >= FRAME_SECONDS:
		_anim_t = 0.0
		_frame = 1 - _frame
		pet.set_pose("walk1" if _frame == 0 else "walk2")
	var speed: float = pet.move_speed()
	var dx := _target_x - pet.position.x
	if absf(dx) <= speed * delta:
		pet.position.x = _target_x
		machine.transition_to("Idle")
		return
	pet.position.x += signf(dx) * speed * delta
