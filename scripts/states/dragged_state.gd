# 집힘: 마우스를 따라다니며 버둥거림. 놓으면 Fall로.
extends "res://scripts/states/state.gd"


var _use_animated_dragged := false


func enter() -> void:
	pet.ps.activity = pet.ps.Activity.ACTIVE
	# 매달림 전용 다중 프레임 시트가 있는 종족은 그쪽을 쓴다. 시트가 좌우로 흔들리는 모습을
	# 직접 그리므로 회전 트윈(wiggle)은 걸지 않는다 — 겹치면 이중으로 흔들린다.
	_use_animated_dragged = pet.start_animated_pose("Dragged")
	if not _use_animated_dragged:
		pet.wiggle(true)


func exit() -> void:
	if _use_animated_dragged:
		pet.stop_animated_pose()
		_use_animated_dragged = false
	pet.wiggle(false)


func update(_delta: float) -> void:
	var mouse := pet.get_viewport().get_mouse_position()
	pet.position = pet.position.lerp(mouse, 0.5)
	if not pet.is_mouse_pressed():
		machine.transition_to("Fall")
