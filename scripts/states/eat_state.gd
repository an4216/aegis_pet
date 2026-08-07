# 먹기: 케어(feed/snack) 시 2초간 오물오물.
extends "res://scripts/states/state.gd"

var _timer := 0.0
var _use_animated_eat := false


func enter() -> void:
	pet.ps.activity = pet.ps.Activity.IDLE
	_timer = 2.0
	# feed/snack은 몸동작(Eat)이 같다 — 옆에 뜨는 음식 소품으로만 구분한다.
	# 종족에 소품이 등록 안 돼 있으면 아무것도 안 뜨고 기존 동작 그대로다(하위 호환).
	pet.show_food_prop(_timer)
	# 먹기 전용 다중 프레임 시트가 있는 종족은 그쪽을 쓰고, 없으면 기존 정지 포즈 + 오물오물 트윈.
	_use_animated_eat = pet.start_animated_pose("Eat")
	if _use_animated_eat:
		return
	pet.set_pose("eat")
	pet.eat_munch()


func exit() -> void:
	pet.hide_food_prop()
	if _use_animated_eat:
		pet.stop_animated_pose()
		_use_animated_eat = false
	pet.set_pose("idle")


func update(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		machine.transition_to("Idle")
