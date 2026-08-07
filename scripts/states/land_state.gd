# Short landing state so the landing sprite sheet completes before idle resumes.
extends "res://scripts/states/state.gd"

const LAND_DURATION := 0.45

var _timer := 0.0
var _use_animated_land := false


func enter() -> void:
	pet.ps.activity = pet.ps.Activity.IDLE
	_timer = LAND_DURATION
	# 착지 전용 다중 프레임 시트(loop=false)가 있는 종족은 시트가 스쿼시-복귀를 직접 그린다.
	# 스케일 트윈(land_squish)을 겹치면 이중 압축이 되므로 폴백 경로에서만 쓴다.
	_use_animated_land = pet.start_animated_pose("Land")
	if not _use_animated_land:
		pet.land_squish()


func exit() -> void:
	if _use_animated_land:
		pet.stop_animated_pose()
		_use_animated_land = false


func update(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		machine.transition_to("Idle")
