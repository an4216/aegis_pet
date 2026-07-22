# 대기: 잠시 두리번거리다 확률적으로 걷기 시작.
extends "res://scripts/states/state.gd"

var _timer := 0.0


func enter() -> void:
	pet.ps.activity = pet.ps.Activity.IDLE
	pet.show_zzz(false)
	_timer = randf_range(3.0, 8.0)
	pet.idle_breathe()


func update(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		var roll := randf()
		if roll < 0.6:
			machine.transition_to("Walk")
		elif roll < 0.8 and _try_jump():
			return
		else:
			_timer = randf_range(3.0, 8.0)
			pet.idle_breathe()


## 열린 창이 있으면 그 위로 점프 (Phase 2, FR-13)
func _try_jump() -> bool:
	if pet.probe == null or not pet.probe.available:
		return false
	var plats: Array = pet.probe.platforms(Rect2(Vector2.ZERO, pet.screen_size), pet.ground_y)
	if plats.is_empty():
		return false
	var win: Dictionary = plats[randi() % plats.size()]
	pet.jump_target_id = win["id"]
	pet.jump_target_rect = win["rect"]
	machine.transition_to("Jump")
	return true
