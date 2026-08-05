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
