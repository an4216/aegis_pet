# 알: 화면 하단 고정, 주기적 흔들림. 클릭은 pet.gd가 PetState.click_egg()로 전달.
extends "res://scripts/states/state.gd"

var _shake_timer := 0.0


func enter() -> void:
	pet.ps.activity = pet.ps.Activity.IDLE
	pet.position = Vector2(pet.screen_size.x * 0.5, pet.ground_y)
	_shake_timer = _next_shake()


func update(delta: float) -> void:
	if pet.ps.stage != "egg":
		pet.refresh_appearance()  # 알 프레임 → 부화 종족 프레임 전환
		pet.hatch_pop()
		machine.transition_to("Idle")
		return
	if pet.ps.hatch_progress >= 80.0:
		pet.set_pose("crack")  # 부화 임박 연출
	_shake_timer -= delta
	if _shake_timer <= 0.0:
		pet.shake()
		_shake_timer = _next_shake()


func _next_shake() -> float:
	return randf_range(4.0, 10.0)
