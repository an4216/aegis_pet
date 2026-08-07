# Design Ref: §3.2, §3.3 — 데이터 주도 캐릭터. 로직은 이 테이블만 조회한다.
# 상세 설정: docs/02-design/characters.md
extends RefCounted

const RARITY_WEIGHT := {"common": 15.0, "uncommon": 8.0, "rare": 4.0}

# 먹기 반응 중 캐릭터 옆에 잠깐 나타났다 사라지는 음식 소품. feed/snack을 몸동작이 아니라
# 이 소품으로 구분한다(둘 다 같은 Eat 애니메이션을 쓴다) — 상태를 늘리지 않고 저비용으로 구분.
# 종족에 값이 없으면 소품 없이 기존 Eat 동작만 재생된다(하위 호환, 점진 도입 가능).
# 소품 크기는 PNG 안 오브젝트의 픽셀 크기가 그대로 정한다 — pet.gd가 소품에 펫과 같은
# _base_scale을 걸고 소품별 배율 키는 없다. 제작 시 원하는 크기는 프롬프트가 아니라
# 추출 safe_margin = (셀 - 원하는 크기) / 2 로 잡는다(프롬프트로는 조절되지 않는다).
#
# ⚠️ 크기 기준은 높이가 아니라 **폭**으로 잡아라. 추출이 컴포넌트를 안전영역에 꽉 맞추므로
# safe_margin 16으로 뽑은 소품은 형태와 무관하게 전부 폭 96px이 된다. 그런데 펫의 셀 폭은
# 종족마다 다르다(모찌 192셀 = 몸통 156px / 햄찌 128셀 = 몸통 77px). 그래서 같은 96px 소품이
# 모찌에선 몸통의 62%지만 햄찌에선 125%로 펫보다 커진다 — 실제로 햄찌 feed가 그렇다.
# 높이 비율(feed 67~71% / snack 46~50%)만 보면 정상 대역이라 이 문제를 못 잡는다.
# 새 소품을 요청할 땐 "그 종족 몸통 폭의 60~70%"를 목표 폭으로 주고 safe_margin을 역산해라.
#
# 아래 실측값은 폭×높이(px)와 그 종족 idle 몸통 폭 대비 비율이다
# (idle 0프레임 알파 바운딩박스 폭: 모찌 156px / 햄찌 81px — 햄찌는 프레임에 따라 75~82px).
# 햄찌 feed는 2026-08-07에 safe_margin 16 -> 40으로 **재추출만** 해서 96px -> 48px로 줄였다
# (재생성 아님 — 같은 raw). 네 소품이 55~62% 대역에 모여 있어야 정상이다.
const FOOD_PROPS := {
	"mochi": {
		"feed": "res://assets/sprites/mochi/food_feed.png",     # 파스텔 핑크 그릇 + 흰쌀밥, 96x86 (62%)
		"snack": "res://assets/sprites/mochi/food_snack.png",   # 접시 위 분홍 모찌 경단 3개, 96x65 (62%)
	},
	"haemjji": {
		"feed": "res://assets/sprites/haemjji/food_feed.png",   # 주황 테두리 그릇 + 해바라기씨·곡물, 48x37 (59%)
		"snack": "res://assets/sprites/haemjji/food_snack.png", # 도토리 1개, 45x48 (56%)
	},
}


static func get_food_prop(species: String, action: String) -> String:
	return FOOD_PROPS.get(species, {}).get(action, "")

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
# 생기는 편차를 상쇄한다. 값이 클수록 원본이 작게 그려진 것.
#
# 2026-08-07: 정규화 기준을 **전체 실루엣 높이 → 몸통(코어 덩어리) 높이**로 바꿨다.
# 예전 기준(BODY_SCALE_TARGET_HEIGHT = 111.5, idle.png 알파 바운딩박스 높이)은 36장 전부를
# 실루엣 223px로 정확히 맞췄지만, 그 바운딩박스에 "몸이 아닌 것"이 캐릭터마다 다르게 대량
# 포함돼 있었다 — 불금조의 머리 불꽃(26px), 콩이의 김(36px), 당근이의 긴 귀, 문덕의 촉수,
# 나른냥/꾸벅의 귀·꼬리·소품, 거부장의 백팩 등. 그래서 실루엣이 같아도 "실제 몸 덩어리"는
# 당근이 53px ~ 꾸벅 104px로 2배까지 차이 났고, 체감 크기가 캐릭터마다 어긋났다.
#
# 새 기준은 아래 BODY_CORE_HEIGHT(코어 몸통 높이)를 전 종족·전 티어 공통 목표
# BODY_SCALE_TARGET_TORSO 로 맞춘다. 산식: BODY_SCALE = 2 * BODY_SCALE_TARGET_TORSO / 코어높이.
# (2배는 2026-08-06 캔버스 256->128 축소분 관례 — 목표치는 128px 캔버스 기준이다.)
# 부작용은 의도된 것이다: 실루엣이 더 이상 균일하지 않고 캔버스 대비 160~280px로 벌어진다
# (부속물이 많은 캐릭터일수록 실루엣이 커진다).
#
# ⚠️ 2026-08-07 변경: 크기 축이 **둘**이 됐다 — STAGE_SCALE(성장) + TIER_SIZE_LADDER(진화).
# 예전 규칙("진화는 몸통 크기를 바꾸지 않는다")은 사용자 지시로 철회됐다. 아래 사다리 참고.
const BODY_SCALE_TARGET_TORSO := 80.0

