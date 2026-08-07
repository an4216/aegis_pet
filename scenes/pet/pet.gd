# Design Ref: §2.1 — 펫 표현(스프라이트·애니메이션·입력). 시뮬레이션은 PetState가 소유.
extends Node2D

signal care_menu_requested(pos: Vector2)

const Characters := preload("res://scripts/data/characters.gd")
const STAGE_SCALE := {"egg": 0.9, "baby": 0.378, "child": 0.378, "adult": 0.45}  # 기존 대비 60% 크기(baby=child 상향) 후 전체 50% 확대
# egg만 0.9(기존 0.45의 2배) — chars/egg/*.png 원본을 256->128로 절반 축소하면서(2026-08-06)
# 화면 표시 크기를 그대로 유지하려는 보정. baby/child/adult는 바뀌지 않는다: bichon의
# fit_scale(아래 SPRITE_SIZE 사용부)도 이 값을 같이 쓰는데, 그쪽은 visible_extent를 절반으로
# 낮춰 별도로 보정했으니 여기서 또 건드리면 bichon이 2배로 겹보정된다.
const POSES := ["idle", "walk1", "walk2", "sleep", "happy", "sulk", "sick", "eat"]
const EGG_POSES := ["idle", "tilt1", "tilt2", "crack"]
const SPRITE_SIZE := 256.0  # bichon fit_scale 전용 정규화 기준 — 실제 파일 크기와 무관, 바꾸지 않는다
const STATIC_POSE_SIZE := 128.0  # 정지 포즈 캔버스 크기 (2026-08-06: 256->128, 원본 용량 절감)
const BICHON_VISIBLE_SIZE_MULTIPLIER := 0.871  # 포즈 시트 12종과 동일한 목표 몸통 높이로 정규화 (Characters.BODY_SCALE 참고)
const BICHON_EDGE_BUFFER := 28.0
const BASE_SPEED := 120.0
const PET_COOLDOWN_SECONDS := 30.0
const DRAG_THRESHOLD := 10.0
const FILE_HOVER_DURATION := 0.34
const FILE_CONSUME_DURATION := 0.70

