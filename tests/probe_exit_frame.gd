# 실측 프로브: 상태가 실제로 빠져나갈 때 "화면에 남는" 마지막 프레임 번호를 엔진을 돌려서 잰다.
#
# 왜 필요한가: 이 팀은 종료 프레임을 산술로 여러 번 틀렸다. loop 시트에서 "duration x fps"를
# 그대로 쓰거나 "loop이면 f0에서 끝난다"고 가정하는 실수가 반복됐다. 정답은
#   loop:false -> clampi(ceil(duration x fps) - 1, 0, frames - 1)
#   loop:true  -> posmod(ceil(duration x fps) - 1, frames)
# 인데, ceil-1인 이유는 전이가 나는 틱에서 exit()가 같은 프레임 안에 시트를 갈아치워
# 그 틱이 렌더되지 않기 때문이다(machine이 pet의 자식이라 _process 순서가
# "애니메이션 진행 -> 상태 전이"다). duration x fps가 정수일 때만 두 식이 갈리는데
# Eat(2.0 x 6 = 12)이 정확히 그 경우다.
#
# 2026-08-10 실측 결과: mochi Eat(4f/6fps/loop) = f3, haemjji Eat(6f/6fps/loop) = f5.
# posmod(11, 4) = 3, posmod(11, 6) = 5 와 일치해 위 식이 옳음을 확인했다.
#
# 실행: godot --headless --fixed-fps 60 --path . --script tests/probe_exit_frame.gd
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
			await _probe(species, tier, "Eat")
	print("PROBE DONE")
	quit()


func _probe(species: String, tier: String, state: String) -> void:
	var pet_state: Node = PetStateScript.new()
	pet_state.name = "ProbePetState_%s_%s" % [species, tier]
	pet_state.debug_set_species(species, "adult")
	pet_state.evolved = tier != "base"
	pet_state.evolved_2 = tier == "evolved2"
	pet_state.stats["energy"] = 90.0
	pet_state.is_sick = false
	pet_state.is_sulking = false
	root.add_child(pet_state)

	var pet: Node2D = PetScene.instantiate()
	pet.screen_size = Vector2(1280.0, 720.0)
	pet.ground_y = 714.0
	root.add_child(pet)
	await process_frame
	pet.ps = pet_state
	pet.refresh_appearance()

	var combo := "%s/%s/%s" % [species, tier, state]
	var config: Dictionary = pet._pose_override_config(state)
	if config.is_empty():
		print("%s: (등록 없음)" % combo)
		pet.queue_free()
		pet_state.queue_free()
		await process_frame
		return

	pet.machine.transition_to(state)
	var last_frame := -1
	var frames_seen: Array = []
	var ticks := 0
	# 매 프레임 끝(process_frame 시그널)에 남아 있는 값이 곧 그 프레임에 그려지는 값이다.
	while ticks < 600:
		await process_frame
		ticks += 1
		if pet.machine.current_name() != state:
			break
		last_frame = pet._bichon_frame
		if not (last_frame in frames_seen):
			frames_seen.append(last_frame)

	print("%s: 실측 마지막 프레임=f%d (frames=%d fps=%.1f loop=%s, %d틱, 관측=%s)"
		% [combo, last_frame, int(config["frames"]), float(config["fps"]),
			str(bool(config.get("loop", true))), ticks, str(frames_seen)])

	pet.queue_free()
	pet_state.queue_free()
	await process_frame
