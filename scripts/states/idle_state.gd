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
		if randf() < 0.65:
			machine.transition_to("Walk")
		else:
			_timer = randf_range(3.0, 8.0)
			pet.idle_breathe()
