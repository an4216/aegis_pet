# Design Ref: §4.1 창 설정, §4.2 트레이, §2.2 클릭 통과 — 오버레이 루트.
extends Node2D

const AUTOSTART_REG_KEY := "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run"
const AUTOSTART_REG_NAME := "DesktopTamagotchi"

var pet: Node2D
var poop_container: Node2D
var care_menu: Control
var stats_popup: Control
var bubble: Control
var speech: Node
var tray_menu: PopupMenu
var screen_rect: Rect2i
var _last_poly := PackedVector2Array()

@onready var _sm: Node = get_node("/root/SaveManager")
@onready var _ps: Node = get_node("/root/PetState")


func _ready() -> void:
	_setup_window()

	poop_container = Node2D.new()
	poop_container.name = "PoopContainer"
	add_child(poop_container)

	pet = load("res://scenes/pet/pet.tscn").instantiate()
	pet.screen_size = Vector2(screen_rect.size)
	pet.ground_y = float(screen_rect.size.y) - 6.0
	add_child(pet)

	_setup_ui()
	_setup_tray()

	_ps.pooped.connect(_spawn_poop)
	pet.care_menu_requested.connect(_open_care_menu)
	get_window().files_dropped.connect(_on_files_dropped)
	for i in _ps.poop_count:  # 저장된 응아 복원
		_spawn_poop_at(Vector2(randf_range(120.0, screen_rect.size.x - 120.0), pet.ground_y))


func _process(_delta: float) -> void:
	_update_passthrough()


func _setup_window() -> void:
	var win := get_window()
	win.borderless = true
	win.transparent = true
	win.transparent_bg = true
	win.always_on_top = _sm.settings.get("always_on_top", true)
	win.unfocusable = true
	screen_rect = DisplayServer.screen_get_usable_rect()
	win.position = screen_rect.position
	win.size = screen_rect.size
	Engine.max_fps = 30


func _setup_ui() -> void:
	# CanvasLayer는 투명 오버레이 창(gl_compatibility)에서 렌더링되지 않는 문제가 있어
	# UI를 월드 캔버스에 직접 배치하고 z_index로 최상위를 보장한다.
	care_menu = load("res://scenes/ui/care_menu.tscn").instantiate()
	stats_popup = load("res://scenes/ui/stats_popup.tscn").instantiate()
	bubble = load("res://scenes/ui/speech_bubble.tscn").instantiate()
	for control in [care_menu, stats_popup, bubble]:
		control.z_index = 100
		add_child(control)
	care_menu.action_selected.connect(_on_care_action)

	speech = load("res://scripts/speech_controller.gd").new()
	speech.name = "SpeechController"
	add_child(speech)
	speech.setup(bubble, pet, Vector2(screen_rect.size))


func _setup_tray() -> void:
	tray_menu = PopupMenu.new()
	tray_menu.add_item("상태 보기", 0)
	tray_menu.add_check_item("집중 모드", 1)
	tray_menu.add_check_item("항상 위", 2)
	tray_menu.add_check_item("시작 시 자동 실행", 3)
	tray_menu.add_separator()
	tray_menu.add_item("종료", 4)
	tray_menu.set_item_checked(1, _sm.settings.get("focus_mode", false))
	tray_menu.set_item_checked(2, _sm.settings.get("always_on_top", true))
	tray_menu.set_item_checked(3, _sm.settings.get("autostart", false))
	tray_menu.id_pressed.connect(_on_tray_action)
	add_child(tray_menu)

	var indicator := StatusIndicator.new()
	indicator.tooltip = "desktop-tamagotchi"
	indicator.icon = load("res://assets/sprites/concept/egg.png")
	add_child(indicator)
	indicator.menu = indicator.get_path_to(tray_menu)
	indicator.pressed.connect(_on_tray_pressed)


func _on_tray_pressed(mouse_button: int, _pos: Vector2i) -> void:
	if mouse_button == MOUSE_BUTTON_LEFT:
		stats_popup.toggle(Vector2(screen_rect.size))


func _on_tray_action(id: int) -> void:
	match id:
		0:
			stats_popup.toggle(Vector2(screen_rect.size))
		1:
			_sm.settings["focus_mode"] = not _sm.settings.get("focus_mode", false)
			tray_menu.set_item_checked(1, _sm.settings["focus_mode"])
			_sm.save_game()
		2:
			_sm.settings["always_on_top"] = not _sm.settings.get("always_on_top", true)
			get_window().always_on_top = _sm.settings["always_on_top"]
			tray_menu.set_item_checked(2, _sm.settings["always_on_top"])
			_sm.save_game()
		3:
			_sm.settings["autostart"] = not _sm.settings.get("autostart", false)
			_set_autostart(_sm.settings["autostart"])
			tray_menu.set_item_checked(3, _sm.settings["autostart"])
			_sm.save_game()
		4:
			_sm.save_game()
			get_tree().quit()


func _open_care_menu(pos: Vector2) -> void:
	care_menu.open_at(pos + Vector2(40.0, -80.0), Vector2(screen_rect.size))


