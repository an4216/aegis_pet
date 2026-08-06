# Design Ref: §3.2, §3.3 — 데이터 주도 캐릭터. 로직은 이 테이블만 조회한다.
# 상세 설정: docs/02-design/characters.md
extends RefCounted

const RARITY_WEIGHT := {"common": 15.0, "uncommon": 8.0, "rare": 4.0}

# 1차 진화형 이름
const EVOLVED_NAMES := {
	"mochi": "프로찌", "ppiyak": "꼬꼬", "haemjji": "함장님",
	"kkubeok": "꿀잠도사", "nyang": "자유냥", "kong": "라떼님",
	"mundeok": "문팀장", "geobujang": "거이사님",
	"bulgeumjo": "불사조", "seureureuk": "스르신",
	"tokki": "다이어토", "ddungsil": "뚱과장",
	"bichon": "달솔",
}

# 최종 진화형 이름 (Plan FR-15 v4)
const EVOLVED_2_NAMES := {
	"mochi": "회찌", "ppiyak": "꼬끼오", "haemjji": "햄왕",
	"kkubeok": "꿈신", "nyang": "여행냥", "kong": "카페왕",
	"mundeok": "문사장", "geobujang": "거회장",
	"bulgeumjo": "영원조", "seureureuk": "자유혼",
	"tokki": "헬토", "ddungsil": "뚱대박",
	"bichon": "별솔",
}


static func get_evolved_name(species: String) -> String:
	return EVOLVED_NAMES.get(species, species)


static func get_evolved_2_name(species: String) -> String:
	return EVOLVED_2_NAMES.get(species, species)


# 몸통 시각 크기 보정 — 포즈 시트 원본 아트가 캔버스를 차지하는 비율이 캐릭터마다 달라
# 생기는 편차를 상쇄한다. idle.png 알파 바운딩박스 실측(높이) 기준, 진화단계(base/evolved/
# evolved2)별 전체 캐릭터 공통 목표 높이로 정규화한 보정값 — 값이 클수록 원본이 작게 그려진 것.
# BODY_SCALE_TARGET_HEIGHT 는 그 정규화 목표(스케일 1.0 기준 픽셀 높이)의 SSoT다 — 애니메이션
# 오버라이드 시트(예: sprite-gen 산출물)도 같은 값으로 fit_scale을 잡아야 몸통 크기가 맞는다.
# 2026-08-06: 정지 포즈 원본 캔버스를 256->128로 축소(파일 용량 절감)하면서, 화면 표시 크기를
# 그대로 유지하려고 이 아래 모든 보정값을 2배로 올렸다 — 목표 높이도 같은 캔버스 기준이라 절반으로.
const BODY_SCALE_TARGET_HEIGHT := 111.5
const BODY_SCALE := {
	"mochi": {"base": 3.076, "evolved": 1.956, "evolved2": 2.018},
	"ppiyak": {"base": 1.956, "evolved": 2.028, "evolved2": 2.322},
	"haemjji": {"base": 1.992, "evolved": 1.94, "evolved2": 1.964},
	"kkubeok": {"base": 2.0, "evolved": 1.982, "evolved2": 2.046},
	"nyang": {"base": 2.046, "evolved": 1.956, "evolved2": 2.0},
	"kong": {"base": 1.982, "evolved": 2.564, "evolved2": 1.956},
	"mundeok": {"base": 1.956, "evolved": 2.084, "evolved2": 2.046},
	"geobujang": {"base": 1.956, "evolved": 2.0, "evolved2": 2.0},
	"bulgeumjo": {"base": 1.974, "evolved": 1.956, "evolved2": 2.252},
	"seureureuk": {"base": 1.982, "evolved": 1.974, "evolved2": 2.084},
	"tokki": {"base": 2.578, "evolved": 2.578, "evolved2": 2.67},
	"ddungsil": {"base": 2.144, "evolved": 2.218, "evolved2": 2.788},
}


static func get_body_scale(species: String, tier: String) -> float:
	return BODY_SCALE.get(species, {}).get(tier, 1.0)

