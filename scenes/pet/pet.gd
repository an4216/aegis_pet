# Design Ref: §2.1 — 펫 표현(스프라이트·애니메이션·입력). 시뮬레이션은 PetState가 소유.
extends Node2D

signal care_menu_requested(pos: Vector2)

const Characters := preload("res://scripts/data/characters.gd")
const STAGE_SCALE := {"egg": 0.5, "baby": 0.35, "child": 0.42, "adult": 0.5}
const POSES := ["idle", "walk1", "walk2", "sleep", "happy", "sulk", "sick", "eat"]
const EGG_POSES := ["idle", "tilt1", "tilt2", "crack"]
const SPRITE_SIZE := 256.0
const BASE_SPEED := 120.0
const PET_COOLDOWN_SECONDS := 30.0
const DRAG_THRESHOLD := 10.0

var ps: Node
var machine: Node
var probe: Node = null            # scripts/platform/window_probe.gd (main이 주입)
var ground_y := 0.0
var screen_size := Vector2.ZERO
var primary_local: Rect2          # 1번 모니터 로컬 영역 (알 스폰 중앙 계산용)
var platform_id := -1             # 올라가 있는 창 핸들 (-1 = 지상)
var platform_rect := Rect2()
var jump_target_id := -1
var jump_target_rect := Rect2()
var jump_cooldown := 0.0          # 창 위 놀이 사이 휴식 (업무 비방해)

var _sprite: Sprite2D
var _zzz: Label
var _sick_mark: Label
var _evolved_badge: Label
var _base_scale := Vector2.ONE
var _pet_cooldown := 0.0
var _pressed := false
var _press_pos := Vector2.ZERO
var _bob_tween: Tween
var _wiggle_tween: Tween
var _frames := {}          # pose -> Texture2D (포즈 시트 있는 캐릭터만)
var _pose := "idle"


func _ready() -> void:
	ps = get_node("/root/PetState")

	_sprite = Sprite2D.new()
	add_child(_sprite)
	_zzz = _make_mark("Zzz", Color(0.55, 0.62, 0.85))
	_sick_mark = _make_mark("@_@", Color(0.45, 0.65, 0.45))
	_evolved_badge = _make_mark("✨", Color(0.95, 0.75, 0.35))
	refresh_appearance()

	ps.species_assigned.connect(func(_s): refresh_appearance())
	ps.stage_changed.connect(func(_s): refresh_appearance())
	ps.care_performed.connect(_on_care_performed)
	ps.pooped.connect(_on_pooped)

	machine = load("res://scenes/pet/state_machine.gd").new()
	machine.name = "StateMachine"
	add_child(machine)
	machine.setup(self)

	# 초기 스폰: 1번 모니터 중앙 (setup 후 state가 재배치할 수 있음)
	var start_x: float = primary_local.get_center().x if primary_local.size.x > 0.0 else screen_size.x * 0.5
	position = Vector2(start_x, ground_y)


func _process(delta: float) -> void:
	if _pet_cooldown > 0.0:
		_pet_cooldown -= delta
	if jump_cooldown > 0.0:
		jump_cooldown -= delta


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed and get_click_rect().has_point(event.position):
			care_menu_requested.emit(event.position)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		# 백업 종료 수단 (기본은 트레이 메뉴 '종료')
		if event.pressed and get_click_rect().has_point(event.position):
			_quit_app()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and get_click_rect().has_point(event.position):
			_pressed = true
			_press_pos = event.position
		elif not event.pressed and _pressed:
			_pressed = false
			if machine.current_name() != "Dragged":
				_short_click()
	elif event is InputEventMouseMotion and _pressed:
		if machine.current_name() != "Dragged" and ps.stage != "egg" \
				and event.position.distance_to(_press_pos) > DRAG_THRESHOLD:
			machine.transition_to("Dragged")


func is_mouse_pressed() -> bool:
	return _pressed


func start_jump(target_id: int, target_rect: Rect2) -> void:
	jump_target_id = target_id
	jump_target_rect = target_rect
	machine.transition_to("Jump")


func get_click_rect() -> Rect2:
	var size := SPRITE_SIZE * _base_scale.x
	return Rect2(global_position + Vector2(-size * 0.5, -size), Vector2(size, size)).grow(8.0)


func move_speed() -> float:
	var speed := BASE_SPEED * Characters.get_stat_modifier(ps.species, "move_speed")
	if ps.caffeine_until_min > 0.0:
		speed *= 2.0
	if ps.has_special("morning_speed"):
		var h: int = Time.get_datetime_dict_from_system().hour
		if h >= 7 and h < 10:
			speed *= 2.0
	return speed


