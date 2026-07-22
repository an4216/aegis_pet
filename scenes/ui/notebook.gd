# 📔 햄찌의 수첩 (FR-21~23) — 할 일 3개 + 리마인더 + 뽀모도로를 한 패널에서 관리.
# 주의: 이 패널이 열려 있는 동안 main이 창을 포커스 가능 상태로 전환한다 (텍스트 입력용).
extends PanelContainer

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
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.99, 0.95, 0.98)
	style.set_corner_radius_all(12)
	style.border_color = Color(0.55, 0.4, 0.47)
	style.set_border_width_all(2)
	style.set_content_margin_all(14)
	style.shadow_size = 6
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	add_theme_stylebox_override("panel", style)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	root.custom_minimum_size = Vector2(300.0, 0.0)
	add_child(root)

	root.add_child(_header("📔 수첩"))

	# --- 오늘 할 일 (최대 3개) ---
	root.add_child(_section("오늘 할 일 (3개까지)"))
	_todo_box = VBoxContainer.new()
	root.add_child(_todo_box)
	var todo_row := HBoxContainer.new()
	_todo_input = LineEdit.new()
	_todo_input.placeholder_text = "할 일 입력…"
	_todo_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_todo_input.text_submitted.connect(func(_t): _on_add_todo())
	todo_row.add_child(_todo_input)
	todo_row.add_child(_small_button("추가", _on_add_todo))
	root.add_child(todo_row)

	root.add_child(HSeparator.new())

	# --- 리마인더 ---
	root.add_child(_section("리마인더"))
	_rem_box = VBoxContainer.new()
	root.add_child(_rem_box)
	var rem_row := HBoxContainer.new()
	rem_row.add_theme_constant_override("separation", 4)
	_rem_input = LineEdit.new()
	_rem_input.placeholder_text = "내용"
	_rem_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rem_row.add_child(_rem_input)
	_rem_hour = _spin(0, 23, 15)
	rem_row.add_child(_rem_hour)
	rem_row.add_child(_small_label(":"))
	_rem_min = _spin(0, 59, 0)
	rem_row.add_child(_rem_min)
	_rem_repeat = OptionButton.new()
	_rem_repeat.add_item("한 번", 0)
	_rem_repeat.add_item("매일", 1)
	_rem_repeat.add_item("평일", 2)
	_rem_repeat.focus_mode = Control.FOCUS_NONE
	rem_row.add_child(_rem_repeat)
	rem_row.add_child(_small_button("추가", _on_add_reminder))
	root.add_child(rem_row)

	root.add_child(HSeparator.new())

	# --- 뽀모도로 ---
	root.add_child(_section("집중 타이머 (뽀모도로)"))
	var pomo_row := HBoxContainer.new()
	_pomo_button = Button.new()
	_pomo_button.text = "▶ 25분 집중 시작"
	_pomo_button.focus_mode = Control.FOCUS_NONE
	_pomo_button.pressed.connect(_on_pomo_button)
	pomo_row.add_child(_pomo_button)
	_pomo_label = _small_label("")
	pomo_row.add_child(_pomo_label)
	root.add_child(pomo_row)

	root.add_child(HSeparator.new())
	var close_button := _small_button("✕ 닫기", func(): visible = false)
	close_button.custom_minimum_size = Vector2(0.0, 28.0)
	root.add_child(close_button)


func open_at_corner(screen_size: Vector2) -> void:
	visible = true
	refresh()
	await get_tree().process_frame
	position = Vector2(screen_size.x - size.x - 20.0, screen_size.y - size.y - 20.0)


const REPEAT_KR := {"once": "한 번", "daily": "매일", "weekdays": "평일"}


func refresh() -> void:
	for child in _todo_box.get_children():
		child.queue_free()
	var todos: Array = _sm.settings.get("todos", [])
	for i in todos.size():
		var row := HBoxContainer.new()
		var checkbox := CheckBox.new()
		checkbox.text = todos[i]["text"]
		checkbox.button_pressed = todos[i]["done"]
		checkbox.focus_mode = Control.FOCUS_NONE
		checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		checkbox.toggled.connect(_on_todo_toggled.bind(i))
		row.add_child(checkbox)
		row.add_child(_small_button("✕", _on_remove_todo.bind(i)))
		_todo_box.add_child(row)

	for child in _rem_box.get_children():
		child.queue_free()
	var reminders: Array = _sm.settings.get("reminders", [])
	for i in reminders.size():
		var r: Dictionary = reminders[i]
		var row := HBoxContainer.new()
		var label := _small_label("%02d:%02d  %s (%s)" % [
			int(r["hour"]), int(r["minute"]), r["text"], REPEAT_KR.get(r["repeat"], "?")])
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		row.add_child(_small_button("✕", _on_remove_reminder.bind(i)))
		_rem_box.add_child(row)

	_refresh_pomo()


func _on_todo_toggled(pressed: bool, index: int) -> void:
	assistant.set_todo_done(index, pressed)


func _on_remove_todo(index: int) -> void:
	assistant.remove_todo(index)
	refresh()


func _on_remove_reminder(index: int) -> void:
	assistant.remove_reminder(index)
	refresh()


func _process(_delta: float) -> void:
	if visible and assistant != null and assistant.pomodoro_phase != "idle":
		_refresh_pomo()


func _refresh_pomo() -> void:
	if assistant == null:
		return
	match assistant.pomodoro_phase:
		"idle":
			_pomo_button.text = "▶ 25분 집중 시작"
			_pomo_label.text = ""
		"work":
			_pomo_button.text = "■ 중지"
			_pomo_label.text = "집중 중 %d:%02d" % [int(assistant.pomodoro_left) / 60, int(assistant.pomodoro_left) % 60]
		"break":
			_pomo_button.text = "■ 중지"
			_pomo_label.text = "휴식 중 %d:%02d" % [int(assistant.pomodoro_left) / 60, int(assistant.pomodoro_left) % 60]


func _on_pomo_button() -> void:
	if assistant.pomodoro_phase == "idle":
		assistant.pomodoro_start()
	else:
		assistant.pomodoro_stop()
	_refresh_pomo()


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

func _header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(0.35, 0.25, 0.3))
	return label


func _section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.5, 0.42, 0.47))
	return label


func _small_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.35, 0.3, 0.33))
	return label


func _small_button(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(handler)
	return button


func _spin(min_value: int, max_value: int, value: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.value = value
	spin.custom_minimum_size = Vector2(58.0, 0.0)
	return spin
