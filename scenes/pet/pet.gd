# Design Ref: §2.1 — 펫 표현(스프라이트·애니메이션·입력). 시뮬레이션은 PetState가 소유.
extends Node2D

signal care_menu_requested(pos: Vector2)

const Characters := preload("res://scripts/data/characters.gd")
const STAGE_SCALE := {"egg": 0.5, "baby": 0.35, "child": 0.42, "adult": 0.5}
const SPRITE_SIZE := 256.0
const BICHON_VISIBLE_SIZE_MULTIPLIER := 1.25
const BICHON_EDGE_BUFFER := 28.0
const PINK_CAT_BABY_VISIBLE_SIZE_MULTIPLIER := 1.20
const PINK_CAT_BABY_EDGE_BUFFER := 28.0
const BASE_SPEED := 120.0
const PET_COOLDOWN_SECONDS := 30.0
const DRAG_THRESHOLD := 10.0
const FILE_HOVER_DURATION := 0.34
const FILE_CONSUME_DURATION := 0.70

const BICHON_ANIMATIONS := {
	"Idle": {"path": "res://assets/sprites/bichon/idle_sit_blink_11f_alpha.png", "columns": 2, "rows": 1, "frames": 11, "fps": 4.0, "loop": true, "visible_extent": 716.0, "sprite_frame_sequence": [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0], "horizontal_offsets": [10.5, 10.5, 10.5, 10.5, 10.5, 10.5, 10.5, 10.5, 10.5, 11.0, 10.5], "foot_padding": [153.0, 153.0, 153.0, 153.0, 153.0, 153.0, 153.0, 153.0, 153.0, 153.0, 153.0]},
	"Walk": {"path": "res://assets/sprites/bichon/walk_12f_chromakey.png", "columns": 4, "rows": 3, "frames": 12, "fps": 12.0, "loop": true, "visible_extent": 273.0, "foot_padding": [56.0, 51.0, 48.0, 45.0, 85.0, 81.0, 78.0, 79.0, 118.0, 114.0, 111.0, 105.0]},
	"Sleep": {"path": "res://assets/sprites/bichon/sleep_8f_chromakey.png", "columns": 4, "rows": 2, "frames": 8, "fps": 5.0, "loop": true, "visible_extent": 342.0, "horizontal_offsets": [-12.0, -13.5, 4.0, 14.5, -9.5, -8.0, 14.0, 29.0], "foot_padding": [80.0, 79.0, 77.0, 80.0, 120.0, 117.0, 115.0, 117.0]},
	"Eat": {"path": "res://assets/sprites/bichon/eat_12f_chromakey.png", "columns": 4, "rows": 3, "frames": 12, "fps": 9.0, "loop": true, "visible_extent": 299.0, "horizontal_offsets": [-8.0, 5.5, 9.0, 6.0, 1.5, 3.5, 9.0, 14.5, 0.5, 3.0, 4.0, 13.0], "foot_padding": [25.0, 25.0, 25.0, 25.0, 45.0, 45.0, 45.0, 45.0, 61.0, 62.0, 62.0, 61.0]},
	"FileHover": {"path": "res://assets/sprites/bichon/file_hover_4f_chromakey.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": false, "visible_extent": 465.0, "horizontal_offsets": [-35.0, -4.0, 12.0, 44.5], "foot_padding": [115.0, 115.0, 115.0, 115.0]},
	"FileConsume": {"path": "res://assets/sprites/bichon/file_consume_8f_chromakey.png", "columns": 4, "rows": 2, "frames": 8, "fps": 12.0, "loop": false, "visible_extent": 358.0, "horizontal_offsets": [-22.5, -9.0, 5.0, 30.5, -8.0, 4.5, 7.0, 20.5], "foot_padding": [42.0, 42.0, 40.0, 39.0, 69.0, 65.0, 61.0, 61.0]},
	"Poop": {"path": "res://assets/sprites/bichon/poop_6f_chromakey.png", "columns": 3, "rows": 2, "frames": 6, "fps": 8.0, "loop": true, "visible_extent": 348.0, "horizontal_offsets": [-27.5, -11.5, 21.0, -31.0, -13.5, 30.5], "foot_padding": [44.0, 47.0, 45.0, 114.0, 113.0, 112.0]},
	"Sick": {"path": "res://assets/sprites/bichon/sick_8f_chromakey.png", "columns": 4, "rows": 2, "frames": 8, "fps": 6.0, "loop": true, "visible_extent": 386.0, "horizontal_offsets": [-10.5, 15.0, 21.5, 8.5, 3.0, 10.5, 27.5, 28.5], "foot_padding": [47.0, 49.0, 47.0, 46.0, 91.0, 92.0, 92.0, 84.0]},
	"Sulk": {"path": "res://assets/sprites/bichon/sulk_8f_chromakey.png", "columns": 4, "rows": 2, "frames": 8, "fps": 6.0, "loop": true, "visible_extent": 345.0, "horizontal_offsets": [-32.0, -2.5, 0.5, 22.0, -17.5, -10.0, -2.5, 31.0], "foot_padding": [34.0, 33.0, 31.0, 29.0, 84.0, 85.0, 87.0, 88.0]},
	"Dragged": {"path": "res://assets/sprites/bichon/dragged_4f_chromakey.png", "columns": 4, "rows": 1, "frames": 4, "fps": 10.0, "loop": true, "visible_extent": 441.0, "horizontal_offsets": [1.5, -1.0, 1.0, 22.0], "foot_padding": [129.0, 145.0, 128.0, 132.0]},
	"Fall": {"path": "res://assets/sprites/bichon/fall_4f_chromakey.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": true, "visible_extent": 463.0, "horizontal_offsets": [-28.5, -30.0, 14.0, 40.5], "foot_padding": [154.0, 154.0, 150.0, 110.0]},
	"Land": {"path": "res://assets/sprites/bichon/land_4f_chromakey.png", "columns": 4, "rows": 1, "frames": 4, "fps": 10.0, "loop": false, "visible_extent": 431.0, "horizontal_offsets": [-25.5, 14.0, 2.0, 37.0], "foot_padding": [162.0, 112.0, 144.0, 138.0]},
	"Pet": {"path": "res://assets/sprites/bichon/petted_8f_chromakey.png", "columns": 4, "rows": 2, "frames": 8, "fps": 10.0, "loop": false, "visible_extent": 382.0, "horizontal_offsets": [-2.5, 0.5, 2.0, 7.5, 0.5, 1.0, 2.0, 4.0], "foot_padding": [32.0, 32.0, 32.0, 32.0, 65.0, 65.0, 63.0, 63.0]},
	"Play": {"path": "res://assets/sprites/bichon/play_8f_chromakey.png", "columns": 4, "rows": 2, "frames": 8, "fps": 10.0, "loop": false, "visible_extent": 344.0, "horizontal_offsets": [7.0, 8.5, 16.0, 23.5, 4.0, 10.5, 16.5, 10.5], "foot_padding": [89.0, 84.0, 96.0, 129.0, 104.0, 94.0, 67.0, 60.0]},
}

