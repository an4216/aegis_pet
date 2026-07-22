# 헤드리스 단위 테스트 (Design §8). 실행:
#   godot --headless --path . --script tests/run_tests.gd
extends SceneTree

const Balance := preload("res://scripts/data/balance.gd")
const Characters := preload("res://scripts/data/characters.gd")
const TimeM := preload("res://autoload/time_manager.gd")
const PetStateScript := preload("res://autoload/pet_state.gd")
const PetScript := preload("res://scenes/pet/pet.gd")
const PetScene := preload("res://scenes/pet/pet.tscn")

var fails := 0
var passes := 0


func _init() -> void:
	_test_decay_basic()
	_test_decay_geobujang()
	_test_care_feed()
	_test_care_modifier()
	_test_offline_cap()
	_test_sick_and_recover()
	_test_egg_hatch_passive()
	_test_hatch_distribution()
	_test_bichon_registration()
	_test_bichon_animation_manifest()
	_test_pink_cat_baby_registration()
	_test_pink_cat_baby_animation_manifest()
	_test_serialize_roundtrip()
	_test_stage_progression()
	_test_digest()
	call_deferred("_test_pink_cat_baby_care_reactions")


func _finish() -> void:
	print("")
	print("RESULT: %d passed, %d failed" % [passes, fails])
	quit(1 if fails > 0 else 0)


