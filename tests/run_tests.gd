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
# 케어 반응 테스트가 야간 판정을 끄고 빌려 쓴 원래 값 (_test_mochi_pose_runtime 끝에서 되돌린다).
var _saved_night_window: Array = []


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
	_test_ppiyak_animated_sleep_manifest()
	_test_ppiyak_idle_blink_sheet()
	_test_mochi_pose_manifest()
	_test_haemjji_pose_manifest()
	_test_serialize_roundtrip()
	_test_stage_progression()
	_test_digest()
	_test_probe_parse()
	_test_reset_to_egg()
	_test_version_compare()
	_test_evolution_keyboard()
	_test_evolution_distinct_days()
	_test_evolution_feed_snack()
	_test_evolution_progress_ratio()
	_test_evolution_persists_across_save()
	_test_evolution_gated_by_egg()
	_test_evolution_2_tier()
	_test_consecutive_days()
	_test_rabbit_full_evolution()
	_test_dialog_evolution_pools()
	_test_bichon_evolution()
	call_deferred("_test_bichon_care_reactions")


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
	for species in Characters.CHARACTERS:
		if not Characters.is_hatchable(species):
			continue
		total_weight += float(Characters.RARITY_WEIGHT[Characters.CHARACTERS[species]["rarity"]])
	var mochi_weight: float = Characters.RARITY_WEIGHT[Characters.CHARACTERS["mochi"]["rarity"]]
	check(absf(counts.get("mochi", 0) / float(n) - mochi_weight / total_weight) < 0.02, "기본 확률: 모찌 가중치 비율")
	check(absf(counts.get("seureureuk", 0) / float(n) - 0.04) < 0.015, "기본 확률: 스르륵 ~4%")
	check(not Characters.is_hatchable("bichon"), "해솔은 부화 후보에서 숨김 처리됨")
	check(counts.get("bichon", 0) == 0, "해솔은 2만 회 샘플링에서 한 번도 뽑히지 않음")
	var fri := 0
	for i in n:
		if Characters.pick_species(["friday_hatch"], rng) == "bulgeumjo":
			fri += 1
	check(absf(fri / float(n) - 12.0 / 116.0) < 0.02, "금요일 가중치: 불금조 ~10.3%")


func _test_bichon_registration() -> void:
	check(Characters.CHARACTERS.has("bichon"), "비숑이 부화 캐릭터로 등록됨")
	check(Characters.CHARACTERS.get("bichon", {}).get("name_kr", "") == "해솔", "비숑 한글 이름 등록")


func _test_bichon_animation_manifest() -> void:
	var expected := {
		"Idle": 11, "Walk": 12, "Sleep": 8, "FileHover": 4,
		"FileConsume": 8, "Poop": 6, "Sick": 8, "Sulk": 8,
		"Dragged": 4, "Fall": 4, "Land": 4, "Pet": 8, "Play": 8,
	}
	for animation in expected:
		var config: Dictionary = PetScript.BICHON_ANIMATIONS.get(animation, {})
		check(config.get("frames", 0) == expected[animation], "비숑 %s 프레임 수" % animation)
		# 비숑은 airborne 선언을 쓰지 않는다 — 이 시트들의 foot_padding 변동은 "떠오른 높이"가
		# 아니라 프레임별 바운딩 박스 차이라, 매 프레임 발 재고정(기본 접지 처리)이 정답이다.
		# 출시 후 정상 동작 중인 시각 결과를 바꾸지 않기 위한 잠금 (2026-08-06).
		check(not bool(config.get("airborne", false)), "비숑 %s airborne 미선언 (접지 재고정 유지)" % animation)


# 삐약 계열: 10상태 x 3티어(base/evolved/evolved2) 애니메이션 오버라이드 매니페스트.
# 셀은 전부 128x128, 접지 상태의 foot_padding은 12.0 고정. Happy(=Play)/Dragged/Fall만
# 의도적으로 공중에 떠서 프레임마다 값이 커진다. Land만 loop=false.
const PPIYAK_TIERS := ["base", "evolved", "evolved2"]
const PPIYAK_SHEET_DIR := {"base": "ppiyak", "evolved": "ppiyak_evolved", "evolved2": "ppiyak_evolved2"}
const PPIYAK_EXPECTED_STATES := {
	# Idle만 물리 6칸을 sprite_frame_sequence로 논리 16프레임에 매핑한다 — 격자 칸 수 != frames.
	"Idle": {"file": "idle_blink_6f.png", "frames": 16, "columns": 6, "rows": 1, "loop": true, "grounded": true, "sequence": [0, 0, 1, 1, 2, 2, 3, 3, 0, 4, 5, 4, 0, 0, 2, 2]},
	"Walk": {"file": "walk_8f.png", "frames": 8, "columns": 4, "rows": 2, "loop": true, "grounded": true},
	"Sleep": {"file": "sleep_6f.png", "frames": 6, "columns": 6, "rows": 1, "loop": true, "grounded": true},
	"Eat": {"file": "eat_6f.png", "frames": 6, "columns": 6, "rows": 1, "loop": true, "grounded": true},
	"Sick": {"file": "sick_6f.png", "frames": 6, "columns": 6, "rows": 1, "loop": true, "grounded": true},
	"Sulk": {"file": "sulk_6f.png", "frames": 6, "columns": 6, "rows": 1, "loop": true, "grounded": true},
	# Happy 시트는 state_machine에 없는 "Happy"가 아니라 "Play" 상태 키로 등록된다.
	"Play": {"file": "happy_6f.png", "frames": 6, "columns": 6, "rows": 1, "loop": true, "grounded": false},
	"Dragged": {"file": "dragged_4f.png", "frames": 4, "columns": 4, "rows": 1, "loop": true, "grounded": false},
	"Fall": {"file": "fall_4f.png", "frames": 4, "columns": 4, "rows": 1, "loop": true, "grounded": false},
	"Land": {"file": "land_4f.png", "frames": 4, "columns": 4, "rows": 1, "loop": false, "grounded": true},
}


func _test_ppiyak_animated_sleep_manifest() -> void:
	var entry: Dictionary = PetScript.ANIMATED_POSE_OVERRIDES.get("ppiyak", {})
	check(not entry.is_empty(), "삐약 포즈 오버라이드 등록됨")
	var states: Dictionary = entry.get("states", {})
	check(states.size() == PPIYAK_EXPECTED_STATES.size(),
		"삐약 등록 상태 수 %d == 기대 %d (10상태 커버리지)" % [states.size(), PPIYAK_EXPECTED_STATES.size()])
	# 삐약은 3티어 전부 전용 시트가 있으므로 "tiers" 제한을 걸면 안 된다 (모찌와 다른 점).
	check(entry.get("tiers", []).is_empty(), "삐약 tiers 제한 없음 (base/evolved/evolved2 전부 시트 보유)")
	# sheet_scale은 tier -> 보정값 딕셔너리다(모찌와 같은 형식). 티어를 등록해 두지 않으면
	# 그 티어만 보정 없이(1.0) 렌더돼 진화 시 몸통 크기가 튄다 — 3티어 전부 값이 있어야 한다.
	var ppiyak_sheet_scale: Dictionary = entry.get("sheet_scale", {})
	for tier in ["base", "evolved", "evolved2"]:
		check(float(ppiyak_sheet_scale.get(tier, 0.0)) > 0.0,
			"삐약 sheet_scale[%s] 등록됨 (%.3f)" % [tier, float(ppiyak_sheet_scale.get(tier, 0.0))])
	# state_machine이 정의하지 않는 상태명은 등록되면 안 된다 (Happy는 Play로 들어간다).
	for illegal in ["Happy", "FileHover", "FileConsume", "Poop", "Pet"]:
		check(not states.has(illegal), "삐약 %s 미등록 (state_machine에 없거나 스코프 외)" % illegal)

	for state in PPIYAK_EXPECTED_STATES:
		var expected: Dictionary = PPIYAK_EXPECTED_STATES[state]
		var by_tier: Dictionary = states.get(state, {})
		check(not by_tier.is_empty(), "삐약 %s 등록됨" % state)
		for tier in PPIYAK_TIERS:
			check(by_tier.has(tier), "삐약 %s/%s 티어 등록" % [state, tier])
			var config: Dictionary = by_tier.get(tier, {})
			if config.is_empty():
				continue
			var frames: int = int(config.get("frames", 0))
			var columns: int = int(config.get("columns", 0))
			var rows: int = int(config.get("rows", 0))
			check(frames == expected["frames"], "삐약 %s/%s 프레임 수 %d == %d" % [state, tier, frames, expected["frames"]])
			check(columns == expected["columns"] and rows == expected["rows"],
				"삐약 %s/%s 격자 %dx%d == %dx%d" % [state, tier, columns, rows, expected["columns"], expected["rows"]])
			var want_sequence: Array = expected.get("sequence", [])
			if want_sequence.is_empty():
				check(columns * rows == frames, "삐약 %s/%s 격자 칸 수(%d) == frames(%d)" % [state, tier, columns * rows, frames])
			else:
				# 셀 재사용 상태는 등록된 시퀀스가 기대값과 정확히 같아야 한다. 시퀀스가 빠지면
				# 런타임이 조용히 물리 칸만 순서대로 돌려 깜박임이 사라진다.
				check(config.get("sprite_frame_sequence", []) == want_sequence,
					"삐약 %s/%s sprite_frame_sequence == 기대 시퀀스" % [state, tier])
			check(bool(config.get("loop", false)) == expected["loop"], "삐약 %s/%s loop == %s" % [state, tier, expected["loop"]])
			check(float(config.get("fps", 0.0)) > 0.0, "삐약 %s/%s fps > 0" % [state, tier])
			var path: String = String(config.get("path", ""))
			var want_path: String = "res://assets/sprites/%s/%s" % [PPIYAK_SHEET_DIR[tier], expected["file"]]
			check(path == want_path, "삐약 %s/%s path == %s" % [state, tier, want_path])
			check(ResourceLoader.exists(path), "삐약 %s/%s 시트 존재: %s" % [state, tier, path])
			var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
			check(texture != null, "삐약 %s/%s 시트 로드" % [state, tier])
			if texture != null:
				var size: Vector2 = texture.get_size()
				check(int(size.x) == 128 * columns and int(size.y) == 128 * rows,
					"삐약 %s/%s 시트 크기 %dx%d == 격자 x 128" % [state, tier, int(size.x), int(size.y)])
			for key in ["foot_padding", "horizontal_offsets"]:
				var arr: Array = config.get(key, [])
				check(arr.size() == frames, "삐약 %s/%s %s 길이(%d) == frames(%d)" % [state, tier, key, arr.size(), frames])
			# 접지 상태는 발바닥 기준선이 전 프레임 12.0으로 고정 — 상태를 바꿔도 발이 튀지 않는다.
			# 공중 상태(Play/Dragged/Fall)는 foot_padding이 점프·부유 높이를 만들므로 12 이상이면 된다.
			var padding_ok := true
			for value in config.get("foot_padding", []):
				if expected["grounded"]:
					if not approx(float(value), 12.0):
						padding_ok = false
				elif float(value) < 12.0:
					padding_ok = false
			check(padding_ok, "삐약 %s/%s foot_padding %s" % [state, tier,
				"전 프레임 12.0" if expected["grounded"] else ">= 12.0 (공중 진폭)"])
			# 공중 상태는 "airborne": true 가 반드시 있어야 한다 — 없으면 런타임이 매 프레임 발을
			# 지면에 재고정해 foot_padding 진폭을 그대로 상쇄한다(2026-08-06 블로커 회귀 방지).
			var want_airborne: bool = not bool(expected["grounded"])
			check(bool(config.get("airborne", false)) == want_airborne,
				"삐약 %s/%s airborne == %s" % [state, tier, want_airborne])
			# 몸통 중심 좌우 흔들림은 셀 중심 기준 +-7px 이내 (핸드오프 실측 -7.0 ~ +3.5)
			var offsets_bounded := true
			for value in config.get("horizontal_offsets", []):
				if absf(float(value)) > 7.0:
					offsets_bounded = false
			check(offsets_bounded, "삐약 %s/%s horizontal_offsets 절댓값 <= 7.0" % [state, tier])
			var seq: Array = config.get("sprite_frame_sequence", [])
			if not seq.is_empty():
				check(seq.size() == frames, "삐약 %s/%s sprite_frame_sequence 길이" % [state, tier])
				var in_range := true
				for v in seq:
					if int(v) < 0 or int(v) >= columns * rows:
						in_range = false
				check(in_range, "삐약 %s/%s sprite_frame_sequence 값이 격자 범위 내" % [state, tier])

	# 공중 상태는 실제로 프레임 간 높이 변화가 있어야 한다 (foot_padding 등록 누락 회귀 방지).
	for state in ["Play", "Dragged", "Fall"]:
		for tier in PPIYAK_TIERS:
			var padding: Array = states.get(state, {}).get(tier, {}).get("foot_padding", [])
			var varies := false
			for value in padding:
				if not approx(float(value), 12.0):
					varies = true
			check(varies, "삐약 %s/%s 공중 진폭 존재 (foot_padding이 전부 12.0이 아님)" % [state, tier])

	# Sick 시트에는 어지럼 기호가 없다 — 런타임 @_@ 라벨을 띄우도록 플래그가 켜져 있어야 한다.
	for tier in PPIYAK_TIERS:
		check(bool(states.get("Sick", {}).get(tier, {}).get("runtime_sick_mark", false)),
			"삐약 Sick/%s runtime_sick_mark == true (@_@ 라벨 런타임 렌더)" % tier)

	# 밉맵: 축소 렌더링 자산이므로 30장 전부 mipmaps/generate=true여야 한다 (제작 가이드 §2).
	for tier in PPIYAK_TIERS:
		for state in PPIYAK_EXPECTED_STATES:
			var import_path: String = "res://assets/sprites/%s/%s.import" % [PPIYAK_SHEET_DIR[tier], PPIYAK_EXPECTED_STATES[state]["file"]]
			var f := FileAccess.open(import_path, FileAccess.READ)
			check(f != null and f.get_as_text().contains("mipmaps/generate=true"),
				"삐약 %s/%s .import 밉맵 생성 켜짐" % [state, tier])

	# 레거시 정지 포즈 8종은 삭제하지 않고 보존한다 (회귀 비교용).
	for dir_name in ["ppiyak", "ppiyak_evolved", "ppiyak_evolved2"]:
		for pose in ["idle", "walk1", "walk2", "sleep", "happy", "sulk", "sick", "eat"]:
			check(FileAccess.file_exists("res://assets/sprites/chars/%s/%s.png" % [dir_name, pose]),
				"삐약 %s 레거시 정지 %s.png 잔존(보존)" % [dir_name, pose])


