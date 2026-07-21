# Design Ref: §3.2, §3.3 — 데이터 주도 캐릭터. 로직은 이 테이블만 조회한다.
# 상세 설정: docs/02-design/characters.md
extends RefCounted

const RARITY_WEIGHT := {"common": 15.0, "uncommon": 8.0, "rare": 4.0}

const CHARACTERS := {
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
}

# 부화 히든 가중치 (characters.md §2.2)
const HATCH_WEIGHTS := {
	"night_hatch": {"seureureuk": 3.0},
	"friday_hatch": {"bulgeumjo": 3.0},
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
