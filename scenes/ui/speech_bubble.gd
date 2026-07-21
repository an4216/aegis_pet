# Design Ref: §5.4 — 말풍선. 펫 머리 바로 위에 꼬리 달린 말풍선이 뽀잉 하고 나타난다.
extends PanelContainer

const SHOW_SECONDS := 5.0
const TAIL_H := 8.0
const HEAD_GAP := 4.0

const BG := Color(1.0, 0.99, 0.94, 0.98)
const BORDER := Color(0.55, 0.4, 0.47)

var _label: Label
var _target: Node2D
var _countdown := 0.0
var _screen_size := Vector2.ZERO
var _fade: Tween
var _debug_in := -1.0


func _ready() -> void:
	visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = BG
	style.set_corner_radius_all(12)
	style.border_color = BORDER
	style.set_border_width_all(2)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	style.shadow_size = 4
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.15)
	add_theme_stylebox_override("panel", style)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.32, 0.24, 0.29))
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_label)


func say(text: String, target: Node2D, screen_size: Vector2) -> void:
	_label.text = text
	_label.custom_minimum_size.x = minf(190.0, 14.0 + text.length() * 11.0)
	_target = target
	_screen_size = screen_size
	_countdown = SHOW_SECONDS
	visible = true
	reset_size()
	if _fade != null:
		_fade.kill()  # 이전 페이드아웃이 새 말풍선을 지우지 않도록
	modulate.a = 0.0
	scale = Vector2(0.5, 0.5)
	_fade = create_tween().set_parallel()
	_fade.tween_property(self, "modulate:a", 1.0, 0.18)
	_fade.tween_property(self, "scale", Vector2.ONE, 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_debug_in = 0.5


func _draw() -> void:
	# 말꼬리: 아래 중앙에서 펫을 향하는 작은 삼각형
	var cx := size.x * 0.5
	var y := size.y - 2.0
	draw_colored_polygon(
		PackedVector2Array([Vector2(cx - 8.0, y), Vector2(cx + 8.0, y), Vector2(cx, y + TAIL_H + 2.0)]),
		BORDER
	)
	draw_colored_polygon(
		PackedVector2Array([Vector2(cx - 5.0, y - 1.0), Vector2(cx + 5.0, y - 1.0), Vector2(cx, y + TAIL_H - 1.0)]),
		BG
	)


func _process(delta: float) -> void:
	if not visible or _target == null:
		return
	pivot_offset = Vector2(size.x * 0.5, size.y + TAIL_H)  # 뽀잉 기준점 = 꼬리 끝
	var head_y: float = _target.global_position.y - 140.0
	if _target.has_method("get_click_rect"):
		head_y = _target.get_click_rect().position.y
	position = Vector2(
		clampf(_target.global_position.x - size.x * 0.5, 8.0, _screen_size.x - size.x - 8.0),
		clampf(head_y - HEAD_GAP - TAIL_H - size.y, 8.0, _screen_size.y - size.y - 8.0),
	)
	queue_redraw()
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