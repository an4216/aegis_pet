extends SceneTree

const OUTPUT_PATH := "res://.omo/evidence/geobujang-eat-screen-edge-runtime.png"
const PetStateScript := preload("res://autoload/pet_state.gd")
const PetScene := preload("res://scenes/pet/pet.tscn")
const CELL_SIZE := Vector2i(320, 256)
const SCREEN_EDGE_X := 16


func _init() -> void:
	var state: Node = PetStateScript.new()
	state.debug_set_species("geobujang", "adult")
	state.evolved = true
	state.evolved_2 = true
	var pet: Node2D = PetScene.instantiate()
	pet.screen_size = Vector2(1280.0, 720.0)
	pet.ground_y = 714.0
	root.add_child(pet)
	await process_frame
	pet.ps = state
	pet.refresh_appearance()

	var board := Image.create_empty(CELL_SIZE.x * 6, CELL_SIZE.y * 2, false, Image.FORMAT_RGBA8)
	board.fill(Color("f7f3ea"))
	for action_index in 2:
		pet.debug_force_state("Idle")
		pet.position = Vector2(1.0, pet.ground_y)
		pet._last_food_action = "feed" if action_index == 0 else "snack"
		pet.debug_force_state("Eat")
		var canvas_width: float = pet._frame_size.x * absf(pet._base_scale.x)
		var required_margin := canvas_width * 0.5 + 24.0
		if pet.position.x < required_margin:
			push_error("Eat did not move Geobujang inside the left screen edge: x=%.2f required=%.2f screen=%.2f" % [pet.position.x, required_margin, pet.screen_size.x])
			quit(1)
			return
		if pet.get_click_rect().size.x < canvas_width + 48.0:
			push_error("Eat render region does not include the 24px cane margin")
			quit(1)
			return
		for frame_index in 6:
			pet._set_bichon_frame(frame_index)
			_blend_screen_edge_frame(board, pet, action_index, frame_index)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.omo/evidence"))
	var error := board.save_png(OUTPUT_PATH)
	print("GEOBUJANG CANE SCREEN EDGE: %s, error=%d" % [OUTPUT_PATH, error])
	root.remove_child(pet)
	pet.free()
	state.free()
	quit(0 if error == OK else 1)


func _blend_screen_edge_frame(board: Image, pet: Node2D, row: int, column: int) -> void:
	var texture_image: Image = pet._sprite.texture.get_image()
	var source_size := Vector2i(
		texture_image.get_width() / pet._sprite.hframes,
		texture_image.get_height() / pet._sprite.vframes,
	)
	var physical_frame: int = pet._sprite.frame
	var source_position := Vector2i(
		(physical_frame % pet._sprite.hframes) * source_size.x,
		(physical_frame / pet._sprite.hframes) * source_size.y,
	)
	var rendered := texture_image.get_region(Rect2i(source_position, source_size))
	var rendered_size := Vector2i(
		maxi(1, roundi(source_size.x * absf(pet._sprite.scale.x))),
		maxi(1, roundi(source_size.y * absf(pet._sprite.scale.y))),
	)
	rendered.resize(rendered_size.x, rendered_size.y, Image.INTERPOLATE_LANCZOS)
	var cell_origin := Vector2i(column * CELL_SIZE.x, row * CELL_SIZE.y)
	for y in CELL_SIZE.y:
		board.set_pixel(cell_origin.x + SCREEN_EDGE_X, cell_origin.y + y, Color("d63c3c"))
	var destination := Vector2i(
		cell_origin.x + SCREEN_EDGE_X + roundi(pet.position.x - rendered_size.x * 0.5),
		cell_origin.y + CELL_SIZE.y - 16 - rendered_size.y,
	)
	board.blend_rect(rendered, Rect2i(Vector2i.ZERO, rendered_size), destination)
