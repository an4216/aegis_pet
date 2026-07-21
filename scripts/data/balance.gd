# Design Ref: §3.4 — 모든 밸런스 수치의 단일 출처. 다른 파일에 수치 하드코딩 금지.
extends RefCounted

const DECAY_PER_HOUR := {
	"hunger": 4.0,
	"happiness": 3.0,
	"energy_active": 5.0,
}
const SLEEP_ENERGY_RECOVERY_PER_HOUR := 25.0

const CARE_EFFECTS := {
	"feed": {"hunger": 30.0},
	"snack": {"hunger": 10.0, "happiness": 5.0},
	"play": {"happiness": 20.0, "energy": -10.0},
	"pet": {"happiness": 3.0},
	"medicine": {"health": 40.0},
	"clean": {"cleanliness": 15.0},
}

const POOP_INTERVAL_MINUTES_MIN := 90.0
const POOP_INTERVAL_MINUTES_MAX := 180.0
const DIGEST_MINUTES_MIN := 15.0              # 먹은 뒤 응아까지 (소화)
const DIGEST_MINUTES_MAX := 30.0
const POOP_CLEAN_PENALTY := 15.0
const MAX_OFFLINE_POOPS := 3

const HEALTH_DRAIN_HUNGER_PER_HOUR := 6.0     # 배고픔 0일 때
const HEALTH_DRAIN_DIRTY_PER_HOUR := 4.0      # 청결 < 30일 때
const HEALTH_REGEN_PER_HOUR := 2.0            # 양호 상태 자연 회복
const SICK_THRESHOLD := 30.0                  # 건강 < 30 → 병듦
const SICK_RECOVER_THRESHOLD := 50.0          # 치료 후 이 이상이면 회복
const SULK_THRESHOLD := 20.0                  # 행복 < 20 → 시무룩
const SULK_RECOVER_THRESHOLD := 40.0

const OFFLINE_DECAY_RATE := 0.5               # Plan FR-10
const OFFLINE_CAP_HOURS := 8.0

const HATCH_HOURS_MAX := 4.0                  # 방치해도 4시간이면 부화
const HATCH_CLICK_PROGRESS := 0.8             # 클릭당 부화 게이지
const HIGH_CARE_CLICKS := 20                  # 알 클릭 횟수 기준 (부화 가중치)
const NEGLECT_CLICKS := 3

const STAGE_BABY_DAYS := 3.0                  # 부화 후 3일 → 소년기
const STAGE_ADULT_DAYS := 7.0                 # 부화 후 7일 → 성체

const WEEKEND_HAPPINESS_REGEN_PER_HOUR := 3.0   # 불금조 weekend_boost
const AFTER_WORK_HAPPINESS_REGEN_PER_HOUR := 3.0  # 스르륵 after_work_boost
const BURNOUT_ENERGY_MULT := 1.5              # 문덕 burnout_link (행복<30일 때 에너지 감소 배율)
const SELF_SNACK_CHANCE_PER_HOUR := 0.1       # 햄찌 self_snack
const SELF_SNACK_HUNGER := 8.0
