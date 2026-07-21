# Design Ref: §3 데이터 모델, §3.5 상태 정의 — 펫 시뮬레이션의 단일 상태 소유자.
# 씬 노드를 직접 참조하지 않는다(시그널만). 테스트에서 단독 인스턴스화 가능해야 한다.
extends Node

signal stat_changed(stat: String, value: float)
signal hatch_progress_changed(progress: float)
signal species_assigned(species: String)
signal stage_changed(stage: String)
signal sickness_changed(is_sick: bool)
signal condition_changed(condition: String)  # "normal" | "sulk"
signal care_performed(action: String)
signal pooped

const Balance := preload("res://scripts/data/balance.gd")
const Characters := preload("res://scripts/data/characters.gd")

const STATS := ["hunger", "happiness", "cleanliness", "energy", "health"]

enum Activity { IDLE, ACTIVE, SLEEPING }

var species: String = ""            # "" = 알 (부화 전)
var stage: String = "egg"           # egg | baby | child | adult
var hatch_progress: float = 0.0
var egg_care_clicks: int = 0
var birth_at: int = 0               # unix (표시용)
var age_minutes: float = 0.0        # 부화 후 경과 (성장 판정 기준)
var stats := {
	"hunger": 80.0, "happiness": 70.0, "cleanliness": 100.0,
	"energy": 80.0, "health": 100.0,
}
var is_sick := false
var is_sulking := false
var poop_count: int = 0
var care_quality_samples: Array = []
var activity: int = Activity.IDLE   # 씬(FSM)이 갱신
var caffeine_until_min: float = -1.0  # 콩이 caffeine_rush 남은 분

var _minutes_until_poop := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()
	_reset_poop_timer()


func _ready() -> void:
	var tm := get_node_or_null("/root/TimeManager")
	if tm != null:
		tm.minute_ticked.connect(_on_minute_ticked)


func _on_minute_ticked() -> void:
	var tm := get_node_or_null("/root/TimeManager")
	var ctx: Dictionary = tm.now_context() if tm != null else {}
	advance_minutes(1.0, ctx)


## 시뮬레이션 심장부. offline=true면 활동성 감소(에너지)와 응아를 제한한다.
func advance_minutes(minutes: float, ctx: Dictionary = {}) -> void:
	if minutes <= 0.0:
		return
	if stage == "egg":
		_advance_egg(minutes, ctx)
		return

	var offline: bool = ctx.get("offline", false)
	var m := minutes / 60.0  # 시간 단위

	# --- 기본 감소 ---
	_add_stat("hunger", -Balance.DECAY_PER_HOUR["hunger"] * m * _decay_mod("hunger_decay"))
	_add_stat("happiness", -Balance.DECAY_PER_HOUR["happiness"] * m * _decay_mod("happiness_decay"))

	# --- 에너지: 활동 시 감소, 수면 시 회복 ---
	if not offline:
		if activity == Activity.SLEEPING:
			var recov := Balance.SLEEP_ENERGY_RECOVERY_PER_HOUR * m
			recov *= Characters.get_stat_modifier(species, "sleep_recovery")
			_add_stat("energy", recov)
		elif activity == Activity.ACTIVE:
			var drain := Balance.DECAY_PER_HOUR["energy_active"] * m * _decay_mod("energy_decay")
			if Characters.has_special(species, "burnout_link") and stats["happiness"] < 30.0:
				drain *= Balance.BURNOUT_ENERGY_MULT
			_add_stat("energy", -drain)

	# --- 특수 규칙 (Design §3.3) ---
	var hour: int = ctx.get("hour", 12)
	var weekday: int = ctx.get("weekday", 2)  # 0=일요일
	if Characters.has_special(species, "weekend_boost"):
		var weekend := weekday == 0 or weekday == 6 or (weekday == 5 and hour >= 18)
		_add_stat("happiness", (Balance.WEEKEND_HAPPINESS_REGEN_PER_HOUR if weekend else -0.6) * m)
	if Characters.has_special(species, "after_work_boost") and hour >= 18:
		_add_stat("happiness", Balance.AFTER_WORK_HAPPINESS_REGEN_PER_HOUR * m)
	if Characters.has_special(species, "self_snack") and not offline:
		if _rng.randf() < Balance.SELF_SNACK_CHANCE_PER_HOUR * m:
			_add_stat("hunger", Balance.SELF_SNACK_HUNGER)
	if caffeine_until_min > 0.0:
		caffeine_until_min = maxf(caffeine_until_min - minutes, 0.0)

	# --- 응아 ---
	var poops_this_tick := 0
	_minutes_until_poop -= minutes
	while _minutes_until_poop <= 0.0:
		if not offline or poops_this_tick < Balance.MAX_OFFLINE_POOPS:
			_do_poop()
			poops_this_tick += 1
		_minutes_until_poop += _next_poop_interval()

	# --- 건강 ---
	var health_delta := 0.0
	if stats["hunger"] <= 0.0:
		health_delta -= Balance.HEALTH_DRAIN_HUNGER_PER_HOUR * m
	if stats["cleanliness"] < 30.0:
		health_delta -= Balance.HEALTH_DRAIN_DIRTY_PER_HOUR * m
	if health_delta == 0.0 and stats["hunger"] > 30.0 and stats["cleanliness"] > 50.0:
		health_delta = Balance.HEALTH_REGEN_PER_HOUR * m
	if health_delta != 0.0:
		_add_stat("health", health_delta)

	_update_conditions()
	_update_stage(minutes)


