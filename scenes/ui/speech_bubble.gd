# Design Ref: §5.4 — 말풍선. 펫 머리 위를 따라다니며 5초 후 사라진다.
extends PanelContainer

const SHOW_SECONDS := 5.0

var _label: Label
var _target: Node2D
var _countdown := 0.0
var _screen_size := Vector2.ZERO
var _fade: Tween
var _debug_in := -1.0


func _ready() -> void:
	visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.99, 0.94, 0.98)
	style.set_corner_radius_all(12)
	style.border_color = Color(0.35, 0.28, 0.32)
	style.set_border_width_all(3)
	style.set_content_margin_all(12)
	style.shadow_size = 6
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.2)
	add_theme_stylebox_override("panel", style)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(0.2, 0.16, 0.2))
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_label)


func say(text: String, target: Node2D, screen_size: Vector2) -> void:
	_label.text = text
	_label.custom_minimum_size.x = minf(260.0, 20.0 + text.length() * 15.0)
	_target = target
	_screen_size = screen_size
	_countdown = SHOW_SECONDS
	visible = true
	reset_size()
	if _fade != null:
		_fade.kill()  # 이전 페이드아웃이 새 말풍선을 지우지 않도록
	modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 1.0, 0.25)
	_debug_in = 0.5


func _process(delta: float) -> void:
	if not visible or _target == null:
		return
	position = Vector2(
		clampf(_target.global_position.x - size.x * 0.5, 8.0, _screen_size.x - size.x - 8.0),
		clampf(_target.global_position.y - 170.0 - size.y, 8.0, _screen_size.y - size.y - 8.0),
	)
	if _debug_in > 0.0:
		_debug_in -= delta
		if _debug_in <= 0.0:
			print("bubble_dbg pos=", position, " size=", size, " a=", modulate.a, " vis=", visible)
	_countdown -= delta
	if _countdown <= 0.6 and _countdown + delta > 0.6:
		if _fade != null:
			_fade.kill()
		_fade = create_tween()
		_fade.tween_property(self, "modulate:a", 0.0, 0.5)
	if _countdown <= 0.0:
		visible = false
