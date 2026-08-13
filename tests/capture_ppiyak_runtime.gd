extends SceneTree

const OUTPUT_PATH := "res://docs/02-design/characters/ppiyak-remake-14state-runtime.png"
const BOARD_SIZE := Vector2i(1200, 2520)
const STATES := [
	"Idle", "Walk", "Sleep", "Eat", "Sick", "Sulk", "Play",
	"Dragged", "Fall", "Land", "FileHover", "FileConsume", "Poop", "Pet",
]
const TIERS := ["base", "evolved", "evolved2"]
const TIER_LABELS := ["BASE", "EVOLVED", "EVOLVED 2"]
const SAMPLE_FRAMES := {
	"Idle": [0, 10],
	"Walk": [0, 4],
	"Sleep": [0, 3],
	"Eat": [0, 3],
	"Sick": [0, 3],
	"Sulk": [0, 3],
	"Play": [0, 4],
	"Dragged": [0, 2],
	"Fall": [0, 2],
	"Land": [0, 2],
	"FileHover": [0, 2],
	"FileConsume": [0, 3],
	"Poop": [0, 3],
	"Pet": [0, 3],
}


func _init() -> void:
	print("PPIYAK CAPTURE: building viewport")
	var viewport := SubViewport.new()
	viewport.size = BOARD_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(viewport)

	var background := ColorRect.new()
	background.color = Color("f7f3ea")
	background.size = Vector2(BOARD_SIZE)
	viewport.add_child(background)

	var title := _make_label("PPIYAK REMAKE · ACTUAL GODOT RUNTIME CONFIG · 3 TIERS × 14 STATES", 32, Color("403a34"))
	title.position = Vector2(36, 22)
	viewport.add_child(title)
	var subtitle := _make_label("Each cell shows frame 1 and a representative motion frame with runtime scale, anchor, grid and mipmap filtering.", 18, Color("756c63"))
	subtitle.position = Vector2(38, 65)
	viewport.add_child(subtitle)

	for tier_index in TIERS.size():
		var tier_label := _make_label(TIER_LABELS[tier_index], 24, Color("5b5148"))
		tier_label.position = Vector2(270 + tier_index * 305, 112)
		viewport.add_child(tier_label)

	var pet_scene: PackedScene = load("res://scenes/pet/pet.tscn")
	var pet = pet_scene.instantiate()
	pet.position = Vector2(-2000, -2000)
	viewport.add_child(pet)
	await process_frame
	print("PPIYAK CAPTURE: runtime Pet ready")
	pet.process_mode = Node.PROCESS_MODE_DISABLED

	for state_index in STATES.size():
		var state_name: String = STATES[state_index]
		print("PPIYAK CAPTURE: %s" % state_name)
		var row_y := 218.0 + state_index * 162.0
		var state_label := _make_label(state_name, 22, Color("403a34"))
		state_label.position = Vector2(34, row_y - 18)
		viewport.add_child(state_label)
		var divider := ColorRect.new()
		divider.color = Color("ddd5c9")
		divider.position = Vector2(28, row_y + 126)
		divider.size = Vector2(1144, 1)
		viewport.add_child(divider)

		for tier_index in TIERS.size():
			var tier: String = TIERS[tier_index]
			pet.debug_set_appearance("ppiyak", "adult", tier)
			pet.play_state_animation(state_name)
			for sample_index in 2:
				var logical_frame: int = SAMPLE_FRAMES[state_name][sample_index]
				pet._set_bichon_frame(logical_frame)
				var snapshot := Sprite2D.new()
				snapshot.texture = pet._sprite.texture
				snapshot.hframes = pet._sprite.hframes
				snapshot.vframes = pet._sprite.vframes
				snapshot.frame = pet._sprite.frame
				snapshot.scale = pet._sprite.scale
				snapshot.texture_filter = pet._sprite.texture_filter
				snapshot.flip_h = pet._sprite.flip_h
				var baseline := Vector2(252 + tier_index * 305 + sample_index * 132, row_y + 108)
				snapshot.position = baseline + pet._sprite.position
				viewport.add_child(snapshot)
				var frame_label := _make_label("f%d" % logical_frame, 14, Color("9a8f84"))
				frame_label.position = baseline + Vector2(-10, 4)
				viewport.add_child(frame_label)

	pet.visible = false
	print("PPIYAK CAPTURE: waiting for draw")
	await process_frame
	RenderingServer.force_draw(false, 0.0)
	var image := viewport.get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	print("PPIYAK RUNTIME CAPTURE: %s (%dx%d), error=%d" % [OUTPUT_PATH, image.get_width(), image.get_height(), error])
	quit(0 if error == OK else 1)


func _make_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
