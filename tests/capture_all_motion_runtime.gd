extends SceneTree

const OUTPUT_PATH := "res://.omo/evidence/all-character-motion-runtime.png"
const BOARD_SIZE := Vector2i(1400, 2560)
const SPECIES := [
	"mochi", "ppiyak", "haemjji", "kkubeok", "nyang", "kong",
	"mundeok", "geobujang", "bulgeumjo", "seureureuk", "tokki", "ddungsil",
]
const SPECIES_LABELS := [
	"MOCHI", "PPIYAK", "HAEMJJI", "KKUBEOK", "NYANG", "KONG",
	"MUNDEOK", "GEOBUJANG", "BULGEUMJO", "SEUREUREUK", "TOKKI", "DDUNGSIL",
]
const TIERS := ["base", "evolved", "evolved2"]


func _init() -> void:
	var viewport := SubViewport.new()
	viewport.size = BOARD_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(viewport)

	var background := ColorRect.new()
	background.color = Color("f7f3ea")
	background.size = Vector2(BOARD_SIZE)
	viewport.add_child(background)

	var title := _make_label("ALL CHARACTERS EXCEPT HAESOL · ACTUAL GODOT RUNTIME MOTION", 34, Color("403a34"))
	title.position = Vector2(36, 22)
	viewport.add_child(title)
	var subtitle := _make_label("Each tier shows Walk f0/f1 and Play f0/apex through the live Pet runtime scale and anchor path.", 18, Color("756c63"))
	subtitle.position = Vector2(38, 68)
	viewport.add_child(subtitle)
	for tier_index in TIERS.size():
		var tier_label := _make_label(String(TIERS[tier_index]).to_upper(), 22, Color("5b5148"))
		tier_label.position = Vector2(295 + tier_index * 360, 116)
		viewport.add_child(tier_label)

	var pet_scene: PackedScene = load("res://scenes/pet/pet.tscn")
	var pet = pet_scene.instantiate()
	pet.position = Vector2(-2000, -2000)
	viewport.add_child(pet)
	await process_frame
	pet.process_mode = Node.PROCESS_MODE_DISABLED

	for species_index in SPECIES.size():
		var row_y := 210.0 + species_index * 192.0
		var species_label := _make_label(SPECIES_LABELS[species_index], 21, Color("403a34"))
		species_label.position = Vector2(30, row_y + 48)
		viewport.add_child(species_label)
		for tier_index in TIERS.size():
			pet.debug_set_appearance(SPECIES[species_index], "adult", TIERS[tier_index])
			_add_samples(viewport, pet, Vector2(250 + tier_index * 360, row_y))
		var divider := ColorRect.new()
		divider.color = Color("ddd5c9")
		divider.position = Vector2(24, row_y + 164)
		divider.size = Vector2(1352, 1)
		viewport.add_child(divider)

	pet.visible = false
	await process_frame
	RenderingServer.force_draw(false, 0.0)
	var image := viewport.get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	print("ALL MOTION RUNTIME CAPTURE: %s (%dx%d), error=%d" % [OUTPUT_PATH, image.get_width(), image.get_height(), error])
	quit(0 if error == OK else 1)


func _add_samples(viewport: SubViewport, pet: Node2D, origin: Vector2) -> void:
	for sample in [["Walk", 0], ["Walk", 1], ["Play", 0], ["Play", 2]]:
		var sample_index: int = [["Walk", 0], ["Walk", 1], ["Play", 0], ["Play", 2]].find(sample)
		pet.play_state_animation(String(sample[0]))
		pet._set_bichon_frame(int(sample[1]))
		var snapshot := Sprite2D.new()
		snapshot.texture = pet._sprite.texture
		snapshot.hframes = pet._sprite.hframes
		snapshot.vframes = pet._sprite.vframes
		snapshot.frame = pet._sprite.frame
		snapshot.scale = pet._sprite.scale
		snapshot.texture_filter = pet._sprite.texture_filter
		var column := sample_index % 2
		var row := sample_index / 2
		var baseline := origin + Vector2(column * 150, row * 78 + 54)
		snapshot.position = baseline + pet._sprite.position
		viewport.add_child(snapshot)
		var label := _make_label("%s f%d" % [sample[0], sample[1]], 12, Color("9a8f84"))
		label.position = baseline + Vector2(-30, 20)
		viewport.add_child(label)


func _make_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