# 2026-08-06: 아래 시트 원본을 전부 256->128 캔버스 기준(50%)으로 축소하면서, 그 시트에서
# 실측한 픽셀 값인 visible_extent/foot_padding/horizontal_offsets도 전부 절반으로 다시 쟀다.
# fit_scale = SPRITE_SIZE(불변) * MULT / visible_extent 이므로 visible_extent가 절반이 되면
# fit_scale·화면 표시 크기는 그대로 유지된다 (SPRITE_SIZE는 실제 파일 크기와 무관한 정규화 상수).
const BICHON_ANIMATIONS := {
	"Idle": {"path": "res://assets/sprites/bichon/idle_sit_blink_11f_alpha.png", "columns": 2, "rows": 1, "frames": 11, "fps": 4.0, "loop": true, "visible_extent": 358.0, "sprite_frame_sequence": [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0], "horizontal_offsets": [5.25, 5.25, 5.25, 5.25, 5.25, 5.25, 5.25, 5.25, 5.25, 5.5, 5.25], "foot_padding": [76.5, 76.5, 76.5, 76.5, 76.5, 76.5, 76.5, 76.5, 76.5, 76.5, 76.5]},
	"Walk": {"path": "res://assets/sprites/bichon/walk_12f_chromakey.png", "columns": 4, "rows": 3, "frames": 12, "fps": 12.0, "loop": true, "visible_extent": 136.5, "foot_padding": [28.0, 25.5, 24.0, 22.5, 42.5, 40.5, 39.0, 39.5, 59.0, 57.0, 55.5, 52.5]},
	"Sleep": {"path": "res://assets/sprites/bichon/sleep_8f_chromakey.png", "columns": 4, "rows": 2, "frames": 8, "fps": 5.0, "loop": true, "visible_extent": 171.0, "horizontal_offsets": [-6.0, -6.75, 2.0, 7.25, -4.75, -4.0, 7.0, 14.5], "foot_padding": [40.0, 39.5, 38.5, 40.0, 60.0, 58.5, 57.5, 58.5]},
	"Eat": {"path": "res://assets/sprites/bichon/eat_12f_chromakey.png", "columns": 4, "rows": 3, "frames": 12, "fps": 9.0, "loop": true, "visible_extent": 149.5, "horizontal_offsets": [-4.0, 2.75, 4.5, 3.0, 0.75, 1.75, 4.5, 7.25, 0.25, 1.5, 2.0, 6.5], "foot_padding": [12.5, 12.5, 12.5, 12.5, 22.5, 22.5, 22.5, 22.5, 30.5, 31.0, 31.0, 30.5]},
	"FileHover": {"path": "res://assets/sprites/bichon/file_hover_4f_chromakey.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": false, "visible_extent": 232.5, "horizontal_offsets": [-17.5, -2.0, 6.0, 22.25], "foot_padding": [57.5, 57.5, 57.5, 57.5]},
	"FileConsume": {"path": "res://assets/sprites/bichon/file_consume_8f_chromakey.png", "columns": 4, "rows": 2, "frames": 8, "fps": 12.0, "loop": false, "visible_extent": 179.0, "horizontal_offsets": [-11.5, -4.0, 3.0, 16.5, -4.0, 2.5, 4.0, 11.5], "foot_padding": [21.0, 21.0, 20.0, 19.5, 34.5, 32.5, 30.5, 30.5]},
	"Poop": {"path": "res://assets/sprites/bichon/poop_6f_chromakey.png", "columns": 3, "rows": 2, "frames": 6, "fps": 8.0, "loop": true, "visible_extent": 174.0, "horizontal_offsets": [-13.75, -5.75, 10.5, -15.5, -6.75, 15.25], "foot_padding": [22.0, 23.5, 22.5, 57.0, 56.5, 56.0]},
	"Sick": {"path": "res://assets/sprites/bichon/sick_8f_chromakey.png", "columns": 4, "rows": 2, "frames": 8, "fps": 6.0, "loop": true, "visible_extent": 193.0, "horizontal_offsets": [-5.0, 8.0, 11.5, 5.5, 1.5, 6.0, 14.5, 14.5], "foot_padding": [23.5, 24.5, 23.5, 23.0, 45.5, 46.0, 46.0, 42.0]},
	"Sulk": {"path": "res://assets/sprites/bichon/sulk_8f_chromakey.png", "columns": 4, "rows": 2, "frames": 8, "fps": 6.0, "loop": true, "visible_extent": 172.5, "horizontal_offsets": [-16.0, -1.25, 0.25, 11.0, -8.75, -5.0, -1.25, 15.5], "foot_padding": [17.0, 16.5, 15.5, 14.5, 42.0, 42.5, 43.5, 44.0]},
	"Dragged": {"path": "res://assets/sprites/bichon/dragged_4f_chromakey.png", "columns": 4, "rows": 1, "frames": 4, "fps": 10.0, "loop": true, "visible_extent": 220.5, "horizontal_offsets": [0.75, -0.5, 0.5, 11.0], "foot_padding": [64.5, 72.5, 64.0, 66.0]},
	"Fall": {"path": "res://assets/sprites/bichon/fall_4f_chromakey.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": true, "visible_extent": 231.5, "horizontal_offsets": [-14.25, -15.0, 7.0, 20.25], "foot_padding": [77.0, 77.0, 75.0, 55.0]},
	"Land": {"path": "res://assets/sprites/bichon/land_4f_chromakey.png", "columns": 4, "rows": 1, "frames": 4, "fps": 10.0, "loop": false, "visible_extent": 215.5, "horizontal_offsets": [-12.75, 7.0, 1.0, 18.5], "foot_padding": [81.0, 56.0, 72.0, 69.0]},
	"Pet": {"path": "res://assets/sprites/bichon/petted_8f_chromakey.png", "columns": 4, "rows": 2, "frames": 8, "fps": 10.0, "loop": false, "visible_extent": 191.0, "horizontal_offsets": [-1.25, 0.25, 1.0, 3.75, 0.25, 0.5, 1.0, 2.0], "foot_padding": [16.0, 16.0, 16.0, 16.0, 32.5, 32.5, 31.5, 31.5]},
	"Play": {"path": "res://assets/sprites/bichon/play_8f_chromakey.png", "columns": 4, "rows": 2, "frames": 8, "fps": 10.0, "loop": false, "visible_extent": 172.0, "horizontal_offsets": [3.5, 4.5, 8.5, 12.5, 2.0, 6.0, 9.0, 6.5], "foot_padding": [44.5, 42.0, 48.0, 64.5, 52.0, 47.0, 33.5, 30.0]},
}