# One shared, transparent 12×14 atlas.  Each logical state receives an explicit
# frame sequence so short rows never spill into the next state row.
const PINK_CAT_BABY_ANIMATIONS := {
	"Idle": {"path": "res://assets/sprites/pink_cat_baby/pink_cat_baby_12x14_alpha.png", "columns": 12, "rows": 14, "frames": 4, "fps": 4.0, "loop": true, "visible_extent": 208.0, "sprite_frame_sequence": [0, 1, 2, 3], "horizontal_offsets": [0.0, 0.0, 0.0, 0.0], "foot_padding": [24.0, 24.0, 24.0, 24.0]},
	"Walk": {"path": "res://assets/sprites/pink_cat_baby/pink_cat_baby_12x14_alpha.png", "columns": 12, "rows": 14, "frames": 12, "fps": 12.0, "loop": true, "visible_extent": 208.0, "sprite_frame_sequence": [12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23], "horizontal_offsets": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "foot_padding": [24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0]},
	"Sleep": {"path": "res://assets/sprites/pink_cat_baby/pink_cat_baby_12x14_alpha.png", "columns": 12, "rows": 14, "frames": 8, "fps": 5.0, "loop": true, "visible_extent": 208.0, "sprite_frame_sequence": [24, 25, 26, 27, 28, 29, 30, 31], "horizontal_offsets": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "foot_padding": [24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0]},
	"Eat": {"path": "res://assets/sprites/pink_cat_baby/pink_cat_baby_12x14_alpha.png", "columns": 12, "rows": 14, "frames": 12, "fps": 9.0, "loop": true, "visible_extent": 208.0, "sprite_frame_sequence": [36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47], "horizontal_offsets": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "foot_padding": [24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0]},
	"FileHover": {"path": "res://assets/sprites/pink_cat_baby/pink_cat_baby_12x14_alpha.png", "columns": 12, "rows": 14, "frames": 4, "fps": 12.0, "loop": false, "visible_extent": 208.0, "sprite_frame_sequence": [48, 49, 50, 51], "horizontal_offsets": [0.0, 0.0, 0.0, 0.0], "foot_padding": [24.0, 24.0, 24.0, 24.0]},
	"FileConsume": {"path": "res://assets/sprites/pink_cat_baby/pink_cat_baby_12x14_alpha.png", "columns": 12, "rows": 14, "frames": 8, "fps": 12.0, "loop": false, "visible_extent": 208.0, "sprite_frame_sequence": [60, 61, 62, 63, 64, 65, 66, 67], "horizontal_offsets": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "foot_padding": [24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0]},
	"Poop": {"path": "res://assets/sprites/pink_cat_baby/pink_cat_baby_12x14_alpha.png", "columns": 12, "rows": 14, "frames": 6, "fps": 8.0, "loop": true, "visible_extent": 208.0, "sprite_frame_sequence": [72, 73, 74, 75, 76, 77], "horizontal_offsets": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "foot_padding": [24.0, 24.0, 24.0, 24.0, 24.0, 24.0]},
	"Sick": {"path": "res://assets/sprites/pink_cat_baby/pink_cat_baby_12x14_alpha.png", "columns": 12, "rows": 14, "frames": 8, "fps": 6.0, "loop": true, "visible_extent": 208.0, "sprite_frame_sequence": [84, 85, 86, 87, 88, 89, 90, 91], "horizontal_offsets": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "foot_padding": [24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0]},
	"Sulk": {"path": "res://assets/sprites/pink_cat_baby/pink_cat_baby_12x14_alpha.png", "columns": 12, "rows": 14, "frames": 8, "fps": 6.0, "loop": true, "visible_extent": 208.0, "sprite_frame_sequence": [96, 97, 98, 99, 100, 101, 102, 103], "horizontal_offsets": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "foot_padding": [24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0]},
	"Dragged": {"path": "res://assets/sprites/pink_cat_baby/pink_cat_baby_12x14_alpha.png", "columns": 12, "rows": 14, "frames": 4, "fps": 10.0, "loop": true, "visible_extent": 208.0, "sprite_frame_sequence": [108, 109, 110, 111], "horizontal_offsets": [0.0, 0.0, 0.0, 0.0], "foot_padding": [24.0, 24.0, 24.0, 24.0]},
	"Fall": {"path": "res://assets/sprites/pink_cat_baby/pink_cat_baby_12x14_alpha.png", "columns": 12, "rows": 14, "frames": 4, "fps": 12.0, "loop": true, "visible_extent": 208.0, "sprite_frame_sequence": [120, 121, 122, 123], "horizontal_offsets": [0.0, 0.0, 0.0, 0.0], "foot_padding": [24.0, 24.0, 24.0, 24.0]},
	"Land": {"path": "res://assets/sprites/pink_cat_baby/pink_cat_baby_12x14_alpha.png", "columns": 12, "rows": 14, "frames": 4, "fps": 10.0, "loop": false, "visible_extent": 208.0, "sprite_frame_sequence": [132, 133, 134, 135], "horizontal_offsets": [0.0, 0.0, 0.0, 0.0], "foot_padding": [24.0, 24.0, 24.0, 24.0]},
	"Pet": {"path": "res://assets/sprites/pink_cat_baby/pink_cat_baby_12x14_alpha.png", "columns": 12, "rows": 14, "frames": 8, "fps": 10.0, "loop": false, "visible_extent": 208.0, "sprite_frame_sequence": [144, 145, 146, 147, 148, 149, 150, 151], "horizontal_offsets": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "foot_padding": [24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0]},
	"Play": {"path": "res://assets/sprites/pink_cat_baby/pink_cat_baby_12x14_alpha.png", "columns": 12, "rows": 14, "frames": 8, "fps": 10.0, "loop": false, "visible_extent": 208.0, "sprite_frame_sequence": [156, 157, 158, 159, 160, 161, 162, 163], "horizontal_offsets": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "foot_padding": [24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0]},
}

