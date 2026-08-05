# 걷기: 화면 하단(작업표시줄 위)을 좌우로 이동. 종족별 속도 보정 적용.
extends "res://scripts/states/state.gd"

const FRAME_SECONDS := 0.22
const Characters := preload("res://scripts/data/characters.gd")

var _target_x := 0.0
var _anim_t := 0.0
var _frame := 0
var _face_mirrored := false
var _walk_static := false


func enter() -> void:
	pet.ps.activity = pet.ps.Activity.ACTIVE
	var margin: float = pet.horizontal_edge_margin()
	_target_x = randf_range(margin, pet.screen_size.x - margin)
	pet.face_towards(_target_x)
	_walk_static = Characters.is_walk_static(pet.ps.species)
	# 걷기 프레임이 하나뿐인 캐릭터는 waddle(좌우 흔들기) 모션으로 보완
	pet.walk_bob(true, _walk_static)
	# 걷기 시트가 뒤돌아본 상태인 캐릭터는 좌우 반전
	if Characters.is_walk_face_inverted(pet.ps.species):
		pet.mirror_face()
		_face_mirrored = true
	_anim_t = 0.0
	_frame = 0
	pet.set_pose("walk1")


func exit() -> void:
	pet.walk_bob(false)
	if _face_mirrored:
		pet.mirror_face()
		_face_mirrored = false
	pet.set_pose("idle")


func update(delta: float) -> void:
	_anim_t += delta
	if _anim_t >= FRAME_SECONDS and not _walk_static:
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
