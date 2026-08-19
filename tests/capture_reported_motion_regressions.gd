extends SceneTree

const OUTPUT_PATH := "res://.omo/evidence/reported-motion-regressions-runtime.png"
const FALL_LOADED_PATH := "res://.omo/evidence/bulgeumjo-evolved2-fall-loaded.png"
const EAT_LOADED_PATH := "res://.omo/evidence/geobujang-evolved2-eat-loaded.png"
const CELL_SIZE := Vector2i(256, 256)
const BOARD_SIZE := Vector2i(CELL_SIZE.x * 6, CELL_SIZE.y * 3)


func _init() -> void:
	var board := Image.create_empty(BOARD_SIZE.x, BOARD_SIZE.y, false, Image.FORMAT_RGBA8)
	board.fill(Color("f7f3ea"))
	var pet_scene: PackedScene = load("res://scenes/pet/pet.tscn")
	var pet: Node2D = pet_scene.instantiate()
	pet.position = Vector2(-2000.0, -2000.0)
	root.add_child(pet)
	await process_frame

	pet.debug_set_appearance("bulgeumjo", "adult", "evolved2")
	await process_frame
	pet.position.y = pet.ground_y - 300.0
	pet.debug_force_state("Fall")
	if pet._pose_override_state != "Fall" or not pet.requires_full_render_region():
		push_error("Bulgeumjo evolved2 Fall did not activate the protected runtime path")
		quit(1)
		return
	var fall_loaded: Image = pet._sprite.texture.get_image()
	if fall_loaded.save_png(FALL_LOADED_PATH) != OK:
		quit(1)
		return
	for frame_index in 4:
		pet._set_bichon_frame(frame_index)
		_blend_runtime_frame(board, pet, 0, frame_index)

	for action_index in 2:
		var action := "feed" if action_index == 0 else "snack"
		pet.debug_set_appearance("geobujang", "adult", "evolved2")
		await process_frame
		pet._last_food_action = action
		pet.debug_force_state("Eat")
		if pet._pose_override_state != "Eat" or not pet.requires_full_render_region():
			push_error("Geobujang evolved2 %s did not activate protected Eat" % action)
			quit(1)
			return
		if action_index == 0:
			var eat_loaded: Image = pet._sprite.texture.get_image()
			if eat_loaded.save_png(EAT_LOADED_PATH) != OK:
				quit(1)
				return
		for frame_index in 6:
			pet._set_bichon_frame(frame_index)
			_blend_runtime_frame(board, pet, action_index + 1, frame_index)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.omo/evidence"))
	var error := board.save_png(OUTPUT_PATH)
	print("REPORTED MOTION REGRESSIONS: %s, error=%d" % [OUTPUT_PATH, error])
	quit(0 if error == OK else 1)


func _blend_runtime_frame(board: Image, pet: Node2D, row: int, column: int) -> void:
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
	var destination := Vector2i(
		column * CELL_SIZE.x + (CELL_SIZE.x - rendered_size.x) / 2,
		(row + 1) * CELL_SIZE.y - 16 - rendered_size.y,
	)
	board.blend_rect(rendered, Rect2i(Vector2i.ZERO, rendered_size), destination)
