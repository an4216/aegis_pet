extends SceneTree

const OUTPUT_PATH := "res://.omo/evidence/motion-fixes-runtime.png"
const CELL_SIZE := Vector2i(192, 208)
const BOARD_SIZE := Vector2i(CELL_SIZE.x * 9, CELL_SIZE.y * 56)
const WALK_SPECIES := ["bulgeumjo", "nyang"]
const TIERS := ["base", "evolved", "evolved2"]


func _init() -> void:
	var board := Image.create_empty(BOARD_SIZE.x, BOARD_SIZE.y, false, Image.FORMAT_RGBA8)
	board.fill(Color("f7f3ea"))
	var pet_scene: PackedScene = load("res://scenes/pet/pet.tscn")
	var pet: Node2D = pet_scene.instantiate()
	pet.position = Vector2(-2000, -2000)
	root.add_child(pet)
	await process_frame
	var row := 0
	for species in WALK_SPECIES:
		for tier in TIERS:
			pet.debug_set_appearance(species, "adult", tier)
			await process_frame
			pet.stop_animated_pose()
			pet.set_pose("idle")
			_blend_runtime_frame(board, pet, row, 0)
			pet.play_state_animation("Walk")
			for frame_index in 8:
				pet._set_bichon_frame(frame_index)
				_blend_runtime_frame(board, pet, row, frame_index + 1)
			row += 1
	for action in ["feed", "snack"]:
		pet.debug_set_appearance("geobujang", "adult", "evolved2")
		await process_frame
		pet._on_care_performed(action)
		for frame_index in 6:
			pet._set_bichon_frame(frame_index)
			_blend_runtime_frame(board, pet, row, frame_index)
		row += 1
	for tier in TIERS:
		pet.debug_set_appearance("bulgeumjo", "adult", tier)
		await process_frame
		pet.play_state_animation("Dragged")
		for frame_index in 4:
			pet._set_bichon_frame(frame_index)
			_blend_runtime_frame(board, pet, row, frame_index)
		pet.stop_animated_pose()
		pet.set_pose("idle")
		_blend_runtime_frame(board, pet, row, 4)
		row += 1
	var tokki_states := ["Idle", "Walk", "Sleep", "Eat", "Sick", "Sulk", "Play",
		"Dragged", "Fall", "Land", "FileHover", "FileConsume", "Poop", "Pet"]
	for tier in TIERS:
		pet.debug_set_appearance("tokki", "adult", tier)
		await process_frame
		for state in tokki_states:
			pet.stop_animated_pose()
			pet.set_pose("idle")
			_blend_runtime_frame(board, pet, row, 0)
			pet.play_state_animation(state)
			var frame_count: int = int(pet._pose_override_config(state)["frames"])
			for frame_index in frame_count:
				pet._set_bichon_frame(frame_index)
				_blend_runtime_frame(board, pet, row, frame_index + 1)
			row += 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.omo/evidence"))
	var error := board.save_png(OUTPUT_PATH)
	print("MOTION FIXES RUNTIME CAPTURE: %s, error=%d" % [OUTPUT_PATH, error])
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
