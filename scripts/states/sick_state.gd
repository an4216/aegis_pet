# 병듦: 이동 정지, 창백한 표정. medicine으로 회복 시 전역 체크가 Idle로 되돌린다.
extends "res://scripts/states/state.gd"


var _use_animated_sick := false


func enter() -> void:
	pet.ps.activity = pet.ps.Activity.IDLE
	_use_animated_sick = pet.start_animated_pose("Sick")
	if _use_animated_sick:
		# 틴트는 쓰지 않는다: 정지 포즈 경로도 아트가 있으면 틴트를 안 걸고, 초록 곱연산을 걸면
		# 노란 삐약이가 탁해진다 (잠자기 청보라 틴트에서 이미 같은 문제를 겪었다).
		pet.set_sprite_tint(Color.WHITE)
		# 시트가 어지럼 기호를 직접 그리지 않는 종족만 @_@ 라벨을 띄운다 (삐약: 제작 가이드 §2가
		# 분리 이펙트를 금지해 시트에서 제외됨). 시트에 기호가 있는 종족은 이중 표시가 된다.
		pet.show_sick(bool(pet.animated_pose_option("Sick", "runtime_sick_mark", false)))
	elif pet.has_poses():
		pet.set_pose("sick")  # 아트에 어지럼 표시 포함 — 틴트·라벨 생략
	else:
		pet.set_sprite_tint(Color(0.75, 0.95, 0.78))
		pet.show_sick(true)


func exit() -> void:
	if _use_animated_sick:
		pet.stop_animated_pose()
		_use_animated_sick = false
	pet.set_sprite_tint(Color.WHITE)
	pet.show_sick(false)
	pet.set_pose("idle")
