# Design Ref: §5.3 — 우클릭 케어 메뉴. OS 팝업 대신 씬 내 패널(비포커스 창 대응).
extends PanelContainer

signal action_selected(action: String)

const ACTIONS := [
	["feed", "🍚 먹이"],
	["snack", "🍪 간식"],
	["play", "🧶 놀기"],
	["clean", "🧹 청소"],
	["medicine", "💊 약"],
	["sleep", "💤 재우기"],
]
const AUTO_HIDE_SECONDS := 10.0

var _countdown := 0.0


func _ready() -> void:
	visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.96)
	style.set_corner_radius_all(10)
	style.border_color = Color(0.55, 0.45, 0.5)
	style.set_border_width_all(2)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)
	for entry in ACTIONS:
		var button := Button.new()
		button.text = entry[1]
		button.custom_minimum_size = Vector2(110.0, 30.0)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(_on_button.bind(entry[0]))
		vbox.add_child(button)
	var close_button := Button.new()
	close_button.text = "✕ 닫기"
	close_button.custom_minimum_size = Vector2(110.0, 26.0)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_size_override("font_size", 12)
	close_button.add_theme_color_override("font_color", Color(0.55, 0.5, 0.55))
	close_button.pressed.connect(func(): visible = false)
	vbox.add_child(close_button)


func _process(delta: float) -> void:
	if visible:
		_countdown -= delta
		if _countdown <= 0.0:
			visible = false


func open_at(pos: Vector2, screen_size: Vector2) -> void:
	visible = true
	_countdown = AUTO_HIDE_SECONDS
	await get_tree().process_frame  # 크기 계산 후 클램프
	position = Vector2(
		clampf(pos.x, 8.0, screen_size.x - size.x - 8.0),
		clampf(pos.y - size.y * 0.5, 8.0, screen_size.y - size.y - 8.0),
	)


func _on_button(action: String) -> void:
	visible = false
	action_selected.emit(action)
