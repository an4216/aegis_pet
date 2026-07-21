# Design Ref: §2.4 기술 스파이크 — S1 투명창+클릭통과, S2 포커스 비탈취, S3 저부하 검증.
extends Node2D

const PET_TEXTURE := "res://assets/sprites/concept/mochi.png"
const WALK_SPEED := 120.0
const AUTO_QUIT_SECONDS := 180.0

var pet: Sprite2D
var info: Label
var dir := 1.0
var elapsed := 0.0
var screen_rect: Rect2i


func _ready() -> void:
	var win := get_window()
	win.borderless = true
	win.transparent = true
	win.transparent_bg = true
	win.always_on_top = true
	win.unfocusable = true  # S2: 포커스 비탈취
	screen_rect = DisplayServer.screen_get_usable_rect()
	win.position = screen_rect.position
	win.size = screen_rect.size
	Engine.max_fps = 30  # S3: 저부하

	pet = Sprite2D.new()
	pet.texture = load(PET_TEXTURE)
	pet.scale = Vector2(0.5, 0.5)
	pet.position = Vector2(screen_rect.size.x * 0.5, screen_rect.size.y - 70.0)
	add_child(pet)

	info = Label.new()
	info.text = "스파이크 테스트: 모찌 클릭=인사 / 더블클릭=종료 / 다른 영역은 클릭 통과"
	info.add_theme_color_override("font_color", Color(0.25, 0.2, 0.25))
	info.add_theme_font_size_override("font_size", 14)
	add_child(info)
	get_tree().create_timer(10.0).timeout.connect(func(): info.text = "")


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= AUTO_QUIT_SECONDS:
		get_tree().quit()
	pet.position.x += dir * WALK_SPEED * delta
	if pet.position.x > screen_rect.size.x - 80.0:
		dir = -1.0
		pet.flip_h = true
	elif pet.position.x < 80.0:
		dir = 1.0
		pet.flip_h = false
	info.position = pet.position + Vector2(-180.0, -110.0)
	_update_passthrough()


func _update_passthrough() -> void:
	# S1: 펫 주변 사각형만 클릭 가능, 나머지는 아래 창으로 통과
	var r := _pet_rect().grow(8.0)
	var poly := PackedVector2Array([
		r.position,
		Vector2(r.end.x, r.position.y),
		r.end,
		Vector2(r.position.x, r.end.y),
	])
	DisplayServer.window_set_mouse_passthrough(poly)


func _pet_rect() -> Rect2:
	var size := Vector2(128.0, 128.0)
	return Rect2(pet.position - size * 0.5, size)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if _pet_rect().grow(8.0).has_point(event.position):
			if event.double_click:
				get_tree().quit()
			else:
				info.text = "안녕! 클릭 감지 성공 (더블클릭하면 종료)"
				var tween := create_tween()
				tween.tween_property(pet, "scale", Vector2(0.56, 0.44), 0.08)
				tween.tween_property(pet, "scale", Vector2(0.5, 0.5), 0.12)
