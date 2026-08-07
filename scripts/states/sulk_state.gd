# 시무룩: 구석에 웅크림. 행복 회복 시 전역 체크가 Idle로 되돌린다.
extends "res://scripts/states/state.gd"

var _at_corner := false
var _corner_x := 0.0
var _use_animated_sulk := false


func enter() -> void:
	_at_corner = false
	var margin: float = pet.horizontal_edge_margin()
	_corner_x = margin if pet.position.x < pet.screen_size.x * 0.5 else pet.screen_size.x - margin
	pet.face_towards(_corner_x)
	pet.ps.activity = pet.ps.Activity.ACTIVE
	# 삐침 전용 다중 프레임 시트가 있는 종족은 그쪽을 쓴다. 틴트는 걸지 않는다 — 아트가 이미
	# 삐친 표정을 그리고 있고, 회색 곱연산은 노란 삐약이를 탁하게 만든다.
	_use_animated_sulk = pet.start_animated_pose("Sulk")
	if _use_animated_sulk:
		pet.set_sprite_tint(Color.WHITE)
	elif pet.has_poses():
		pet.set_pose("sulk")
	else:
		pet.set_sprite_tint(Color(0.8, 0.8, 0.8))


func exit() -> void:
	if _use_animated_sulk:
		pet.stop_animated_pose()
		_use_animated_sulk = false
	pet.set_sprite_tint(Color.WHITE)
	pet.set_pose("idle")


func update(delta: float) -> void:
	if _at_corner:
		return
	var speed: float = pet.move_speed() * 0.5
	var dx := _corner_x - pet.position.x
	if absf(dx) <= speed * delta:
		pet.position.x = _corner_x
		_at_corner = true
		pet.ps.activity = pet.ps.Activity.IDLE
		# 웅크림 스케일 트윈은 시트가 웅크린 자세를 이미 그리고 있으면 이중 압축이 된다.
		if not _use_animated_sulk:
			pet.sulk_crouch()
	else:
		pet.position.x += signf(dx) * speed * delta
