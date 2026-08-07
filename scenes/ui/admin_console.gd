# 🛠️ 관리자 콘솔 (QA 전용) — 저장/진화 조건과 무관하게 모든 캐릭터·성장단계·진화단계·
# 동작 상태를 즉시 미리보기 위한 개발자 패널. 트레이 메뉴에서 연다.
# 주의: 이 패널이 열려 있는 동안 main이 창을 포커스 가능 상태로 전환한다 (notebook과 동일 패턴).
extends PanelContainer

const UITheme := preload("res://scripts/ui_theme.gd")
const Characters := preload("res://scripts/data/characters.gd")

const STAGES := [["egg", "알"], ["baby", "아기"], ["child", "성장"], ["adult", "성체"]]
const TIERS := [["base", "기본"], ["evolved", "1차 진화"], ["evolved2", "2차 진화"]]
const STATES := [
	["Idle", "대기"], ["Walk", "걷기"], ["Eat", "먹기"], ["Sleep", "잠자기"],
	["Sick", "아픔"], ["Sulk", "시무룩"], ["Play", "놀기"], ["Poop", "응아"],
]

var pet: Node2D

var _species_ids: Array = []
var _info_label: Label
var _species_buttons := {}
var _stage_buttons := {}
var _tier_buttons := {}

var _header: Control
var _positioned := false     # open_at_corner()가 기본 위치는 처음 한 번만 잡고, 이후엔 드래그한 위치 유지
var _dragging := false
var _drag_start_mouse := Vector2.ZERO
var _drag_start_pos := Vector2.ZERO


