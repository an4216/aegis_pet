# 응아: 클릭하면 청소된다 (PetState.clean_poop).
extends Node2D

const BODY := Color(0.45, 0.3, 0.18)
const SHADE := Color(0.36, 0.23, 0.13)


func _ready() -> void:
	add_to_group("poop")


func _draw() -> void:
	draw_circle(Vector2(0.0, -2.0), 13.0, SHADE)
	draw_circle(Vector2(0.0, -4.0), 12.0, BODY)
	draw_circle(Vector2(-1.0, -13.0), 8.0, BODY)
	draw_circle(Vector2(1.0, -20.0), 4.5, BODY)
	draw_circle(Vector2(-4.0, -8.0), 2.0, Color(0.62, 0.45, 0.3))


func get_click_rect() -> Rect2:
	return Rect2(global_position + Vector2(-16.0, -26.0), Vector2(32.0, 30.0)).grow(6.0)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and get_click_rect().has_point(event.position):
		get_node("/root/PetState").clean_poop()
		var sparkle := Label.new()
		sparkle.text = "반짝"
		sparkle.add_theme_color_override("font_color", Color(0.5, 0.75, 0.95))
		sparkle.position = global_position + Vector2(-14.0, -40.0)
		get_parent().add_child(sparkle)
		var t := sparkle.create_tween()
		t.tween_property(sparkle, "modulate:a", 0.0, 0.7)
		t.tween_callback(sparkle.queue_free)
		queue_free()
