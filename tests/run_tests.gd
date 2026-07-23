# 헤드리스 단위 테스트 (Design §8). 실행:
#   godot --headless --path . --script tests/run_tests.gd
extends SceneTree

const Balance := preload("res://scripts/data/balance.gd")
const Characters := preload("res://scripts/data/characters.gd")
const TimeM := preload("res://autoload/time_manager.gd")
const PetStateScript := preload("res://autoload/pet_state.gd")

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
	check(absf(counts.get("mochi", 0) / float(n) - 0.15) < 0.02, "기본 확률: 모찌 ~15%")
	check(absf(counts.get("seureureuk", 0) / float(n) - 0.04) < 0.015, "기본 확률: 스르륵 ~4%")
	var fri := 0
	for i in n:
		if Characters.pick_species(["friday_hatch"], rng) == "bulgeumjo":
			fri += 1
	check(absf(fri / float(n) - 12.0 / 108.0) < 0.02, "금요일 가중치: 불금조 ~11.1%")


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
	var got_signal := [false]
	pet.evolution_ready.connect(func(_s): got_signal[0] = true)
	pet.add_input_delta({"kb": 15000, "mouse": 0, "active_sec": 0.0, "friday_active_sec": 0.0})
	check(not pet.evolved, "모찌 진화 미충족 (kb 절반)")
	pet.add_input_delta({"kb": 15001, "mouse": 0, "active_sec": 0.0, "friday_active_sec": 0.0})
	check(pet.evolved and got_signal[0], "모찌 진화: 키보드 30,000 달성")
	check(pet.stage == "adult", "진화 시 성체로 자동 승격")


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