func care(action: String) -> void:
	if stage == "egg":
		click_egg()
		return
	var effects: Dictionary = Balance.CARE_EFFECTS.get(action, {})
	var mult := Characters.get_care_modifier(species, action)
	for stat in effects:
		_add_stat(stat, effects[stat] * mult)
	if action == "clean" and poop_count > 0:
		poop_count -= 1
	if action == "medicine" and is_sick and stats["health"] >= Balance.SICK_RECOVER_THRESHOLD:
		_set_sick(false)
	if action == "feed" and Characters.has_special(species, "caffeine_rush"):
		caffeine_until_min = 10.0
	if action == "feed" or action == "snack":
		# 소화: 먹으면 15~30분 내 응아 (기존 타이머보다 빠를 때만)
		var digest := _rng.randf_range(Balance.DIGEST_MINUTES_MIN, Balance.DIGEST_MINUTES_MAX)
		_minutes_until_poop = minf(_minutes_until_poop, digest)
	_update_conditions()
	care_performed.emit(action)


func clean_poop() -> void:
	if poop_count > 0:
		poop_count -= 1
		_add_stat("cleanliness", Balance.CARE_EFFECTS["clean"]["cleanliness"])


func click_egg() -> void:
	if stage != "egg":
		return
	egg_care_clicks += 1
	hatch_progress = minf(hatch_progress + Balance.HATCH_CLICK_PROGRESS, 100.0)
	hatch_progress_changed.emit(hatch_progress)
	if hatch_progress >= 100.0:
		_hatch({})


# --- 직렬화 (Design §3.1) ---

func serialize() -> Dictionary:
	return {
		"species": species, "stage": stage,
		"hatch_progress": hatch_progress, "egg_care_clicks": egg_care_clicks,
		"birth_at": birth_at, "age_minutes": age_minutes,
		"stats": stats.duplicate(), "is_sick": is_sick,
		"poop_count": poop_count,
		"care_quality_samples": care_quality_samples.duplicate(),
	}


func deserialize(data: Dictionary) -> void:
	species = data.get("species", "")
	stage = data.get("stage", "egg")
	hatch_progress = data.get("hatch_progress", 0.0)
	egg_care_clicks = int(data.get("egg_care_clicks", 0))
	birth_at = int(data.get("birth_at", 0))
	age_minutes = data.get("age_minutes", 0.0)
	var loaded: Dictionary = data.get("stats", {})
	for stat in STATS:
		stats[stat] = clampf(float(loaded.get(stat, stats[stat])), 0.0, 100.0)
	is_sick = data.get("is_sick", false)
	poop_count = int(data.get("poop_count", 0))
	care_quality_samples = data.get("care_quality_samples", [])