# 삐약 Idle 눈 깜박임: 물리 6칸(768x128) 시트를 논리 16프레임에 매핑한다.
# 인덱스 4/5가 "눈 감은" 셀이라, 시퀀스에서 이 둘이 빠지면 시트만 교체되고 깜박임은 사라진다.
const PPIYAK_BLINK_CELLS := [4, 5]


func _test_ppiyak_idle_blink_sheet() -> void:
	var states: Dictionary = PetScript.ANIMATED_POSE_OVERRIDES.get("ppiyak", {}).get("states", {})
	var idle_by_tier: Dictionary = states.get("Idle", {})
	for tier in PPIYAK_TIERS:
		var config: Dictionary = idle_by_tier.get(tier, {})
		check(not config.is_empty(), "삐약 블링크 Idle/%s 등록됨" % tier)
		if config.is_empty():
			continue
		check(int(config.get("frames", 0)) == 16, "삐약 블링크 Idle/%s frames == 16" % tier)
		for key in ["foot_padding", "horizontal_offsets"]:
			check(Array(config.get(key, [])).size() == 16,
				"삐약 블링크 Idle/%s %s 길이 == 16" % [tier, key])

		var seq: Array = config.get("sprite_frame_sequence", [])
		check(seq.size() == 16, "삐약 블링크 Idle/%s sprite_frame_sequence 길이 == 16" % tier)
		var in_range := true
		for v in seq:
			if int(v) < 0 or int(v) > 5:
				in_range = false
		check(in_range, "삐약 블링크 Idle/%s 시퀀스 값 전부 0~5 (물리 6칸)" % tier)
		var blink_hits := 0
		for v in seq:
			if int(v) in PPIYAK_BLINK_CELLS:
				blink_hits += 1
		check(blink_hits > 0, "삐약 블링크 Idle/%s 시퀀스에 눈 감은 셀(4/5) %d회 포함" % [tier, blink_hits])

		var path: String = String(config.get("path", ""))
		var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
		check(texture != null, "삐약 블링크 Idle/%s 시트 로드: %s" % [tier, path])
		if texture == null:
			continue
		var image: Image = texture.get_image()
		check(image.get_width() == 768 and image.get_height() == 128,
			"삐약 블링크 Idle/%s 시트 크기 %dx%d == 768x128" % [tier, image.get_width(), image.get_height()])
		if image.get_width() != 768 or image.get_height() != 128:
			continue
		# 6칸이 서로 다른 그림이어야 한다 — 복사된 칸이 섞이면 매니페스트는 통과하는데
		# 화면에서는 깜박이지 않는다(2026-08-07 헤드리스 QA에서 픽셀로 확인).
		var cells: Array[Image] = []
		for index in 6:
			cells.append(image.get_region(Rect2i(index * 128, 0, 128, 128)))
		var duplicates := ""
		for i in 6:
			for j in range(i + 1, 6):
				if _image_diff_pixels(cells[i], cells[j]) == 0:
					duplicates += " %d==%d" % [i, j]
		check(duplicates.is_empty(), "삐약 블링크 Idle/%s 6칸 전부 서로 다른 그림%s" % [tier, duplicates])


## 두 동일 크기 이미지에서 RGBA 중 한 채널이라도 0.05 넘게 다른 픽셀 수.
func _image_diff_pixels(a: Image, b: Image) -> int:
	var count := 0
	for y in a.get_height():
		for x in a.get_width():
			var pa: Color = a.get_pixel(x, y)
			var pb: Color = b.get_pixel(x, y)
			if absf(pa.r - pb.r) > 0.05 or absf(pa.g - pb.g) > 0.05 \
					or absf(pa.b - pb.b) > 0.05 or absf(pa.a - pb.a) > 0.05:
				count += 1
	return count


# 모찌 base: 10상태 포즈 오버라이드 매니페스트. 셀 192x208, foot_padding 전 프레임 16.0.
# 햄찌 base 14상태 — 셀 128x128, 접지 기준선 12.0 고정, evolved/evolved2는 아트 미제작.
const HAEMJJI_EXPECTED_STATES := {
	"Idle": {"frames": 6, "columns": 6, "rows": 1, "loop": true},
	"Walk": {"frames": 8, "columns": 4, "rows": 2, "loop": true},
	"Sleep": {"frames": 6, "columns": 6, "rows": 1, "loop": true},
	"Eat": {"frames": 6, "columns": 6, "rows": 1, "loop": true},
	"Sick": {"frames": 6, "columns": 6, "rows": 1, "loop": true},
	"Sulk": {"frames": 6, "columns": 6, "rows": 1, "loop": true},
	"Play": {"frames": 6, "columns": 6, "rows": 1, "loop": true},
	"Dragged": {"frames": 4, "columns": 4, "rows": 1, "loop": true},
	"Fall": {"frames": 4, "columns": 4, "rows": 1, "loop": true},
	"Land": {"frames": 4, "columns": 4, "rows": 1, "loop": false},
	"FileHover": {"frames": 4, "columns": 4, "rows": 1, "loop": false},
	"FileConsume": {"frames": 4, "columns": 4, "rows": 1, "loop": false},
	"Poop": {"frames": 6, "columns": 6, "rows": 1, "loop": true},
	"Pet": {"frames": 6, "columns": 6, "rows": 1, "loop": false},
}


func _test_haemjji_pose_manifest() -> void:
	var entry: Dictionary = PetScript.ANIMATED_POSE_OVERRIDES.get("haemjji", {})
	check(not entry.is_empty(), "햄찌 포즈 오버라이드 등록됨")
	var states: Dictionary = entry.get("states", {})
	check(states.size() == HAEMJJI_EXPECTED_STATES.size(),
		"햄찌 등록 상태 수 %d == 기대 %d" % [states.size(), HAEMJJI_EXPECTED_STATES.size()])
	# base(햄찌)·evolved(함장님)·evolved2(햄왕) 3티어 전부 애니메이션 시트를 갖는다.
	check(entry.get("tiers", []) == ["base", "evolved", "evolved2"], "햄찌 tiers == 3티어 전부")
	# sheet_scale은 티어맵 — 티어마다 정지 아트와 시트 몸통 비율이 다르다.
	# 2026-08-07 §12: evolved 계열 정지 아트만 256px로 복원돼 art_ratio(2.0177 / 2.0089)만큼
	# 커졌다. sheet_scale = 정지 몸통 / 시트 몸통 이므로 분자만 커져 같은 배수로 올라간다
	# (시트 자산은 128px 그대로). 1.125 -> 2.2699, 1.056 -> 2.1214.
	var expected_sheet_scale := {"base": 1.083, "evolved": 2.2699, "evolved2": 2.1214}
	var sheet_scale: Variant = entry.get("sheet_scale")
	check(sheet_scale is Dictionary, "햄찌 sheet_scale 티어맵 구조")
	for tier in expected_sheet_scale:
		check(sheet_scale is Dictionary and approx(float(sheet_scale[tier]), expected_sheet_scale[tier], 0.001),
			"햄찌 sheet_scale[%s] == %.3f" % [tier, expected_sheet_scale[tier]])
	var tier_dirs := {"base": "haemjji", "evolved": "haemjji_evolved", "evolved2": "haemjji_evolved2"}

	for state in HAEMJJI_EXPECTED_STATES:
		var expected: Dictionary = HAEMJJI_EXPECTED_STATES[state]
		var by_tier: Dictionary = states.get(state, {})
		check(not by_tier.has("path"), "햄찌 %s 는 티어맵 구조" % state)
		for tier in ["base", "evolved", "evolved2"]:
			var label: String = "햄찌 %s %s" % [tier, state]
			var config: Dictionary = by_tier.get(tier, {})
			check(not config.is_empty(), "%s 등록됨" % label)
			if config.is_empty():
				continue
			var frames: int = int(config.get("frames", 0))
			var columns: int = int(config.get("columns", 0))
			var rows: int = int(config.get("rows", 0))
			check(frames == expected["frames"] and columns == expected["columns"] and rows == expected["rows"],
				"%s 격자 %dx%d / %d프레임" % [label, columns, rows, frames])
			check(columns * rows == frames, "%s 격자 칸 수(%d) == frames(%d)" % [label, columns * rows, frames])
			check(bool(config.get("loop", false)) == expected["loop"], "%s loop == %s" % [label, expected["loop"]])
			check(float(config.get("fps", 0.0)) > 0.0, "%s fps > 0" % label)
			var path: String = String(config.get("path", ""))
			check(path.begins_with("res://assets/sprites/%s/" % tier_dirs[tier]) and ResourceLoader.exists(path),
				"%s 시트 경로·존재: %s" % [label, path.get_file()])
			var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
			check(texture != null, "%s 시트 로드" % label)
			if texture != null:
				var size: Vector2 = texture.get_size()
				check(int(size.x) == 128 * columns and int(size.y) == 128 * rows,
					"%s 시트 크기 %dx%d == 격자 x 128" % [label, int(size.x), int(size.y)])
			for key in ["foot_padding", "horizontal_offsets"]:
				var arr: Array = config.get(key, [])
				check(arr.size() == frames, "%s %s 길이(%d) == frames(%d)" % [label, key, arr.size(), frames])
			# 접지 기준선은 두 티어 76프레임씩 전부 12.0 — 프레임 간 상하 튐이 없어야 한다.
			var padding_uniform := true
			for value in config.get("foot_padding", []):
				if not approx(float(value), 12.0):
					padding_uniform = false
			check(padding_uniform, "%s foot_padding 전 프레임 12.0" % label)
			# evolved는 셰프 토크·앞치마 때문에 base(±2.0)보다 중심 흔들림이 크다(핸드오프 실측 ±3.5).
			# 진화 티어는 착용물(토크·앞치마·금관) 때문에 base(±2.0)보다 중심 흔들림이 크다.
			var offset_bound: float = 2.0 if tier == "base" else 3.5
			var offsets_bounded := true
			for value in config.get("horizontal_offsets", []):
				if absf(float(value)) > offset_bound:
					offsets_bounded = false
			check(offsets_bounded, "%s horizontal_offsets 절댓값 <= %.1f" % [label, offset_bound])
			# 공중 3상태만 airborne (없으면 매 프레임 발 재고정이 부양분을 상쇄한다).
			check(bool(config.get("airborne", false)) == (state in ["Play", "Dragged", "Fall"]),
				"%s airborne == %s" % [label, state in ["Play", "Dragged", "Fall"]])
			# Sick 시트에 부유 기호가 없으므로 런타임 @_@ 라벨이 어지럼 표시를 대신해야 한다.
			check(bool(config.get("runtime_sick_mark", false)) == (state == "Sick"),
				"%s runtime_sick_mark == %s" % [label, state == "Sick"])


const MOCHI_EXPECTED_STATES := {
	"Idle": {"frames": 4, "columns": 4, "rows": 1, "loop": true},
	"Walk": {"frames": 8, "columns": 4, "rows": 2, "loop": true},
	"Sleep": {"frames": 4, "columns": 4, "rows": 1, "loop": true},
	"Eat": {"frames": 4, "columns": 4, "rows": 1, "loop": true},
	"Sick": {"frames": 4, "columns": 4, "rows": 1, "loop": true},
	"Sulk": {"frames": 4, "columns": 4, "rows": 1, "loop": true},
	"Play": {"frames": 4, "columns": 4, "rows": 1, "loop": true},
	"Dragged": {"frames": 4, "columns": 4, "rows": 1, "loop": true},
	"Fall": {"frames": 4, "columns": 4, "rows": 1, "loop": true},
	"Land": {"frames": 4, "columns": 4, "rows": 1, "loop": false},
	# 잔여 4상태(2026-08-07 추가) — 이로써 모찌가 bichon과 동일한 14상태를 갖춘다.
	"FileHover": {"frames": 4, "columns": 4, "rows": 1, "loop": false},
	"FileConsume": {"frames": 4, "columns": 4, "rows": 1, "loop": false},
	"Poop": {"frames": 4, "columns": 4, "rows": 1, "loop": true},
	"Pet": {"frames": 4, "columns": 4, "rows": 1, "loop": false},
}


