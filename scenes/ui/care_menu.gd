# Design Ref: §5.3 — 우클릭 케어 메뉴. OS 팝업 대신 씬 내 패널(비포커스 창 대응).
extends PanelContainer

signal action_selected(action: String)

const UITheme := preload("res://scripts/ui_theme.gd")
const ACTIONS := [
	["feed", "🍚", "먹이"],
	["snack", "🍪", "간식"],
	["play", "🧶", "놀기"],
	["clean", "🧹", "청소"],
	["medicine", "💊", "약"],
	["sleep", "💤", "재우기"],
]
const AUTO_HIDE_SECONDS := 10.0

var _countdown := 0.0


func _ready() -> void:
	visible = false
	add_theme_stylebox_override("panel", UITheme.panel())

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	add_child(vbox)

	var title := UITheme.make_label("돌보기", UITheme.FONT_SMALL, UITheme.MUTED)
	vbox.add_child(title)
	vbox.add_child(UITheme.hsep())

	for entry in ACTIONS:
		var button := Button.new()
		button.text = "%s  %s" % [entry[1], entry[2]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(108.0, 27.0)
		UITheme.style_button(button)
		button.pressed.connect(_on_button.bind(entry[0]))
		vbox.add_child(button)

	vbox.add_child(UITheme.hsep())
	var close_button := Button.new()
	close_button.text = "닫기"
	close_button.custom_minimum_size = Vector2(108.0, 24.0)
	UITheme.style_button(close_button)
	close_button.add_theme_font_size_override("font_size", UITheme.FONT_SMALL)
	close_button.add_theme_color_override("font_color", UITheme.MUTED)
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
