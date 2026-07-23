# 알: 화면 하단 고정, 주기적 흔들림. 클릭은 pet.gd가 PetState.click_egg()로 전달.
extends "res://scripts/states/state.gd"

var _shake_timer := 0.0


func enter() -> void:
	pet.ps.activity = pet.ps.Activity.IDLE
	# 알은 1번 모니터 중앙 하단에 스폰 (듀얼모니터에서 경계에 뜨는 문제 방지)
	var center_x: float = pet.primary_local.get_center().x if pet.primary_local.size.x > 0.0 else pet.screen_size.x * 0.5
	pet.position = Vector2(center_x, pet.ground_y)
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