# 2026-08-07 **크기 사다리** — 사용자 지정: "진화할수록 커져야 한다".
# 같은 성장단계끼리 비교했을 때 base < evolved < evolved2 로 몸통이 커진다.
# 기준 화면 크기(adult 기준 몸통 px): base 108 / evolved 118 / evolved2 128
#   → 배율 118/108 = 1.0926, 128/108 = 1.1852.
# 이전 규칙("진화는 모양만 바뀐다 = 크기 불변")은 이 지시로 **명시적으로 철회**됐다.
#
# 주의(의도된 비직교성): 성장 폭(baby→adult 0.32→0.45 = 1.406배)이 진화 폭(1.0926배)보다
# 크므로 "evolved 아기 > base 성체" 같은 9단계 전역 순서는 성립하지 않는다. 사용자가
# "순서 규칙은 느슨하게"로 결정했다 — 같은 성장단계 안에서만 진화 순서를 보장한다.
#
# 이 배율은 몸통 정규화 목표에 곱해진다: 비예외 종족의 목표 몸통 =
# 2 * BODY_SCALE_TARGET_TORSO * TIER_SIZE_LADDER[tier] (= 160 / 174.8 / 189.6).
# 아래 BODY_SCALE 표의 evolved/evolved2 값에도 이미 곱해져 들어가 있다.
const TIER_SIZE_LADDER := {"base": 1.0, "evolved": 1.0926, "evolved2": 1.1852}


static func get_tier_size_ladder(tier: String) -> float:
	return float(TIER_SIZE_LADDER.get(tier, 1.0))

# 코어 몸통 높이 실측값(px @128 캔버스, idle.png, α>0.125 기준).
# docs/02-design/characters/body-size-audit.md — 36장 전수 시각 실측(2026-08-07)의 SSoT다.
# 판정 규칙: 융합형(얼굴-몸통 경계 없음)은 덩어리 전체, 분리형(kkubeok/nyang)은 머리 정수리
# (귀·모자 제외)부터 접지선까지의 코어 덩어리. 제외: 귀·뿔·볏·꼬리·팔다리·촉수·김/불꽃/반짝임
# 이펙트·가방/모자 등 소품. 이 표를 고치면 BODY_SCALE도 위 산식으로 같이 다시 계산해야 한다
# (tests/run_tests.gd 의 몸통 정규화 테스트가 두 표의 일관성을 잠근다).
const BODY_CORE_HEIGHT := {
	# ⚠️ 2026-08-07(§12): evolved/evolved2는 **256px 캔버스 기준**이다(base/egg만 128px).
	# 아트가 커진 만큼(art_ratio ~2.0) 이 값도 커졌고 BODY_SCALE은 같은 비율로 내려갔다.
	"mochi": {"base": 72.0, "evolved": 222.00, "evolved2": 205.06},
	"ppiyak": {"base": 93.0, "evolved": 176.00, "evolved2": 143.51},
	"haemjji": {"base": 96.0, "evolved": 187.65, "evolved2": 186.83},
	"kkubeok": {"base": 104.0, "evolved": 185.17, "evolved2": 164.00},
	"nyang": {"base": 99.0, "evolved": 178.00, "evolved2": 173.22},
	"kong": {"base": 75.0, "evolved": 118.69, "evolved2": 154.00},
	"mundeok": {"base": 69.0, "evolved": 126.00, "evolved2": 126.00},
	"geobujang": {"base": 93.0, "evolved": 161.27, "evolved2": 179.19},
	"bulgeumjo": {"base": 81.0, "evolved": 164.73, "evolved2": 126.66},
	"seureureuk": {"base": 75.0, "evolved": 158.00, "evolved2": 154.00},
	# tokki만 이 표의 값이 반복해서 바뀌는데, **아트 내용이 바뀐 게 아니라 프레이밍(캔버스를
	# 얼마나 채우는가)이 바뀐 것**이다. 같은 256px 원본을 매번 다른 배수로 128px에 다시 내리고
	# 있으므로 코어 몸통도 같은 배수만큼 선형으로 커진다 — 몸통 정의(§2)는 손대지 않았다.
	#   §9 (해상도 복구): 53.0/55.0/51.0 -> 70.2/72.8/70.6. 렌더 배율 1.23x(확대) -> 0.93x(축소).
	#                     아트가 커진 만큼 BODY_SCALE을 낮춰 화면 크기는 불변으로 유지.
	#   §10 (눈 크기 정렬): 70.2/72.8/70.6 -> 아래 값 (x1.1190 / x1.1190 / x1.08566).
	#                     이번엔 BODY_SCALE을 그대로 두므로 화면 크기가 의도적으로 커진다.
	# 근거: body-size-audit.md §9~§10.
	#   §12 (진화 티어 256px 복원): evolved/evolved2만 81.5/76.7 -> 112.64/103.10 (x1.3821/x1.3443).
	#                     tokki만 배수가 ~1.34인 것은 §9/§10에서 이미 재프레이밍을 해뒀기 때문.
	"tokki": {"base": 78.6, "evolved": 112.64, "evolved2": 103.10},
	"ddungsil": {"base": 85.0, "evolved": 165.17, "evolved2": 142.00},
}