# 포즈 시트 캐릭터의 상태별 정지 포즈를 다중 프레임 시트로 대체한다 (sprite-gen 산출물).
# 등록이 없는 상태·티어는 그 상태만 기존 단일 이미지(정지 포즈)로 폴백한다.
# 프레임별로 스케일을 다시 계산하는 방식(frame_heights)을 한 번 시도했으나, 모찌처럼
# 세로 높이가 81~160px로 크게 요동치는 스쿼시-스트레치 시트에서는 폭까지 반대로 같이
# 요동쳐(웅크릴 때 넓어지고 늘어날 때 좁아짐) "몸통이 늘어났다 줄었다"하는 것처럼 보였다.
# idle과 똑같은 고정 배율(Characters.get_body_scale) 하나만 쓰면 원본 아트 자체의
# 스쿼시-스트레치만 남고 배율은 흔들리지 않는다 — 다른 포즈/캐릭터가 이미 쓰는 방식과 동일.
#
# 구조: species -> {"sheet_scale"(선택), "states" -> 상태명 -> config}
# 시트가 진화 티어마다 따로 있으면 상태 밑에 tier(base|evolved|evolved2) 한 단을 더 둔다(삐약 잠자기).
# "sheet_scale": 시트 셀 안 몸통 높이를 정지 포즈 아트의 몸통 높이에 맞추는 보정(기본 1.0).
# BODY_SCALE은 정지 포즈 캔버스(STATIC_POSE_SIZE=128) 기준으로 정규화된 값이라, 셀이 더 큰
# 시트를 그대로 쓰면 몸통만 커진다. 모찌: 정지 idle 알파높이 78px ÷ 시트 idle 정지프레임 129px = 0.605.
const ANIMATED_POSE_OVERRIDES := {
	"mochi": {
		"sheet_scale": 0.605,
		"tiers": ["base"],   # 진화 단계 시트 미제작 — evolved/evolved2는 정지 포즈 8종을 그대로 쓴다
		"states": {
			"Idle": {"path": "res://assets/sprites/mochi/idle_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 4.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-1.0, -1.0, -1.0, -1.0]},
			"Walk": {"path": "res://assets/sprites/mochi/walk_8f_alpha_smooth.png", "columns": 4, "rows": 2, "frames": 8, "fps": 10.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-1.0, 0.0, 0.0, -1.0, -1.0, 0.0, 0.0, -1.0]},
			"Sleep": {"path": "res://assets/sprites/mochi/sleep_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 5.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-1.0, -2.0, -2.0, -1.0]},
			"Eat": {"path": "res://assets/sprites/mochi/eat_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 6.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-1.0, -1.0, -1.0, -1.0]},
			"Sick": {"path": "res://assets/sprites/mochi/sick_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 6.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-1.0, -4.0, 0.0, -4.0]},
			"Sulk": {"path": "res://assets/sprites/mochi/sulk_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 6.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-3.0, -3.0, -2.0, -1.0]},
			# happy 시트는 놀기 리액션(Play 상태)에서 재생된다 — 정지 포즈 "happy"와 같은 자리.
			"Play": {"path": "res://assets/sprites/mochi/happy_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 8.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-1.0, -1.0, -1.0, -1.0]},
			"Dragged": {"path": "res://assets/sprites/mochi/dragged_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 10.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [5.0, 0.0, 1.0, 4.5]},
			"Fall": {"path": "res://assets/sprites/mochi/fall_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 2.0, 0.5, -1.0]},
			"Land": {"path": "res://assets/sprites/mochi/land_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 10.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, -1.0, -2.0, -1.0]},
		},
	},
	"ppiyak": {
		"states": {
			"Sleep": {
				"base": {"path": "res://assets/sprites/ppiyak/sleep_6f.png", "columns": 6, "rows": 1, "frames": 6, "fps": 4.0, "loop": true, "foot_padding": [12.0, 12.0, 12.0, 12.0, 12.0, 12.0], "horizontal_offsets": [-3.0, -3.0, -2.75, -2.75, -2.75, -3.25]},
				"evolved": {"path": "res://assets/sprites/ppiyak_evolved/sleep_6f.png", "columns": 6, "rows": 1, "frames": 6, "fps": 4.0, "loop": true, "foot_padding": [12.0, 12.0, 12.0, 12.0, 12.0, 12.0], "horizontal_offsets": [-4.75, -5.0, -5.0, -4.75, -4.5, -4.5]},
				"evolved2": {"path": "res://assets/sprites/ppiyak_evolved2/sleep_6f.png", "columns": 6, "rows": 1, "frames": 6, "fps": 4.0, "loop": true, "foot_padding": [12.0, 12.0, 12.0, 12.0, 12.0, 12.0], "horizontal_offsets": [-6.75, -7.0, -7.0, -6.75, -6.75, -6.25]},
			},
		},
	},
}

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
var _base_scale := Vector2.ONE
var _frame_size := Vector2.ONE * SPRITE_SIZE
var _pet_cooldown := 0.0
var _pressed := false
var _press_pos := Vector2.ZERO
var _bob_tween: Tween
var _wiggle_tween: Tween
var _wobble_tween: Tween
var _frames := {}          # pose -> Texture2D (포즈 시트 있는 캐릭터만)
var _pose := "idle"
var _bichon_animation := ""
var _bichon_elapsed := 0.0
var _bichon_frame := 0
var _bichon_override := ""
var _bichon_frame_foot_padding := []
var _bichon_frame_horizontal_offsets := []
var _bichon_sprite_frame_sequence := []
var _idle_tween: Tween
var _body_tier := "base"          # refresh_appearance()가 채움: base|evolved|evolved2
var _pose_override_active := false
var _pose_override_state := ""
var _pose_override_fps := 0.0
var _pose_override_frame_count := 0
var _pose_override_loop := true

# 위장/숨김 모드 (재시작 시 항상 normal — save에 저장 안 함)
var hide_mode: String = "normal"   # "normal" | "disguise" | "invisible"
var _disguise_textures: Array = []
# 익스포트 빌드에서 DirAccess 순회가 불안정하므로 파일명 하드코딩
const DISGUISE_FILES := [
	"calculator.png", "memo.png", "folder.png", "search.png",
	"usb.png", "hoodie.png", "mail.png", "trash.png",
]


func _ready() -> void:
	ps = get_node("/root/PetState")

	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_sprite)
	_zzz = _make_mark("Zzz", Color(0.55, 0.62, 0.85))
	_sick_mark = _make_mark("@_@", Color(0.45, 0.65, 0.45))
	_load_disguise_textures()
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
	_advance_bichon_animation(delta)
	if jump_cooldown > 0.0:
		jump_cooldown -= delta


func _input(event: InputEvent) -> void:
	# 완전 숨김: 모든 입력 무시
	if hide_mode == "invisible":
		return
	# 위장 중 & 일반 모드: 상호작용 동일 (드래그·우클릭·클릭 모두 허용).
	# 자율 이동만 상태머신에서 별도로 정지시킴.
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
	# 완전 숨김 중에만 클릭 영역 비움 (Windows SetWindowRgn이 렌더링도 잘라내므로
	# 위장 중에는 렌더 유지를 위해 영역을 그대로 반환. 클릭은 _input에서 차단.)
	if hide_mode == "invisible":
		return Rect2()
	# 애니메이션 시트는 캔버스에 여백이 많아 실제 보이는 크기를 별도로 환산한다.
	if _is_animated_pet():
		var size := SPRITE_SIZE * float(STAGE_SCALE.get(ps.stage, 0.5)) * _animated_visible_size_multiplier()
		return Rect2(global_position + Vector2(-size * 0.5, -size), Vector2(size, size)).grow(8.0)
	# 캐릭터가 실제로 그려지는 영역만 클릭 감지 (스프라이트 캔버스 대비 ~75%).
	# 나머지 여백까지 클릭을 막으면 펫이 지나가는 궤적이 넓게 blocked 되어 뒤 창 조작이 불편함.
	var w: float = _frame_size.x * _base_scale.x * 0.75
	var h: float = _frame_size.y * _base_scale.y * 0.85
	return Rect2(global_position + Vector2(-w * 0.5, -h - 4.0), Vector2(w, h))


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


func mirror_face() -> void:
	if _sprite:
		_sprite.flip_h = not _sprite.flip_h


## 포즈 시트(assets/sprites/chars/<종족>/)가 있으면 프레임 시스템, 없으면 단일 컨셉 이미지 폴백
func has_poses() -> bool:
	return not _frames.is_empty()


func set_pose(pose: String) -> void:
	_pose = pose
	# 위장 중에는 아이콘 텍스처를 유지 (드래그 종료 후 Idle.enter 등에서 pose 리셋해도 안 바뀜)
	if hide_mode == "disguise":
		return
	# 애니메이션 시트가 재생 중이면 정지 포즈로 덮지 않는다. 상태 스크립트들은 enter()에서
	# set_pose()를 부르는데, 상태 전환 직전 play_state_animation()이 이미 시트를 걸어놨다.
	if _pose_override_active:
		return
	if _frames.has(pose):
		_sprite.texture = _frames[pose]


func refresh_appearance() -> void:
	_frames.clear()
	_pose = "idle"
	_pose_override_active = false
	_pose_override_state = ""
	if _is_animated_pet():
		var state_name: String = machine.current_name() if machine != null else "Idle"
		var animation_name := _bichon_override if not _bichon_override.is_empty() else _animation_for_state(state_name)
		_set_bichon_animation(animation_name)
		return

	var char_key: String = "egg" if ps.stage == "egg" else ps.species
	var pose_list: Array = EGG_POSES if ps.stage == "egg" else POSES
	# 진화 완료 시 우선순위: evolved2 > evolved > 기본 (아트 없으면 순차 폴백)
	var dirs: Array = ["res://assets/sprites/chars/%s/" % char_key]
	if ps.evolved and ps.stage != "egg":
		dirs.push_front("res://assets/sprites/chars/%s_evolved/" % char_key)
	if ps.evolved_2 and ps.stage != "egg":
		dirs.push_front("res://assets/sprites/chars/%s_evolved2/" % char_key)
	_body_tier = "base"
	for dir_path in dirs:
		if not ResourceLoader.exists(dir_path + "idle.png"):
			continue
		if dir_path.ends_with("_evolved2/"):
			_body_tier = "evolved2"
		elif dir_path.ends_with("_evolved/"):
			_body_tier = "evolved"
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
	_sprite.hframes = 1
	_sprite.vframes = 1
	_sprite.frame = 0
	_bichon_frame = 0
	_bichon_sprite_frame_sequence = []
	_bichon_frame_foot_padding = []
	_bichon_frame_horizontal_offsets = []
	# 임포트 캐시가 없거나 로드가 실패하면 texture가 null이므로 캔버스 기본값으로 폴백
	_frame_size = _sprite.texture.get_size() if _sprite.texture != null else Vector2.ONE * STATIC_POSE_SIZE
	_base_scale = Vector2.ONE * STAGE_SCALE.get(ps.stage, 0.5) * Characters.get_body_scale(ps.species, _body_tier)
	_sprite.scale = _base_scale
	_sprite.position = _sprite_anchor()
	# Zzz·@_@ 라벨은 스프라이트 상단 근처에 (진화 배지는 제거됨 — 위쪽 클릭 영역 최소화)
	_update_mark_positions()


# --- 상태별 표현 (states/*.gd에서 호출) ---

func play_state_animation(state_name: String) -> void:
	if _is_animated_pet():
		if _bichon_override.is_empty():
			_set_bichon_animation(_animation_for_state(state_name))
		return
	# 포즈 캐릭터: 이 상태에 시트가 있으면 재생하고, 없으면 오버라이드를 끄고 정지 포즈로 돌아간다.
	if not start_animated_pose(state_name):
		stop_animated_pose()


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


## 관리자 콘솔(QA용) — 종족/성장단계/진화단계를 즉시 바꾸고 화면을 새로고침한다.
## tier: "base" | "evolved" | "evolved2"
func debug_set_appearance(species: String, stage: String, tier: String) -> void:
	ps.species = species
	ps.stage = stage
	ps.evolved = tier != "base"
	ps.evolved_2 = tier == "evolved2"
	refresh_appearance()
	if machine != null:
		machine.transition_to("Egg" if stage == "egg" else "Idle")


## 관리자 콘솔(QA용) — 상태머신을 강제 전환한다. Sick/Sulk는 조건 플래그도 맞춰서
## _check_global()이 다음 프레임에 곧바로 되돌리지 않게 하고, 그 외 상태는 두 플래그를 꺼서
## 이전 강제 상태가 남아있지 않게 한다.
func debug_force_state(state_name: String) -> void:
	if machine == null:
		return
	ps.is_sick = state_name == "Sick"
	ps.is_sulking = state_name == "Sulk"
	machine.transition_to(state_name)


func _is_bichon() -> bool:
	return ps != null and ps.stage != "egg" and ps.species == "bichon"


func _is_animated_pet() -> bool:
	return _is_bichon()


## bichon류(전신 애니메이션 펫)뿐 아니라 포즈 캐릭터의 걷기/잠자기 오버라이드가 켜져 있을 때도 참.
## get_click_rect()/horizontal_edge_margin() 등 몸통 크기 계산은 이 조건을 쓰지 않는다 —
## 포즈 캐릭터는 걷는 동안에도 자기 몸통 크기(STAGE_SCALE*BODY_SCALE) 그대로 유지해야 한다.
func _has_active_frame_animation() -> bool:
	return _is_bichon() or _pose_override_active


func _animation_catalog() -> Dictionary:
	return BICHON_ANIMATIONS


func _animated_visible_size_multiplier() -> float:
	return BICHON_VISIBLE_SIZE_MULTIPLIER


func _animated_edge_buffer() -> float:
	return BICHON_EDGE_BUFFER


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
	# 캐시 무시 로드 — 해솔의 상태별 시트는 장당 6~12MB(비압축 RGBA)라, 기본 캐시(load())로
	# 불러오면 한 세션에서 여러 상태를 거칠수록 전부 영구 누적된다(관찰된 상주 메모리 급증의
	# 주원인). CACHE_MODE_IGNORE로 불러오면 _sprite.texture가 교체되는 순간 참조가 끊겨
	# 즉시 해제되고, 현재 활성 상태 한 장만 메모리에 남는다. 같은 상태 재진입 시 디스크에서
	# 다시 디코딩하지만 이 크기(<1MB PNG)는 수십 ms 내로 체감 지연이 없다.
	var texture: Texture2D = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
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
	if _pose_override_active:
		_advance_override_frame(delta, _pose_override_fps, _pose_override_frame_count, _pose_override_loop)
		return
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


## 포즈 캐릭터 오버라이드(걷기·잠자기) 공통 프레임 진행. bichon 카탈로그 경로와 달리
## 상태별 config를 매 프레임 조회하지 않고 진입 시 캐시해 둔 fps/frames/loop를 쓴다.
func _advance_override_frame(delta: float, fps: float, frame_count: int, loop: bool) -> void:
	if fps <= 0.0 or frame_count <= 0:
		return
	_bichon_elapsed += delta
	var override_frame := int(_bichon_elapsed * fps)
	if loop:
		override_frame %= frame_count
	else:
		override_frame = mini(override_frame, frame_count - 1)
	_set_bichon_frame(override_frame)


## 현재 종족·티어에서 이 상태에 걸린 시트 설정. 없으면 빈 딕셔너리.
func _pose_override_config(state_name: String) -> Dictionary:
	if ps == null or ps.stage == "egg":
		return {}
	var entry: Dictionary = ANIMATED_POSE_OVERRIDES.get(ps.species, {})
	# "tiers"가 있으면 그 티어에서만 시트를 쓴다 — 진화 단계 아트가 없는 종족은 정지 포즈로 폴백.
	var tiers: Array = entry.get("tiers", [])
	if not tiers.is_empty() and not (_body_tier in tiers):
		return {}
	var config: Dictionary = entry.get("states", {}).get(state_name, {})
	# 티어별 시트가 따로 있는 상태는 한 단 더 들어간다 (config에 "path"가 없으면 티어 딕셔너리).
	if not config.is_empty() and not config.has("path"):
		return config.get(_body_tier, {})
	return config


## 포즈 캐릭터의 한 상태를 다중 프레임 시트로 재생. state_machine의 상태 전환마다
## play_state_animation()이 호출하며, walk_state/sleep_state는 진입 시점을 직접 잡으려고
## start_animated_walk()/start_animated_sleep() 래퍼로 다시 부른다.
## 등록이 없으면 false를 반환해 호출부가 기존 정지 포즈로 폴백한다.
func start_animated_pose(state_name: String) -> bool:
	var config := _pose_override_config(state_name)
	if config.is_empty():
		return false
	var texture: Texture2D = load(String(config["path"]))
	if texture == null:
		return false
	_pose_override_active = true
	_pose_override_state = state_name
	_sprite.texture = texture
	_sprite.hframes = int(config["columns"])
	_sprite.vframes = int(config["rows"])
	_frame_size = texture.get_size() / Vector2(_sprite.hframes, _sprite.vframes)
	_bichon_frame_foot_padding = config.get("foot_padding", [])
	_bichon_frame_horizontal_offsets = config.get("horizontal_offsets", [])
	_bichon_sprite_frame_sequence = config.get("sprite_frame_sequence", [])
	_pose_override_fps = float(config.get("fps", 10.0))
	_pose_override_frame_count = int(config.get("frames", int(config["columns"]) * int(config["rows"])))
	_pose_override_loop = bool(config.get("loop", true))
	_bichon_elapsed = 0.0
	# idle과 같은 고정 배율 — 원본 시트의 스쿼시-스트레치만 자연스럽게 보이고 배율 자체는 흔들리지 않는다.
	_base_scale = Vector2.ONE * float(STAGE_SCALE.get(ps.stage, 0.5)) * _pose_override_body_scale()
	_sprite.scale = _base_scale
	_set_bichon_frame(0)
	# 잠자기 중 Zzz 라벨 등 마커는 몸통 높이를 기준으로 붙는다.
	_update_mark_positions()
	return true


## 시트 재생 종료 후 정지 포즈로 복귀. 등록되지 않은 상태로 전환될 때도 호출된다.
func stop_animated_pose() -> void:
	if not _pose_override_active:
		return
	_pose_override_active = false
	_pose_override_state = ""
	_bichon_frame_foot_padding = []
	_bichon_frame_horizontal_offsets = []
	_bichon_sprite_frame_sequence = []
	# 정지 포즈는 단일 프레임 텍스처라 격자를 되돌려야 한다. 되돌리지 않으면 다음 set_pose()가
	# 128x128 이미지를 6칸으로 계속 잘라 몸통 1/6만 보인다.
	_sprite.hframes = 1
	_sprite.vframes = 1
	_sprite.frame = 0
	_bichon_frame = 0
	# 시트 텍스처가 그대로 남으면 격자를 되돌린 순간 시트 전체가 한 칸으로 보인다.
	set_pose(_pose)
	_frame_size = _sprite.texture.get_size() if _sprite.texture != null else Vector2.ONE * STATIC_POSE_SIZE
	_base_scale = Vector2.ONE * float(STAGE_SCALE.get(ps.stage, 0.5)) * Characters.get_body_scale(ps.species, _body_tier)
	_sprite.scale = _base_scale
	# foot_padding/horizontal_offsets로 밀어놨던 위치를 정지 포즈 기준으로 복귀
	_position_sprite_for_current_frame()
	_update_mark_positions()


## 시트 셀 크기가 정지 포즈 캔버스와 달라 생기는 몸통 크기 차이를 sheet_scale로 흡수한다.
func _pose_override_body_scale() -> float:
	var entry: Dictionary = ANIMATED_POSE_OVERRIDES.get(ps.species, {})
	return Characters.get_body_scale(ps.species, _body_tier) * float(entry.get("sheet_scale", 1.0))


## walk_state.gd가 걷기 진입 시 호출 — 기존 walk1/walk2 토글 폴백 판정을 그대로 유지한다.
func start_animated_walk() -> bool:
	return start_animated_pose("Walk")


func stop_animated_walk() -> void:
	stop_animated_pose()


## sleep_state.gd가 구석 도착 시 호출 — 이동 중에는 Walk 시트를 쓰고 도착 후 Sleep으로 바꾼다.
func start_animated_sleep() -> bool:
	return start_animated_pose("Sleep")


func stop_animated_sleep() -> void:
	stop_animated_pose()


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
	if _has_active_frame_animation() and _bichon_frame < _bichon_frame_horizontal_offsets.size():
		var horizontal_direction: float = -1.0 if _sprite.flip_h else 1.0
		_sprite.position.x += float(_bichon_frame_horizontal_offsets[_bichon_frame]) * _base_scale.x * horizontal_direction
	if _has_active_frame_animation() and _bichon_frame < _bichon_frame_foot_padding.size():
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


func walk_bob(on: bool, waddle: bool = false) -> void:
	_kill_bob()
	# 애니메이션 시트 펫은 시트 자체에 보행 모션이 있어 tween bob을 쓰지 않는다.
	if _keep_bichon_grounded():
		return
	if not on:
		return
	_bob_tween = create_tween().set_loops()
	var down := _sprite_anchor().y
	var up := down - 6.0
	_bob_tween.tween_property(_sprite, "position:y", up, 0.18)
	_bob_tween.tween_property(_sprite, "position:y", down, 0.18)
	# walk1/walk2가 동일한 캐릭터(뚱실이 등)는 몸을 좌우로 흔들어 걷는 느낌 부여
	if waddle:
		_wobble_tween = create_tween().set_loops()
		_wobble_tween.tween_property(_sprite, "rotation", 0.08, 0.28)
		_wobble_tween.tween_property(_sprite, "rotation", -0.08, 0.28)


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


func celebrate() -> void:
	# 신나는 세리머니: 폴짝폴짝 3연속 점프 + 음표 + 신남 표정
	# 애니메이션 시트 펫은 좌표를 tween하면 프레임별 발 위치(foot_padding)가 무시된 곳에서 멈춘다.
	if _is_animated_pet():
		_play_care_reaction("Play", 0.8)
		_float_text("♪")
		return
	# 시트 재생 중인 포즈 캐릭터도 같은 이유로 좌표 tween을 쓰지 않는다 (시트가 모션을 갖고 있다).
	if _keep_bichon_grounded():
		_float_text("♪")
		return
	var prev_pose := _pose
	set_pose("happy")
	var base_y := -STATIC_POSE_SIZE * _base_scale.y * 0.5
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
	if _is_animated_pet():
		_play_care_reaction("Play", 0.8)
		_float_text("신난다~♪")
		return
	if _keep_bichon_grounded():
		_float_text("신난다~♪")
		return
	var base_y := -STATIC_POSE_SIZE * _base_scale.y * 0.5
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
	if _is_animated_pet():
		_position_sprite_for_current_frame()
		return
	_sprite.position.y = -STATIC_POSE_SIZE * _base_scale.y * 0.5


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
		if _is_animated_pet():
			_play_care_reaction("Play", 0.8)
		elif not ps.is_sick and machine.current_name() not in machine.UNINTERRUPTIBLE:
			machine.transition_to("Play")
	elif action == "medicine":
		_float_text("+HP")


func _on_pooped() -> void:
	if ps.stage != "egg" and machine.current_name() not in machine.UNINTERRUPTIBLE:
		machine.transition_to("Poop")


func _float_text(text: String) -> void:
	# 스프라이트 내부(캐릭터 머리 위 근처)에서 시작해서 살짝만 위로.
	# 스프라이트 밖으로 크게 나가지 않도록 해서 위쪽 클릭 영역을 확장할 필요가 없게.
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.95, 0.4, 0.55))
	var start_y := -_frame_size.y * _base_scale.y * 0.85
	label.position = Vector2(-10.0, start_y)
	add_child(label)
	var t := create_tween()
	t.tween_property(label, "position:y", start_y - 18.0, 0.8)
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
	if _wobble_tween != null:
		_wobble_tween.kill()
		_wobble_tween = null
		_sprite.rotation = 0.0


func _kill_idle_breathe() -> void:
	if _idle_tween != null:
		_idle_tween.kill()
		_idle_tween = null
	_sprite.scale = _base_scale


func _keep_bichon_grounded() -> bool:
	if not _has_active_frame_animation():
		return false
	_kill_idle_breathe()
	_position_sprite_for_current_frame()
	return true


func _quit_app() -> void:
	get_node("/root/SaveManager").save_game()
	get_tree().quit()


## 위장/숨김 모드 설정 — main.gd에서 단축키·케어메뉴로 호출.
## mode: "normal" | "disguise" | "invisible"
func set_hide_mode(mode: String) -> void:
	if mode == hide_mode:
		return
	hide_mode = mode
	# 액세서리(응아 마커·zzz·아픔 마커) 정리
	_zzz.visible = false
	_sick_mark.visible = false
	match mode:
		"invisible":
			_sprite.visible = false
			_kill_bob()
		"disguise":
			_sprite.visible = true
			_kill_bob()
			_sprite.rotation = 0.0
			_sprite.scale = _base_scale
			# 스프라이트 하단이 지면에 닿도록 정렬 (Vector2.ZERO는 지면 아래로 잘림)
			_sprite.position = Vector2(0.0, -SPRITE_SIZE * _base_scale.y * 0.5)
			# 왼쪽 하단(모니터 구석)으로 순간이동 — 실제 데스크톱 아이콘처럼 자리잡음
			var left_min: float = primary_local.position.x + 40.0 if primary_local.size.x > 0.0 else 40.0
			var left_max: float = left_min + 160.0
			position = Vector2(randf_range(left_min, left_max), ground_y)
			if not _disguise_textures.is_empty():
				_sprite.texture = _disguise_textures[randi() % _disguise_textures.size()]
			# 위장 텍스처 없으면 그냥 현재 스프라이트 유지 (그래도 상호작용은 차단됨)
		"normal":
			_sprite.visible = true
			refresh_appearance()
			set_pose(_pose)


func toggle_disguise() -> void:
	set_hide_mode("normal" if hide_mode == "disguise" else "disguise")


func toggle_invisible() -> void:
	set_hide_mode("normal" if hide_mode == "invisible" else "invisible")


func _load_disguise_textures() -> void:
	_disguise_textures.clear()
	for fname in DISGUISE_FILES:
		var res_path: String = "res://assets/sprites/disguise/" + str(fname)
		if not ResourceLoader.exists(res_path):
			continue
		var tex = load(res_path)
		if tex != null and tex is Texture2D:
			_disguise_textures.append(tex)
