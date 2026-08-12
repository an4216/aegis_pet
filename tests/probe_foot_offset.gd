# 실측 프로브: 접지 상태와 공중 상태의 발 높이를 프레임별로 잰다.
#
# 이 프로브가 답하는 질문 (2026-08-10 팀 논쟁 B-1):
#   "airborne 시트의 foot_padding 최솟값이 접지 기준값(mochi 16 / haemjji 12 / ppiyak 12)과
#    달라도 되는가? 다르면 발이 접지 상태와 어긋나는가?"
#
# 실측 결론: **최솟값의 절댓값은 발 정렬과 무관하다.**
#   - 접지 상태(Idle/Walk): 전 프레임 발 높이가 정확히 0.00px
#   - 공중 상태: 접지 프레임의 발 높이도 정확히 0.00px — min이 16이든 12든 11이든 4든 예외 없음
#   - 실측 최대부양 == (pad_max - pad_min) x 배율, 18개 조합 전부 소수점까지 일치
#
# 이유는 pet.gd 의 폴백이다. ground_padding 을 생략하면 _minimum_foot_padding() 이 쓰이므로
#   foot_offset = (ground_padding - foot_padding[frame]) x scale = (min - pad[f]) x scale
# 가 되어 min 프레임은 항상 0이 된다. 즉 행 전체를 셀 안에서 위/아래로 옮겨도 자기보정된다.
# 그래서 등록 규약은 "ground_padding 은 기본 생략, 명시할 경우 반드시 min 과 동일"이다.
#
# 이 논쟁은 누가 또 min 을 내릴 때 반복된다. 그때 산술로 다투지 말고 이 프로브를 돌려라.
# 실행: godot --headless --fixed-fps 60 --path . --script tests/probe_foot_offset.gd
extends SceneTree

const PetStateScript := preload("res://autoload/pet_state.gd")
const PetScene := preload("res://scenes/pet/pet.tscn")


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

	for species in ["mochi", "haemjji", "ppiyak"]:
		for tier in ["base", "evolved", "evolved2"]:
			await _probe(species, tier)
	print("PROBE DONE")
	quit()


func _probe(species: String, tier: String) -> void:
	var pet_state: Node = PetStateScript.new()
	pet_state.name = "P_%s_%s" % [species, tier]
	pet_state.debug_set_species(species, "adult")
	pet_state.evolved = tier != "base"
	pet_state.evolved_2 = tier == "evolved2"
	pet_state.stats["energy"] = 90.0
	root.add_child(pet_state)

	var pet: Node2D = PetScene.instantiate()
	pet.screen_size = Vector2(1280.0, 720.0)
	pet.ground_y = 714.0
	root.add_child(pet)
	await process_frame
	pet.ps = pet_state
	pet.refresh_appearance()

	# 주의: 여기서 찍으면 정지 포즈 경로 배율이다. 애니메이션 경로는 start_animated_pose()가
	# BODY_SCALE x sheet_scale로 다시 잡으므로 상태별로 다시 찍는다(둘을 헷갈리면 "경로마다
	# 크기가 다르다"는 오진을 하게 된다 — 실제로 한 번 그랬다).
	print("=== %s/%s (정지 경로 배율 y=%.4f) ===" % [species, tier, pet._base_scale.y])
	for state in ["Idle", "Walk", "Dragged", "Fall", "Play"]:
		var config: Dictionary = pet._pose_override_config(state)
		if config.is_empty():
			print("  %-8s (등록 없음)" % state)
			continue
		if not pet.start_animated_pose(state):
			print("  %-8s (재생 실패)" % state)
			continue
		var paddings: Array = config.get("foot_padding", [])
		var offsets := ""
		var worst := 0.0
		var contact := 9999.0
		for frame in int(config["frames"]):
			pet._set_bichon_frame(frame)
			var foot: float = pet.current_frame_foot_offset()
			offsets += " f%d=%+.1f" % [frame, foot]
			worst = minf(worst, foot)
			contact = minf(contact, absf(foot))
		var pad_min := 9999.0
		var pad_max := -9999.0
		for v in paddings:
			pad_min = minf(pad_min, float(v))
			pad_max = maxf(pad_max, float(v))
		print("  %-8s 배율=%.4f airborne=%s ground_padding=%s pad=[%.0f..%.0f]%s"
			% [state, pet._base_scale.y, str(bool(config.get("airborne", false))),
				"명시" if config.has("ground_padding") else "생략(min)",
				pad_min, pad_max, offsets])
		print("           접지프레임 |발높이|최솟값=%.2fpx  최대부양=%.2fpx  기대부양=(pad_max-pad_min)x배율=%.2fpx"
			% [contact, -worst, (pad_max - pad_min) * pet._base_scale.y])
	pet.queue_free()
	pet_state.queue_free()
	await process_frame