var ps: Node
var machine: Node
var ground_y := 0.0
var screen_size := Vector2.ZERO

var _sprite: Sprite2D
var _zzz: Label
var _sick_mark: Label
var _base_scale := Vector2.ONE
var _frame_size := Vector2.ONE * SPRITE_SIZE
var _pet_cooldown := 0.0
var _pressed := false
var _press_pos := Vector2.ZERO
var _bob_tween: Tween
var _wiggle_tween: Tween
var _bichon_animation := ""
var _bichon_elapsed := 0.0
var _bichon_frame := 0
var _bichon_override := ""
var _bichon_frame_foot_padding := []
var _bichon_frame_horizontal_offsets := []
var _bichon_sprite_frame_sequence := []
var _idle_tween: Tween


func _ready() -> void:
	ps = get_node("/root/PetState")

	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_sprite)
	_zzz = _make_mark("Zzz", Color(0.55, 0.62, 0.85))
	_sick_mark = _make_mark("@_@", Color(0.45, 0.65, 0.45))
	refresh_appearance()

	ps.species_assigned.connect(func(_s): refresh_appearance())
	ps.stage_changed.connect(func(_s): refresh_appearance())
	ps.care_performed.connect(_on_care_performed)
	ps.pooped.connect(_on_pooped)

	machine = load("res://scenes/pet/state_machine.gd").new()
	machine.name = "StateMachine"
	add_child(machine)
	machine.setup(self)

	position = Vector2(screen_size.x * 0.5, ground_y)


