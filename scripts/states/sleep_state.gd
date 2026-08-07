# 잠자기: 화면 구석으로 이동 후 Zzz. 에너지 회복은 PetState(activity=SLEEPING)가 처리.
extends "res://scripts/states/state.gd"

const Characters := preload("res://scripts/data/characters.gd")

var _at_corner := false
var _corner_x := 0.0
var _use_animated_sleep := false


func enter() -> void:
	_at_corner = false
	_use_animated_sleep = false
	var margin: float = pet.horizontal_edge_margin()
	_corner_x = margin if pet.position.x < pet.screen_size.x * 0.5 else pet.screen_size.x - margin
	pet.face_towards(_corner_x)
	pet.ps.activity = pet.ps.Activity.ACTIVE  # 이동 중
	pet.play_state_animation("Walk")


func exit() -> void:
	pet.show_zzz(false)
	pet.set_sprite_tint(Color.WHITE)
	if _use_animated_sleep:
		pet.stop_animated_sleep()
		_use_animated_sleep = false
	pet.set_pose("idle")


func update(delta: float) -> void:
	if not _at_corner:
		var speed: float = pet.move_speed() * 0.6
		var dx := _corner_x - pet.position.x
		if absf(dx) <= speed * delta:
			pet.position.x = _corner_x
			_at_corner = true
			pet.ps.activity = pet.ps.Activity.SLEEPING
			if pet._is_animated_pet():
				pet.play_state_animation("Sleep")
				pet.show_zzz(true)
				pet.set_sprite_tint(Color(0.75, 0.75, 0.85))
			elif pet.start_animated_sleep():
				# 포즈 캐릭터 중 잠자기 전용 다중 프레임 시트가 있는 종족(삐약 계열).
				# 시트에 Zzz가 없으므로 라벨만 붙이고, 틴트는 쓰지 않는다 — 포즈 캐릭터의
				# 정지 sleep 경로가 원래 틴트 없이 동작했고, 청보라 곱연산을 걸면 노란 삐약이가
				# 올리브색으로 탁해진다(QA 실측: idle 255,255,255 → sleep 190,190,216).
				_use_animated_sleep = true
				pet.show_zzz(true)
				pet.set_sprite_tint(Color.WHITE)
			elif pet.has_poses():
				pet.set_pose("sleep")
				# 보통은 아트에 Zzz가 그려져 있어 라벨·틴트를 생략한다. 아트에 없는 종족
				# (당근이: 2026-08-07 재추출에서 제작 가이드 §2 위반인 떠 있는 "z"를 제거)만
				# 라벨을 대신 띄운다 — 없으면 자는 표시가 화면에 아무것도 남지 않는다.
				# 틴트는 여기서도 쓰지 않는다(위 삐약 분기와 같은 이유: 곱연산이 색을 탁하게 만든다).
				pet.show_zzz(Characters.pose_sleep_needs_zzz_label(pet.ps.species))
			else:
				pet.show_zzz(true)
				pet.set_sprite_tint(Color(0.75, 0.75, 0.85))
		else:
			pet.position.x += signf(dx) * speed * delta
		return
	# 기상 조건: 에너지 충분 + 밤 아님 + 집중 모드 아님
	if pet.ps.stats["energy"] >= 95.0 and not machine.must_sleep():
		machine.transition_to("Idle")
