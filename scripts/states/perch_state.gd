# 창 위 생활: 창 상단에 앉거나 걷는다. 창이 사라지거나 움직이면 추적/낙하 (FR-13, FR-14).
extends "res://scripts/states/state.gd"

var _stay := 0.0
var _walk_target := 0.0
var _walking := false


func enter() -> void:
	pet.platform_id = pet.jump_target_id
	pet.platform_rect = pet.jump_target_rect
	pet.ps.activity = pet.ps.Activity.IDLE
	_stay = randf_range(20.0, 60.0)
	_walking = false
	pet.idle_breathe()
	print("perch: enter id=", pet.platform_id, " stay=", snappedf(_stay, 0.1))


func exit() -> void:
	pet.platform_id = -1
	pet.walk_bob(false)
	pet.jump_cooldown = randf_range(90.0, 240.0)  # 내려온 뒤엔 한동안 지상 생활


func update(delta: float) -> void:
	# 병듦/수면/시무룩은 지상에서 처리 — 내려가서 전역 체크에 맡긴다
	if pet.ps.is_sick or pet.ps.is_sulking or machine.must_sleep():
		machine.transition_to("Fall")
		return
	var win: Dictionary = pet.probe.find_by_id(pet.platform_id) if pet.probe != null else {}
	if win.is_empty():
		machine.transition_to("Fall")  # 창이 닫힘/최소화 → 낙하 (FR-14)
		return
	var r: Rect2 = win["rect"]
	# 화면 안에 보이는 부분만 발판으로 사용 (멀티모니터 경계 보호)
	var on_screen := r.intersection(Rect2(Vector2.ZERO, pet.screen_size))
	if on_screen.size.x < 60.0:
		machine.transition_to("Fall")
		return
	r = Rect2(on_screen.position.x, r.position.y, on_screen.size.x, r.size.y)
	# 창 이동 추적: y는 항상 상단에 붙이고, x는 창 이동량만큼 따라간다
	pet.position.x += r.position.x - pet.platform_rect.position.x
	pet.position.y = r.position.y
	pet.platform_rect = r
	if pet.position.x < r.position.x + 20.0 or pet.position.x > r.end.x - 20.0:
		machine.transition_to("Fall")  # 발판 밖으로 밀려남 → 낙하
		return

	_stay -= delta
	if _stay <= 0.0:
		print("perch: stay 만료 → fall")
		machine.transition_to("Fall")  # 다 놀았으면 뛰어내리기
		return

	if _walking:
		var speed: float = pet.move_speed() * 0.7
		var dx := _walk_target - pet.position.x
		if absf(dx) <= speed * delta:
			_walking = false
			pet.walk_bob(false)
			pet.ps.activity = pet.ps.Activity.IDLE
		else:
			pet.position.x += signf(dx) * speed * delta
	elif randf() < delta * 0.15:  # 가끔 창 위에서 산책
		_walk_target = randf_range(r.position.x + 30.0, r.end.x - 30.0)
		pet.face_towards(_walk_target)
		pet.walk_bob(true)
		pet.ps.activity = pet.ps.Activity.ACTIVE
		_walking = true
