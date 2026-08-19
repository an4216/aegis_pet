# 실측 프로브: 진화 티어별 "화면에 실제로 보이는 크기"를 잰다 (Task #9 기준선).
#
# 왜 필요한가: 몸통 정규화 검사(_test_mochi_pose_manifest 등)는 상수끼리의 정합
# (BODY_CORE_HEIGHT x BODY_SCALE == expected_torso)만 본다. 그 검사가 초록이어도
# **렌더된 크기**가 티어 사다리를 따르는지는 보지 않는다 — 2026-08-10 화면 QA에서
# mochi가 base 123x102 / evolved 101x103 / evolved2 103x113 으로 나와
# "base -> evolved에서 높이 +1%, 폭 -18%"(진화해도 커지지 않음)가 드러났다.
#
# 렌더 경로:
#   _base_scale = _stage_scale() x fit_scale
#   fit_scale   = SPRITE_SIZE x multiplier / visible_extent
#   포즈 경로의 몸통 배율 = BODY_SCALE x sheet_scale   (_pose_override_body_scale)
#   설계 의도상 sheet_scale = 정지 아트 몸통 / 시트 Idle f0 몸통 이므로
#   화면 몸통 = BODY_SCALE x 정지 몸통 x 상수 = expected_torso x 상수 → 사다리가 반영돼야 한다.
#
# 이 프로브는 그 "돼야 한다"를 실제로 재서 확인한다. 상수만 보고 판단하지 마라.
# 실행: godot --headless --fixed-fps 60 --path . --script tests/probe_tier_size.gd
extends SceneTree

const PetStateScript := preload("res://autoload/pet_state.gd")
const PetScene := preload("res://scenes/pet/pet.tscn")
const Characters := preload("res://scripts/data/characters.gd")
const PetScript := preload("res://scenes/pet/pet.gd")

# 스킬 문서 기준 화면 몸통 기대값(adult). 사다리 1.0 / 1.0926 / 1.1852.
const EXPECTED_SCREEN := {"base": 108.0, "evolved": 118.0, "evolved2": 128.0}


class TestTimeManager:
	extends Node
	signal minute_ticked(_minutes: float)

	func is_night(_start_hour: int, _end_hour: int) -> bool:
		return false


class TestSaveManager:
	extends Node

	var settings := {"focus_mode": false, "night_start": 22, "night_end": 7}


func _init() -> void:
	var tm := TestTimeManager.new()
	tm.name = "TimeManager"
	root.add_child(tm)
	var sm := TestSaveManager.new()
	sm.name = "SaveManager"
	root.add_child(sm)

	# mochi는 몸통이 아니라 **눈 세로 높이**가 사용자 지정 기준이다(TORSO_NORMALIZATION_EXEMPT).
	# 그 기준을 검사하는 테스트가 하나도 없어서, expected_torso를 사다리 비로 바꾸면 몸통 검사와
	# probe_tier_size는 초록인데 눈 기준만 조용히 깨진다. 그래서 여기서 함께 잰다.
	_probe_eyes()
	for species in ["mochi", "haemjji", "ppiyak"]:
		print("=== %s ===" % species)
		var first := 0.0
		for tier in ["base", "evolved", "evolved2"]:
			var h := await _probe(species, tier)
			if tier == "base":
				first = h
			elif first > 0.0:
				print("        base 대비 화면 높이 비 %.3f (기대 사다리 %.4f)"
					% [h / first, Characters.get_tier_size_ladder(tier)])
	print("PROBE DONE")
	quit()


## mochi 정지 아트의 눈 세로 높이를 티어별로 잰다.
## 눈 = 몸(분홍)에 대비되는 어두운 연결성분 중 (a) 채움률 >= 0.45 (b) 가로세로비 0.6~1.6
## (c) 높이가 서로 15% 안이고 좌우로 떨어진 쌍. 안경테·양복·나비넥타이가 걸리지 않게 하는 조건이다
## (2026-08-11 실측 시 evolved2 양복이 실제로 걸려서 세 조건을 다 넣었다).
func _probe_eyes() -> void:
	print("=== mochi 눈 세로 높이 (사용자 지정 기준, 검사 없음) ===")
	var base_eye := 0.0
	for entry in [["base", "mochi", 128.0], ["evolved", "mochi_evolved", 256.0],
			["evolved2", "mochi_evolved2", 256.0]]:
		var tier := String(entry[0])
		var path := "res://assets/sprites/chars/%s/idle.png" % String(entry[1])
		var canvas := float(entry[2])
		if not ResourceLoader.exists(path):
			print("  %-9s (정지 아트 없음)" % tier)
			continue
		var image: Image = (load(path) as Texture2D).get_image()
		var eye := _eye_height(image)
		if eye <= 0.0:
			print("  %-9s 눈 쌍 검출 실패" % tier)
			continue
		var scale: float = Characters.get_body_scale("mochi", tier)
		var screen: float = eye * scale * float(PetScript.STAGE_SCALE["adult"])
		if tier == "base":
			base_eye = screen
		var core: float = Characters.get_body_core_height("mochi", tier)
		print("  %-9s 눈 %.1fpx(캔버스) = %.1fpx(128환산)  화면 눈 %.2fpx  눈/코어 %.3f%s"
			% [tier, eye, eye * 128.0 / canvas, screen, eye / core,
				"" if base_eye <= 0.0 or tier == "base"
					else "  base 대비 %.3f (기대 %.4f)" % [screen / base_eye,
						Characters.get_tier_size_ladder(tier)]])
	print()