func face_towards(target_x: float) -> void:
	_sprite.flip_h = target_x < position.x


## 포즈 시트(assets/sprites/chars/<종족>/)가 있으면 프레임 시스템, 없으면 단일 컨셉 이미지 폴백
func has_poses() -> bool:
	return not _frames.is_empty()


func set_pose(pose: String) -> void:
	_pose = pose
	if _frames.has(pose):
		_sprite.texture = _frames[pose]


func refresh_appearance() -> void:
	_frames.clear()
	_pose = "idle"
	var char_key: String = "egg" if ps.stage == "egg" else ps.species
	var pose_list: Array = EGG_POSES if ps.stage == "egg" else POSES
	# 진화 완료 시 evolved 프레임 폴더를 우선 시도 (아트 없으면 기본 폴더로 폴백)
	var dirs: Array = ["res://assets/sprites/chars/%s/" % char_key]
	if ps.evolved and ps.stage != "egg":
		dirs.push_front("res://assets/sprites/chars/%s_evolved/" % char_key)
	for dir_path in dirs:
		if not ResourceLoader.exists(dir_path + "idle.png"):
			continue
		for pose in pose_list:
			var frame_path: String = dir_path + pose + ".png"
			if ResourceLoader.exists(frame_path):
				_frames[pose] = load(frame_path)
		break
	if _frames.has("idle"):
		_sprite.texture = _frames["idle"]
	else:
		_frames.clear()
		var path := "res://assets/sprites/concept/%s.png" % char_key
		if not ResourceLoader.exists(path):
			path = "res://assets/sprites/concept/mochi.png"  # Design §6: 리소스 폴백
		_sprite.texture = load(path)
	_update_evolved_badge()
	_base_scale = Vector2.ONE * STAGE_SCALE.get(ps.stage, 0.5)
	_sprite.scale = _base_scale
	_sprite.position = Vector2(0.0, -SPRITE_SIZE * _base_scale.y * 0.5)
	var mark_y := -SPRITE_SIZE * _base_scale.y - 26.0
	_zzz.position = Vector2(10.0, mark_y)
	_sick_mark.position = Vector2(-16.0, mark_y)
	# 진화 배지는 스프라이트 오른쪽 위 (약간 반짝)
	var half_w := SPRITE_SIZE * _base_scale.x * 0.5
	var half_h := SPRITE_SIZE * _base_scale.y
	_evolved_badge.position = Vector2(half_w - 24.0, -half_h - 6.0)


func _update_evolved_badge() -> void:
	if _evolved_badge == null:
		return
	_evolved_badge.visible = ps != null and ps.evolved and ps.stage != "egg"


# --- 상태별 표현 (states/*.gd에서 호출) ---

func idle_breathe() -> void:
	var t := create_tween()
	t.tween_property(_sprite, "scale", _base_scale * Vector2(1.03, 0.97), 0.5)
	t.tween_property(_sprite, "scale", _base_scale, 0.5)


func walk_bob(on: bool) -> void:
	_kill_bob()
	if on:
		_bob_tween = create_tween().set_loops()
		var up := -SPRITE_SIZE * _base_scale.y * 0.5 - 6.0
		var down := -SPRITE_SIZE * _base_scale.y * 0.5
		_bob_tween.tween_property(_sprite, "position:y", up, 0.18)
		_bob_tween.tween_property(_sprite, "position:y", down, 0.18)


func shake() -> void:
	if _frames.has("tilt1") and _frames.has("tilt2"):
		# 알 프레임 흔들기: 갸우뚱 좌우 교차, 80% 이상이면 금 간 모습으로 복귀
		var base := "crack" if ps.hatch_progress >= 80.0 and _frames.has("crack") else "idle"
		var t := create_tween()
		for i in 2:
			t.tween_callback(set_pose.bind("tilt1"))
			t.tween_interval(0.14)
			t.tween_callback(set_pose.bind("tilt2"))
			t.tween_interval(0.14)
		t.tween_callback(set_pose.bind(base))
		return
	var t := create_tween()
	for i in 3:
		t.tween_property(_sprite, "rotation", 0.12, 0.06)
		t.tween_property(_sprite, "rotation", -0.12, 0.06)
	t.tween_property(_sprite, "rotation", 0.0, 0.06)


func hatch_pop() -> void:
	var t := create_tween()
	t.tween_property(_sprite, "scale", _base_scale * 1.35, 0.15)
	t.tween_property(_sprite, "scale", _base_scale, 0.25)
	_float_text("탄생!")