func _process(delta: float) -> void:
	if _pet_cooldown > 0.0:
		_pet_cooldown -= delta
	_advance_bichon_animation(delta)


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


func get_click_rect() -> Rect2:
	var animated_size_multiplier := _animated_visible_size_multiplier() if _is_animated_pet() else 1.0
	var size := SPRITE_SIZE * float(STAGE_SCALE.get(ps.stage, 0.5)) * animated_size_multiplier
	return Rect2(global_position + Vector2(-size * 0.5, -size), Vector2(size, size)).grow(8.0)


func horizontal_edge_margin() -> float:
	if _is_animated_pet():
		return SPRITE_SIZE * float(STAGE_SCALE.get(ps.stage, 0.5)) * _animated_visible_size_multiplier() * 0.5 + _animated_edge_buffer()
	return 80.0


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
	_sprite.flip_h = target_x > position.x


func refresh_appearance() -> void:
	if _is_animated_pet():
		var state_name: String = machine.current_name() if machine != null else "Idle"
		var animation_name := _bichon_override if not _bichon_override.is_empty() else _animation_for_state(state_name)
		_set_bichon_animation(animation_name)
		return

	var tex_key: String = "egg" if ps.stage == "egg" else ps.species
	var path := "res://assets/sprites/concept/%s.png" % tex_key
	if not ResourceLoader.exists(path):
		path = "res://assets/sprites/concept/mochi.png"  # Design §6: 리소스 폴백
	_sprite.hframes = 1
	_sprite.vframes = 1
	_sprite.frame = 0
	_bichon_frame = 0
	_bichon_sprite_frame_sequence = []
	_sprite.texture = load(path)
	_frame_size = _sprite.texture.get_size()
	_base_scale = Vector2.ONE * STAGE_SCALE.get(ps.stage, 0.5)
	_sprite.scale = _base_scale
	_sprite.position = _sprite_anchor()
	_update_mark_positions()


# --- 상태별 표현 (states/*.gd에서 호출) ---

func play_state_animation(state_name: String) -> void:
	if _is_animated_pet() and _bichon_override.is_empty():
		_set_bichon_animation(_animation_for_state(state_name))


func set_file_hover(active: bool) -> void:
	if not _is_animated_pet():
		return
	if active:
		_bichon_override = "FileHover"
		_set_bichon_animation(_bichon_override)
		return
	_bichon_override = ""
	_restore_bichon_state_animation()


