# Design Ref: §4.1 창 설정, §4.2 트레이, §2.2 클릭 통과 — 오버레이 루트.
extends Node2D

const AUTOSTART_REG_KEY := "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run"
const AUTOSTART_REG_NAME := "DesktopTamagotchi"
const RegionBuilder := preload("res://scripts/platform/region_builder.gd")
const DialogData := preload("res://scripts/data/dialog.gd")
const Balance := preload("res://scripts/data/balance.gd")
const Characters := preload("res://scripts/data/characters.gd")

var pet: Node2D
var probe: Node
var poop_container: Node2D
var care_menu: Control
var stats_popup: Control
var bubble: Control
var notebook: Control
var reset_confirm: Control
var speech: Node
var assistant: Node
var updater: Node
var tray_menu: PopupMenu
var screen_rect: Rect2i
var _last_quantized: Array = []

@onready var _sm: Node = get_node("/root/SaveManager")
@onready var _ps: Node = get_node("/root/PetState")


func _ready() -> void:
	_setup_window()

	poop_container = Node2D.new()
	poop_container.name = "PoopContainer"
	add_child(poop_container)

	pet = load("res://scenes/pet/pet.tscn").instantiate()
	pet.screen_size = Vector2(screen_rect.size)
	pet.ground_y = ground_bottom - 6.0
	pet.primary_local = primary_local
	add_child(pet)

	probe = load("res://scripts/platform/window_probe.gd").new()
	probe.name = "WindowProbe"
	probe.origin = Vector2(screen_rect.position)  # 전역 → 창 로컬 좌표 변환
	add_child(probe)
	if _sm.settings.get("window_play", false):
		probe.start()
	probe.toast_appeared.connect(_on_toast)
	pet.probe = probe

	_setup_ui()
	_setup_tray()

	_ps.pooped.connect(_spawn_poop)
	pet.care_menu_requested.connect(_open_care_menu)
	get_window().files_dropped.connect(_on_files_dropped)
	for i in _ps.poop_count:  # 저장된 응아 복원
		_spawn_poop_at(Vector2(randf_range(120.0, screen_rect.size.x - 120.0), pet.ground_y))


func _process(_delta: float) -> void:
	# 수첩이 열려 있을 때만 키보드 입력 허용 (텍스트 입력용, 닫히면 다시 비침습)
	var need_focus: bool = notebook != null and notebook.visible
	if get_window().unfocusable == need_focus:
		get_window().unfocusable = not need_focus
	_update_passthrough()


var ground_bottom := 0.0    # 로컬 좌표 기준 바닥 (가장 낮은 작업표시줄 위)
var primary_local: Rect2    # 1번 모니터의 오버레이-로컬 좌표 (알 스폰·다이얼로그 중앙 배치용)


func _setup_window() -> void:
	var win := get_window()
	win.borderless = true
	win.transparent = true
	win.transparent_bg = true
	win.always_on_top = _sm.settings.get("always_on_top", true)
	win.unfocusable = true
	# 모든 모니터를 덮는 하나의 오버레이 (Phase 2: 멀티모니터)
	screen_rect = DisplayServer.screen_get_usable_rect(0)
	var primary := screen_rect
	var min_bottom := float((screen_rect as Rect2i).end.y)
	for i in range(1, DisplayServer.get_screen_count()):
		var usable := DisplayServer.screen_get_usable_rect(i)
		screen_rect = (screen_rect as Rect2i).merge(usable)
		min_bottom = minf(min_bottom, float(usable.end.y))
	# 오버레이-로컬 좌표계에서 1번 모니터 영역
	primary_local = Rect2(
		Vector2(primary.position - screen_rect.position),
		Vector2(primary.size))
	ground_bottom = min_bottom - float(screen_rect.position.y)
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

	notebook = load("res://scenes/ui/notebook.tscn").instantiate()
	notebook.z_index = 100
	add_child(notebook)
	assistant = load("res://scripts/assistant.gd").new()
	assistant.name = "Assistant"
	add_child(assistant)
	assistant.setup(pet, bubble, Vector2(screen_rect.size))
	notebook.assistant = assistant

	updater = load("res://scripts/updater.gd").new()
	updater.name = "Updater"
	add_child(updater)
	updater.update_available.connect(_on_update_available)
	updater.update_failed.connect(func(reason):
		bubble.say("업데이트 실패… %s" % reason, pet, Vector2(screen_rect.size), 8.0))

	# Plan FR-15 v3: 업무 활동 추적 시작
	_ps.evolution_ready.connect(_on_evolution_ready)
	var today := Time.get_datetime_dict_from_system()
	_ps.note_activity_day("%04d-%02d-%02d" % [today.year, today.month, today.day])
	var probe := get_node_or_null("/root/InputProbe")
	if probe != null:
		probe.counter_delta.connect(func(delta): _ps.add_input_delta(delta))
		probe.start()