func has_special(tag: String) -> bool:
	return Characters.has_special(species, tag)


## 케어 품질 스코어 (성체 진화 분기용, 일 1회 샘플링)
func care_quality_now() -> float:
	var total := 0.0
	for stat in STATS:
		total += stats[stat]
	return total / STATS.size()


# --- 테스트/디버그 ---

func debug_set_species(new_species: String, new_stage: String = "baby") -> void:
	species = new_species
	stage = new_stage
	birth_at = int(Time.get_unix_time_from_system())
	age_minutes = 0.0


# --- 내부 ---

func _advance_egg(minutes: float, ctx: Dictionary) -> void:
	hatch_progress += minutes * (100.0 / (Balance.HATCH_HOURS_MAX * 60.0))
	hatch_progress = minf(hatch_progress, 100.0)
	hatch_progress_changed.emit(hatch_progress)
	if hatch_progress >= 100.0:
		_hatch(ctx)


func _hatch(ctx: Dictionary) -> void:
	var TimeM := preload("res://autoload/time_manager.gd")
	var dt: Dictionary = ctx if not ctx.is_empty() else Time.get_datetime_dict_from_system()
	var flags: Array = TimeM.hatch_context_flags(dt)
	if egg_care_clicks >= Balance.HIGH_CARE_CLICKS:
		flags.append("high_care")
	elif egg_care_clicks < Balance.NEGLECT_CLICKS:
		flags.append("neglect")
	species = Characters.pick_species(flags, _rng)
	stage = "baby"
	birth_at = int(Time.get_unix_time_from_system())
	age_minutes = 0.0
	species_assigned.emit(species)
	stage_changed.emit(stage)


func _update_stage(minutes: float) -> void:
	age_minutes += minutes
	var days := age_minutes / 1440.0
	var new_stage := stage
	if stage == "baby" and days >= Balance.STAGE_BABY_DAYS:
		new_stage = "child"
	elif stage == "child" and days >= Balance.STAGE_ADULT_DAYS:
		new_stage = "adult"
	if new_stage != stage:
		stage = new_stage
		care_quality_samples.append(care_quality_now())
		stage_changed.emit(stage)


func _update_conditions() -> void:
	if not is_sick and stats["health"] < Balance.SICK_THRESHOLD:
		_set_sick(true)
	if not is_sulking and stats["happiness"] < Balance.SULK_THRESHOLD:
		is_sulking = true
		condition_changed.emit("sulk")
	elif is_sulking and stats["happiness"] >= Balance.SULK_RECOVER_THRESHOLD:
		is_sulking = false
		condition_changed.emit("normal")


func _set_sick(value: bool) -> void:
	if is_sick == value:
		return
	is_sick = value
	sickness_changed.emit(is_sick)


func _do_poop() -> void:
	poop_count += 1
	var penalty := Balance.POOP_CLEAN_PENALTY
	penalty *= Characters.get_stat_modifier(species, "poop_penalty")
	_add_stat("cleanliness", -penalty)
	pooped.emit()


func _next_poop_interval() -> float:
	return _rng.randf_range(Balance.POOP_INTERVAL_MINUTES_MIN, Balance.POOP_INTERVAL_MINUTES_MAX)


func _reset_poop_timer() -> void:
	_minutes_until_poop = _next_poop_interval()


func _decay_mod(key: String) -> float:
	return Characters.get_stat_modifier(species, key)


func _add_stat(stat: String, delta: float) -> void:
	var before: float = stats[stat]
	var after := clampf(before + delta, 0.0, 100.0)
	if after != before:
		stats[stat] = after
		stat_changed.emit(stat, after)