func play_file_drop_reaction() -> void:
	if not _is_animated_pet():
		return
	set_file_hover(true)
	await get_tree().create_timer(FILE_HOVER_DURATION).timeout
	if _bichon_override != "FileHover":
		return
	_bichon_override = "FileConsume"
	_set_bichon_animation(_bichon_override)
	await get_tree().create_timer(FILE_CONSUME_DURATION).timeout
	if _bichon_override == "FileConsume":
		set_file_hover(false)


func _is_bichon() -> bool:
	return ps != null and ps.stage != "egg" and ps.species == "bichon"


func _is_pink_cat_baby() -> bool:
	return ps != null and ps.stage != "egg" and ps.species == "pink_cat_baby"


func _is_animated_pet() -> bool:
	return _is_bichon() or _is_pink_cat_baby()


func _animation_catalog() -> Dictionary:
	return PINK_CAT_BABY_ANIMATIONS if _is_pink_cat_baby() else BICHON_ANIMATIONS


func _animated_visible_size_multiplier() -> float:
	return PINK_CAT_BABY_VISIBLE_SIZE_MULTIPLIER if _is_pink_cat_baby() else BICHON_VISIBLE_SIZE_MULTIPLIER


func _animated_edge_buffer() -> float:
	return PINK_CAT_BABY_EDGE_BUFFER if _is_pink_cat_baby() else BICHON_EDGE_BUFFER


func _animation_for_state(state_name: String) -> String:
	var catalog := _animation_catalog()
	return state_name if catalog.has(state_name) else "Idle"


func _set_bichon_animation(animation_name: String) -> void:
	var catalog := _animation_catalog()
	var config: Dictionary = catalog.get(animation_name, catalog["Idle"])
	var path: String = config["path"]
	if not ResourceLoader.exists(path):
		push_error("Missing animated pet sprite sheet: %s" % path)
		return
	var texture: Texture2D = load(path)
	_sprite.texture = texture
	_sprite.hframes = int(config["columns"])
	_sprite.vframes = int(config["rows"])
	_sprite.frame = 0
	_frame_size = texture.get_size() / Vector2(_sprite.hframes, _sprite.vframes)
	var visible_extent: float = float(config.get("visible_extent", maxf(_frame_size.x, _frame_size.y)))
	var fit_scale := SPRITE_SIZE * _animated_visible_size_multiplier() / visible_extent
	_base_scale = Vector2.ONE * float(STAGE_SCALE.get(ps.stage, 0.5)) * fit_scale
	_sprite.scale = _base_scale
	_bichon_animation = animation_name
	_bichon_elapsed = 0.0
	_bichon_frame_foot_padding = config.get("foot_padding", [])
	_bichon_frame_horizontal_offsets = config.get("horizontal_offsets", [])
	_bichon_sprite_frame_sequence = config.get("sprite_frame_sequence", [])
	_set_bichon_frame(0)
	_update_mark_positions()


func _advance_bichon_animation(delta: float) -> void:
	if not _is_animated_pet() or _bichon_animation.is_empty():
		return
	var config: Dictionary = _animation_catalog().get(_bichon_animation, {})
	var fps: float = float(config.get("fps", 0.0))
	var frames: int = int(config.get("frames", 0))
	if fps <= 0.0 or frames <= 0:
		return
	_bichon_elapsed += delta
	var next_frame := int(_bichon_elapsed * fps)
	if bool(config.get("loop", true)):
		next_frame %= frames
	else:
		next_frame = mini(next_frame, frames - 1)
	_set_bichon_frame(next_frame)


func _set_bichon_frame(frame_index: int) -> void:
	_bichon_frame = frame_index
	_sprite.frame = _sprite_frame_for_bichon_frame(frame_index)
	_position_sprite_for_current_frame()


func _sprite_frame_for_bichon_frame(frame_index: int) -> int:
	if frame_index >= 0 and frame_index < _bichon_sprite_frame_sequence.size():
		return clampi(int(_bichon_sprite_frame_sequence[frame_index]), 0, _sprite.hframes * _sprite.vframes - 1)
	return clampi(frame_index, 0, _sprite.hframes * _sprite.vframes - 1)