func _test_mochi_pose_manifest() -> void:
	var entry: Dictionary = PetScript.ANIMATED_POSE_OVERRIDES.get("mochi", {})
	check(not entry.is_empty(), "모찌 포즈 오버라이드 등록됨")
	var states: Dictionary = entry.get("states", {})
	check(states.size() == MOCHI_EXPECTED_STATES.size(),
		"모찌 등록 상태 수 %d == 기대 %d" % [states.size(), MOCHI_EXPECTED_STATES.size()])
	# base(모찌)·evolved(프로찌)·evolved2(회찌) 3티어 전부 애니메이션 시트를 갖는다.
	check(entry.get("tiers", []) == ["base", "evolved", "evolved2"], "모찌 tiers == 3티어 전부")
	# 시트 셀(208px)이 정지 포즈 캔버스(128px)보다 커서 sheet_scale로 몸통 크기를 맞춘다.
	# 정지 경로와 같은 화면 높이를 내는 실효 배율 (핸드오프 실측).
	# 티어마다 정지 아트 몸통(78 / 119 / 115)과 시트 몸통(129 / 158 / 176)이 달라 보정값도 티어별이다.
	# BODY_SCALE 변경 이력: 3.076/1.956/2.018 (구 실루엣 기준) -> 2.222/1.441/1.553 (몸통 정규화)
	# -> 1.757/1.757/1.866 (2026-08-07 사용자 지정 "눈 크기" 기준, body-size-audit.md §8.1)
	# -> 1.757/0.9598/1.1109 (2026-08-07 §12: evolved 계열 아트가 256px로 복원돼 BODY_SCALE이
	#    ~1/2로 내려가고, 그 위에 크기 사다리 x1.0926/x1.1852가 곱해졌다).
	# sheet_scale은 "같은 티어의 정지 아트 / 시트" 비율인데 정지 아트만 2배가 됐으므로
	# 0.605/0.753/0.653 -> 0.605/1.5060/1.3001 로 같이 올라갔다(시트 자산은 128px 그대로).
	# 그래서 실효 배율은 base 불변, evolved/evolved2만 사다리 배율만큼 커진다.
	var expected_effective := {"base": 1.063, "evolved": 1.4455, "evolved2": 1.4442}
	var sheet_scale_by_tier: Dictionary = entry.get("sheet_scale", {})
	for tier in expected_effective:
		var effective: float = Characters.BODY_SCALE["mochi"][tier] * float(sheet_scale_by_tier.get(tier, 1.0))
		check(approx(effective, expected_effective[tier], 0.005),
			"모찌 %s 실효 몸통 배율 %.4f == %.3f (BODY_SCALE x sheet_scale)" % [tier, effective, expected_effective[tier]])
	# 티어별 몸통 중심 흔들림 허용 범위 (핸드오프 실측: base -4.0~+5.0, evolved -3.0~+6.0, evolved2 -4.0~+6.0)
	var offset_bounds := {"base": 5.0, "evolved": 6.0, "evolved2": 6.0}
	var tier_dirs := {"base": "mochi", "evolved": "mochi_evolved", "evolved2": "mochi_evolved2"}

	for state in MOCHI_EXPECTED_STATES:
		var expected: Dictionary = MOCHI_EXPECTED_STATES[state]
		var by_tier: Dictionary = states.get(state, {})
		check(not by_tier.is_empty(), "모찌 %s 등록됨" % state)
		check(not by_tier.has("path"), "모찌 %s 는 티어맵 구조 (티어별 분기)" % state)
		for tier in ["base", "evolved", "evolved2"]:
			var label: String = "모찌 %s %s" % [tier, state]
			var config: Dictionary = by_tier.get(tier, {})
			check(not config.is_empty(), "%s 등록됨" % label)
			if config.is_empty():
				continue
			var frames: int = int(config.get("frames", 0))
			var columns: int = int(config.get("columns", 0))
			var rows: int = int(config.get("rows", 0))
			check(frames == expected["frames"], "%s 프레임 수 %d == %d" % [label, frames, expected["frames"]])
			check(columns == expected["columns"] and rows == expected["rows"],
				"%s 격자 %dx%d == %dx%d" % [label, columns, rows, expected["columns"], expected["rows"]])
			check(columns * rows == frames, "%s 격자 칸 수(%d) == frames(%d)" % [label, columns * rows, frames])
			check(bool(config.get("loop", false)) == expected["loop"], "%s loop == %s" % [label, expected["loop"]])
			check(float(config.get("fps", 0.0)) > 0.0, "%s fps > 0" % label)
			var path: String = String(config.get("path", ""))
			check(path.begins_with("res://assets/sprites/%s/" % tier_dirs[tier]),
				"%s 경로가 티어 폴더(%s)를 가리킴: %s" % [label, tier_dirs[tier], path])
			check(ResourceLoader.exists(path), "%s 시트 존재: %s" % [label, path])
			var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
			check(texture != null, "%s 시트 로드" % label)
			if texture != null:
				var size: Vector2 = texture.get_size()
				check(int(size.x) == 192 * columns and int(size.y) == 208 * rows,
					"%s 시트 크기 %dx%d == 격자 x 192x208" % [label, int(size.x), int(size.y)])
			for key in ["foot_padding", "horizontal_offsets"]:
				var arr: Array = config.get(key, [])
				check(arr.size() == frames, "%s %s 길이(%d) == frames(%d)" % [label, key, arr.size(), frames])
			# 발바닥 기준선은 두 티어 44프레임 전부 셀 하단 16px — 프레임 간 상하 튐이 없어야 한다.
			var padding_uniform := true
			for value in config.get("foot_padding", []):
				if not approx(float(value), 16.0):
					padding_uniform = false
			check(padding_uniform, "%s foot_padding 전 프레임 16.0" % label)
			var offsets_bounded := true
			for value in config.get("horizontal_offsets", []):
				if absf(float(value)) > float(offset_bounds[tier]):
					offsets_bounded = false
			check(offsets_bounded, "%s horizontal_offsets 절댓값 <= %.1f" % [label, offset_bounds[tier]])
			# 공중 3상태는 airborne 선언이 있어야 한다 (모찌는 padding 고정이라 화면 결과는 동일하지만,
			# 시트를 다시 뽑아 진폭이 생기는 순간 이 선언이 없으면 그대로 상쇄된다).
			var want_airborne: bool = state in ["Play", "Dragged", "Fall"]
			check(bool(config.get("airborne", false)) == want_airborne,
				"%s airborne == %s" % [label, want_airborne])
			# Sick 시트에 어지럼 표시가 없으므로 런타임 @_@ 라벨을 반드시 켜야 한다.
			# (2026-08-06 회귀: 이 키가 빠져 모찌 Sick이 Sulk와 화면상 구분되지 않았다.)
			check(bool(config.get("runtime_sick_mark", false)) == (state == "Sick"),
				"%s runtime_sick_mark == %s" % [label, state == "Sick"])

	# 이번 스코프에서 미제작인 상태는 등록되지 않아야 한다 (정지 포즈 폴백 유지).
	# 모찌는 bichon과 동일한 14상태를 갖췄다 — state_machine에 없는 키가 섞이면 안 된다.
	for illegal in ["Happy", "Jump", "Perch", "Egg"]:
		check(not states.has(illegal), "모찌 %s 미등록 (Happy는 Play 키로 들어간다)" % illegal)


func _test_bichon_evolution() -> void:
	var pet := make_pet("bichon")
	for i in 14:
		pet.note_file_dropped()
	check(not pet.evolved, "비숑 진화 미충족 (파일 14개)")
	pet.note_file_dropped()
	check(pet.evolved, "비숑 진화: 파일 15개 정리")
	for i in 45:
		pet.note_file_dropped()
	check(pet.evolved_2, "비숑 최종 진화: 파일 60개 누적 - 별솔")


func _test_bichon_care_reactions() -> void:
	var pet_state := make_pet("bichon")
	var pet: Node2D = PetScene.instantiate()
	pet.screen_size = Vector2(1280.0, 720.0)
	pet.ground_y = 714.0
	root.add_child(pet)
	await process_frame
	pet.ps = pet_state
	pet.refresh_appearance()
	# 벽시계 의존 제거: 케어 반응 후 복귀 애니메이션은 "그 시점의 상태"라서, 실행 시각이
	# 야간(기본 22~7시)에 걸리면 대기 중 _check_global()이 Sleep으로 넘겨 "Idle 복귀"가 깨진다.
	# night_start == night_end면 is_night()가 항상 false이므로 must_sleep()을 확실히 끈다.
	var save_manager: Node = root.get_node("SaveManager")
	_saved_night_window = [save_manager.settings["night_start"], save_manager.settings["night_end"]]
	save_manager.settings["night_start"] = 0
	save_manager.settings["night_end"] = 0
	check(not pet.machine.must_sleep(), "케어 반응 테스트 전제: 강제 수면 조건 해제됨")
	check(pet._is_animated_pet(), "비숑이 애니메이션 펫 경로를 사용")
	check(pet._animation_catalog() == PetScript.BICHON_ANIMATIONS, "비숑 전용 애니메이션 카탈로그 선택")
	for care_reaction in ["Pet", "Play"]:
		pet._on_care_performed(care_reaction.to_lower())
		check(pet._bichon_override == care_reaction and pet._bichon_animation == care_reaction and pet._sprite.texture != null, "비숑 %s 케어 반응 경로와 에셋 로드" % care_reaction)
		await create_timer(0.81).timeout
		check(pet._bichon_override.is_empty() and pet._bichon_animation == "Idle", "비숑 %s 후 Idle 복귀" % care_reaction)
	# 좌표 밀림 회귀: celebrate/play_frolic이 tween으로 SPRITE_SIZE 기준 좌표를 직접 옮기면
	# 애니메이션 상태 복귀 후에도 프레임별 발 위치(foot_padding)가 깨진 채 남는다.
	# 비숑은 상태마다 별도 시트(크기 다름)를 쓰므로, Idle로 복귀했을 때의 앵커만 비교한다.
	var idle_anchor_y: float = pet._sprite.position.y
	pet.celebrate()
	check(pet._bichon_override == "Play", "비숑 celebrate가 Play 시트 재생 경로 사용")
	await create_timer(0.81).timeout
	check(pet._bichon_override.is_empty() and approx(pet._sprite.position.y, idle_anchor_y), "비숑 celebrate 후 Idle 프레임 앵커로 복귀")
	pet.play_frolic()
	check(pet._bichon_override == "Play", "비숑 play_frolic이 Play 시트 재생 경로 사용")
	await create_timer(0.81).timeout
	check(approx(pet._sprite.position.y, idle_anchor_y), "비숑 play_frolic 후 Idle 프레임 앵커로 복귀")
	pet._sprite.position.y = idle_anchor_y - 40.0
	pet.reset_sprite_pose()
	check(approx(pet._sprite.position.y, idle_anchor_y), "비숑 reset_sprite_pose가 프레임 앵커로 복귀")
	pet.queue_free()
	pet_state.free()
	call_deferred("_test_mochi_pose_runtime")