## 어두운 연결성분 쌍의 평균 높이. 못 찾으면 0.
func _eye_height(image: Image) -> float:
	var w := image.get_width()
	var h := image.get_height()
	var seen := {}
	var cand := []
	for y in range(h):
		for x in range(w):
			var key := y * w + x
			if seen.has(key):
				continue
			if not _is_dark(image, x, y):
				seen[key] = true
				continue
			# 너비 우선 탐색으로 한 덩어리를 모은다.
			var queue := [Vector2i(x, y)]
			seen[key] = true
			var min_x := x
			var max_x := x
			var min_y := y
			var max_y := y
			var area := 0
			while not queue.is_empty():
				var p: Vector2i = queue.pop_back()
				area += 1
				min_x = mini(min_x, p.x)
				max_x = maxi(max_x, p.x)
				min_y = mini(min_y, p.y)
				max_y = maxi(max_y, p.y)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = p + d
					if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
						continue
					var nk := n.y * w + n.x
					if seen.has(nk):
						continue
					seen[nk] = true
					if _is_dark(image, n.x, n.y):
						queue.push_back(n)
			var bw := float(max_x - min_x + 1)
			var bh := float(max_y - min_y + 1)
			if area < 12 or float(area) / (bw * bh) < 0.45:
				continue
			var aspect := bw / bh
			if aspect < 0.6 or aspect > 1.6:
				continue
			cand.append({"h": bh, "w": bw, "area": area, "cx": (min_x + max_x + 1) * 0.5})
	cand.sort_custom(func(a, b): return int(a["area"]) > int(b["area"]))
	for i in range(cand.size()):
		for j in range(i + 1, cand.size()):
			var a: Dictionary = cand[i]
			var b: Dictionary = cand[j]
			var ha := float(a["h"])
			var hb := float(b["h"])
			if absf(ha - hb) / maxf(ha, hb) > 0.15:
				continue
			if absf(float(a["cx"]) - float(b["cx"])) <= float(a["w"]) * 0.8:
				continue
			return (ha + hb) * 0.5
	return 0.0


func _is_dark(image: Image, x: int, y: int) -> bool:
	var c := image.get_pixel(x, y)
	if c.a < 0.5:
		return false
	return (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) * 255.0 <= 90.0


## 그 티어 Idle f0의 화면 높이를 돌려준다.
func _probe(species: String, tier: String) -> float:
	var ps: Node = PetStateScript.new()
	ps.name = "T_%s_%s" % [species, tier]
	ps.debug_set_species(species, "adult")
	ps.evolved = tier != "base"
	ps.evolved_2 = tier == "evolved2"
	ps.stats["energy"] = 90.0
	root.add_child(ps)

	var pet: Node2D = PetScene.instantiate()
	pet.screen_size = Vector2(1280.0, 720.0)
	pet.ground_y = 714.0
	root.add_child(pet)
	await process_frame
	pet.ps = ps
	pet.refresh_appearance()

	var config: Dictionary = pet._pose_override_config("Idle")
	if config.is_empty():
		print("  %-9s (Idle 애니메이션 미등록 — 정지 포즈 폴백)" % tier)
		pet.queue_free()
		ps.queue_free()
		await process_frame
		return 0.0

	pet.start_animated_pose("Idle")
	pet._set_bichon_frame(0)
	var size := _visible_size(config, 0)
	var scale: float = pet._base_scale.y
	var screen_h: float = size.y * scale
	var screen_w: float = size.x * scale
	var expected: float = float(EXPECTED_SCREEN[tier])
	var raw: Variant = PetScript.ANIMATED_POSE_OVERRIDES.get(species, {}).get("sheet_scale", 1.0)
	var sheet: float = float((raw as Dictionary).get(tier, 1.0)) if raw is Dictionary else float(raw)
	print("  %-9s 시트 f0=%.0fx%.0f  배율=%.4f  화면=%.0fx%.0f  기대 %.0f (%+.1f%%)"
		% [tier, size.x, size.y, scale, screen_w, screen_h, expected,
			(screen_h / expected - 1.0) * 100.0])
	print("            BODY_SCALE=%.4f  sheet_scale=%.4f  expected_torso=%.1f  코어=%.1f"
		% [Characters.get_body_scale(species, tier), sheet,
			Characters.get_expected_torso(species, tier),
			Characters.get_body_core_height(species, tier)])

	pet.queue_free()
	ps.queue_free()
	await process_frame
	return screen_h


## 한 프레임의 보이는 픽셀 크기(셀 좌표계). 임계값은 런타임·검사와 같은 VISIBLE_ALPHA 0.125.
func _visible_size(config: Dictionary, frame: int) -> Vector2:
	var texture: Texture2D = load(String(config["path"]))
	var image: Image = texture.get_image()
	var columns := int(config["columns"])
	var sequence: Array = config.get("sprite_frame_sequence", [])
	var cell := frame if sequence.is_empty() else int(sequence[frame])
	var cw: int = image.get_width() / columns
	var ch: int = image.get_height() / int(config["rows"])
	var min_x := cw
	var max_x := -1
	var min_y := ch
	var max_y := -1
	for y in range(ch):
		for x in range(cw):
			if image.get_pixel((cell % columns) * cw + x, (cell / columns) * ch + y).a >= 0.125:
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
	if max_x < 0:
		return Vector2.ZERO
	return Vector2(float(max_x - min_x + 1), float(max_y - min_y + 1))