const CHARACTERS := {
	"bichon": {
		"name_kr": "해솔", "rarity": "uncommon",
		"stat_modifiers": {"happiness_decay": 0.8},
		"care_modifiers": {"pet": 1.3},
		"special": [],
	},
	"mochi": {
		"name_kr": "모찌", "rarity": "common",
		"stat_modifiers": {},
		"care_modifiers": {"pet": 1.5},
		"special": [],
	},
	"ppiyak": {
		"name_kr": "삐약", "rarity": "common",
		"stat_modifiers": {"happiness_decay": 0.75, "energy_decay": 1.25},
		"care_modifiers": {},
		"special": ["morning_speed"],
	},
	"haemjji": {
		"name_kr": "햄찌", "rarity": "common",
		"stat_modifiers": {"hunger_decay": 1.4},
		"care_modifiers": {"snack": 2.0},
		"special": ["self_snack"],
	},
	"kkubeok": {
		"name_kr": "꾸벅", "rarity": "common",
		"stat_modifiers": {"sleep_recovery": 2.0, "move_speed": 0.7, "poop_penalty": 0.75},
		"care_modifiers": {},
		"special": ["healing_sleep"],
	},
	"nyang": {
		"name_kr": "나른냥", "rarity": "uncommon",
		"stat_modifiers": {"energy_decay": 1.3, "sleep_recovery": 1.5},
		"care_modifiers": {},
		"special": ["tsundere_pet"],
	},
	"kong": {
		"name_kr": "콩이", "rarity": "uncommon",
		"stat_modifiers": {"hunger_decay": 1.3},
		"care_modifiers": {},
		"special": ["caffeine_rush", "late_sleep"],
	},
	"mundeok": {
		"name_kr": "문덕", "rarity": "uncommon",
		"stat_modifiers": {},
		"care_modifiers": {"play": 1.5},
		"special": ["burnout_link"],
	},
	"geobujang": {
		"name_kr": "거부장", "rarity": "uncommon",
		"stat_modifiers": {"all_decay": 0.7, "move_speed": 0.5},
		"care_modifiers": {"play": 0.7, "pet": 0.7},
		"special": [],
	},
	"bulgeumjo": {
		"name_kr": "불금조", "rarity": "rare",
		"stat_modifiers": {},
		"care_modifiers": {},
		"special": ["weekend_boost"],
	},
	"seureureuk": {
		"name_kr": "스르륵", "rarity": "rare",
		"stat_modifiers": {"all_decay": 0.8},
		"care_modifiers": {},
		"special": ["after_work_boost"],
	},
	"tokki": {
		"name_kr": "당근이", "rarity": "uncommon",
		"stat_modifiers": {"happiness_decay": 0.85, "energy_decay": 0.85},
		"care_modifiers": {},
		"special": [],
	},
	"ddungsil": {
		"name_kr": "뚱실이", "rarity": "uncommon",
		"stat_modifiers": {"hunger_decay": 0.7, "energy_decay": 1.3, "move_speed": 0.6},
		"care_modifiers": {"feed": 1.5, "snack": 1.5},
		"special": [],
		"walk_static": true,   # walk2가 walk1과 동일 → waddle 모션으로 보완
		"walk_face_inverted": true,   # 걷기 시트가 뒤돌아본 상태 → 좌우 반전
	},
}

# 부화 히든 가중치 (characters.md §2.2)
const HATCH_WEIGHTS := {
	"night_hatch": {"seureureuk": 3.0},
	"friday_hatch": {"bulgeumjo": 3.0},
	"wednesday_hatch": {"ddungsil": 3.0},
	"lunch_hatch": {"haemjji": 2.0},
	"morning_hatch": {"kong": 2.0},
	"high_care": {"ppiyak": 2.0},
	"neglect": {"nyang": 2.0, "geobujang": 2.0},
}


static func get_stat_modifier(species: String, key: String) -> float:
	if not CHARACTERS.has(species):
		return 1.0
	var mods: Dictionary = CHARACTERS[species]["stat_modifiers"]
	return mods.get(key, 1.0) * mods.get("all_decay", 1.0) if key.ends_with("_decay") else mods.get(key, 1.0)


static func get_care_modifier(species: String, action: String) -> float:
	if not CHARACTERS.has(species):
		return 1.0
	var mods: Dictionary = CHARACTERS[species]["care_modifiers"]
	return mods.get(action, 1.0) * mods.get("all", 1.0)


static func has_special(species: String, tag: String) -> bool:
	return CHARACTERS.has(species) and tag in CHARACTERS[species]["special"]


static func is_walk_static(species: String) -> bool:
	return CHARACTERS.has(species) and bool(CHARACTERS[species].get("walk_static", false))


static func is_walk_face_inverted(species: String) -> bool:
	return CHARACTERS.has(species) and bool(CHARACTERS[species].get("walk_face_inverted", false))


## 부화 종족 결정: 기본 확률 × 컨텍스트 가중치 후 정규화 샘플링
static func pick_species(context_flags: Array, rng: RandomNumberGenerator) -> String:
	var weights := {}
	for species in CHARACTERS:
		weights[species] = RARITY_WEIGHT[CHARACTERS[species]["rarity"]]
	for flag in context_flags:
		if HATCH_WEIGHTS.has(flag):
			for species in HATCH_WEIGHTS[flag]:
				weights[species] *= HATCH_WEIGHTS[flag][species]
	var total := 0.0
	for species in weights:
		total += weights[species]
	var roll := rng.randf() * total
	for species in weights:
		roll -= weights[species]
		if roll <= 0.0:
			return species
	return "mochi"