# 모찌 10상태를 실제 씬에서 재생해 시트가 걸리는지·프레임 앵커가 흔들리지 않는지 확인.
# 매니페스트 검사(_test_mochi_pose_manifest)가 데이터만 보는 것과 달리 런타임 경로를 통과시킨다.
func _test_mochi_pose_runtime() -> void:
	var pet_state := make_pet("mochi")
	var pet: Node2D = PetScene.instantiate()
	pet.screen_size = Vector2(1280.0, 720.0)
	pet.ground_y = 714.0
	root.add_child(pet)
	await process_frame
	pet.ps = pet_state
	pet.refresh_appearance()
	check(not pet._is_animated_pet(), "모찌는 비숑 카탈로그 경로를 쓰지 않음 (포즈 오버라이드 경로)")

	for state in MOCHI_EXPECTED_STATES:
		var expected: Dictionary = MOCHI_EXPECTED_STATES[state]
		pet.play_state_animation(state)
		check(pet._pose_override_active and pet._pose_override_state == state,
			"모찌 %s 시트 오버라이드 활성" % state)
		check(pet._sprite.texture != null
			and pet._sprite.hframes == expected["columns"] and pet._sprite.vframes == expected["rows"],
			"모찌 %s 텍스처 로드 + 격자 %dx%d 적용" % [state, expected["columns"], expected["rows"]])
		# 발바닥 기준선: foot_padding이 전 프레임 16.0이므로 프레임을 넘겨도 y 앵커가 고정이어야 한다.
		var anchor_y: float = pet._sprite.position.y
		var y_stable := true
		var x_bounded := true
		for frame_index in int(expected["frames"]):
			pet._set_bichon_frame(frame_index)
			if not approx(pet._sprite.position.y, anchor_y):
				y_stable = false
			# 몸통 중심 흔들림은 horizontal_offsets(<=5px) x 배율만큼만 허용
			if absf(pet._sprite.position.x) > 5.0 * pet._base_scale.x + 0.01:
				x_bounded = false
		check(y_stable, "모찌 %s 전 프레임 발바닥 앵커 고정" % state)
		check(x_bounded, "모찌 %s 전 프레임 몸통 중심 흔들림 한계 내" % state)

	# Walk 좌우 반전: 모찌 시트는 정면 대칭이라 walk_face_inverted가 없어야 하고,
	# flip_h가 걸리면 horizontal_offsets도 같이 부호가 뒤집혀 몸통 중심 보정이 유지되어야 한다.
	check(not Characters.is_walk_face_inverted("mochi"),
		"모찌 walk_face_inverted 없음 (정면 대칭 시트 — 반전 보정 불필요)")
	pet.play_state_animation("Walk")
	pet._sprite.flip_h = false
	pet._set_bichon_frame(6)   # horizontal_offsets[6] == -2.0 (0이 아닌 프레임)
	var unflipped_x: float = pet._sprite.position.x
	pet._sprite.flip_h = true
	pet._set_bichon_frame(6)
	check(approx(pet._sprite.position.x, -unflipped_x),
		"모찌 Walk flip_h 시 horizontal_offsets 부호 반전 (%.3f → %.3f)" % [unflipped_x, pet._sprite.position.x])
	pet._sprite.flip_h = false

	# 미등록 상태로 전환하면 정지 포즈로 폴백하고 격자를 1x1로 되돌려야 한다
	# (되돌리지 않으면 128px 정지 이미지가 4칸으로 잘려 몸통 1/4만 보인다).
	# Jump/Perch는 상태머신에는 있지만 어느 종족도 시트를 등록하지 않은 상태다 —
	# 모찌가 14상태를 전부 갖춘 뒤에도 폴백 경로를 검증할 수 있는 실제 사례.
	pet.play_state_animation("Jump")
	check(not pet._pose_override_active, "모찌 미등록 상태(Jump) → 포즈 오버라이드 해제")
	check(pet._sprite.hframes == 1 and pet._sprite.vframes == 1, "모찌 폴백 시 격자 1x1 복원")

	# 실효 몸통 배율이 정지 경로와 같은 화면 높이를 내는지 (sheet_scale 적용 확인)
	pet.play_state_animation("Idle")
	var stage_scale: float = float(PetScript.STAGE_SCALE[pet_state.stage])
	# 1.063 = BODY_SCALE 1.757(사용자 지정 눈 크기 기준) x sheet_scale 0.605.
	# 이력: 1.860(구 실루엣 기준) -> 1.344(몸통 정규화) -> 1.063.
	# base 티어는 §12 256px 복원 대상이 아니므로 이 값은 그대로다.
	check(approx(pet._base_scale.y, stage_scale * 1.063, 0.01),
		"모찌 Idle 실효 배율 %.4f == STAGE_SCALE x 1.063" % pet._base_scale.y)

	# Sick 옵션 조회 경로 (sick_state.gd가 @_@ 라벨 여부를 이 값으로 결정한다).
	pet.play_state_animation("Sick")
	check(bool(pet.animated_pose_option("Sick", "runtime_sick_mark", false)),
		"모찌 animated_pose_option(Sick, runtime_sick_mark) == true")
	# 실제 sick_state.gd를 태워 화면에 아픔 신호가 남는지 확인 — 옵션 조회만으로는
	# "Sick이 Sulk와 구분되지 않는다"는 회귀를 못 잡는다.
	var sick_state: Node = load("res://scripts/states/sick_state.gd").new()
	sick_state.pet = pet
	sick_state.enter()
	check(pet._sick_mark.visible, "모찌 Sick 진입 시 @_@ 라벨 표시 (Sulk와 구분됨)")
	sick_state.exit()
	check(not pet._sick_mark.visible, "모찌 Sick 이탈 시 @_@ 라벨 해제")
	sick_state.free()
	check(not bool(pet.animated_pose_option("Sulk", "runtime_sick_mark", false)),
		"모찌 Sulk에는 runtime_sick_mark 없음 (기본값 반환)")
	# 모찌 공중 3상태는 padding이 고정이라 airborne을 켜도 화면 결과가 기존과 동일해야 한다.
	for state in ["Play", "Dragged", "Fall", "Land"]:
		pet.play_state_animation(state)
		var unchanged := true
		for frame_index in pet._pose_override_frame_count:
			pet._set_bichon_frame(frame_index)
			if not approx(pet.current_frame_foot_offset(), 0.0):
				unchanged = false
		check(unchanged, "모찌 %s 발 위치 회귀 없음 (padding 고정 → airborne 무영향)" % state)

	# 회귀 1: refresh_appearance()가 재생 중이던 시트를 다시 걸어야 한다.
	# 성장(stage_changed)·위장 해제·관리자 콘솔이 이 함수를 부르는데, 시트를 잃으면
	# transition_to()가 같은 상태로는 조기 반환하므로 다른 상태가 될 때까지 정지 포즈가 남는다.
	pet.play_state_animation("Idle")
	var sheet_texture: String = pet._sprite.texture.resource_path
	var sheet_scale_y: float = pet._base_scale.y
	pet.refresh_appearance()
	check(pet._pose_override_active and pet._pose_override_state == "Idle",
		"모찌 refresh_appearance() 후 시트 오버라이드 유지")
	check(pet._sprite.hframes == 4 and pet._sprite.vframes == 1,
		"모찌 refresh_appearance() 후 격자 4x1 유지 (정지 포즈로 안 떨어짐)")
	check(pet._sprite.texture != null and pet._sprite.texture.resource_path == sheet_texture,
		"모찌 refresh_appearance() 후 같은 시트 텍스처 유지")
	check(approx(pet._base_scale.y, sheet_scale_y),
		"모찌 refresh_appearance() 후 시트 배율 유지 (정지 배율로 안 튐)")
	# 재생 중이 아니었으면 되살리지 않아야 한다 — 삐약이 구석으로 걸어가는 Sleep 전반처럼
	# 아직 시트를 걸지 않은 구간에서 시트가 조기 재생되면 안 된다.
	pet.play_state_animation("Jump")   # 미등록 → 정지 포즈
	pet.refresh_appearance()
	check(not pet._pose_override_active,
		"모찌 재생 중이 아닐 때 refresh_appearance()가 시트를 되살리지 않음")

	# 회귀 2: 호흡 트윈이 도는 중에 시트가 걸리면 앵커와 실제 배율이 어긋난다.
	# _position_sprite_for_current_frame()은 _base_scale로 앵커를 잡는데 _sprite.scale은
	# 트윈된 값이라, 트윈을 죽이지 않으면 발바닥이 최대 3px 아래로 밀린다.
	pet.idle_breathe()   # 정지 포즈 상태라 트윈이 실제로 생성된다
	check(pet._idle_tween != null, "모찌 정지 포즈에서 호흡 트윈 생성됨 (전제 조건)")
	pet.play_state_animation("Idle")
	check(pet._idle_tween == null, "모찌 시트 적용 시 호흡 트윈 종료")
	check(pet._sprite.scale.is_equal_approx(pet._base_scale),
		"모찌 시트 적용 직후 _sprite.scale == _base_scale (앵커 기준과 일치)")
	await process_frame
	check(pet._sprite.scale.is_equal_approx(pet._base_scale),
		"모찌 다음 프레임에도 배율 유지 (트윈이 되살아나지 않음)")
	check(approx(pet.current_frame_foot_offset(), 0.0),
		"모찌 시트 적용 후 발이 지면에 정확히 접지")

	# 케어 반응 테스트가 빌려 쓴 야간 설정을 되돌린다 (SaveManager는 오토로드 = 전역 상태).
	if not _saved_night_window.is_empty():
		var save_manager: Node = root.get_node("SaveManager")
		save_manager.settings["night_start"] = _saved_night_window[0]
		save_manager.settings["night_end"] = _saved_night_window[1]

	# ps를 먼저 해제하면 남은 프레임의 state_machine._check_global()이 해제된 인스턴스를 참조한다.
	root.remove_child(pet)
	pet.free()
	pet_state.free()
	call_deferred("_test_mochi_tier_runtime")


# 모찌 10상태 x 티어(base/evolved/evolved2)를 실제 씬에서 재생.
# 매니페스트 검사는 딕셔너리만 보므로 "진화 후 실제로 프로찌 시트가 걸리는가"를 잡지 못한다 —
# 티어 전환(_body_tier)을 태워 base 시트로 새지 않는지, evolved2는 정지 포즈로 폴백하는지 확인한다.
func _test_mochi_tier_runtime() -> void:
	var pet_state := make_pet("mochi")
	var pet: Node2D = PetScene.instantiate()
	pet.screen_size = Vector2(1280.0, 720.0)
	pet.ground_y = 714.0
	root.add_child(pet)
	await process_frame
	pet.ps = pet_state

	# 티어별 기대값: 시트 디렉토리, 실효 배율(BODY_SCALE x sheet_scale), 몸통 중심 흔들림 상한
	var tier_expect := {
		"base": {"dir": "mochi", "effective": 1.063, "offset_bound": 5.0},
		# 2026-08-07 §12 + 크기 사다리: 1.323 -> 1.4455 (x1.0926), 1.219 -> 1.4442 (x1.1852).
		"evolved": {"dir": "mochi_evolved", "effective": 1.4455, "offset_bound": 6.0},
		"evolved2": {"dir": "mochi_evolved2", "effective": 1.4442, "offset_bound": 6.0},
	}
	for tier in ["base", "evolved", "evolved2"]:
		var expect: Dictionary = tier_expect[tier]
		pet_state.evolved = tier != "base"
		pet_state.evolved_2 = tier == "evolved2"
		pet.refresh_appearance()
		check(pet._body_tier == tier, "모찌 티어 전환 %s → _body_tier == %s" % [tier, pet._body_tier])
		var stage_scale: float = float(PetScript.STAGE_SCALE[pet_state.stage])
		for state in MOCHI_EXPECTED_STATES:
			var frames: int = int(MOCHI_EXPECTED_STATES[state]["frames"])
			pet.play_state_animation(state)
			check(pet._pose_override_active and pet._pose_override_state == state,
				"모찌[%s] %s 시트 오버라이드 활성" % [tier, state])
			# 티어 누수 검사: evolved인데 base 시트(assets/sprites/mochi/)를 물면 화면상 진화가 안 보인다.
			var path: String = pet._sprite.texture.resource_path if pet._sprite.texture != null else ""
			check(path.begins_with("res://assets/sprites/%s/" % expect["dir"]),
				"모찌[%s] %s 시트 경로가 %s/ (티어 누수 없음): %s" % [tier, state, expect["dir"], path.get_file()])
			check(approx(pet._base_scale.y, stage_scale * float(expect["effective"]), 0.01),
				"모찌[%s] %s 실효 배율 %.4f == STAGE_SCALE x %.3f" % [tier, state, pet._base_scale.y, expect["effective"]])
			var anchor_y: float = pet._sprite.position.y
			var y_stable := true
			var x_bounded := true
			var grounded := true
			for frame_index in frames:
				pet._set_bichon_frame(frame_index)
				if not approx(pet._sprite.position.y, anchor_y):
					y_stable = false
				if absf(pet._sprite.position.x) > float(expect["offset_bound"]) * pet._base_scale.x + 0.01:
					x_bounded = false
				if not approx(pet.current_frame_foot_offset(), 0.0):
					grounded = false
			check(y_stable, "모찌[%s] %s 전 프레임 발바닥 앵커 고정" % [tier, state])
			check(x_bounded, "모찌[%s] %s 몸통 중심 흔들림 <= %.1fpx" % [tier, state, expect["offset_bound"]])
			check(grounded, "모찌[%s] %s 전 프레임 발이 지면 고정" % [tier, state])

	# 시트가 없는 상태(공중 이동 Jump/Perch)는 3티어 모두 정지 포즈로 폴백해야 한다.
	# 폴백 시 격자를 1x1로 되돌리지 않으면 128px 정지 이미지가 4칸으로 잘려 몸통 1/4만 보인다.
	for tier in ["base", "evolved", "evolved2"]:
		pet_state.evolved = tier != "base"
		pet_state.evolved_2 = tier == "evolved2"
		pet.refresh_appearance()
		check(pet._body_tier == tier, "모찌 티어 전환 %s → _body_tier == %s" % [tier, pet._body_tier])
		for state in ["Jump", "Perch"]:
			pet.play_state_animation(state)
			check(not pet._pose_override_active,
				"모찌[%s] %s 시트 미등록 → 정지 포즈 폴백" % [tier, state])
			check(pet._sprite.hframes == 1 and pet._sprite.vframes == 1,
				"모찌[%s] %s 폴백 시 격자 1x1" % [tier, state])
	# 정지 폴백 아트가 실제로 있어야 한다 (없으면 몸통이 base 아트로 되돌아가 진화가 사라진다).
	for pose in ["idle", "walk1", "sleep", "happy", "sulk", "sick", "eat"]:
		check(FileAccess.file_exists("res://assets/sprites/chars/mochi_evolved2/%s.png" % pose),
			"모찌 evolved2 정지 포즈 %s.png 존재 (폴백 아트)" % pose)

	root.remove_child(pet)
	pet.free()
	pet_state.free()
	call_deferred("_test_ppiyak_pose_runtime")


