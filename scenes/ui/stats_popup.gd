# Design Ref: §5.3 — 스탯 요약 팝업 (트레이 좌클릭으로 토글).
extends PanelContainer

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


func _ready() -> void:
	visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.96)
	style.set_corner_radius_all(10)
	style.border_color = Color(0.55, 0.45, 0.5)
	style.set_border_width_all(2)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)

	_ps = get_node("/root/PetState")
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 15)
	_header.add_theme_color_override("font_color", Color(0.3, 0.25, 0.3))
	vbox.add_child(_header)

	for entry in STAT_LABELS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.text = entry[1]
		label.custom_minimum_size = Vector2(52.0, 0.0)
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color(0.35, 0.3, 0.35))
		row.add_child(label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(140.0, 16.0)
		bar.max_value = 100.0
		bar.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = entry[2]
		fill.set_corner_radius_all(6)
		bar.add_theme_stylebox_override("fill", fill)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.9, 0.88, 0.9)
		bg.set_corner_radius_all(6)
		bar.add_theme_stylebox_override("background", bg)
		row.add_child(bar)
		_bars[entry[0]] = bar
		vbox.add_child(row)

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
	if _ps.species != "" and Characters.CHARACTERS.has(_ps.species):
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
