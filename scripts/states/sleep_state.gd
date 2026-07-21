# 잠자기: 화면 구석으로 이동 후 Zzz. 에너지 회복은 PetState(activity=SLEEPING)가 처리.
extends "res://scripts/states/state.gd"

var _at_corner := false
var _corner_x := 0.0


func enter() -> void:
	_at_corner = false
	var margin := 90.0
	_corner_x = margin if pet.position.x < pet.screen_size.x * 0.5 else pet.screen_size.x - margin
	pet.face_towards(_corner_x)
	pet.ps.activity = pet.ps.Activity.ACTIVE  # 이동 중


func exit() -> void:
	pet.show_zzz(false)
	pet.set_sprite_tint(Color.WHITE)


func update(delta: float) -> void:
	if not _at_corner:
		var speed: float = pet.move_speed() * 0.6
		var dx := _corner_x - pet.position.x
		if absf(dx) <= speed * delta:
			pet.position.x = _corner_x
			_at_corner = true
			pet.ps.activity = pet.ps.Activity.SLEEPING
			pet.show_zzz(true)
			pet.set_sprite_tint(Color(0.75, 0.75, 0.85))
		else:
			pet.position.x += signf(dx) * speed * delta
		return
	# 기상 조건: 에너지 충분 + 밤 아님 + 집중 모드 아님
	if pet.ps.stats["energy"] >= 95.0 and not machine.must_sleep():
		machine.transition_to("Idle")