# 삐약 10상태 x 3티어를 실제 씬에서 재생. 모찌와 달리 진화 티어마다 시트가 따로 있으므로
# tier 전환(_body_tier)까지 통과시켜, evolved/evolved2가 base 시트로 새지 않는지 확인한다.
func _test_ppiyak_pose_runtime() -> void:
	var pet_state := make_pet("ppiyak")
	var pet: Node2D = PetScene.instantiate()
	pet.screen_size = Vector2(1280.0, 720.0)
	pet.ground_y = 714.0
	root.add_child(pet)
	await process_frame
	pet.ps = pet_state
	check(not pet._is_animated_pet(), "삐약은 비숑 카탈로그 경로를 쓰지 않음 (포즈 오버라이드 경로)")

	for tier in PPIYAK_TIERS:
		pet_state.evolved = tier != "base"
		pet_state.evolved_2 = tier == "evolved2"
		pet.refresh_appearance()
		check(pet._body_tier == tier, "삐약 티어 전환 %s → _body_tier == %s" % [tier, pet._body_tier])
		for state in PPIYAK_EXPECTED_STATES:
			var expected: Dictionary = PPIYAK_EXPECTED_STATES[state]
			pet.play_state_animation(state)
			check(pet._pose_override_active and pet._pose_override_state == state,
				"삐약 %s/%s 시트 오버라이드 활성" % [state, tier])
			check(pet._sprite.texture != null
				and pet._sprite.hframes == expected["columns"] and pet._sprite.vframes == expected["rows"],
				"삐약 %s/%s 텍스처 로드 + 격자 %dx%d" % [state, tier, expected["columns"], expected["rows"]])
			# 해당 티어의 시트가 실제로 걸렸는지 (티어 폴백 누수 회귀 방지)
			check(String(pet._sprite.texture.resource_path).contains("/%s/" % PPIYAK_SHEET_DIR[tier]),
				"삐약 %s/%s 티어 전용 시트 로드 (%s)" % [state, tier, pet._sprite.texture.resource_path])
			check(pet._pose_override_loop == expected["loop"], "삐약 %s/%s 런타임 loop == %s" % [state, tier, expected["loop"]])
			check(pet._pose_override_frame_count == int(expected["frames"]),
				"삐약 %s/%s 런타임 프레임 수 %d" % [state, tier, pet._pose_override_frame_count])
			var anchor_y: float = pet._sprite.position.y
			var y_stable := true
			var x_bounded := true
			# 화면상 실제 발 위치(0 = 지면). 접지 상태는 전 프레임 0이어야 하고,
			# 공중 상태는 접지 프레임만 0이고 나머지는 음수(떠 있음)여야 한다.
			var foot_min := 0.0
			var foot_max := 0.0
			for frame_index in int(expected["frames"]):
				pet._set_bichon_frame(frame_index)
				if expected["grounded"] and not approx(pet._sprite.position.y, anchor_y):
					y_stable = false
				if absf(pet._sprite.position.x) > 7.0 * pet._base_scale.x + 0.01:
					x_bounded = false
				var foot: float = pet.current_frame_foot_offset()
				if frame_index == 0:
					foot_min = foot
					foot_max = foot
				foot_min = minf(foot_min, foot)
				foot_max = maxf(foot_max, foot)
			check(y_stable, "삐약 %s/%s 전 프레임 발바닥 앵커 고정" % [state, tier])
			check(x_bounded, "삐약 %s/%s 전 프레임 몸통 중심 흔들림 한계 내" % [state, tier])
			# 접지 프레임(공중 상태의 최저점 포함)은 발이 정확히 지면에 닿아야 한다.
			check(approx(foot_max, 0.0), "삐약 %s/%s 최저 프레임 발 == 지면(y=0)" % [state, tier])
			if expected["grounded"]:
				check(approx(foot_min, 0.0), "삐약 %s/%s 전 프레임 발 == 지면(y=0)" % [state, tier])
			else:
				# 공중 상태는 화면상 발이 실제로 떠올라야 한다 (진폭 0이면 점프가 안 보인다).
				check(foot_min < -1.0,
					"삐약 %s/%s 공중 진폭 %.2fpx (화면상 발이 실제로 뜸)" % [state, tier, -foot_min])

	# 공중 상태는 프레임을 넘기면 화면상 캐릭터 최하단(= 발)이 실제로 움직여야 한다.
	# 예전 버전은 _sprite.position.y가 변하는지만 봤는데, 그 값은 발을 매 프레임 지면에
	# 재고정하느라 움직인 것이라 화면 결과(최하단 고정, span 0px)와 정반대였다.
	# 이제는 스프라이트 프레임 안의 실제 발 위치까지 반영한 world y로 검사한다.
	pet_state.evolved = false
	pet_state.evolved_2 = false
	pet.refresh_appearance()
	for state in ["Play", "Dragged", "Fall"]:
		pet.play_state_animation(state)
		var lowest := 0.0
		var highest := 0.0
		for frame_index in pet._pose_override_frame_count:
			pet._set_bichon_frame(frame_index)
			var foot: float = pet.current_frame_foot_offset()
			if frame_index == 0:
				lowest = foot
				highest = foot
			lowest = maxf(lowest, foot)    # y가 클수록 아래 = 접지에 가까움
			highest = minf(highest, foot)
		check(lowest - highest > 1.0,
			"삐약 %s 화면상 발 높이 span %.2fpx > 0 (점프/부유가 실제로 보임)" % [state, lowest - highest])
		check(approx(lowest, 0.0), "삐약 %s 최저 프레임은 지면에 닿음 (y=0)" % state)
	# 접지 상태는 대조군: 프레임을 다 넘겨도 화면상 발이 지면에서 떨어지지 않는다.
	for state in ["Idle", "Walk", "Eat", "Sick", "Sulk", "Sleep", "Land"]:
		pet.play_state_animation(state)
		var grounded_all := true
		for frame_index in pet._pose_override_frame_count:
			pet._set_bichon_frame(frame_index)
			if not approx(pet.current_frame_foot_offset(), 0.0):
				grounded_all = false
		check(grounded_all, "삐약 %s 접지 상태는 전 프레임 발이 지면 고정" % state)

	# Walk 좌우 반전: 시트 기본이 왼쪽이므로 오른쪽 이동 시 flip_h + offsets 부호 반전.
	pet.play_state_animation("Walk")
	pet._sprite.flip_h = false
	pet._set_bichon_frame(3)   # horizontal_offsets[3] == 2.0 (0이 아닌 프레임)
	var unflipped_x: float = pet._sprite.position.x
	pet._sprite.flip_h = true
	pet._set_bichon_frame(3)
	check(approx(pet._sprite.position.x, -unflipped_x),
		"삐약 Walk flip_h 시 horizontal_offsets 부호 반전 (%.3f → %.3f)" % [unflipped_x, pet._sprite.position.x])
	pet._sprite.flip_h = false

	# 미등록 상태(Poop)는 정지 포즈로 폴백하고 격자를 1x1로 되돌려야 한다.
	pet.play_state_animation("Poop")
	check(not pet._pose_override_active, "삐약 미등록 상태(Poop) → 포즈 오버라이드 해제")
	check(pet._sprite.hframes == 1 and pet._sprite.vframes == 1, "삐약 폴백 시 격자 1x1 복원")

	# Sick 옵션 조회 경로 (sick_state.gd가 @_@ 라벨 여부를 이 값으로 결정한다).
	check(bool(pet.animated_pose_option("Sick", "runtime_sick_mark", false)),
		"삐약 animated_pose_option(Sick, runtime_sick_mark) == true")
	var ppiyak_sick: Node = load("res://scripts/states/sick_state.gd").new()
	ppiyak_sick.pet = pet
	ppiyak_sick.enter()
	check(pet._sick_mark.visible, "삐약 Sick 진입 시 @_@ 라벨 표시")
	ppiyak_sick.exit()
	check(not pet._sick_mark.visible, "삐약 Sick 이탈 시 @_@ 라벨 해제")
	ppiyak_sick.free()
	check(not bool(pet.animated_pose_option("Idle", "runtime_sick_mark", false)),
		"삐약 Idle에는 runtime_sick_mark 없음 (기본값 반환)")

	root.remove_child(pet)
	pet.free()
	pet_state.free()
	call_deferred("_test_size_rules")


# ============================================================================
# 크기 규칙 (2026-08-07 개정): 크기 축이 **둘**이다.
#   A) 성장(stage): egg < baby < child < adult — 여전히 단조증가여야 한다.
#   B) 진화(tier): 같은 성장단계에서 base < evolved < evolved2 로 커진다.
#      예전 규칙("진화는 모양만 바뀐다 = 크기 불변")은 사용자가 명시적으로 철회했다.
#      Characters.TIER_SIZE_LADDER = 1.0 / 1.0926 / 1.1852 (화면 몸통 108 / 118 / 128px).
#
# ⚠️ 두 축의 **전역 9단계 순서는 검사하지 않는다**(예: "evolved 아기 > base 성체").
# 성장 폭(baby→adult 0.32→0.45 = 1.406배)이 진화 폭(1.0926배)보다 크므로 수학적으로 양립
# 불가능하고, 사용자가 "순서 규칙은 느슨하게"로 결정했다. 같은 성장단계 안에서만 진화
# 순서를 보장한다. 이 항목을 "빠진 검사"로 오해해 추가하지 마라 — 반드시 실패한다.
#
# 이 테스트가 잠그는 과거 회귀:
#   1) egg가 BODY_SCALE(성체 아트 정규화용)을 잘못 곱해 종족마다 3.1배까지 벌어지고 adult보다 컸다.
#   2) baby와 child의 STAGE_SCALE이 같아(0.378) 4단계 중 실질 3단계뿐이었다.
#   3) 삐약 애니메이션 시트에 sheet_scale이 없어 진화 시 몸통이 12.7% 커졌다.
#   4) 진화 티어 아트가 확대 렌더(BODY_SCALE x STAGE_SCALE > 1.0)라 뿌옇게 나왔다 (§12).
# 화면상 몸통 높이 = (현재 프레임 알파 바운딩박스 높이) x _base_scale.y 로 실측한다.
# ============================================================================

## 현재 걸린 텍스처의 "현재 프레임" 알파 바운딩박스 높이 x 배율 = 화면상 몸통 높이(px).
## 화면에 보이는 실루엣으로 치는 알파 하한. 이보다 옅은 픽셀은 몸통 크기에 포함하지 않는다.
const VISIBLE_ALPHA := 0.125


## visible_only=true면 α>VISIBLE_ALPHA인 픽셀만 몸통으로 친다. 서로 다른 자산의 크기를 비교할
## 때 필요하다 — 기본 get_used_rect()는 α>0이라 자산마다 두께가 다른 투명 헤일로까지 세기 때문이다.
## 기본값을 바꾸면 헤일로에 기대어 보정값이 잡힌 기존 캐릭터(seureureuk 등)가 함께 흔들린다.
func _rendered_body_height(pet: Node2D, visible_only := false) -> float:
	var tex: Texture2D = pet._sprite.texture
	if tex == null:
		return 0.0
	var img: Image = tex.get_image()
	if img == null:
		return 0.0
	var cols: int = maxi(pet._sprite.hframes, 1)
	var rows: int = maxi(pet._sprite.vframes, 1)
	var cell_w: int = img.get_width() / cols
	var cell_h: int = img.get_height() / rows
	var index: int = pet._sprite.frame
	var cell: Image = img.get_region(Rect2i(
		(index % cols) * cell_w, (index / cols) * cell_h, cell_w, cell_h))
	if not visible_only:
		return float(cell.get_used_rect().size.y) * pet._base_scale.y
	var top := -1
	var bottom := -1
	for y in range(cell.get_height()):
		for x in range(cell.get_width()):
			if cell.get_pixel(x, y).a > VISIBLE_ALPHA:
				if top < 0:
					top = y
				bottom = y
				break
	if top < 0:
		return 0.0
	return float(bottom - top + 1) * pet._base_scale.y


## 정지 포즈(idle) 상태의 화면상 몸통 높이. stage/tier를 세팅하고 다시 그린다.
func _static_body_height(pet: Node2D, pet_state: Node, stage: String, tier := "base", visible_only := false) -> float:
	pet_state.stage = stage
	pet_state.evolved = tier != "base"
	pet_state.evolved_2 = tier == "evolved2"
	pet.refresh_appearance()
	return _rendered_body_height(pet, visible_only)


## 현재 걸린 정지 포즈 텍스처에서 "캐릭터 발"이 지면(y=0)에서 얼마나 떨어져 있는지(px, 화면 기준).
## 0이면 정확히 접지, 양수면 공중에 뜬 것, 음수면 지면 아래로 파고든 것.
## 캔버스 크기가 티어마다 다르므로(base 128 / evolved·evolved2 256) 반드시 실측 텍스처 크기로
## 계산한다 — 상수 128을 곱하면 256px 티어가 화면에서 크게 어긋난다(2026-08-07 §12 회귀 방지).
func _static_foot_gap(pet: Node2D) -> float:
	var tex: Texture2D = pet._sprite.texture
	if tex == null:
		return 999.0
	var img: Image = tex.get_image()
	if img == null:
		return 999.0
	var h: int = img.get_height()
	var bottom := -1
	for y in range(h - 1, -1, -1):
		var found := false
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > VISIBLE_ALPHA:
				found = true
				break
		if found:
			bottom = y
			break
	if bottom < 0:
		return 999.0
	# 스프라이트는 중앙 정렬이라 텍스처 상단이 position.y - h * scale / 2 에 놓인다.
	return -(pet._sprite.position.y + (float(bottom + 1) - float(h) * 0.5) * pet._base_scale.y)


