# Run with:
# godot --headless --path . --script tests/bichon_animation_integration.gd
extends SceneTree

const PetStateScript := preload("res://autoload/pet_state.gd")
const PetScene := preload("res://scenes/pet/pet.tscn")
const WalkStateScript := preload("res://scripts/states/walk_state.gd")
const SleepStateScript := preload("res://scripts/states/sleep_state.gd")
const SulkStateScript := preload("res://scripts/states/sulk_state.gd")


class TestTimeManager:
	extends Node
	signal minute_ticked(_minutes: float)

	func is_night(_start_hour: int, _end_hour: int) -> bool:
		return false


class TestSaveManager:
	extends Node

	var settings := {"focus_mode": false, "night_start": 22, "night_end": 7}


func _init() -> void:
	var time_manager := TestTimeManager.new()
	time_manager.name = "TimeManager"
	root.add_child(time_manager)
	var save_manager := TestSaveManager.new()
	save_manager.name = "SaveManager"
	root.add_child(save_manager)

	var pet_state: Node = PetStateScript.new()
	pet_state.name = "TestPetState"
	pet_state.debug_set_species("bichon")
	root.add_child(pet_state)

	var pet: Node2D = PetScene.instantiate()
	pet.screen_size = Vector2(1280.0, 720.0)
	pet.ground_y = 714.0
	root.add_child(pet)
	await process_frame
	# The project autoload may retain a user's selected species.  Bind this test's
	# isolated PetState explicitly so assertions always exercise Bichon.
	pet.ps = pet_state
	pet.refresh_appearance()
	check(pet._bichon_animation == "Idle", "Idle sheet starts on Bichon pet scene")
	check(pet._sprite.hframes == 2 and pet._sprite.vframes == 1, "Idle uses its two-cell composed atlas")
	check(int(pet.BICHON_ANIMATIONS["Idle"]["frames"]) == 11, "Idle has a long still-and-blink cycle")
	check(pet._sprite_frame_for_bichon_frame(9) == 1, "Idle maps only its blink to the closed-eye cell")
	var idle_image: Image = pet._sprite.texture.get_image()
	var idle_cell_width: int = idle_image.get_width() / pet._sprite.hframes
	var idle_cell_height: int = idle_image.get_height() / pet._sprite.vframes
	var idle_open_bounds := _frame_body_bounds(idle_image, idle_cell_width, idle_cell_height, pet._sprite.hframes, 0)
	check(idle_open_bounds.size.y > idle_open_bounds.size.x, "Idle uses a seated upright Bichon silhouette")
	check(pet._sprite.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "Bichon uses mipmapped texture filtering when downscaled")
	pet.position = Vector2(500.0, pet.ground_y)
	pet.face_towards(600.0)
	check(pet._sprite.flip_h, "Rightward movement mirrors the left-facing walk sheet")
	pet.face_towards(400.0)
	check(not pet._sprite.flip_h, "Leftward movement keeps the base walk sheet direction")
	pet.play_state_animation("Walk")
	pet.walk_bob(true)
	check(pet._sprite.scale.is_equal_approx(pet._base_scale), "Walking clears the prior idle scale tween")
	var first_frame_feet_y: float = pet._sprite.position.y + (305.0 - pet._frame_size.y * 0.5) * pet._base_scale.y
	check(absf(first_frame_feet_y) <= 1.0, "First walk frame paws stay on the taskbar ground line")
	pet._advance_bichon_animation(0.5)
	var later_frame_feet_y: float = pet._sprite.position.y + (283.0 - pet._frame_size.y * 0.5) * pet._base_scale.y
	check(absf(later_frame_feet_y) <= 1.0, "Later walk frame paws stay on the taskbar ground line")
	for animation in pet.BICHON_ANIMATIONS:
		var config: Dictionary = pet.BICHON_ANIMATIONS[animation]
		var frame_count: int = int(config["frames"])
		var texture_path := String(config["path"])
		var foot_padding: Array = config.get("foot_padding", [])
		var visible_extent: float = float(config.get("visible_extent", 0.0))
		var horizontal_offsets: Array = config.get("horizontal_offsets", [])
		var import_path := texture_path + ".import"
		check(FileAccess.file_exists(import_path), "%s has a Godot texture import file" % animation)
		if FileAccess.file_exists(import_path):
			var import_text := FileAccess.get_file_as_string(import_path)
			check(import_text.contains("mipmaps/generate=true"), "%s import generates mipmaps for downscaled rendering" % animation)
		check(foot_padding.size() == frame_count, "%s has foot padding for every frame" % animation)
		check(visible_extent > 0.0, "%s has a visible-content extent for scale fitting" % animation)
		if animation != "Walk":
			check(horizontal_offsets.size() == frame_count, "%s has horizontal offsets for every frame" % animation)
		else:
			check(horizontal_offsets.is_empty(), "Walk keeps its source horizontal motion")
		if animation == "Idle":
			var idle_sequence: Array = config.get("sprite_frame_sequence", [])
			check(idle_sequence.size() == frame_count, "Idle maps every logical frame to a composed atlas cell")
			check(int(idle_sequence[9]) != int(idle_sequence[0]), "Idle contains one closed-eye blink frame")
		if foot_padding.size() != frame_count:
			continue
		pet.play_state_animation(animation)
		if visible_extent > 0.0:
			var expected_scale: float = 256.0 * 0.35 * pet.BICHON_VISIBLE_SIZE_MULTIPLIER / visible_extent
			check(is_equal_approx(pet._base_scale.x, expected_scale), "%s scales from visible content bounds" % animation)
		var first_expected_y: float = pet._sprite_anchor().y + float(foot_padding[0]) * pet._base_scale.y
		check(is_equal_approx(pet._sprite.position.y, first_expected_y), "%s first frame is aligned to the ground line" % animation)
		pet._set_bichon_frame(frame_count - 1)
		var last_expected_y: float = pet._sprite_anchor().y + float(foot_padding[-1]) * pet._base_scale.y
		check(is_equal_approx(pet._sprite.position.y, last_expected_y), "%s last frame is aligned to the ground line" % animation)
		var image: Image = pet._sprite.texture.get_image()
		var cell_width: int = image.get_width() / pet._sprite.hframes
		var cell_height: int = image.get_height() / pet._sprite.vframes
		if animation != "Walk" and horizontal_offsets.size() == frame_count:
			for frame_index in frame_count:
				pet._set_bichon_frame(frame_index)
				var rendered_center_x: float = pet._sprite.position.x + _frame_body_center_x(image, cell_width, cell_height, pet._sprite.hframes, pet._sprite.frame) * pet._base_scale.x
				check(absf(rendered_center_x) <= 0.5, "%s frame %d keeps its body centered" % [animation, frame_index])
			pet._sprite.flip_h = true
			for frame_index in frame_count:
				pet._set_bichon_frame(frame_index)
				var mirrored_center_x: float = pet._sprite.position.x - _frame_body_center_x(image, cell_width, cell_height, pet._sprite.hframes, pet._sprite.frame) * pet._base_scale.x
				check(absf(mirrored_center_x) <= 0.5, "%s frame %d stays centered when facing right" % [animation, frame_index])
			pet._sprite.flip_h = false
		elif animation == "Walk":
			var walk_centers := []
			for frame_index in frame_count:
				pet._set_bichon_frame(frame_index)
				var source_center_x: float = _frame_body_center_x(image, cell_width, cell_height, pet._sprite.hframes, pet._sprite.frame) * pet._base_scale.x
				var rendered_center_x: float = pet._sprite.position.x + source_center_x
				check(is_equal_approx(rendered_center_x, source_center_x), "Walk frame %d preserves source horizontal motion" % frame_index)
				walk_centers.append(source_center_x)
			check(not is_equal_approx(walk_centers[0], walk_centers[-1]), "Walk frames retain visible horizontal travel")
	var idle_body_height: float = _average_rendered_body_height(pet, "Idle")
	var petted_body_height: float = _average_rendered_body_height(pet, "Pet")
	check(absf(petted_body_height - idle_body_height) <= 1.0, "Pet body size matches the default Idle body size")

	pet.ps.debug_set_species("bichon", "adult")
	pet.refresh_appearance()
	var edge_margin: float = pet.horizontal_edge_margin()
	for animation in pet.BICHON_ANIMATIONS:
		var config: Dictionary = pet.BICHON_ANIMATIONS[animation]
		pet.play_state_animation(animation)
		var image: Image = pet._sprite.texture.get_image()
		var cell_width: int = image.get_width() / pet._sprite.hframes
		var cell_height: int = image.get_height() / pet._sprite.vframes
		for frame_index in int(config["frames"]):
			pet._set_bichon_frame(frame_index)
			var alpha_bounds := _frame_alpha_bounds_x(image, cell_width, cell_height, pet._sprite.hframes, pet._sprite.frame)
			var local_left: float = pet._sprite.position.x + (float(alpha_bounds.x) - (cell_width - 1) * 0.5) * pet._base_scale.x
			var local_right: float = pet._sprite.position.x + (float(alpha_bounds.y) - (cell_width - 1) * 0.5) * pet._base_scale.x
			check(edge_margin + local_left >= 0.0, "%s frame %d clears the adult left edge" % [animation, frame_index])
			check(pet.screen_size.x - edge_margin + local_right <= pet.screen_size.x, "%s frame %d clears the adult right edge" % [animation, frame_index])
	pet.position.x = 0.0
	var sleep_state: Node = SleepStateScript.new()
	sleep_state.pet = pet
	sleep_state.enter()
	check(is_equal_approx(sleep_state._corner_x, edge_margin), "Sleep uses the adult Bichon left edge margin")
	check(pet._bichon_animation == "Walk", "Sleep walks to the edge before showing the sleep sheet")
	pet.position.x = sleep_state._corner_x
	# Vector2 stores components as 32-bit floats, so assigning a 64-bit corner_x into
	# position.x can leave a sub-pixel rounding residue. A zero delta would demand exact
	# equality against that residue; use one frame's worth of delta instead, like real
	# gameplay always does, so the arrival check tolerates that rounding.
	sleep_state.update(1.0 / 60.0)
	check(pet._bichon_animation == "Sleep", "Sleep sheet begins only after reaching the edge")
	var sulk_state: Node = SulkStateScript.new()
	sulk_state.pet = pet
	sulk_state.enter()
	check(is_equal_approx(sulk_state._corner_x, edge_margin), "Sulk uses the adult Bichon left edge margin")
	var walk_state: Node = WalkStateScript.new()
	walk_state.pet = pet
	walk_state.enter()
	check(walk_state._target_x >= edge_margin and walk_state._target_x <= pet.screen_size.x - edge_margin, "Walk uses the adult Bichon edge margin")
	pet.ps.debug_set_species("bichon", "baby")
	pet.refresh_appearance()

	pet.play_file_drop_reaction()
	await process_frame
	check(pet._bichon_animation == "FileHover", "File drop begins with open-mouth hover sheet")
	await create_timer(0.38).timeout
	check(pet._bichon_animation == "FileConsume", "Open-mouth hover advances to consume sheet")
	await create_timer(0.76).timeout
	check(pet._bichon_animation == "Idle", "Consume sheet restores the current Idle state")
	quit()


