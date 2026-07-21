# Design Ref: §5.4 — 말풍선. 펫 머리 위를 따라다니며 5초 후 사라진다.
extends PanelContainer

const SHOW_SECONDS := 5.0

var _label: Label
var _target: Node2D
var _countdown := 0.0
var _screen_size := Vector2.ZERO


func _ready() -> void:
	visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.95)
	style.set_corner_radius_all(12)
	style.border_color = Color(0.6, 0.5, 0.55)
	style.set_border_width_all(2)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(0.28, 0.24, 0.28))
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(0.0, 0.0)
	add_child(_label)


func say(text: String, target: Node2D, screen_size: Vector2) -> void:
	_label.text = text
	_label.custom_minimum_size.x = minf(240.0, 16.0 + text.length() * 14.0)
	_target = target
	_screen_size = screen_size
	_countdown = SHOW_SECONDS
	visible = true
	modulate.a = 0.0
	size = Vector2.ZERO
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.25)


func _process(delta: float) -> void:
	if not visible or _target == null:
		return
	position = Vector2(
		clampf(_target.global_position.x - size.x * 0.5, 8.0, _screen_size.x - size.x - 8.0),
		clampf(_target.global_position.y - 170.0 - size.y, 8.0, _screen_size.y - size.y - 8.0),
	)
	_countdown -= delta
	if _countdown <= 0.6 and _countdown + delta > 0.6:
		var t := create_tween()
		t.tween_property(self, "modulate:a", 0.0, 0.5)
	if _countdown <= 0.0:
		visible = false
