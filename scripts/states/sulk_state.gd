# 시무룩: 구석에 웅크림. 행복 회복 시 전역 체크가 Idle로 되돌린다.
extends "res://scripts/states/state.gd"

var _at_corner := false
var _corner_x := 0.0


func enter() -> void:
	_at_corner = false
	var margin := 90.0
	_corner_x = margin if pet.position.x < pet.screen_size.x * 0.5 else pet.screen_size.x - margin
	pet.face_towards(_corner_x)
	pet.ps.activity = pet.ps.Activity.ACTIVE
	pet.set_sprite_tint(Color(0.8, 0.8, 0.8))


func exit() -> void:
	pet.set_sprite_tint(Color.WHITE)


func update(delta: float) -> void:
	if _at_corner:
		return
	var speed: float = pet.move_speed() * 0.5
	var dx := _corner_x - pet.position.x
	if absf(dx) <= speed * delta:
		pet.position.x = _corner_x
		_at_corner = true
		pet.ps.activity = pet.ps.Activity.IDLE
		pet.sulk_crouch()
	else:
		pet.position.x += signf(dx) * speed * delta