func _setup_tray() -> void:
	tray_menu = PopupMenu.new()
	tray_menu.add_item("상태 보기", 0)
	tray_menu.add_check_item("집중 모드", 1)
	tray_menu.add_check_item("항상 위", 2)
	tray_menu.add_check_item("시작 시 자동 실행", 3)
	tray_menu.add_check_item("창 위 놀이 (점프)", 5)
	tray_menu.add_item("📔 수첩 (할 일·리마인더·집중)", 6)
	tray_menu.add_separator()
	tray_menu.add_item("🥚 처음부터 다시 키우기", 7)
	tray_menu.add_item("종료", 4)
	tray_menu.set_item_checked(1, _sm.settings.get("focus_mode", false))
	tray_menu.set_item_checked(2, _sm.settings.get("always_on_top", true))
	tray_menu.set_item_checked(3, _sm.settings.get("autostart", false))
	tray_menu.set_item_checked(4, _sm.settings.get("window_play", false))
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
			_maybe_note_late_shutdown()
			_sm.save_game()
			get_tree().quit()
		5:
			_sm.settings["window_play"] = not _sm.settings.get("window_play", false)
			tray_menu.set_item_checked(tray_menu.get_item_index(5), _sm.settings["window_play"])
			if _sm.settings["window_play"] and not probe.available:
				probe.start()
			_sm.save_game()
		6:
			if notebook.visible:
				notebook.visible = false
			else:
				notebook.open_at_corner(Vector2(screen_rect.size))
		7:
			_show_reset_confirm()
		8:
			bubble.say("업데이트 다운로드 중… 끝나면 자동으로 다시 켜질게!", pet, Vector2(screen_rect.size), 10.0)
			updater.start_update()


func _open_care_menu(pos: Vector2) -> void:
	if care_menu.visible:
		care_menu.visible = false  # 우클릭 다시 하면 닫기
		return
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


## 정시퇴근(18~19시 종료)이면 카운트 (Plan FR-15 v3: 스르륵 진화 조건)
func _maybe_note_late_shutdown() -> void:
	var h: int = Time.get_datetime_dict_from_system().hour
	if h in Balance.LATE_SHUTDOWN_HOURS:
		_ps.note_late_shutdown()


## 진화 조건 달성 (Plan FR-15 v3)
func _on_evolution_ready(species: String) -> void:
	var evolved_name: String = Characters.get_evolved_name(species)
	pet.refresh_appearance()  # evolved 스프라이트 로드 (있으면)
	pet.celebrate()
	bubble.say("✨ %s(으)로 진화했다!! ✨" % evolved_name, pet, Vector2(screen_rect.size), 12.0)
	_sm.save_game()


## 새 버전 발견 (FR-29): 펫이 알리고, 트레이에 설치 메뉴 추가
func _on_update_available(version: String) -> void:
	bubble.say("새 버전 v%s 나왔대! 트레이 메뉴에서 설치할 수 있어" % version,
		pet, Vector2(screen_rect.size), 12.0)
	pet.celebrate()
	tray_menu.add_item("⬆️ v%s 업데이트 설치" % version, 8)