func setup(pet_node: Node2D) -> void:
	pet = pet_node
	_refresh_info()


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(320.0, 0.0)
	add_theme_stylebox_override("panel", UITheme.panel())
	_species_ids = Characters.CHARACTERS.keys()

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 7)
	add_child(root)

	var header := HBoxContainer.new()
	header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	var title := UITheme.make_label("🛠️ 관리자 콘솔 (캐릭터 테스트) — 드래그해서 이동", UITheme.FONT_TITLE, UITheme.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_x := Button.new()
	close_x.text = "✕"
	UITheme.style_button(close_x)
	close_x.add_theme_font_size_override("font_size", UITheme.FONT_SMALL)
	close_x.add_theme_color_override("font_color", UITheme.MUTED)
	close_x.pressed.connect(func(): visible = false)
	header.add_child(close_x)
	root.add_child(header)
	_header = header

	_info_label = UITheme.make_label("", UITheme.FONT_SMALL, UITheme.MUTED)
	root.add_child(_info_label)
	root.add_child(UITheme.hsep())

	root.add_child(_section("캐릭터"))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	for species in _species_ids:
		var label: String = Characters.CHARACTERS[species]["name_kr"]
		var btn := _toggle_chip_button(label, _on_species_selected.bind(species))
		grid.add_child(btn)
		_species_buttons[species] = btn
	root.add_child(grid)

	var cycle_row := HBoxContainer.new()
	cycle_row.add_theme_constant_override("separation", 4)
	cycle_row.add_child(_chip_button("◀ 이전", _on_cycle.bind(-1)))
	cycle_row.add_child(_chip_button("다음 ▶", _on_cycle.bind(1)))
	cycle_row.add_child(_chip_button("🎲 무작위", _on_random))
	root.add_child(cycle_row)
	root.add_child(UITheme.hsep())

	root.add_child(_section("성장 단계"))
	var stage_row := HBoxContainer.new()
	stage_row.add_theme_constant_override("separation", 4)
	for pair in STAGES:
		var btn := _toggle_chip_button(pair[1], _on_stage_selected.bind(pair[0]))
		stage_row.add_child(btn)
		_stage_buttons[pair[0]] = btn
	root.add_child(stage_row)

	root.add_child(_section("진화 단계"))
	var tier_row := HBoxContainer.new()
	tier_row.add_theme_constant_override("separation", 4)
	for pair in TIERS:
		var btn := _toggle_chip_button(pair[1], _on_tier_selected.bind(pair[0]))
		tier_row.add_child(btn)
		_tier_buttons[pair[0]] = btn
	root.add_child(tier_row)
	root.add_child(UITheme.hsep())

	root.add_child(_section("동작/상태 테스트"))
	var state_grid := GridContainer.new()
	state_grid.columns = 4
	state_grid.add_theme_constant_override("h_separation", 4)
	state_grid.add_theme_constant_override("v_separation", 4)
	for pair in STATES:
		state_grid.add_child(_chip_button(pair[1], _on_state_selected.bind(pair[0])))
	root.add_child(state_grid)


func open_at_corner(_screen_size: Vector2) -> void:
	visible = true
	_refresh_info()
	if _positioned:
		return
	_positioned = true
	await get_tree().process_frame
	position = Vector2(20.0, 20.0)


## 헤더(제목줄) 영역을 누른 채 드래그하면 패널이 움직인다. 버튼 위 클릭은 버튼이
## accept_event()로 먼저 소비하므로 여기까지 올라오지 않는다.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.position.y <= _header.size.y:
			_dragging = true
			_drag_start_mouse = get_global_mouse_position()
			_drag_start_pos = position
			accept_event()
		elif not event.pressed:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		position = _drag_start_pos + (get_global_mouse_position() - _drag_start_mouse)
		accept_event()


func _on_species_selected(species: String) -> void:
	pet.debug_set_appearance(species, pet.ps.stage, _current_tier())
	_refresh_info()


func _on_stage_selected(stage: String) -> void:
	pet.debug_set_appearance(pet.ps.species if pet.ps.species != "" else _species_ids[0], stage, _current_tier())
	_refresh_info()


func _on_tier_selected(tier: String) -> void:
	pet.debug_set_appearance(pet.ps.species if pet.ps.species != "" else _species_ids[0], pet.ps.stage, tier)
	_refresh_info()


func _on_state_selected(state_name: String) -> void:
	pet.debug_force_state(state_name)
	_refresh_info()


func _on_cycle(step: int) -> void:
	var current: String = pet.ps.species
	var idx: int = _species_ids.find(current)
	if idx == -1:
		idx = 0
	else:
		idx = (idx + step + _species_ids.size()) % _species_ids.size()
	pet.debug_set_appearance(_species_ids[idx], pet.ps.stage, _current_tier())
	_refresh_info()


func _on_random() -> void:
	var species: String = _species_ids[randi() % _species_ids.size()]
	var stage: String = STAGES[randi() % STAGES.size()][0]
	var tier: String = TIERS[randi() % TIERS.size()][0]
	pet.debug_set_appearance(species, stage, tier)
	_refresh_info()


func _current_tier() -> String:
	if pet.ps.evolved_2:
		return "evolved2"
	if pet.ps.evolved:
		return "evolved"
	return "base"


func _refresh_info() -> void:
	if pet == null:
		return
	var species: String = pet.ps.species
	var name_kr: String = Characters.CHARACTERS.get(species, {}).get("name_kr", species)
	var tier := _current_tier()
	var tier_kr: String = {"base": "기본", "evolved": "1차 진화", "evolved2": "2차 진화"}[tier]
	var stage_kr: String = {"egg": "알", "baby": "아기", "child": "성장", "adult": "성체"}.get(pet.ps.stage, pet.ps.stage)
	var state_name: String = pet.machine.current_name() if pet.machine != null else ""
	_info_label.text = "현재: %s · %s · %s · %s" % [name_kr, stage_kr, tier_kr, state_name]
	for species_id in _species_buttons:
		(_species_buttons[species_id] as Button).button_pressed = (species_id == species)
	for stage_key in _stage_buttons:
		(_stage_buttons[stage_key] as Button).button_pressed = (stage_key == pet.ps.stage)
	for tier_key in _tier_buttons:
		(_tier_buttons[tier_key] as Button).button_pressed = (tier_key == tier)


func _process(_delta: float) -> void:
	if visible:
		_refresh_info()


func _section(text: String) -> Label:
	return UITheme.make_label(text, UITheme.FONT_SMALL, UITheme.MUTED)


func _chip_button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	UITheme.style_button(b, true)
	b.add_theme_font_size_override("font_size", UITheme.FONT_SMALL)
	b.pressed.connect(handler)
	return b


## 현재 선택 상태를 계속 표시해야 하는 버튼(캐릭터/성장단계/진화단계)용 — button_pressed는
## _refresh_info()가 매번 실제 pet.ps 값으로 다시 맞춘다.
func _toggle_chip_button(text: String, handler: Callable) -> Button:
	var b := _chip_button(text, handler)
	b.toggle_mode = true
	return b
