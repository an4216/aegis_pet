extends SceneTree

const OUTPUT_ROOT := "res://.omo/evidence/true-walk-runtime"
const CELL_SIZE := Vector2i(192, 208)
const SPECIES := [
	"kkubeok", "nyang", "kong", "mundeok", "geobujang", "bulgeumjo", "seureureuk", "tokki",
]
const TIERS := ["base", "evolved", "evolved2"]


func _init() -> void:
	Engine.time_scale = 0.05
	var pet_scene: PackedScene = load("res://scenes/pet/pet.tscn")
	var pet: Node2D = pet_scene.instantiate()
	pet.position = Vector2(-2000, -2000)
	root.add_child(pet)
	await process_frame
	var traces: Array[String] = []
	var requested := OS.get_cmdline_user_args()
	var capture_species: Array = SPECIES if requested.is_empty() else [requested[0]]
	for species in capture_species:
		var board := Image.create_empty(CELL_SIZE.x * 9, CELL_SIZE.y * 3, false, Image.FORMAT_RGBA8)
		board.fill(Color("f7f3ea"))
		var row := 0
		for tier in TIERS:
			pet.debug_set_appearance(species, "adult", tier)
			await process_frame
			var idle_height := _runtime_visible_height(pet)
			var idle_area := _runtime_visible_area(pet)
			var idle_scale_ratio := absf(pet._sprite.scale.x / pet._sprite.scale.y)
			_blend_runtime_frame(board, pet, row, 0)
			if not pet.start_animated_pose("Walk"):
				push_error("Walk playback failed: %s/%s" % [species, tier])
				quit(1)
				return
			for phase in 8:
				pet._set_bichon_frame(phase)
				if pet._bichon_frame != phase:
					push_error("runtime frame order mismatch for %s/%s at phase %d: %d" % [species, tier, phase, pet._bichon_frame])
					quit(1)
					return
				var walk_height := _runtime_visible_height(pet)
				var walk_area := _runtime_visible_area(pet)
				var scale_ratio := absf(pet._sprite.scale.x / pet._sprite.scale.y)
				traces.append("%s/%s:f%d=height:%.2f,area:%.2f,scale:%.3f" % [
					species, tier, pet._bichon_frame, walk_height / idle_height,
					walk_area / idle_area, scale_ratio / idle_scale_ratio,
				])
				_blend_runtime_frame(board, pet, row, phase + 1)
			pet.stop_animated_pose()
			row += 1
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_ROOT))
		var error := board.save_png("%s/%s.png" % [OUTPUT_ROOT, species])
		if error != OK:
			push_error("runtime board save failed for %s: %d" % [species, error])
			quit(1)
			return
	pet.visible = false
	var trace := "TRUE WALK TRACE: %s" % " ".join(traces)
	var trace_file := FileAccess.open("%s/trace.txt" % OUTPUT_ROOT, FileAccess.WRITE)
	trace_file.store_string(trace + "\n")
	print(trace)
	quit(0)


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
	var source_rect := Rect2i(source_position, source_size)
	var rendered := texture_image.get_region(source_rect)
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


func _runtime_visible_height(pet: Node2D) -> float:
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
	var frame := texture_image.get_region(Rect2i(source_position, source_size))
	var top := -1
	var bottom := -1
	for y in range(frame.get_height()):
		for x in range(frame.get_width()):
			if frame.get_pixel(x, y).a >= 0.125:
				if top < 0:
					top = y
				bottom = y
				break
	return float(bottom - top + 1) * absf(pet._sprite.scale.y)


func _runtime_visible_area(pet: Node2D) -> float:
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
	var frame := texture_image.get_region(Rect2i(source_position, source_size))
	var visible_pixels := 0
	for y in range(frame.get_height()):
		for x in range(frame.get_width()):
			if frame.get_pixel(x, y).a >= 0.125:
				visible_pixels += 1
	return float(visible_pixels) * absf(pet._sprite.scale.x * pet._sprite.scale.y)
