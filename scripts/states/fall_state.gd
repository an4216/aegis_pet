# 낙하: 중력으로 떨어져 바닥에 착지(찌부 애니메이션) 후 Idle.
extends "res://scripts/states/state.gd"

const GRAVITY := 2400.0

var _vy := 0.0


func enter() -> void:
	pet.ps.activity = pet.ps.Activity.ACTIVE
	_vy = 0.0


func update(delta: float) -> void:
	_vy += GRAVITY * delta
	pet.position.y += _vy * delta
	if pet.position.y >= pet.ground_y:
		pet.position.y = pet.ground_y
		pet.land_squish()
		machine.transition_to("Idle")
