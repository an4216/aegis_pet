# Design Ref: §5.3 — 스탯 요약 팝업 (트레이 좌클릭으로 토글) + 진화 진행률 (FR-15 v3).
extends PanelContainer

const UITheme := preload("res://scripts/ui_theme.gd")
const Characters := preload("res://scripts/data/characters.gd")
const STAT_LABELS := [
	["hunger", "배고픔", Color(0.95, 0.6, 0.3)],
	["happiness", "행복", Color(0.95, 0.5, 0.65)],
	["cleanliness", "청결", Color(0.4, 0.75, 0.9)],
	["energy", "에너지", Color(0.55, 0.8, 0.45)],
	["health", "건강", Color(0.9, 0.35, 0.4)],
]
const STAGE_KR := {"egg": "알", "baby": "유아기", "child": "소년기", "adult": "성체"}

var _ps: Node
var _header: Label
var _bars := {}
var _evo_section: VBoxContainer
var _evo_hint: Label
var _evo_bar: ProgressBar
var _evo_progress_label: Label


func _ready() -> void:
	visible = false
	add_theme_stylebox_override("panel", UITheme.panel())

	_ps = get_node("/root/PetState")
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	_header = UITheme.make_label("", UITheme.FONT_TITLE, UITheme.INK)
	vbox.add_child(_header)

	for entry in STAT_LABELS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label := UITheme.make_label(entry[1], UITheme.FONT_BODY, UITheme.MUTED)
		label.custom_minimum_size = Vector2(48.0, 0.0)
		row.add_child(label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(140.0, 14.0)
		bar.max_value = 100.0
		bar.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = entry[2]
		fill.set_corner_radius_all(5)
		bar.add_theme_stylebox_override("fill", fill)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.93, 0.90, 0.90)
		bg.set_corner_radius_all(5)
		bar.add_theme_stylebox_override("background", bg)
		row.add_child(bar)
		_bars[entry[0]] = bar
		vbox.add_child(row)

	vbox.add_child(UITheme.hsep())
	_evo_section = VBoxContainer.new()
	_evo_section.add_theme_constant_override("separation", 3)
	_evo_hint = UITheme.make_label("", UITheme.FONT_SMALL, UITheme.MUTED)
	_evo_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_evo_hint.custom_minimum_size = Vector2(210.0, 0.0)
	_evo_section.add_child(_evo_hint)
	_evo_bar = ProgressBar.new()
	_evo_bar.custom_minimum_size = Vector2(210.0, 8.0)
	_evo_bar.max_value = 100.0
	_evo_bar.show_percentage = false
	var evo_fill := StyleBoxFlat.new()
	evo_fill.bg_color = UITheme.ACCENT
	evo_fill.set_corner_radius_all(4)
	_evo_bar.add_theme_stylebox_override("fill", evo_fill)
	var evo_bg := StyleBoxFlat.new()
	evo_bg.bg_color = Color(0.93, 0.90, 0.90)
	evo_bg.set_corner_radius_all(4)
	_evo_bar.add_theme_stylebox_override("background", evo_bg)
	_evo_section.add_child(_evo_bar)
	_evo_progress_label = UITheme.make_label("", UITheme.FONT_SMALL, UITheme.MUTED)
	_evo_section.add_child(_evo_progress_label)
	vbox.add_child(_evo_section)

	_ps.stat_changed.connect(_on_stat_changed)


func _on_stat_changed(_stat: String, _value: float) -> void:
	if visible:
		refresh()


func toggle(screen_size: Vector2) -> void:
	visible = not visible
	if visible:
		refresh()
		await get_tree().process_frame
		position = Vector2(screen_size.x - size.x - 16.0, screen_size.y - size.y - 16.0)


func refresh() -> void:
	var name_kr := "?"
	if _ps.evolved and _ps.species != "":
		name_kr = "✨ %s" % Characters.get_evolved_name(_ps.species)
	elif _ps.species != "" and Characters.CHARACTERS.has(_ps.species):
		name_kr = Characters.CHARACTERS[_ps.species]["name_kr"]
	elif _ps.stage == "egg":
		name_kr = "알"
	var age_days := int(_ps.age_minutes / 1440.0)
	_header.text = "%s · %s · %d일차%s" % [
		name_kr, STAGE_KR.get(_ps.stage, "?"), age_days,
		" · 아픔!" if _ps.is_sick else "",
	]
	for stat in _bars:
		_bars[stat].value = _ps.stats[stat]
	_refresh_evolution()


func _refresh_evolution() -> void:
	if _ps.stage == "egg" or _ps.species == "":
		_evo_section.visible = false
		return
	if _ps.evolved:
		_evo_section.visible = true
		_evo_hint.text = "✨ 진화 완료 — %s" % Characters.get_evolved_name(_ps.species)
		_evo_bar.value = 100.0
		_evo_progress_label.text = ""
		return
	_evo_section.visible = true
	var p: Dictionary = _ps.evolution_progress()
	_evo_hint.text = "📈 진화까지: %s" % p["hint"]
	_evo_bar.value = p["ratio"] * 100.0
	_evo_progress_label.text = "%s / %s (%d%%)" % [
		_fmt_number(p["current"]), _fmt_number(p["target"]), int(p["ratio"] * 100.0)
	]


func _fmt_number(v: float) -> String:
	if v >= 10000:
		return "%.1fk" % (v / 1000.0)
	if int(v) == v:
		return str(int(v))
	return "%.0f" % v