func check(condition: bool, name: String) -> void:
	if condition:
		print("PASS  " + name)
		return
	push_error("FAIL  " + name)
	quit(1)


func _frame_body_center_x(image: Image, cell_width: int, cell_height: int, columns: int, frame_index: int) -> float:
	var bounds := _frame_body_bounds(image, cell_width, cell_height, columns, frame_index)
	return float(bounds.position.x) + float(bounds.size.x - 1) * 0.5 - (cell_width - 1) * 0.5


func _average_rendered_body_height(pet: Node2D, animation: String) -> float:
	var config: Dictionary = pet.BICHON_ANIMATIONS[animation]
	pet.play_state_animation(animation)
	var image: Image = pet._sprite.texture.get_image()
	var cell_width: int = image.get_width() / pet._sprite.hframes
	var cell_height: int = image.get_height() / pet._sprite.vframes
	var total_height := 0.0
	for frame_index in int(config["frames"]):
		pet._set_bichon_frame(frame_index)
		var bounds := _frame_body_bounds(image, cell_width, cell_height, pet._sprite.hframes, pet._sprite.frame)
		total_height += float(bounds.size.y) * pet._base_scale.y
	return total_height / float(int(config["frames"]))


func _frame_body_bounds(image: Image, cell_width: int, cell_height: int, columns: int, frame_index: int) -> Rect2i:
	var cell_x: int = frame_index % columns * cell_width
	var cell_y: int = frame_index / columns * cell_height
	var seen := PackedByteArray()
	seen.resize(cell_width * cell_height)
	var largest_count := 0
	var largest_left := cell_width
	var largest_right := -1
	var largest_top := cell_height
	var largest_bottom := -1
	for y in cell_height:
		for x in cell_width:
			var start: int = y * cell_width + x
			if seen[start] != 0 or image.get_pixel(cell_x + x, cell_y + y).a <= 0.05:
				continue
			seen[start] = 1
			var queue := PackedInt32Array([start])
			var queue_index := 0
			var component_count := 0
			var component_left := x
			var component_right := x
			var component_top := y
			var component_bottom := y
			while queue_index < queue.size():
				var current: int = queue[queue_index]
				queue_index += 1
				var current_x: int = current % cell_width
				var current_y: int = current / cell_width
				component_count += 1
				component_left = mini(component_left, current_x)
				component_right = maxi(component_right, current_x)
				component_top = mini(component_top, current_y)
				component_bottom = maxi(component_bottom, current_y)
				for offset_y in range(-1, 2):
					for offset_x in range(-1, 2):
						if offset_x == 0 and offset_y == 0:
							continue
						var neighbor_x := current_x + offset_x
						var neighbor_y := current_y + offset_y
						if neighbor_x < 0 or neighbor_x >= cell_width or neighbor_y < 0 or neighbor_y >= cell_height:
							continue
						var neighbor: int = neighbor_y * cell_width + neighbor_x
						if seen[neighbor] != 0 or image.get_pixel(cell_x + neighbor_x, cell_y + neighbor_y).a <= 0.05:
							continue
						seen[neighbor] = 1
						queue.append(neighbor)
			if component_count > largest_count:
				largest_count = component_count
				largest_left = component_left
				largest_right = component_right
				largest_top = component_top
				largest_bottom = component_bottom
	return Rect2i(largest_left, largest_top, largest_right - largest_left + 1, largest_bottom - largest_top + 1)


func _frame_alpha_bounds_x(image: Image, cell_width: int, cell_height: int, columns: int, frame_index: int) -> Vector2i:
	var cell_x: int = frame_index % columns * cell_width
	var cell_y: int = frame_index / columns * cell_height
	var left := cell_width
	var right := -1
	for y in cell_height:
		for x in cell_width:
			if image.get_pixel(cell_x + x, cell_y + y).a <= 0.05:
				continue
			left = mini(left, x)
			right = maxi(right, x)
	return Vector2i(left, right)