func _test_size_rules() -> void:
	var pet_state := make_pet("mochi")
	var pet: Node2D = PetScene.instantiate()
	pet.screen_size = Vector2(1280.0, 720.0)
	pet.ground_y = 714.0
	root.add_child(pet)
	await process_frame
	pet.ps = pet_state

	# --- 1. 성장 단계 단조증가: egg < baby < child < adult ---
	# 예전에는 baby == child(둘 다 0.378)라 실질 3단계였다.
	for species in ["mochi", "tokki", "ppiyak", "bichon"]:
		pet_state.debug_set_species(species)
		var heights: Array[float] = []
		for stage in ["egg", "baby", "child", "adult"]:
			heights.append(_static_body_height(pet, pet_state, stage))
		var monotonic := true
		for i in range(1, heights.size()):
			if heights[i] <= heights[i - 1]:
				monotonic = false
		check(monotonic, "[%s] 성장 단계 단조증가 egg<baby<child<adult (%.1f/%.1f/%.1f/%.1f)"
			% [species, heights[0], heights[1], heights[2], heights[3]])

	# --- 2. egg는 종족과 무관하게 같은 크기 ---
	# egg 아트(chars/egg/*.png)는 전 종족 공통 단일 이미지이므로 화면 크기도 공통이어야 한다.
	# BODY_SCALE을 곱하던 시절엔 모찌 219px vs 비숑 71px로 3.1배 벌어졌다.
	var egg_heights := {}
	for species in ["mochi", "tokki", "ppiyak", "bichon", "ddungsil", "kong"]:
		pet_state.debug_set_species(species)
		egg_heights[species] = _static_body_height(pet, pet_state, "egg")
	var egg_values: Array = egg_heights.values()
	var egg_min: float = egg_values.min()
	var egg_max: float = egg_values.max()
	check(egg_max - egg_min <= 1.0,
		"egg 크기가 종족과 무관하게 동일 (편차 %.2fpx <= 1px, %s)" % [egg_max - egg_min, egg_heights])
	check(egg_min > 0.0, "egg가 화면에 보이는 크기 (%.1fpx > 0)" % egg_min)

	# --- 3. 몸통(코어) 정규화: 진화 단계 크기 불변 + 12종 크로스-종족 균일 ---
	# 2026-08-07: 정규화 기준이 전체 실루엣 -> 몸통(코어 덩어리)으로 바뀌었다.
	# 예전 테스트는 알파 바운딩박스 높이가 티어끼리 +-5%인지 봤지만, 이제 실루엣은 **의도적으로**
	# 벌어진다(귀·불꽃·촉수 같은 부속물이 몸통에서 빠졌으므로). 대신 코어 몸통 높이 실측값
	# (Characters.BODY_CORE_HEIGHT, body-size-audit.md 36장 전수 실측)에 BODY_SCALE을 곱한 값이
	# 전 종족·전 티어에서 같은 목표(2 x BODY_SCALE_TARGET_TORSO)로 수렴하는지 본다 —
	# "진화는 모양만 바뀐다"(티어 불변)와 "12종 몸집이 서로 비슷하다"(크로스-종족)를 한 번에 잠근다.
	# 2026-08-07 후속: mochi/mundeok/tokki 3종은 사용자가 몸통 높이가 아닌 별도 지표를 직접
	# 지정했다(모찌=눈 크기 중앙값 13.44px, 문덕이=머리끝 높이 중앙값 75.85px, 당근이=발 접지 + 5% 축소).
	# 그래서 이 3종은 공통 목표에서 -32% ~ +22%까지 벗어나며, 그것이 정상이다
	# (근거는 Characters.TORSO_NORMALIZATION_EXEMPT의 reason과 body-size-audit.md §8).
	# 예외 종족은 검사에서 빼지 않는다 — 공통 목표(160) 대신 그 종족의 기대값 +-2%로 검사한다.
	# 2026-08-07: 공통 목표가 티어별로 달라졌다 — 크기 사다리를 곱한다(160 / 174.8 / 189.6).
	var torso_target_base: float = 2.0 * Characters.BODY_SCALE_TARGET_TORSO
	var adult_scale: float = float(PetScript.STAGE_SCALE["adult"])
	# 예외가 슬금슬금 늘어나는 것을 막는 상한. 늘리려면 육안 QA 근거를 남기고 이 수를 올려라.
	check(Characters.TORSO_NORMALIZATION_EXEMPT.size() <= 3,
		"몸통 정규화 예외가 3종 이하 (현재 %d종: %s)"
		% [Characters.TORSO_NORMALIZATION_EXEMPT.size(),
			", ".join(Characters.TORSO_NORMALIZATION_EXEMPT.keys())])
	for exempt_species in Characters.TORSO_NORMALIZATION_EXEMPT.keys():
		var entry: Dictionary = Characters.TORSO_NORMALIZATION_EXEMPT[exempt_species]
		check(Characters.BODY_SCALE.has(exempt_species)
			and not String(entry.get("reason", "")).is_empty()
			and entry.get("expected_torso", {}).size() == 3,
			"[%s] 예외 항목이 사유 + 3티어 기대값을 갖춤" % exempt_species)
	for species in Characters.BODY_SCALE.keys():
		check(Characters.BODY_CORE_HEIGHT.has(species),
			"[%s] 코어 몸통 실측값 등록됨 (BODY_CORE_HEIGHT)" % species)
		pet_state.debug_set_species(species)
		var exempt: bool = Characters.TORSO_NORMALIZATION_EXEMPT.has(species)
		for tier in ["base", "evolved", "evolved2"]:
			var core: float = Characters.get_body_core_height(species, tier)
			var scale: float = Characters.get_body_scale(species, tier)
			# 예외 종족은 자기 기대값으로, 나머지 10종은 공통 목표 160으로 엄격히 검사한다.
			var expected: float = Characters.get_expected_torso(species, tier)
			var torso_target: float = torso_target_base * Characters.get_tier_size_ladder(tier)
			if not exempt:
				check(is_equal_approx(expected, torso_target),
					"[%s/%s] 예외가 아니므로 기대값이 티어 목표 %.1f (160 x 사다리 %.4f)"
					% [species, tier, torso_target, Characters.get_tier_size_ladder(tier)])
			check(core > 0.0 and absf(core * scale - expected) / expected <= 0.02,
				"[%s/%s] 몸통 정규화 코어 %.0f x BODY_SCALE %.3f = %.1f == 기대값 %.1f (+-2%%%s)"
				% [species, tier, core, scale, core * scale, expected,
					", 사용자 지정 기준 예외" if exempt else ""])
			# 실제 렌더 경로(_base_scale)까지 태워서 확인한다 — 위 검사는 테이블만 보므로
			# egg 분기(_static_body_scale)나 티어 해석이 깨져도 잡지 못한다.
			var silhouette: float = _static_body_height(pet, pet_state, "adult", tier)
			var rendered_core: float = core * pet._base_scale.y
			check(absf(rendered_core - expected * adult_scale) / (expected * adult_scale) <= 0.02,
				"[%s/%s] adult 화면상 몸통 %.1fpx == %.1fpx (+-2%%, 실루엣 %.1fpx)"
				% [species, tier, rendered_core, expected * adult_scale, silhouette])
			# 실루엣은 균일하지 않아도 되지만, 몸통 정규화가 폭주하면(예: 코어 오측정) 여기서 걸린다.
			# 상한은 크기 사다리(evolved2 x1.1852)만큼 함께 올렸다: 145 -> 172.
			check(silhouette > 60.0 and silhouette < 172.0,
				"[%s/%s] adult 실루엣 %.1fpx 가 상식 범위(60~172px)" % [species, tier, silhouette])

	# --- 4. 삐약 애니메이션 경로도 진화 단계 크기 불변 ---
	# sheet_scale이 없던 시절 evolved2 Idle이 base/evolved보다 12.7% 컸다.
	# 각 티어의 시트 몸통이 (a) 티어끼리 서로, (b) 자기 티어 정지 포즈와 +-5% 이내여야 한다.
	# 시트와 정지 포즈는 별개 자산이라 투명 헤일로 두께가 다르다 — 양쪽 다 visible_only로 잰다.
	# (ppiyak Idle 시트를 idle_blink_6f로 교체할 때 α>0 측정은 실루엣이 같은데도 -5.8%로 읽혔다.)
	# 2026-08-07: 티어 간 비교는 "시트 실루엣이 서로 같다"에서 "시트가 자기 티어 정지 포즈에
	# 붙어 있는 정도가 티어끼리 같다"로 바꿨다. 정지 포즈 쪽이 이제 몸통 기준으로 정규화되므로
	# (실루엣은 티어마다 다르다) 시트 실루엣의 절대 비교는 더 이상 의미가 없다. 원래 잡으려던
	# 회귀(sheet_scale 누락 -> evolved2만 12.7% 큼)는 아래 비율 비교로 그대로 걸린다.
	pet_state.debug_set_species("ppiyak")
	for state in ["Idle", "Walk", "Eat"]:
		var anim_heights: Array[float] = []
		var anim_ratios: Array[float] = []
		for tier in ["base", "evolved", "evolved2"]:
			var static_h: float = _static_body_height(pet, pet_state, "adult", tier, true)
			pet.play_state_animation(state)
			var anim_h: float = _rendered_body_height(pet, true)
			anim_heights.append(anim_h)
			anim_ratios.append(anim_h / maxf(static_h, 0.001))
			check(static_h > 0.0 and absf(anim_h - static_h) / static_h <= 0.05,
				"[삐약/%s] %s 시트가 자기 티어 정지 포즈와 +-5%% (시트 %.1f vs 정지 %.1f, %.1f%%)"
				% [tier, state, anim_h, static_h, 100.0 * (anim_h - static_h) / maxf(static_h, 0.001)])
			pet.stop_animated_pose()
		var alo: float = anim_ratios.min()
		var ahi: float = anim_ratios.max()
		check(alo > 0.0 and (ahi - alo) / alo <= 0.05,
			"[삐약] %s 시트/정지 비율이 티어끼리 +-5%% (%.3f/%.3f/%.3f, 시트 %.1f/%.1f/%.1f)"
			% [state, anim_ratios[0], anim_ratios[1], anim_ratios[2],
				anim_heights[0], anim_heights[1], anim_heights[2]])

	# --- 5. 진화 크기 사다리: 같은 성장단계에서 base < evolved < evolved2 ---
	# 2026-08-07 사용자 지시로 "진화해도 크기 불변" 규칙을 뒤집었다. 검사를 지운 게 아니라
	# 기대값을 뒤집은 것이다 — 이전 규칙으로 되돌리려면 여기와 Characters.TIER_SIZE_LADDER를
	# 같이 고쳐야 한다. 비교 지표는 실루엣이 아니라 화면상 코어 몸통(부속물 제외)이다.
	# 성장단계 간 비교는 하지 않는다(위 ⚠️ 주석 참고 — 성장 폭 > 진화 폭이라 양립 불가).
	# 예외 3종(mochi/mundeok/tokki)은 코어 몸통이 아니라 사용자가 지정한 다른 지표(눈 크기 /
	# 머리끝 높이 / 발 접지)로 정규화돼 있어, base와 evolved의 **코어 몸통 절대값 비교가
	# 애초에 성립하지 않는다** — 예: mundeok은 머리끝 높이를 맞추느라 evolved의 코어가 base보다
	# 원래 작다(121.2 vs 108.4, 사다리 이전부터). 이 3종은 (a) evolved < evolved2 렌더 검사와
	# (b) 사다리가 기대값에 실제로 곱해졌는지를 데이터로 검사한다.
	var ladder_exempt_before := {
		"mochi": {"evolved": 195.0, "evolved2": 192.3},
		"mundeok": {"evolved": 108.4, "evolved2": 108.4},
		"tokki": {"evolved": 164.1, "evolved2": 157.4},
	}
	for species in Characters.BODY_SCALE.keys():
		pet_state.debug_set_species(species)
		var ladder_exempt: bool = Characters.TORSO_NORMALIZATION_EXEMPT.has(species)
		for stage in ["baby", "child", "adult"]:
			var ladder_heights: Array[float] = []
			for tier in ["base", "evolved", "evolved2"]:
				pet_state.stage = stage
				pet_state.evolved = tier != "base"
				pet_state.evolved_2 = tier == "evolved2"
				pet.refresh_appearance()
				ladder_heights.append(Characters.get_body_core_height(species, tier) * pet._base_scale.y)
			if ladder_exempt:
				check(ladder_heights[1] < ladder_heights[2],
					"[%s/%s] 진화 사다리 evolved < evolved2 (%.1f < %.1f px, base %.1f는 사용자 지정 지표라 제외)"
					% [species, stage, ladder_heights[1], ladder_heights[2], ladder_heights[0]])
			else:
				check(ladder_heights[0] < ladder_heights[1] and ladder_heights[1] < ladder_heights[2],
					"[%s/%s] 진화 사다리 base < evolved < evolved2 (%.1f < %.1f < %.1f px)"
					% [species, stage, ladder_heights[0], ladder_heights[1], ladder_heights[2]])
	for species in ladder_exempt_before.keys():
		for tier in ["evolved", "evolved2"]:
			var before: float = float(ladder_exempt_before[species][tier])
			var after: float = Characters.get_expected_torso(species, tier)
			var want: float = before * Characters.get_tier_size_ladder(tier)
			check(absf(after - want) / want <= 0.005,
				"[%s/%s] 예외 종족 기대값에 사다리 적용됨 %.1f x %.4f = %.1f (등록 %.1f)"
				% [species, tier, before, Characters.get_tier_size_ladder(tier), want, after])

	# --- 6. 확대 렌더 금지 (이번 작업의 핵심 성과를 잠근다) ---
	# 렌더 배율 = BODY_SCALE x STAGE_SCALE. 1.0을 넘으면 원본에 없는 픽셀을 보간으로 만들어
	# 뿌옇게 보인다(§12.1: kong/evolved 1.22x, bulgeumjo/evolved2 1.14x 등이 그랬다).
	# 12종 x 3티어 x 3성장단계 = 108조합 전부 1.0 미만이어야 한다.
	# egg는 BODY_SCALE을 곱하지 않으므로(전 종족 공통 아트) 이 검사 대상이 아니다.
	var worst_zoom := 0.0
	var worst_label := ""
	for species in Characters.BODY_SCALE.keys():
		for tier in ["base", "evolved", "evolved2"]:
			var body_scale: float = Characters.get_body_scale(species, tier)
			for stage in ["baby", "child", "adult"]:
				var zoom: float = body_scale * float(PetScript.STAGE_SCALE[stage])
				if zoom > worst_zoom:
					worst_zoom = zoom
					worst_label = "%s/%s/%s" % [species, tier, stage]
				check(zoom <= 1.0,
					"[%s/%s/%s] 확대 렌더 금지 BODY_SCALE %.4f x STAGE_SCALE %.2f = %.4f <= 1.0"
					% [species, tier, stage, body_scale, PetScript.STAGE_SCALE[stage], zoom])
	check(worst_zoom <= 1.0, "108개 조합 최대 렌더 배율 %.4f (%s) <= 1.0" % [worst_zoom, worst_label])

	# --- 7. 캔버스 크기 혼재 + 발 접지 ---
	# 2026-08-07 §12부터 아트 캔버스가 티어마다 다르다: base/egg 128px, evolved/evolved2 256px.
	# 그래서 위치 계산은 상수(STATIC_POSE_FALLBACK_SIZE)가 아니라 실측 텍스처 크기를 써야 한다.
	# 이 검사가 없으면 256px 티어가 화면에서 위아래로 절반쯤 어긋난 채 조용히 통과한다.
	var expected_canvas := {"base": 128, "evolved": 256, "evolved2": 256}
	for species in Characters.BODY_SCALE.keys():
		pet_state.debug_set_species(species)
		for tier in ["base", "evolved", "evolved2"]:
			pet_state.stage = "adult"
			pet_state.evolved = tier != "base"
			pet_state.evolved_2 = tier == "evolved2"
			pet.refresh_appearance()
			var tex: Texture2D = pet._sprite.texture
			var canvas: int = int(tex.get_size().y) if tex != null else 0
			check(canvas == int(expected_canvas[tier]),
				"[%s/%s] 정지 포즈 캔버스 %dpx == %dpx" % [species, tier, canvas, expected_canvas[tier]])
			# 캔버스 크기와 무관하게 발이 지면(y=0)에 닿아야 한다. 아트 하단 여백은 0px 규약이라
			# 허용 오차는 1px(반올림)로 충분하다.
			# 허용 오차가 티어별로 다르다. evolved/evolved2는 §12.3에서 하단 여백을 0px로 맞춰
			# 재생성했으므로 1px(반올림) 안에 들어와야 한다. base/egg 128px 아트는 §12에서
			# **의도적으로 손대지 않았고**(§12.9) 원래 하단 여백이 조금 남아 있다 — 현재 실측
			# 2.1~2.9px, seureureuk만 8.6px(배경 소품이 그려진 풀신 아트라 bbox가 크게 잡힌다).
			# 그래서 base는 9px로 둔다. 이 값을 넘으면 캔버스-위치 계산이 어긋난 것이다
			# (상수 128을 256px 티어에 곱하던 버그는 화면상 수십 px로 벌어져 여기서 걸린다).
			var gap: float = _static_foot_gap(pet)
			var gap_bound: float = 1.0 if tier != "base" else 9.0
			check(absf(gap) <= gap_bound,
				"[%s/%s] 발이 지면에 접지 (지면과의 거리 %.2fpx <= %.1f, 캔버스 %dpx)"
				% [species, tier, gap, gap_bound, canvas])

	root.remove_child(pet)
	pet.free()
	pet_state.free()
	call_deferred("_test_pose_reaction_triggers")