# 몸통 정규화(옵션 A)의 예외 종족 — **사용자가 몸통 높이가 아닌 다른 지표를 직접 지정한 곳**.
#
# 되돌리지 마라. 아래 3종이 공통 목표(몸통 160 = 화면상 72px)에서 -32% ~ +22%까지 벗어나
# 있는 것은 버그가 아니라 2026-08-07 사용자 지시의 결과다. "왜 이 3종만 목표에서 벗어나지?"
# 하고 BODY_SCALE을 공통 산식으로 되돌리면 사용자가 확인한 화면이 깨진다.
#
# 배경: 사람이 캐릭터 크기를 판단할 때 쓰는 단서는 코어 몸통 높이가 아니라 **눈 크기 ·
# 머리끝 위치 · 발 접지 여부**였다. 12종을 adult 기준으로 나란히 렌더해 육안 확인한 뒤
# 사용자가 3종에 대해 종별로 다른 기준을 지정했고, 그 지표를 12종 전수 실측해 중앙값에
# 맞춘 값이 지금의 BODY_SCALE이다(실측 표: body-size-audit.md §8).
# 몸통 단일 정규화는 이 3종에서 적용되지 않는다 — 사용자 지정 기준이 우선한다.
#
# `expected_torso`는 "이 종족이 몸통 정규화 목표(2 x BODY_SCALE_TARGET_TORSO = 160) 대신
# 수렴해야 하는 값"이다(= BODY_CORE_HEIGHT x 그 종족의 BODY_SCALE). 테스트는 예외 종족을
# 검사에서 빼는 것이 아니라 이 기대값 +-2%로 검사한다 — 예외 종족도 회귀는 그대로 잡힌다.
#
# 예외를 더 늘리지 마라. 새로 추가하려면 육안 QA 근거(비교 스트립)를 남기고 감사 문서에
# 후기를 적어야 하며, 테스트가 예외 목록의 크기 자체를 상한(3)으로 잠그고 있다.
const TORSO_NORMALIZATION_EXEMPT := {
	"mochi": {
		"reason": "사용자 지정 기준(2026-08-07): \"눈 크기가 다른 애들과 비슷할 정도로\". 몸통 높이가 아니라 **눈 세로 높이**를 지표로 12종 전수 실측(ddungsil은 4px 실눈이라 제외)해 중앙값 13.44px에 맞췄다. 티어별 눈 원본 17/17/16px -> 세 티어가 1.76~1.87로 수렴한다. body-size-audit.md §8.1.",
		"expected_torso": {"base": 126.5, "evolved": 213.1, "evolved2": 227.9},
	},
	"mundeok": {
		"reason": "사용자 지정 기준(2026-08-07): \"머리끝이 다른 애들 머리끝과 맞을 정도로\". 몸통 높이가 아니라 **머리 정수리(부속물 제외)~접지선 높이**를 지표로 12종 전수 실측해 중앙값 75.85px에 맞췄다. 이전 지표(코어 몸통)로는 촉수를 제외한 탓에 머리끝이 95.2px로 혼자 높았다. body-size-audit.md §8.2.",
		"expected_torso": {"base": 121.2, "evolved": 118.4, "evolved2": 128.5},
	},
	"tokki": {
		"reason": "사용자 지정 기준(2026-08-07): \"발이 바닥에 닿아야 한다 + 5% 축소\". 아트 24장의 하단 여백을 0px로 내려 접지를 맞추고(크기 불변 — solid bbox 높이 동일), 그 위에 사용자 지시대로 선형 5% 축소(2.879/2.806/2.989 -> 2.735/2.666/2.840). BODY_CORE_HEIGHT는 y범위만 이동했고 높이는 그대로다. body-size-audit.md §8.3. // 2026-08-07 후속(§9): 256px 원본에서 캔버스를 채우도록 24장 재추출해 해상도를 복구했다(렌더 배율 1.23x 확대 -> 0.93x 축소). 크기는 그대로이고 픽셀 밀도만 올랐으므로 이 예외 사유는 그대로 유효하다 — BODY_SCALE/BODY_CORE_HEIGHT는 바뀌었지만 곱인 expected_torso는 불변이며, 그것이 화면 크기 불변의 산술 증명이다. // 2026-08-07 눈 크기 정렬(§10): 12종 눈 높이 중앙값 12.48px에 맞추려고 256px 원본 재추출 배수를 상향(x1.1190 / x1.1190 / x1.08566). BODY_SCALE은 불변이고 아트가 커진 것이라 렌더는 축소 유지(0.929/0.906/0.923) — 그래서 expected_torso만 커진다.",
		"expected_torso": {"base": 162.3, "evolved": 179.3, "evolved2": 186.6},
	},
}


