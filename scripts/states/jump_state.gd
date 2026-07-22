# 점프: 포물선을 그리며 목표 창 상단으로 뛰어오른다 (Phase 2, FR-13).
extends "res://scripts/states/state.gd"

const DURATION := 0.7
const ARC_HEIGHT := 120.0

var _t := 0.0
var _from := Vector2.ZERO
var _to := Vector2.ZERO


func enter() -> void:
	pet.ps.activity = pet.ps.Activity.ACTIVE
	_t = 0.0
	_from = pet.position
	_to = Vector2(
		clampf(pet.jump_target_rect.get_center().x, pet.jump_target_rect.position.x + 40.0,
			pet.jump_target_rect.end.x - 40.0),
		pet.jump_target_rect.position.y,
	)
	pet.face_towards(_to.x)


func update(delta: float) -> void:
	_t += delta / DURATION
	if _t >= 1.0:
		pet.position = _to
		machine.transition_to("Perch")
		return
	var pos := _from.lerp(_to, _t)
	pos.y -= ARC_HEIGHT * 4.0 * _t * (1.0 - _t)  # 포물선
	pet.position = pos
