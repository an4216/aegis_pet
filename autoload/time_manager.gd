# Design Ref: §2.1 — 게임 시간 틱·밤낮·오프라인 경과 계산.
# 씬 노드를 직접 참조하지 않는다 (시그널 발신만).
extends Node

signal minute_ticked

const Balance := preload("res://scripts/data/balance.gd")

## 디버그 시간 가속 (x60 = 1초당 1분). 디버그 빌드에서만 변경 허용.
var time_scale: float = 1.0:
	set(v):
		time_scale = v if OS.is_debug_build() else 1.0

var _accum_seconds := 0.0


func _ready() -> void:
	# 데모/디버그: `godot --path . -- --time-scale=10` 처럼 실행하면 시간 가속
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--time-scale="):
			time_scale = maxf(float(arg.get_slice("=", 1)), 1.0)


func _process(delta: float) -> void:
	_accum_seconds += delta * time_scale
	while _accum_seconds >= 60.0:
		_accum_seconds -= 60.0
		minute_ticked.emit()


## 현재 시각 컨텍스트 (PetState.advance_minutes에 전달)
func now_context() -> Dictionary:
	var dt := Time.get_datetime_dict_from_system()
	return {"hour": dt.hour, "minute": dt.minute, "weekday": dt.weekday, "day": dt.day}


func is_night(night_start_hour: int = 22, night_end_hour: int = 7) -> bool:
	var h: int = Time.get_datetime_dict_from_system().hour
	if night_start_hour > night_end_hour:
		return h >= night_start_hour or h < night_end_hour
	return h >= night_start_hour and h < night_end_hour


## 부화 시점 컨텍스트 플래그 (characters.gd HATCH_WEIGHTS 키와 일치)
static func hatch_context_flags(dt: Dictionary) -> Array:
	var flags: Array = []
	var h: int = dt.get("hour", 12)
	var wd: int = dt.get("weekday", 2)  # Time.get_datetime_dict: 0=일요일
	if h >= 22 or h < 7:
		flags.append("night_hatch")
	if wd == 5:
		flags.append("friday_hatch")
	if h == 12:
		flags.append("lunch_hatch")
	if h >= 7 and h < 9:
		flags.append("morning_hatch")
	return flags


## 오프라인 경과 → 적용할 유효 감소 시간 (50% 비율, 8시간 캡. Plan FR-10)
static func compute_offline_hours(elapsed_seconds: float) -> float:
	if elapsed_seconds <= 0.0:
		return 0.0
	var hours := elapsed_seconds / 3600.0
	return minf(hours, Balance.OFFLINE_CAP_HOURS) * Balance.OFFLINE_DECAY_RATE