func check(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("PASS  " + test_name)
	else:
		fails += 1
		print("FAIL  " + test_name)


func approx(a: float, b: float, eps := 0.01) -> bool:
	return absf(a - b) < eps


func make_pet(species := "mochi") -> Node:
	var pet: Node = PetStateScript.new()
	pet.debug_set_species(species)
	return pet


# 1시간 경과: hunger -4, happiness -3 (모찌 = 무보정)
func _test_decay_basic() -> void:
	var pet := make_pet("mochi")
	pet.activity = pet.Activity.IDLE
	pet.advance_minutes(60.0, {"hour": 10, "weekday": 2})
	check(approx(pet.stats["hunger"], 76.0), "1시간 감소: hunger 80→76")
	check(approx(pet.stats["happiness"], 67.0), "1시간 감소: happiness 70→67")


# 거부장 all_decay 0.7: hunger -2.8
func _test_decay_geobujang() -> void:
	var pet := make_pet("geobujang")
	pet.advance_minutes(60.0, {"hour": 10, "weekday": 2})
	check(approx(pet.stats["hunger"], 77.2), "거부장 항상성: hunger 80→77.2")


func _test_care_feed() -> void:
	var pet := make_pet("mochi")
	pet.stats["hunger"] = 50.0
	pet.care("feed")
	check(approx(pet.stats["hunger"], 80.0), "먹이: hunger 50→80")


# 햄찌 간식 2배: hunger +20, happiness +10
func _test_care_modifier() -> void:
	var pet := make_pet("haemjji")
	pet.stats["hunger"] = 50.0
	pet.stats["happiness"] = 50.0
	pet.care("snack")
	check(approx(pet.stats["hunger"], 70.0), "햄찌 간식 2배: hunger +20")
	check(approx(pet.stats["happiness"], 60.0), "햄찌 간식 2배: happiness +10")


# 오프라인 12시간 → 8시간 캡 × 50% = 유효 4시간
func _test_offline_cap() -> void:
	check(approx(TimeM.compute_offline_hours(12.0 * 3600.0), 4.0), "오프라인 캡: 12h→유효 4h")
	check(approx(TimeM.compute_offline_hours(2.0 * 3600.0), 1.0), "오프라인 비율: 2h→유효 1h")
	check(approx(TimeM.compute_offline_hours(-100.0), 0.0), "시계 역행: 페널티 0")


func _test_sick_and_recover() -> void:
	var pet := make_pet("mochi")
	pet.stats["health"] = 25.0
	pet.advance_minutes(1.0, {"hour": 10, "weekday": 2})
	check(pet.is_sick, "건강 30 미만 → 병듦")
	pet.care("medicine")
	check(not pet.is_sick and pet.stats["health"] >= 50.0, "약 → 회복")


# 알: 방치 4시간이면 부화 (HATCH_HOURS_MAX)
func _test_egg_hatch_passive() -> void:
	var pet: Node = PetStateScript.new()
	check(pet.stage == "egg" and pet.species == "", "초기 상태는 알")
	pet.advance_minutes(Balance.HATCH_HOURS_MAX * 60.0, {"hour": 10, "weekday": 2})
	check(pet.stage == "baby" and pet.species != "", "4시간 후 부화")


# 부화 확률: 기본 분포 ±2%p, 금요일 가중치 시 불금조 ~11.1%
func _test_hatch_distribution() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260721
	var n := 20000
	var counts := {}
	for i in n:
		var s := Characters.pick_species([], rng)
		counts[s] = counts.get(s, 0) + 1
	var total_weight := 0.0
	for character in Characters.CHARACTERS.values():
		total_weight += float(Characters.RARITY_WEIGHT[character["rarity"]])
	var mochi_weight: float = Characters.RARITY_WEIGHT[Characters.CHARACTERS["mochi"]["rarity"]]
	check(absf(counts.get("mochi", 0) / float(n) - mochi_weight / total_weight) < 0.02, "기본 확률: 모찌 가중치 비율")
	check(absf(counts.get("seureureuk", 0) / float(n) - 0.04) < 0.015, "기본 확률: 스르륵 ~4%")
	var fri := 0
	for i in n:
		if Characters.pick_species(["friday_hatch"], rng) == "bulgeumjo":
			fri += 1
	check(absf(fri / float(n) - 12.0 / 116.0) < 0.02, "금요일 가중치: 불금조 ~10.3%")


func _test_bichon_registration() -> void:
	check(Characters.CHARACTERS.has("bichon"), "비숑이 부화 캐릭터로 등록됨")
	check(Characters.CHARACTERS.get("bichon", {}).get("name_kr", "") == "비숑", "비숑 한글 이름 등록")


func _test_bichon_animation_manifest() -> void:
	var expected := {
		"Idle": 11, "Walk": 12, "Sleep": 8, "FileHover": 4,
		"FileConsume": 8, "Poop": 6, "Sick": 8, "Sulk": 8,
		"Dragged": 4, "Fall": 4, "Land": 4, "Pet": 8, "Play": 8,
	}
	for animation in expected:
		var config: Dictionary = PetScript.BICHON_ANIMATIONS.get(animation, {})
		check(config.get("frames", 0) == expected[animation], "비숑 %s 프레임 수" % animation)


func _test_pink_cat_baby_registration() -> void:
	check(Characters.CHARACTERS.has("pink_cat_baby"), "핑냥이가 부화 캐릭터로 등록됨")
	check(Characters.CHARACTERS.get("pink_cat_baby", {}).get("name_kr", "") == "핑냥이", "핑냥이 한글 이름 등록")


func _test_pink_cat_baby_animation_manifest() -> void:
	var expected := {
		"Idle": 4, "Walk": 12, "Sleep": 8, "Eat": 12,
		"FileHover": 4, "FileConsume": 8, "Poop": 6, "Sick": 8,
		"Sulk": 8, "Dragged": 4, "Fall": 4, "Land": 4,
		"Pet": 8, "Play": 8,
	}
	var atlas_path: String = PetScript.PINK_CAT_BABY_ANIMATIONS["Idle"]["path"]
	var atlas_import_path := atlas_path + ".import"
	check(FileAccess.file_exists(atlas_import_path) and FileAccess.get_file_as_string(atlas_import_path).contains("mipmaps/generate=true"), "핑냥이 아틀라스는 다운스케일 밉맵을 생성")
	for animation in expected:
		var config: Dictionary = PetScript.PINK_CAT_BABY_ANIMATIONS.get(animation, {})
		var frame_count: int = expected[animation]
		check(config.get("frames", 0) == frame_count, "핑냥이 %s 프레임 수" % animation)
		check(config.get("sprite_frame_sequence", []).size() == frame_count, "핑냥이 %s 아틀라스 프레임 매핑" % animation)
		check(config.get("foot_padding", []).size() == frame_count, "핑냥이 %s 작업표시줄 기준선 보정" % animation)
		check(config.get("horizontal_offsets", []).size() == frame_count, "핑냥이 %s 몸통 중심 고정" % animation)
		var animation_atlas_path: String = config.get("path", "")
		check(ResourceLoader.exists(animation_atlas_path), "핑냥이 %s 아틀라스 리소스 존재" % animation)
		var frames_in_atlas := int(config.get("columns", 0)) * int(config.get("rows", 0))
		var sequence_is_in_bounds := true
		for sprite_frame in config.get("sprite_frame_sequence", []):
			sequence_is_in_bounds = sequence_is_in_bounds and int(sprite_frame) >= 0 and int(sprite_frame) < frames_in_atlas
		check(sequence_is_in_bounds, "핑냥이 %s 아틀라스 프레임 범위" % animation)



func _test_pink_cat_baby_care_reactions() -> void:
	var pet_state := make_pet("pink_cat_baby")
	var pet: Node2D = PetScene.instantiate()
	pet.screen_size = Vector2(1280.0, 720.0)
	pet.ground_y = 714.0
	root.add_child(pet)
	await process_frame
	pet.ps = pet_state
	pet.refresh_appearance()
	check(pet._is_animated_pet(), "핑냥이가 애니메이션 펫 경로를 사용")
	check(pet._animation_catalog() == PetScript.PINK_CAT_BABY_ANIMATIONS, "핑냥이 전용 애니메이션 카탈로그 선택")
	for care_reaction in ["Pet", "Play"]:
		pet._on_care_performed(care_reaction.to_lower())
		check(pet._bichon_override == care_reaction and pet._bichon_animation == care_reaction and pet._sprite.texture != null, "핑냥이 %s 케어 반응 경로와 에셋 로드" % care_reaction)
		await create_timer(0.81).timeout
		check(pet._bichon_override.is_empty() and pet._bichon_animation == "Idle", "핑냥이 %s 후 Idle 복귀" % care_reaction)
	pet.queue_free()
	pet_state.free()
	call_deferred("_finish")


func _test_serialize_roundtrip() -> void:
	var pet := make_pet("nyang")
	pet.stats["hunger"] = 42.0
	pet.poop_count = 2
	pet.age_minutes = 1234.0
	var restored: Node = PetStateScript.new()
	restored.deserialize(pet.serialize())
	check(
		restored.species == "nyang"
		and approx(restored.stats["hunger"], 42.0)
		and restored.poop_count == 2
		and approx(restored.age_minutes, 1234.0),
		"직렬화 왕복 보존"
	)


# 소화: 먹이 후 30분 내 응아
func _test_digest() -> void:
	var pet := make_pet("mochi")
	pet.care("feed")
	pet.advance_minutes(Balance.DIGEST_MINUTES_MAX + 1.0, {"hour": 10, "weekday": 2})
	check(pet.poop_count >= 1, "먹이 후 30분 내 응아")


# 성장: 3일 → 소년기, 7일 → 성체
func _test_stage_progression() -> void:
	var pet := make_pet("mochi")
	pet.stats["hunger"] = 100.0
	# 케어를 반복하며 시간을 흘림 (스탯 고갈로 인한 부작용 무시, 단계만 검증)
	for day in 3:
		pet.advance_minutes(1440.0, {"hour": 10, "weekday": 2})
		pet.care("feed")
		pet.care("clean")
	check(pet.stage == "child", "3일 경과 → 소년기")
	for day in 4:
		pet.advance_minutes(1440.0, {"hour": 10, "weekday": 2})
	check(pet.stage == "adult", "7일 경과 → 성체")
	check(pet.care_quality_samples.size() >= 2, "단계 전환 시 케어 품질 샘플 기록")