# 반응 연출(Pet/FileHover/FileConsume)은 상태머신 상태가 아니라 오버라이드라, 등록만 있고
# 트리거가 막혀 있어도 매니페스트 테스트는 전부 통과한다 — 실제로 2026-08-07에 그랬다
# (등록은 끝났는데 비숑 게이트에 막혀 3상태가 화면에 안 나왔다).
# 그래서 이 테스트는 등록이 아니라 **트리거를 실제로 태워서** 시트가 걸리는지만 본다.
func _test_pose_reaction_triggers() -> void:
	var pet_state := make_pet("mochi")
	pet_state.stage = "adult"
	var pet: Node2D = PetScene.instantiate()
	pet.screen_size = Vector2(1280.0, 720.0)
	pet.ground_y = 714.0
	root.add_child(pet)
	await process_frame
	pet.ps = pet_state
	pet.refresh_appearance()
	# 반응 연출의 복귀 대상은 "상태머신 현재 상태"다. 상태머신을 돌린 채로 두면 대기 중에
	# idle_state가 자율적으로 Walk로 넘어가 복귀 대상이 바뀌고, 검사가 시간에 따라 흔들린다.
	# 여기서 보려는 건 자율 전이가 아니라 반응 오버라이드라서 상태머신 처리를 멈춘다.
	pet.machine.set_process(false)

	# 1) 쓰다듬기 — _on_care_performed → _play_care_reaction → Pet 시트
	pet.play_state_animation("Idle")
	pet._on_care_performed("pet")
	check(pet._pose_override_state == "Pet" and _sheet_dir(pet) == "mochi",
		"모찌 care(pet) → Pet 시트 재생 (state=%s)" % pet._pose_override_state)
	await create_timer(0.9).timeout
	check(pet._pose_override_state == "Idle",
		"모찌 Pet 반응 종료 후 Idle 복귀 (state=%s)" % pet._pose_override_state)

	# 2) 파일 호버 — 켜고 끄기
	pet.set_file_hover(true)
	check(pet._pose_override_state == "FileHover",
		"모찌 set_file_hover(true) → FileHover 시트 (state=%s)" % pet._pose_override_state)
	pet.set_file_hover(false)
	check(pet._pose_override_state == "Idle",
		"모찌 set_file_hover(false) → Idle 복귀 (state=%s)" % pet._pose_override_state)

	# 3) 파일 드롭 — Hover(0.34s) → Consume(0.70s) → 복귀
	pet.play_file_drop_reaction()
	check(pet._pose_override_state == "FileHover", "모찌 파일 드롭 1단계 FileHover")
	await create_timer(0.45).timeout
	check(pet._pose_override_state == "FileConsume",
		"모찌 파일 드롭 2단계 FileConsume (state=%s)" % pet._pose_override_state)
	await create_timer(0.85).timeout
	check(pet._pose_override_state == "Idle",
		"모찌 파일 드롭 종료 후 Idle 복귀 (state=%s)" % pet._pose_override_state)

	# 4) 회귀 방지 — 반응 중 상태가 바뀌면 복귀 예약이 취소되어야 한다.
	# 취소되지 않으면 뒤늦은 타이머가 새 상태를 Pet으로 덮어써 "케어 후 상태가 되돌아가는" 버그가 된다.
	pet._on_care_performed("pet")
	check(pet._pose_override_state == "Pet", "모찌 반응 취소 검증: Pet 재생 시작")
	pet.play_state_animation("Sulk")
	await create_timer(0.9).timeout
	check(pet._pose_override_state == "Sulk",
		"모찌 반응 중 상태 전환 시 복귀 예약 취소 (state=%s, Pet으로 안 되돌아감)" % pet._pose_override_state)

	# 5) refresh_appearance()(성장·위장해제·관리자 콘솔)가 반응 연출 중에 끼어든 경우.
	# 반응 연출은 시간 제한이 있는 일회성이라, 시트만 되살리면 끝내줄 주체가 없어 그 포즈에 멈춘다.
	# 그래서 반응 상태만 예외로 두고 상태머신 현재 상태로 복귀시킨다(2026-08-07 결정).
	pet.play_state_animation("Idle")
	pet._on_care_performed("pet")
	check(pet._pose_override_state == "Pet", "모찌 refresh 취소 검증: Pet 재생 시작")
	pet.refresh_appearance()
	check(pet._pose_reaction_state.is_empty(),
		"모찌 반응 중 refresh_appearance() → 복귀 예약 해제 (_pose_reaction_state 비움)")
	check(pet._pose_override_state == "Idle",
		"모찌 반응 중 refresh → 반응 시트를 되살리지 않고 상태머신 현재 상태(Idle) 복귀 (state=%s)"
		% pet._pose_override_state)
	await create_timer(0.9).timeout
	check(pet._pose_override_state == "Idle",
		"모찌 refresh 후 뒤늦은 복귀 없음 (state=%s)" % pet._pose_override_state)

	# 5-b) 경계 고정 — **반응만 예외**다. 일반 상태 연출(Sulk 등)은 기존대로 이어붙여야 한다.
	# 이 단정문이 없으면 "반응 예외" 처리가 일반 상태까지 삼켜도 아무도 못 잡는다.
	pet.play_state_animation("Sulk")
	pet.refresh_appearance()
	check(pet._pose_override_state == "Sulk",
		"모찌 일반 상태 연출(Sulk) 중 refresh → 그대로 이어붙임 (반응만 예외, state=%s)"
		% pet._pose_override_state)

	# 5-c) 실제 도달 경로 — 성장(stage_changed)이 반응 중에 발생하면 시트도 배율도 갱신되어야 한다.
	pet.play_state_animation("Idle")
	pet._on_care_performed("pet")
	check(pet._pose_override_state == "Pet", "모찌 성장 경로 검증: Pet 재생 시작")
	var scale_before: float = pet._base_scale.y
	pet_state.stage = "child"
	pet.refresh_appearance()
	check(pet._pose_override_state == "Idle",
		"모찌 반응 중 성장 → Idle 시트 복귀 (state=%s)" % pet._pose_override_state)
	check(not approx(pet._base_scale.y, scale_before),
		"모찌 반응 중 성장 → 단계 배율 갱신 (%.4f → %.4f)" % [scale_before, pet._base_scale.y])
	pet_state.stage = "adult"
	pet.refresh_appearance()

	root.remove_child(pet)
	pet.free()
	pet_state.free()

	# 6) 반응 시트가 없는 종족은 조용히 무시되어야 한다 (삐약은 Pet/FileHover 미등록).
	# 무시하지 않고 비숑 카탈로그로 새면 삐약이 비숑 시트를 물게 된다.
	var ppiyak_state := make_pet("ppiyak")
	ppiyak_state.stage = "adult"
	var ppiyak: Node2D = PetScene.instantiate()
	ppiyak.screen_size = Vector2(1280.0, 720.0)
	ppiyak.ground_y = 714.0
	root.add_child(ppiyak)
	await process_frame
	ppiyak.ps = ppiyak_state
	ppiyak.refresh_appearance()
	ppiyak.play_state_animation("Idle")
	var before: String = ppiyak._pose_override_state
	ppiyak._on_care_performed("pet")
	check(ppiyak._pose_override_state == before and _sheet_dir(ppiyak) == "ppiyak",
		"삐약 care(pet) 무시 (Pet 시트 미등록, state=%s 유지)" % ppiyak._pose_override_state)
	ppiyak.set_file_hover(true)
	check(ppiyak._pose_override_state == before and _sheet_dir(ppiyak) == "ppiyak",
		"삐약 set_file_hover 무시 (FileHover 시트 미등록, 비숑 시트로 안 샘)")

	root.remove_child(ppiyak)
	ppiyak.free()
	ppiyak_state.free()
	call_deferred("_test_haemjji_pose_runtime")


