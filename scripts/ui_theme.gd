# 공용 UI 테마 — 아이보리+로즈 팔레트, 작은 글씨, 낮은 대비, 은은한 그림자.
# 케어 메뉴·수첩 등 모든 패널 UI는 이 테마를 통해 일관된 톤을 유지한다.
extends RefCounted

const BG := Color(0.992, 0.978, 0.958)
const BORDER := Color(0.86, 0.81, 0.79)
const INK := Color(0.30, 0.26, 0.29)
const MUTED := Color(0.60, 0.55, 0.57)
const ACCENT := Color(0.88, 0.48, 0.57)
const HOVER_BG := Color(0.96, 0.91, 0.895)
const PRESS_BG := Color(0.935, 0.87, 0.855)
const INPUT_BG := Color(1.0, 1.0, 1.0, 0.85)

const FONT_TITLE := 14
const FONT_BODY := 12
const FONT_SMALL := 11


static func panel() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = BG
	s.set_corner_radius_all(12)
	s.border_color = BORDER
	s.set_border_width_all(1)
	s.set_content_margin_all(12)
	s.shadow_size = 10
	s.shadow_color = Color(0.25, 0.15, 0.2, 0.13)
	s.shadow_offset = Vector2(0.0, 3.0)
	return s


static func _btn_box(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(8)
	s.content_margin_left = 10.0
	s.content_margin_right = 10.0
	s.content_margin_top = 4.0
	s.content_margin_bottom = 4.0
	return s


## 기본: 투명 배경 + 호버 시 은은한 하이라이트. accent=true: 로즈 배경 강조 버튼.
static func style_button(b: Button, accent: bool = false) -> void:
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", FONT_BODY)
	var normal_bg: Color = ACCENT if accent else Color(0, 0, 0, 0)
	var hover_bg: Color = ACCENT.lightened(0.12) if accent else HOVER_BG
	var press_bg: Color = ACCENT.darkened(0.08) if accent else PRESS_BG
	b.add_theme_stylebox_override("normal", _btn_box(normal_bg))
	b.add_theme_stylebox_override("hover", _btn_box(hover_bg))
	b.add_theme_stylebox_override("pressed", _btn_box(press_bg))
	b.add_theme_stylebox_override("focus", _btn_box(Color(0, 0, 0, 0)))
	var ink: Color = Color.WHITE if accent else INK
	b.add_theme_color_override("font_color", ink)
	b.add_theme_color_override("font_hover_color", ink)
	b.add_theme_color_override("font_pressed_color", ink)
	b.add_theme_color_override("font_focus_color", ink)


static func style_input(e: LineEdit) -> void:
	e.add_theme_font_size_override("font_size", FONT_BODY)
	e.add_theme_color_override("font_color", INK)
	e.add_theme_color_override("font_placeholder_color", Color(MUTED.r, MUTED.g, MUTED.b, 0.7))
	var s := StyleBoxFlat.new()
	s.bg_color = INPUT_BG
	s.border_color = BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.content_margin_left = 8.0
	s.content_margin_right = 8.0
	s.content_margin_top = 4.0
	s.content_margin_bottom = 4.0
	e.add_theme_stylebox_override("normal", s)
	var f: StyleBoxFlat = s.duplicate()
	f.border_color = ACCENT
	e.add_theme_stylebox_override("focus", f)


static func make_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func hsep() -> HSeparator:
	var sep := HSeparator.new()
	var st := StyleBoxLine.new()
	st.color = Color(BORDER.r, BORDER.g, BORDER.b, 0.55)
	sep.add_theme_stylebox_override("separator", st)
	return sep
