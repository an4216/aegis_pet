# 대기: 잠시 두리번거리다 확률적으로 걷기 시작.
extends "res://scripts/states/state.gd"

var _timer := 0.0
var _use_animated_idle := false


func enter() -> void:
	pet.ps.activity = pet.ps.Activity.IDLE
	pet.show_zzz(false)
	# Idle 전용 다중 프레임 시트가 있는 종족은 그쪽을 쓰고, 없으면 기존 정지 포즈 폴백.
	_use_animated_idle = pet.start_animated_pose("Idle")
	_timer = randf_range(3.0, 8.0)
	if _use_animated_idle:
		return
	pet.set_pose("idle")
	# 호흡 트윈은 시트가 이미 호흡을 그리고 있으면 이중으로 겹친다 (pet.idle_breathe도 내부에서
	# 막지만, 시트 재생 중임을 여기서 명시해 폴백 경로와 구분한다).
	pet.idle_breathe()


func exit() -> void:
	if _use_animated_idle:
		pet.stop_animated_pose()
		_use_animated_idle = false


func update(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		if get_node("/root/SaveManager").pomodoro_work:
			_timer = randf_range(5.0, 10.0)  # 집중 시간엔 얌전히 대기 (FR-22)
			return
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
	var sm := get_node("/root/SaveManager")
	if not sm.settings.get("window_play", false):
		return false  # 창 위 놀이 꺼짐 (기본값) — 업무 방해 방지
	if pet.probe == null or not pet.probe.available:
		return false
	if pet.jump_cooldown > 0.0:
		return false
	var plats: Array = pet.probe.platforms(Rect2(Vector2.ZERO, pet.screen_size), pet.ground_y)
	if plats.is_empty():
		return false
	var win: Dictionary = plats[randi() % plats.size()]
	pet.jump_target_id = win["id"]
	pet.jump_target_rect = win["rect"]
	machine.transition_to("Jump")
	return true