func eat_munch() -> void:
	var t := create_tween()
	for i in 3:
		t.tween_property(_sprite, "scale", _base_scale * Vector2(1.1, 0.9), 0.15)
		t.tween_property(_sprite, "scale", _base_scale, 0.15)


func squat() -> void:
	var t := create_tween()
	t.tween_property(_sprite, "scale", _base_scale * Vector2(1.12, 0.82), 0.2)
	t.tween_property(_sprite, "scale", _base_scale, 0.3)


func land_squish() -> void:
	var t := create_tween()
	t.tween_property(_sprite, "scale", _base_scale * Vector2(1.25, 0.7), 0.08)
	t.tween_property(_sprite, "scale", _base_scale, 0.2)


func celebrate() -> void:
	# 신나는 세리머니: 폴짝폴짝 3연속 점프 + 음표 + 신남 표정
	var prev_pose := _pose
	set_pose("happy")
	var base_y := -SPRITE_SIZE * _base_scale.y * 0.5
	var t := create_tween()
	for i in 3:
		t.tween_property(_sprite, "position:y", base_y - 22.0, 0.14) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(_sprite, "position:y", base_y, 0.14) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		if _pose == "happy":
			set_pose(prev_pose if prev_pose != "happy" else "idle"))
	_float_text("♪")


func play_frolic() -> void:
	# 좌우로 기울며 폴짝폴짝 4연속 (놀기 리액션)
	var base_y := -SPRITE_SIZE * _base_scale.y * 0.5
	var t := create_tween()
	for i in 4:
		var dir := 1.0 if i % 2 == 0 else -1.0
		t.tween_property(_sprite, "rotation", 0.22 * dir, 0.13)
		t.parallel().tween_property(_sprite, "position:y", base_y - 26.0, 0.13) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(_sprite, "position:y", base_y, 0.14) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_sprite, "rotation", 0.0, 0.1)
	_float_text("신난다~♪")


func reset_sprite_pose() -> void:
	_sprite.rotation = 0.0
	_sprite.position.y = -SPRITE_SIZE * _base_scale.y * 0.5


func sulk_crouch() -> void:
	var t := create_tween()
	t.tween_property(_sprite, "scale", _base_scale * Vector2(1.05, 0.88), 0.4)


func wiggle(on: bool) -> void:
	if _wiggle_tween != null:
		_wiggle_tween.kill()
		_wiggle_tween = null
		_sprite.rotation = 0.0
	if on:
		_wiggle_tween = create_tween().set_loops()
		_wiggle_tween.tween_property(_sprite, "rotation", 0.18, 0.12)
		_wiggle_tween.tween_property(_sprite, "rotation", -0.18, 0.12)


func show_zzz(on: bool) -> void:
	_zzz.visible = on


func show_sick(on: bool) -> void:
	_sick_mark.visible = on


func set_sprite_tint(color: Color) -> void:
	_sprite.modulate = color


# --- 내부 ---

func _short_click() -> void:
	if ps.stage == "egg":
		ps.click_egg()
		shake()
		return
	if _pet_cooldown <= 0.0:
		ps.care("pet")
		_pet_cooldown = PET_COOLDOWN_SECONDS
		_float_text("♥")
	else:
		idle_breathe()


func _on_care_performed(action: String) -> void:
	if action == "feed" or action == "snack":
		if machine.current_name() not in machine.UNINTERRUPTIBLE:
			machine.transition_to("Eat")
	elif action == "play":
		if not ps.is_sick and machine.current_name() not in machine.UNINTERRUPTIBLE:
			machine.transition_to("Play")
	elif action == "medicine":
		_float_text("+HP")


func _on_pooped() -> void:
	if ps.stage != "egg" and machine.current_name() not in machine.UNINTERRUPTIBLE:
		machine.transition_to("Poop")


func _float_text(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.95, 0.4, 0.55))
	label.position = Vector2(-10.0, -SPRITE_SIZE * _base_scale.y - 30.0)
	add_child(label)
	var t := create_tween()
	t.tween_property(label, "position:y", label.position.y - 30.0, 0.8)
	t.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	t.tween_callback(label.queue_free)


func _make_mark(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	label.visible = false
	add_child(label)
	return label


func _kill_bob() -> void:
	if _bob_tween != null:
		_bob_tween.kill()
		_bob_tween = null
		_sprite.position.y = -SPRITE_SIZE * _base_scale.y * 0.5


func _quit_app() -> void:
	get_node("/root/SaveManager").save_game()
	get_tree().quit()