func _restore_bichon_state_animation() -> void:
	var state_name: String = machine.current_name() if machine != null else "Idle"
	_set_bichon_animation(_animation_for_state(state_name))


func _play_care_reaction(animation_name: String, duration: float) -> void:
	if not _is_animated_pet():
		return
	_bichon_override = animation_name
	_set_bichon_animation(animation_name)
	await get_tree().create_timer(duration).timeout
	if _bichon_override == animation_name:
		_bichon_override = ""
		_restore_bichon_state_animation()


func _sprite_anchor() -> Vector2:
	return Vector2(0.0, -_frame_size.y * _base_scale.y * 0.5)


func _position_sprite_for_current_frame() -> void:
	_sprite.position = _sprite_anchor()
	if _is_animated_pet() and _bichon_frame < _bichon_frame_horizontal_offsets.size():
		var horizontal_direction: float = -1.0 if _sprite.flip_h else 1.0
		_sprite.position.x += float(_bichon_frame_horizontal_offsets[_bichon_frame]) * _base_scale.x * horizontal_direction
	if _is_animated_pet() and _bichon_frame < _bichon_frame_foot_padding.size():
		_sprite.position.y += float(_bichon_frame_foot_padding[_bichon_frame]) * _base_scale.y


func _update_mark_positions() -> void:
	var mark_y := -_frame_size.y * _base_scale.y - 26.0
	_zzz.position = Vector2(10.0, mark_y)
	_sick_mark.position = Vector2(-16.0, mark_y)


func idle_breathe() -> void:
	if _keep_bichon_grounded():
		return
	if _idle_tween != null:
		_idle_tween.kill()
	_idle_tween = create_tween()
	_idle_tween.tween_property(_sprite, "scale", _base_scale * Vector2(1.03, 0.97), 0.5)
	_idle_tween.tween_property(_sprite, "scale", _base_scale, 0.5)


func walk_bob(_on: bool) -> void:
	_kill_idle_breathe()
	_kill_bob()
	_position_sprite_for_current_frame()


func shake() -> void:
	var t := create_tween()
	for i in 3:
		t.tween_property(_sprite, "rotation", 0.12, 0.06)
		t.tween_property(_sprite, "rotation", -0.12, 0.06)
	t.tween_property(_sprite, "rotation", 0.0, 0.06)


func hatch_pop() -> void:
	if _keep_bichon_grounded():
		return
	var t := create_tween()
	t.tween_property(_sprite, "scale", _base_scale * 1.35, 0.15)
	t.tween_property(_sprite, "scale", _base_scale, 0.25)
	_float_text("탄생!")


func eat_munch() -> void:
	if _keep_bichon_grounded():
		return
	var t := create_tween()
	for i in 3:
		t.tween_property(_sprite, "scale", _base_scale * Vector2(1.1, 0.9), 0.15)
		t.tween_property(_sprite, "scale", _base_scale, 0.15)


func squat() -> void:
	if _keep_bichon_grounded():
		return
	var t := create_tween()
	t.tween_property(_sprite, "scale", _base_scale * Vector2(1.12, 0.82), 0.2)
	t.tween_property(_sprite, "scale", _base_scale, 0.3)


func land_squish() -> void:
	if _keep_bichon_grounded():
		return
	var t := create_tween()
	t.tween_property(_sprite, "scale", _base_scale * Vector2(1.25, 0.7), 0.08)
	t.tween_property(_sprite, "scale", _base_scale, 0.2)


func sulk_crouch() -> void:
	if _keep_bichon_grounded():
		return
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
	elif action == "pet":
		_play_care_reaction("Pet", 0.8)
	elif action == "play":
		_play_care_reaction("Play", 0.8)
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
	label.position = Vector2(-10.0, -_frame_size.y * _base_scale.y - 30.0)
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
		_position_sprite_for_current_frame()


func _kill_idle_breathe() -> void:
	if _idle_tween != null:
		_idle_tween.kill()
		_idle_tween = null
	_sprite.scale = _base_scale


func _keep_bichon_grounded() -> bool:
	if not _is_animated_pet():
		return false
	_kill_idle_breathe()
	_position_sprite_for_current_frame()
	return true


func _quit_app() -> void:
	get_node("/root/SaveManager").save_game()
	get_tree().quit()