## 이 종족·티어가 수렴해야 하는 몸통 높이(px @128 캔버스 x 2배 관례).
## 예외 목록에 없으면 공통 목표 2 x BODY_SCALE_TARGET_TORSO.
## 2026-08-07: 목표가 티어별로 달라졌다 — 크기 사다리(TIER_SIZE_LADDER)를 곱한다.
## 예외 3종은 자기 기대값을 그대로 쓴다(그 값에 이미 사다리가 반영돼 있다).
static func get_expected_torso(species: String, tier: String) -> float:
	var common: float = 2.0 * BODY_SCALE_TARGET_TORSO * get_tier_size_ladder(tier)
	var entry: Dictionary = TORSO_NORMALIZATION_EXEMPT.get(species, {})
	if entry.is_empty():
		return common
	return float(entry["expected_torso"].get(tier, common))


# 주의: mochi / mundeok / tokki 3종은 위 산식(2 x 80 / 코어높이)을 따르지 않는다.
# 사용자가 지정한 별도 기준(눈 크기 / 머리끝 높이 / 발 접지)으로 잡은 값이며
# TORSO_NORMALIZATION_EXEMPT의 reason과 body-size-audit.md §8에 근거가 있다. 되돌리지 마라.
const BODY_SCALE := {
	# 사용자 지정: 눈 높이 기준(중앙값 13.44px). 몸통 산식 값은 2.222/1.441/1.553이었다.
	"mochi": {"base": 1.757, "evolved": 0.9598, "evolved2": 1.1109},
	"ppiyak": {"base": 1.72, "evolved": 0.9932, "evolved2": 1.3216},
	"haemjji": {"base": 1.667, "evolved": 0.9314, "evolved2": 1.0148},
	"kkubeok": {"base": 1.538, "evolved": 0.9439, "evolved2": 1.1562},
	"nyang": {"base": 1.616, "evolved": 0.9822, "evolved2": 1.0948},
	"kong": {"base": 2.133, "evolved": 1.4729, "evolved2": 1.2314},
	# 사용자 지정: 머리끝 높이 기준(중앙값 75.85px). 옵션 A는 2.319/2.54/2.54, 옵션 B는 2.203/2.393/2.38이었다.
	"mundeok": {"base": 1.756, "evolved": 0.9396, "evolved2": 1.0193},
	"geobujang": {"base": 1.72, "evolved": 1.0839, "evolved2": 1.0584},
	"bulgeumjo": {"base": 1.975, "evolved": 1.0611, "evolved2": 1.4974},
	"seureureuk": {"base": 2.133, "evolved": 1.1063, "evolved2": 1.2314},
	# 사용자 지정: 발 접지(아트 하단 여백 0px화) + 5% 축소. 옵션 A는 3.019/2.909/3.137, 옵션 B는 2.879/2.806/2.989였다.
	# 2026-08-07 256px 원본 재프레이밍으로 아트가 커져 배율을 낮춤(2.735/2.666/2.840 -> 아래 값).
	# 화면 크기는 불변, 렌더 배율 1.23x(확대) -> 0.93x(축소)로 선명도 복구. 근거: body-size-audit.md §9.
	# 2026-08-07 눈 크기 정렬(§10)에서는 이 값을 **일부러 그대로 뒀다** — 1.119배 하면 렌더 배율이
	# 1.04x로 다시 확대(=뿌옇게)가 되므로, 대신 아트 자체를 1.119배로 재추출해 화면 크기를 키웠다.
	"tokki": {"base": 2.065, "evolved": 1.5914, "evolved2": 1.8092},
	"ddungsil": {"base": 1.882, "evolved": 1.0585, "evolved2": 1.3357},
}


