# 📔 햄찌의 수첩 (FR-21~23) — 할 일 3개 + 리마인더 + 뽀모도로를 한 패널에서 관리.
# 주의: 이 패널이 열려 있는 동안 main이 창을 포커스 가능 상태로 전환한다 (텍스트 입력용).
extends PanelContainer

const UITheme := preload("res://scripts/ui_theme.gd")
const REPEAT_KR := {"once": "한 번", "daily": "매일", "weekdays": "평일"}

var assistant: Node

var _todo_box: VBoxContainer
var _todo_input: LineEdit
var _rem_box: VBoxContainer
var _rem_input: LineEdit
var _rem_hour: SpinBox
var _rem_min: SpinBox
var _rem_repeat: OptionButton
var _pomo_button: Button
var _pomo_label: Label

@onready var _sm: Node = get_node("/root/SaveManager")


func _ready() -> void:
	visible = false
	add_theme_stylebox_override("panel", UITheme.panel())

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 7)
	root.custom_minimum_size = Vector2(272.0, 0.0)
	add_child(root)

	var header := HBoxContainer.new()
	var title := UITheme.make_label("📔 수첩", UITheme.FONT_TITLE, UITheme.INK)
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

	# --- 오늘 할 일 (최대 3개) ---
	root.add_child(_section("오늘 할 일 · 3개까지"))
	_todo_box = VBoxContainer.new()
	_todo_box.add_theme_constant_override("separation", 1)
	root.add_child(_todo_box)
	var todo_row := HBoxContainer.new()
	todo_row.add_theme_constant_override("separation", 5)
	_todo_input = LineEdit.new()
	_todo_input.placeholder_text = "할 일 입력"
	_todo_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_input(_todo_input)
	_todo_input.text_submitted.connect(func(_t): _on_add_todo())
	todo_row.add_child(_todo_input)
	todo_row.add_child(_chip_button("추가", _on_add_todo))
	root.add_child(todo_row)

	root.add_child(UITheme.hsep())

	# --- 리마인더 ---
	root.add_child(_section("리마인더"))
	_rem_box = VBoxContainer.new()
	_rem_box.add_theme_constant_override("separation", 1)
	root.add_child(_rem_box)
	var rem_row := HBoxContainer.new()
	rem_row.add_theme_constant_override("separation", 4)
	_rem_input = LineEdit.new()
	_rem_input.placeholder_text = "내용"
	_rem_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_input(_rem_input)
	rem_row.add_child(_rem_input)
	_rem_hour = _spin(0, 23, 15)
	rem_row.add_child(_rem_hour)
	rem_row.add_child(UITheme.make_label(":", UITheme.FONT_BODY, UITheme.MUTED))
	_rem_min = _spin(0, 59, 0)
	rem_row.add_child(_rem_min)
	root.add_child(rem_row)
	var rem_row2 := HBoxContainer.new()
	rem_row2.add_theme_constant_override("separation", 5)
	_rem_repeat = OptionButton.new()
	_rem_repeat.add_item("한 번", 0)
	_rem_repeat.add_item("매일", 1)
	_rem_repeat.add_item("평일", 2)
	_rem_repeat.focus_mode = Control.FOCUS_NONE
	_rem_repeat.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	_rem_repeat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rem_row2.add_child(_rem_repeat)
	rem_row2.add_child(_chip_button("추가", _on_add_reminder))
	root.add_child(rem_row2)

	root.add_child(UITheme.hsep())

	# --- 뽀모도로 ---
	root.add_child(_section("집중 타이머"))
	var pomo_row := HBoxContainer.new()
	pomo_row.add_theme_constant_override("separation", 8)
	_pomo_button = Button.new()
	_pomo_button.text = "▶  25분 집중"
	UITheme.style_button(_pomo_button, true)
	_pomo_button.pressed.connect(_on_pomo_button)
	pomo_row.add_child(_pomo_button)
	_pomo_label = UITheme.make_label("", UITheme.FONT_BODY, UITheme.MUTED)
	_pomo_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pomo_row.add_child(_pomo_label)
	root.add_child(pomo_row)


func open_at_corner(screen_size: Vector2) -> void:
	visible = true
	refresh()
	await get_tree().process_frame
	position = Vector2(screen_size.x - size.x - 20.0, screen_size.y - size.y - 20.0)