func _on_care_action(action: String) -> void:
	match action:
		"sleep":
			pet.machine.transition_to("Sleep")
		"clean":
			var poops := get_tree().get_nodes_in_group("poop")
			if poops.is_empty():
				bubble.say("이미 깨끗한걸?", pet, Vector2(screen_rect.size))
				return
			for poop in poops:
				_ps.clean_poop()
				poop.queue_free()
		"medicine":
			if not _ps.is_sick:
				bubble.say("나 안 아픈데? 마음만 받을게", pet, Vector2(screen_rect.size))
				return
			_ps.care(action)
		_:
			_ps.care(action)


## 파일 먹이기: 펫 위에 파일을 드롭하면 휴지통으로 이동(복구 가능) + 먹이 효과.
## 안전 규칙: 폴더 제외, 한 번에 최대 5개, 영구 삭제 아닌 휴지통 이동만.
func _on_files_dropped(files: PackedStringArray) -> void:
	var size_vec := Vector2(screen_rect.size)
	if _ps.stage == "egg":
		bubble.say("아직 알이라서 못 먹어…", pet, size_vec)
		return
	var mouse := get_viewport().get_mouse_position()
	if not pet.get_click_rect().grow(24.0).has_point(mouse):
		return
	var eaten: Array = []
	for path in files:
		if eaten.size() >= 5:
			break
		if DirAccess.dir_exists_absolute(path) or not FileAccess.file_exists(path):
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		var bytes: int = f.get_length() if f != null else 0
		if f != null:
			f.close()
		if OS.move_to_trash(path) == OK:
			eaten.append(path.get_file())
			_ps.care("feed" if bytes >= 1_000_000 else "snack")
	if eaten.is_empty():
		bubble.say("으음… 그건 못 먹겠어 (폴더나 잠긴 파일이야?)", pet, size_vec)
	else:
		bubble.say("냠냠! '%s' 맛있다! (휴지통으로 보냈으니 복구할 수 있어)" % eaten[0], pet, size_vec)


## Plan FR-16: HKCU Run 키 자동 시작 (opt-in, 관리자 권한 불필요)
func _set_autostart(enabled: bool) -> void:
	if enabled:
		var reg_value := '"%s"' % OS.get_executable_path()
		if OS.has_feature("editor"):
			reg_value = '"%s" --path "%s"' % [
				OS.get_executable_path(),
				ProjectSettings.globalize_path("res://").trim_suffix("/"),
			]
		var code := OS.execute("reg", [
			"add", AUTOSTART_REG_KEY, "/v", AUTOSTART_REG_NAME,
			"/t", "REG_SZ", "/d", reg_value, "/f",
		])
		if code != 0:  # Design §6: 등록 실패 시 토글 해제
			_sm.settings["autostart"] = false
			tray_menu.set_item_checked(3, false)
			bubble.say("자동 시작 등록에 실패했어…", pet, Vector2(screen_rect.size))
	else:
		OS.execute("reg", ["delete", AUTOSTART_REG_KEY, "/v", AUTOSTART_REG_NAME, "/f"])


func _spawn_poop() -> void:
	var offset := 60.0 if pet._sprite.flip_h else -60.0
	var x := clampf(pet.position.x + offset, 40.0, screen_rect.size.x - 40.0)
	_spawn_poop_at(Vector2(x, pet.ground_y))


func _spawn_poop_at(pos: Vector2) -> void:
	var poop: Node2D = load("res://scenes/pet/poop.tscn").instantiate()
	poop.position = pos
	poop_container.add_child(poop)


## 클릭 가능한 영역(펫+응아+열린 UI)만 마우스를 받고, 나머지는 아래 창으로 통과.
## 주의: Windows에서 이 영역은 입력뿐 아니라 "그리기 영역"도 잘라낸다 (SetWindowRgn).
## 따라서 말풍선·머리 위 이펙트(Zzz/하트)도 반드시 영역에 포함해야 화면에 보인다.
func _update_passthrough() -> void:
	# 펫 영역을 위로 70px 확장: Zzz·하트·탄생! 등 머리 위 이펙트 포함
	var rects: Array = [pet.get_click_rect().grow_individual(12.0, 70.0, 12.0, 0.0)]
	for poop in get_tree().get_nodes_in_group("poop"):
		rects.append(poop.get_click_rect())
	for control in [care_menu, stats_popup, bubble]:
		if control != null and control.visible:
			rects.append(control.get_global_rect().grow(12.0))  # 말꼬리 포함 여유

	var intervals: Array = []  # [x0, x1, top_y]
	for r in rects:
		intervals.append([r.position.x, r.end.x, r.position.y])
	intervals.sort_custom(func(a, b): return a[0] < b[0])
	var merged: Array = []
	for it in intervals:
		if merged.is_empty() or it[0] > merged[-1][1]:
			merged.append([it[0], it[1], it[2]])
		else:
			merged[-1][1] = maxf(merged[-1][1], it[1])
			merged[-1][2] = minf(merged[-1][2], it[2])

	var base := float(screen_rect.size.y)
	var poly := PackedVector2Array()
	for m in merged:
		poly.append(Vector2(m[0], base))
		poly.append(Vector2(m[0], m[2]))
		poly.append(Vector2(m[1], m[2]))
		poly.append(Vector2(m[1], base))
	if poly != _last_poly:
		DisplayServer.window_set_mouse_passthrough(poly)
		_last_poly = poly