static func get_body_scale(species: String, tier: String) -> float:
	return BODY_SCALE.get(species, {}).get(tier, 1.0)


## 코어 몸통 높이 실측값(px @128 캔버스). 미등록 종족(bichon 등)은 0.0 — bichon은 정지 포즈
## 경로가 아니라 애니메이션 카탈로그의 visible_extent 경로로 크기가 정해지므로 이 표에 없다.
static func get_body_core_height(species: String, tier: String) -> float:
	return BODY_CORE_HEIGHT.get(species, {}).get(tier, 0.0)

const CHARACTERS := {
	"bichon": {
		"name_kr": "해솔", "rarity": "uncommon",
		"stat_modifiers": {"happiness_decay": 0.8},
		"care_modifiers": {"pet": 1.3},
		"special": [],
		# 2026-08-07 사용자 지시로 부화 풀에서 숨김. 이미 해솔로 부화한 저장 데이터·애니메이션
		# 카탈로그·관리자 콘솔 테스트는 전부 그대로 동작해야 하므로 CHARACTERS 항목 자체는
		# 지우지 않고, pick_species()의 부화 후보에서만 제외한다.
		"hidden_from_hatch": true,
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
		# 정지 sleep.png에 "z" 글자가 없다 → sleep_state가 런타임 Zzz 라벨을 대신 띄운다.
		# 나머지 11종은 아트에 z(콩이는 김 모락)가 그려져 있어 라벨을 띄우면 이중 표시가 된다.
		# tokki는 2026-08-07 §10 재추출에서 제작 가이드 §2(분리 이펙트·텍스트 금지) 위반이던
		# 떠 있는 반짝임·하트·"z"를 24장 전부에서 제거했다. 라벨이 없으면 자는 표시가 사라진다.
		"sleep_art_lacks_zzz": true,
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


## 새 부화 후보로 뽑힐 수 있는 종족인가. 이미 그 종족으로 부화한 저장 데이터에는 영향 없다 —
## 이 함수는 pick_species()의 후보 목록에서만 걸러낸다.
static func is_hatchable(species: String) -> bool:
	return CHARACTERS.has(species) and not bool(CHARACTERS[species].get("hidden_from_hatch", false))


static func is_walk_static(species: String) -> bool:
	return CHARACTERS.has(species) and bool(CHARACTERS[species].get("walk_static", false))


static func is_walk_face_inverted(species: String) -> bool:
	return CHARACTERS.has(species) and bool(CHARACTERS[species].get("walk_face_inverted", false))


## 정지 포즈 sleep.png에 Zzz 표시가 없어 런타임 라벨이 필요한 종족인가.
## 기본값 false = "아트에 그려져 있다"(12종 중 11종). 애니메이션 시트 경로와는 무관하다 —
## 시트 경로는 ANIMATED_POSE_OVERRIDES / start_animated_sleep()이 따로 판단한다.
static func pose_sleep_needs_zzz_label(species: String) -> bool:
	return CHARACTERS.has(species) and bool(CHARACTERS[species].get("sleep_art_lacks_zzz", false))


## 부화 종족 결정: 기본 확률 × 컨텍스트 가중치 후 정규화 샘플링
static func pick_species(context_flags: Array, rng: RandomNumberGenerator) -> String:
	var weights := {}
	for species in CHARACTERS:
		if not is_hatchable(species):
			continue
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