## 처음부터 다시 키우기 (FR-28): 확인창 → 새 알로 리셋
func _show_reset_confirm() -> void:
	if reset_confirm != null:
		reset_confirm.queue_free()
	reset_confirm = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.99, 0.95, 0.98)
	style.set_corner_radius_all(12)
	style.border_color = Color(0.75, 0.4, 0.45)
	style.set_border_width_all(3)
	style.set_content_margin_all(16)
	style.shadow_size = 6
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.2)
	reset_confirm.add_theme_stylebox_override("panel", style)
	reset_confirm.z_index = 110

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.text = "정말 처음부터 다시 키울까요?\n지금 펫과는 영영 헤어지게 돼요…"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.35, 0.28, 0.3))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var yes_button := Button.new()
	yes_button.text = "🥚 다시 키우기"
	yes_button.focus_mode = Control.FOCUS_NONE
	yes_button.pressed.connect(_do_reset)
	var no_button := Button.new()
	no_button.text = "취소"
	no_button.focus_mode = Control.FOCUS_NONE
	no_button.pressed.connect(func():
		reset_confirm.queue_free()
		reset_confirm = null)
	row.add_child(yes_button)
	row.add_child(no_button)
	vbox.add_child(row)
	reset_confirm.add_child(vbox)
	add_child(reset_confirm)
	await get_tree().process_frame
	# 1번 모니터 중앙에 배치 (듀얼 모니터에서 모니터 경계에 뜨는 문제 방지)
	reset_confirm.position = Vector2(
		primary_local.position.x + (primary_local.size.x - reset_confirm.size.x) * 0.5,
		primary_local.position.y + primary_local.size.y * 0.55,
	)


func _do_reset() -> void:
	if reset_confirm != null:
		reset_confirm.queue_free()
		reset_confirm = null
	_ps.reset_to_egg()
	for poop in get_tree().get_nodes_in_group("poop"):
		poop.queue_free()
	pet.machine.transition_to("Egg")
	_sm.save_game()
	bubble.say("새 알이 도착했어! 소중히 돌봐줘", pet, Vector2(screen_rect.size), 8.0)


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


const REGION_GRID := 64.0

## 클릭 가능한 영역(펫+응아+열린 UI)만 마우스를 받고, 나머지는 아래 창으로 통과.
## Windows에서 이 영역(SetWindowRgn)은 렌더링도 잘라내며, region을 자주 갱신하면
## 경계에 흰 줄이 번쩍인다 → 모든 사각형을 64px 격자에 스냅해 갱신 빈도를 최소화한다.
## (Godot의 mouse_passthrough 전체 플래그는 이 환경에서 OS에 적용되지 않음 — 검증됨)
func _update_passthrough() -> void:
	var rects: Array = [
		_quantize(pet.get_click_rect().grow_individual(12.0, 70.0, 12.0, 0.0)),
	]
	for poop in get_tree().get_nodes_in_group("poop"):
		rects.append(_quantize(poop.get_click_rect()))
	for control in [care_menu, stats_popup, bubble, notebook, reset_confirm]:
		if control != null and control.visible:
			rects.append(_quantize(control.get_global_rect().grow(12.0)))
	if rects == _last_quantized:
		return
	_last_quantized = rects
	DisplayServer.window_set_mouse_passthrough(
		RegionBuilder.build(rects.duplicate(), ground_bottom + 4.0))


func _quantize(r: Rect2) -> Rect2:
	var x0 := floorf(r.position.x / REGION_GRID) * REGION_GRID
	var y0 := floorf(r.position.y / REGION_GRID) * REGION_GRID
	return Rect2(x0, y0,
		ceilf(r.end.x / REGION_GRID) * REGION_GRID - x0,
		ceilf(r.end.y / REGION_GRID) * REGION_GRID - y0)


## 알림 토스트가 뜨면 달려가서 올라탄다 (Phase 2)
func _on_toast(id: int, rect: Rect2) -> void:
	if not _sm.settings.get("window_play", false):
		return
	if _ps.stage == "egg":
		return
	if not rect.intersects(Rect2(Vector2.ZERO, Vector2(screen_rect.size))):
		return
	if pet.machine.current_name() in ["Idle", "Walk"]:
		pet.start_jump(id, rect)
		var lines: Array = DialogData.COMMON.get("toast", [])
		if not lines.is_empty():
			bubble.say(lines[randi() % lines.size()], pet, Vector2(screen_rect.size))