func refresh() -> void:
	for child in _todo_box.get_children():
		child.queue_free()
	var todos: Array = _sm.settings.get("todos", [])
	if todos.is_empty():
		_todo_box.add_child(UITheme.make_label("아직 없음 — 하나 맡겨보세요!", UITheme.FONT_SMALL, UITheme.MUTED))
	for i in todos.size():
		var row := HBoxContainer.new()
		var checkbox := CheckBox.new()
		checkbox.text = todos[i]["text"]
		checkbox.button_pressed = todos[i]["done"]
		checkbox.focus_mode = Control.FOCUS_NONE
		checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		checkbox.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
		checkbox.add_theme_color_override("font_color", UITheme.INK)
		checkbox.add_theme_color_override("font_pressed_color", UITheme.MUTED)
		checkbox.toggled.connect(_on_todo_toggled.bind(i))
		row.add_child(checkbox)
		row.add_child(_x_button(_on_remove_todo.bind(i)))
		_todo_box.add_child(row)

	for child in _rem_box.get_children():
		child.queue_free()
	var reminders: Array = _sm.settings.get("reminders", [])
	if reminders.is_empty():
		_rem_box.add_child(UITheme.make_label("등록된 알림 없음", UITheme.FONT_SMALL, UITheme.MUTED))
	for i in reminders.size():
		var r: Dictionary = reminders[i]
		var row := HBoxContainer.new()
		var time_label := UITheme.make_label("%02d:%02d" % [int(r["hour"]), int(r["minute"])], UITheme.FONT_BODY, UITheme.ACCENT)
		time_label.custom_minimum_size = Vector2(42.0, 0.0)
		row.add_child(time_label)
		var text_label := UITheme.make_label("%s · %s" % [r["text"], REPEAT_KR.get(r["repeat"], "?")], UITheme.FONT_BODY, UITheme.INK)
		text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_label.clip_text = true
		row.add_child(text_label)
		row.add_child(_x_button(_on_remove_reminder.bind(i)))
		_rem_box.add_child(row)

	_refresh_pomo()


func _process(_delta: float) -> void:
	if visible and assistant != null and assistant.pomodoro_phase != "idle":
		_refresh_pomo()


func _refresh_pomo() -> void:
	if assistant == null:
		return
	match assistant.pomodoro_phase:
		"idle":
			_pomo_button.text = "▶  25분 집중"
			_pomo_label.text = ""
		"work":
			_pomo_button.text = "■  중지"
			_pomo_label.text = "집중 %d:%02d" % [int(assistant.pomodoro_left) / 60, int(assistant.pomodoro_left) % 60]
		"break":
			_pomo_button.text = "■  중지"
			_pomo_label.text = "휴식 %d:%02d" % [int(assistant.pomodoro_left) / 60, int(assistant.pomodoro_left) % 60]


func _on_pomo_button() -> void:
	if assistant.pomodoro_phase == "idle":
		assistant.pomodoro_start()
	else:
		assistant.pomodoro_stop()
	_refresh_pomo()


func _on_todo_toggled(pressed: bool, index: int) -> void:
	assistant.set_todo_done(index, pressed)


func _on_remove_todo(index: int) -> void:
	assistant.remove_todo(index)
	refresh()


func _on_remove_reminder(index: int) -> void:
	assistant.remove_reminder(index)
	refresh()


func _on_add_todo() -> void:
	var text := _todo_input.text.strip_edges()
	if text == "":
		return
	if assistant.add_todo(text):
		_todo_input.text = ""
		refresh()


func _on_add_reminder() -> void:
	var text := _rem_input.text.strip_edges()
	if text == "":
		return
	var repeat: String = ["once", "daily", "weekdays"][_rem_repeat.selected]
	assistant.add_reminder(text, int(_rem_hour.value), int(_rem_min.value), repeat)
	_rem_input.text = ""
	refresh()


# --- UI 헬퍼 ---

func _section(text: String) -> Label:
	return UITheme.make_label(text, UITheme.FONT_SMALL, UITheme.MUTED)


func _chip_button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	UITheme.style_button(b, true)
	b.add_theme_font_size_override("font_size", UITheme.FONT_SMALL)
	b.pressed.connect(handler)
	return b


func _x_button(handler: Callable) -> Button:
	var b := Button.new()
	b.text = "✕"
	UITheme.style_button(b)
	b.add_theme_font_size_override("font_size", UITheme.FONT_SMALL)
	b.add_theme_color_override("font_color", UITheme.MUTED)
	b.pressed.connect(handler)
	return b


func _spin(min_value: int, max_value: int, value: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.value = value
	spin.custom_minimum_size = Vector2(52.0, 0.0)
	spin.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	return spin
