# 낙하: 중력으로 떨어져 바닥에 착지(찌부 애니메이션) 후 Idle.
extends "res://scripts/states/state.gd"

const GRAVITY := 2400.0

var _vy := 0.0
var _use_animated_fall := false


func enter() -> void:
	pet.ps.activity = pet.ps.Activity.ACTIVE
	_vy = 0.0
	# 낙하 전용 다중 프레임 시트가 있는 종족만 재생. 정지 포즈에는 낙하 전용 아트가 없어
	# (POSES에 fall 없음) 폴백은 직전 포즈를 그대로 유지한다 — 기존 동작과 동일.
	_use_animated_fall = pet.start_animated_pose("Fall")


func exit() -> void:
	if _use_animated_fall:
		pet.stop_animated_pose()
		_use_animated_fall = false


func update(delta: float) -> void:
	_vy += GRAVITY * delta
	pet.position.y += _vy * delta
	if pet.position.y >= pet.ground_y:
		pet.position.y = pet.ground_y
		machine.transition_to("Land")