# 햄찌 14상태를 실제 씬에서 재생. 매니페스트는 딕셔너리만 보므로 "정말 그 시트가 걸리는가"와
# "진화 티어가 정지 포즈로 폴백하는가"는 여기서만 잡힌다.
func _test_haemjji_pose_runtime() -> void:
	var pet_state := make_pet("haemjji")
	pet_state.stage = "adult"
	var pet: Node2D = PetScene.instantiate()
	pet.screen_size = Vector2(1280.0, 720.0)
	pet.ground_y = 714.0
	root.add_child(pet)
	await process_frame
	pet.ps = pet_state
	pet.refresh_appearance()
	# 아래 반응 트리거 검사가 대기 중 자율 전이(idle_state → Walk)에 흔들리지 않도록 멈춘다.
	pet.machine.set_process(false)

	var stage_scale: float = float(PetScript.STAGE_SCALE[pet_state.stage])
	# 실효 배율 = STAGE_SCALE x BODY_SCALE(티어별) x sheet_scale(티어별)
	var tier_runtime := {
		"base": {"dir": "haemjji", "scale": 1.667 * 1.083},
		# 2026-08-07 §12: evolved 계열 정지 아트 256px 복원으로 BODY_SCALE이 내려가고 sheet_scale이
		# 같은 비율로 올라갔다. 곱은 크기 사다리(x1.0926 / x1.1852)만큼만 커진다.
		"evolved": {"dir": "haemjji_evolved", "scale": 0.9314 * 2.2699},
		"evolved2": {"dir": "haemjji_evolved2", "scale": 1.0148 * 2.1214},
	}
	for tier in ["base", "evolved", "evolved2"]:
		var expect: Dictionary = tier_runtime[tier]
		pet_state.evolved = tier != "base"
		pet_state.evolved_2 = tier == "evolved2"
		pet.refresh_appearance()
		check(pet._body_tier == tier, "햄찌 티어 전환 %s → _body_tier == %s" % [tier, pet._body_tier])
		var expected_scale: float = stage_scale * float(expect["scale"])
		for state in HAEMJJI_EXPECTED_STATES:
			var expected: Dictionary = HAEMJJI_EXPECTED_STATES[state]
			var label: String = "햄찌[%s] %s" % [tier, state]
			pet.play_state_animation(state)
			check(pet._pose_override_active and pet._pose_override_state == state,
				"%s 시트 오버라이드 활성" % label)
			var path: String = pet._sprite.texture.resource_path if pet._sprite.texture != null else ""
			# 티어 누수 검사: evolved인데 base 시트를 물면 화면상 진화가 보이지 않는다.
			check(path.begins_with("res://assets/sprites/%s/" % expect["dir"]),
				"%s 시트가 %s/ 폴더 (%s)" % [label, expect["dir"], path.get_file()])
			check(pet._sprite.hframes == expected["columns"] and pet._sprite.vframes == expected["rows"],
				"%s 격자 %dx%d 적용" % [label, expected["columns"], expected["rows"]])
			check(approx(pet._base_scale.y, expected_scale, 0.01),
				"%s 실효 배율 %.4f == STAGE_SCALE x BODY_SCALE x sheet_scale" % [label, pet._base_scale.y])
			# foot_padding이 전 프레임 12.0이라 프레임을 넘겨도 발이 지면에 고정돼야 한다.
			var grounded := true
			for frame_index in int(expected["frames"]):
				pet._set_bichon_frame(frame_index)
				if not approx(pet.current_frame_foot_offset(), 0.0):
					grounded = false
			check(grounded, "%s 전 프레임 발이 지면 고정" % label)

	# 아래 반응 트리거 검사는 base 티어에서 수행한다.
	pet_state.evolved = false
	pet_state.evolved_2 = false
	pet.refresh_appearance()

	# 반응 연출(Pet/FileHover/FileConsume)은 상태머신 상태가 아니라 오버라이드라, 등록만 있고
	# 트리거가 막혀 있어도 위 매니페스트·재생 검사는 전부 통과한다 — 모찌에서 실제로 그랬다.
	# 그래서 종족이 늘 때마다 트리거를 직접 태워봐야 한다.
	pet.play_state_animation("Idle")
	pet._on_care_performed("pet")
	check(pet._pose_override_state == "Pet"
		and String(pet._sprite.texture.resource_path).begins_with("res://assets/sprites/haemjji/"),
		"햄찌 care(pet) → Pet 시트 재생 (state=%s)" % pet._pose_override_state)
	await create_timer(0.9).timeout
	check(pet._pose_override_state == "Idle",
		"햄찌 Pet 반응 종료 후 Idle 복귀 (state=%s)" % pet._pose_override_state)

	pet.set_file_hover(true)
	check(pet._pose_override_state == "FileHover",
		"햄찌 set_file_hover(true) → FileHover 시트 (state=%s)" % pet._pose_override_state)
	pet.set_file_hover(false)
	check(pet._pose_override_state == "Idle",
		"햄찌 set_file_hover(false) → Idle 복귀 (state=%s)" % pet._pose_override_state)

	pet.play_file_drop_reaction()
	check(pet._pose_override_state == "FileHover", "햄찌 파일 드롭 1단계 FileHover")
	await create_timer(0.45).timeout
	check(pet._pose_override_state == "FileConsume",
		"햄찌 파일 드롭 2단계 FileConsume (state=%s)" % pet._pose_override_state)
	await create_timer(0.85).timeout
	check(pet._pose_override_state == "Idle",
		"햄찌 파일 드롭 종료 후 Idle 복귀 (state=%s)" % pet._pose_override_state)

	# 반응 중 상태가 바뀌면 복귀 예약이 취소되어야 한다 (뒤늦은 타이머가 새 상태를 덮으면 안 됨).
	pet._on_care_performed("pet")
	check(pet._pose_override_state == "Pet", "햄찌 반응 취소 검증: Pet 재생 시작")
	pet.play_state_animation("Sulk")
	await create_timer(0.9).timeout
	check(pet._pose_override_state == "Sulk",
		"햄찌 반응 중 상태 전환 시 복귀 예약 취소 (state=%s)" % pet._pose_override_state)

	# 햄찌는 3티어 전부 시트가 있으므로, 폴백 경로는 시트가 없는 상태(Jump/Perch)로 검증한다.
	# 폴백 시 격자를 1x1로 되돌리지 않으면 128px 정지 이미지가 6칸으로 잘려 몸통 1/6만 보인다.
	for tier in ["base", "evolved", "evolved2"]:
		pet_state.evolved = tier != "base"
		pet_state.evolved_2 = tier == "evolved2"
		pet.refresh_appearance()
		for state in ["Jump", "Perch"]:
			pet.play_state_animation(state)
			check(not pet._pose_override_active, "햄찌[%s] %s 시트 미등록 → 정지 포즈 폴백" % [tier, state])
			check(pet._sprite.hframes == 1 and pet._sprite.vframes == 1,
				"햄찌[%s] %s 폴백 시 격자 1x1" % [tier, state])

	root.remove_child(pet)
	pet.free()
	pet_state.free()
	call_deferred("_finish")


## 현재 걸린 시트가 속한 자산 폴더 이름 (티어·종족 누수 검사용).
func _sheet_dir(pet: Node2D) -> String:
	if pet._sprite.texture == null:
		return "<null>"
	return pet._sprite.texture.resource_path.get_base_dir().get_file()


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


# Plan FR-15 v3: 활동 기반 진화
func _test_evolution_keyboard() -> void:
	var pet := make_pet("mochi")
	var got_tier := [0]
	pet.evolution_ready.connect(func(_s, tier): got_tier[0] = tier)
	pet.add_input_delta({"kb": 15000, "mouse": 0, "active_sec": 0.0, "friday_active_sec": 0.0})
	check(not pet.evolved, "모찌 진화 미충족 (kb 절반)")
	pet.add_input_delta({"kb": 15001, "mouse": 0, "active_sec": 0.0, "friday_active_sec": 0.0})
	check(pet.evolved and got_tier[0] == 1, "모찌 1차 진화: 키보드 30,000 달성 (tier=1)")
	check(pet.stage == "adult", "진화 시 성체로 자동 승격")


# 최종 진화 (2단계) — 1차 완료 후 임계값 상향된 조건 달성
func _test_evolution_2_tier() -> void:
	var pet := make_pet("mochi")
	var tiers: Array = []
	pet.evolution_ready.connect(func(_s, tier): tiers.append(tier))
	pet.add_input_delta({"kb": 30000, "mouse": 0, "active_sec": 0.0, "friday_active_sec": 0.0})
	check(pet.evolved and not pet.evolved_2, "1차 진화만 완료 상태")
	pet.add_input_delta({"kb": 70000, "mouse": 0, "active_sec": 0.0, "friday_active_sec": 0.0})
	check(pet.evolved_2, "모찌 최종 진화: 키보드 누적 100,000 달성")
	check(tiers == [1, 2], "진화 신호가 1→2 순서로 발화")


# 연속 출근일수 지표 (당근이 진화 조건)
func _test_consecutive_days() -> void:
	var pet := make_pet("tokki")
	pet.note_activity_day("2026-07-25")
	check(pet.work_stats["consecutive_days"] == 1, "첫 활성일: 연속 1일")
	pet.note_activity_day("2026-07-25")
	check(pet.work_stats["consecutive_days"] == 1, "같은 날 중복: 카운트 유지")
	pet.note_activity_day("2026-07-26")
	pet.note_activity_day("2026-07-27")
	check(pet.work_stats["consecutive_days"] == 3, "연속 3일: 3")
	pet.note_activity_day("2026-07-29")  # 하루 건너뜀
	check(pet.work_stats["consecutive_days"] == 1, "하루 공백 → 리셋")


# 대사 pool: 캐릭터 진화 유무에 따라 base / (e1) / (e2) 각각 검증
func _test_dialog_evolution_pools() -> void:
	var Dialog := preload("res://scripts/data/dialog.gd")
	var Chars := preload("res://scripts/data/characters.gd")
	var Balance := preload("res://scripts/data/balance.gd")
	var missing: Array = []
	var missing_triggers: Array = []
	for species in Chars.CHARACTERS.keys():
		var entry = Dialog.BY_CHARACTER.get(species)
		if not (entry is Dictionary):
			missing.append(species + ":not-dict")
			continue
		var stages: Array = ["base"]
		if Balance.EVOLUTION.has(species):
			stages.append("e1")
		if Balance.EVOLUTION_2.has(species):
			stages.append("e2")
		for key in stages:
			var stage_data = entry.get(key)
			var lines: Array = []
			var trigger_count: int = 0
			if stage_data is Dictionary:
				lines = stage_data.get("random", [])
				for k in stage_data.keys():
					if k != "random":
						trigger_count += 1
			elif stage_data is Array:
				lines = stage_data
			if lines.size() < 3:
				missing.append("%s.%s.random(%d)" % [species, key, lines.size()])
			if trigger_count < 3:
				missing_triggers.append("%s.%s.triggers(%d)" % [species, key, trigger_count])
	check(missing.is_empty(), "랜덤 대사 3줄 이상: %s" % str(missing))
	check(missing_triggers.is_empty(), "각 캐릭터·단계별 트리거 override 3개 이상: %s" % str(missing_triggers))


# 토끼: 3일 연속 → 다이어토, 14일 연속 → 헬토
func _test_rabbit_full_evolution() -> void:
	var pet := make_pet("tokki")
	pet.note_activity_day("2026-07-01")
	pet.note_activity_day("2026-07-02")
	check(not pet.evolved, "당근이: 2일 연속 (미충족)")
	pet.note_activity_day("2026-07-03")
	check(pet.evolved, "당근이 → 다이어토: 3일 연속")
	for d in range(4, 15):
		pet.note_activity_day("2026-07-%02d" % d)
	check(pet.evolved_2, "다이어토 → 헬토: 14일 연속")


func _test_evolution_distinct_days() -> void:
	var pet := make_pet("ppiyak")
	for i in 4:
		pet.note_activity_day("2026-07-%02d" % (20 + i))
	check(not pet.evolved, "삐약 진화 미충족 (4일)")
	pet.note_activity_day("2026-07-24")
	check(pet.evolved, "삐약 진화: 서로 다른 날 5일")
	# 중복 날짜는 카운트 안 됨
	var pet2 := make_pet("ppiyak")
	for i in 10:
		pet2.note_activity_day("2026-07-21")
	check(not pet2.evolved, "중복 날짜는 진화 카운트 안 됨")


func _test_evolution_feed_snack() -> void:
	var pet := make_pet("haemjji")
	for i in 39:
		pet.care("feed" if i % 2 == 0 else "snack")
	check(not pet.evolved, "햄찌 진화 미충족 (39회)")
	pet.care("feed")
	check(pet.evolved, "햄찌 진화: 먹이/간식 40회")


func _test_evolution_progress_ratio() -> void:
	var pet := make_pet("kong")
	pet.add_input_delta({"kb": 0, "mouse": 5000, "active_sec": 0.0, "friday_active_sec": 0.0})
	var p: Dictionary = pet.evolution_progress()
	check(approx(p["ratio"], 0.25), "진화 진행률: 5000/20000 = 25%")
	check(p["hint"] != "", "진행률에 힌트 문구 포함")


func _test_evolution_persists_across_save() -> void:
	var pet := make_pet("mundeok")
	for i in 30:
		pet.note_todo_complete()
	check(pet.evolved, "문덕 진화: 할 일 30개")
	var restored: Node = PetStateScript.new()
	restored.deserialize(pet.serialize())
	check(restored.evolved and restored.work_stats["todos_done"] == 30,
		"진화 상태·카운터 직렬화 왕복 보존")


func _test_evolution_gated_by_egg() -> void:
	var pet: Node = PetStateScript.new()  # 알 상태
	pet.add_input_delta({"kb": 999999, "mouse": 999999, "active_sec": 0.0, "friday_active_sec": 0.0})
	check(not pet.evolved, "알 상태에서는 진화 불가")


# 업데이트 버전 비교 (FR-29)
func _test_version_compare() -> void:
	var Updater := preload("res://scripts/updater.gd")
	check(Updater.is_newer("v0.3.0", "0.2.0"), "버전 비교: 0.3.0 > 0.2.0")
	check(Updater.is_newer("1.0.0", "0.9.9"), "버전 비교: 1.0.0 > 0.9.9")
	check(not Updater.is_newer("v0.2.0", "0.2.0"), "버전 비교: 동일 버전은 미갱신")
	check(not Updater.is_newer("0.1.9", "0.2.0"), "버전 비교: 구버전은 미갱신")
	check(Updater.is_newer("0.2.1", "0.2"), "버전 비교: 자릿수 부족 보정")


# 알로 리셋: 성체+병듦 상태에서도 완전 초기화
func _test_reset_to_egg() -> void:
	var pet := make_pet("haemjji")
	pet.stage = "adult"
	pet.stats["health"] = 10.0
	pet.is_sick = true
	pet.poop_count = 3
	pet.age_minutes = 99999.0
	pet.reset_to_egg()
	check(
		pet.stage == "egg" and pet.species == "" and not pet.is_sick
		and pet.poop_count == 0 and pet.hatch_progress == 0.0
		and approx(pet.stats["health"], 100.0),
		"알로 리셋: 전체 상태 초기화"
	)
	pet.advance_minutes(Balance.HATCH_HOURS_MAX * 60.0, {"hour": 10, "weekday": 2})
	check(pet.stage == "baby" and pet.species != "", "알로 리셋 후 재부화 정상")


# 창 감지 JSON 파싱
func _test_probe_parse() -> void:
	var Probe := preload("res://scripts/platform/window_probe.gd")
	var parsed: Array = Probe.parse_windows(
		'[{"i":123,"x":100,"y":200,"w":800,"h":600,"z":0,"t":0},{"i":9,"x":1500,"y":900,"w":360,"h":150,"z":1,"t":1}]'
	)
	check(parsed.size() == 2, "probe 파싱: 창 2개")
	check(parsed[0]["rect"] == Rect2(100, 200, 800, 600) and not parsed[0]["toast"], "probe 파싱: 일반 창")
	check(parsed[1]["toast"], "probe 파싱: 토스트 판별")
	check(Probe.parse_windows("깨진 json").is_empty(), "probe 파싱: 손상 입력 → 빈 배열")


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
