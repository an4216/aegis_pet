# Design Ref: §2.1 — 펫 표현(스프라이트·애니메이션·입력). 시뮬레이션은 PetState가 소유.
extends Node2D

signal care_menu_requested(pos: Vector2)

const Characters := preload("res://scripts/data/characters.gd")
# 성장 곡선. 프로젝트 규칙: **성장(stage)은 크기가 커지고, 진화(tier)는 모양만 바뀐다(크기 불변).**
# 그래서 크기를 결정하는 축은 이 표 하나뿐이고, 반드시 단조증가해야 한다(egg < baby < child < adult).
# 2026-08-07: baby와 child가 둘 다 0.378로 같아서 4단계 중 실질 3단계뿐이었다(실제로 커지는
# 구간이 child->adult 한 번). baby를 낮춰 네 단계가 전부 구분되게 고쳤다 — 단계마다 약 +19%.
#
# 화면상 몸통(코어) 높이 — 2026-08-07부터 정규화 기준이 실루엣이 아니라 몸통이다
# (Characters.BODY_SCALE / BODY_CORE_HEIGHT 주석 참고):
#   egg 37.5px < baby 51.2px < child 60.8px < adult 72.0px
# (단, mochi/mundeok/tokki 3종은 사용자 지정 기준을 쓰므로 비-egg 몸통이 위 값에서 벗어난다 —
#  Characters.TORSO_NORMALIZATION_EXEMPT 와 body-size-audit.md §8 참고.)
# 비-egg 단계는 종족·티어와 무관하게 항상 160px * STAGE_SCALE 로 정규화된다
# (160 = 2 * Characters.BODY_SCALE_TARGET_TORSO). 실루엣은 더 이상 균일하지 않다 — 귀·꼬리·
# 불꽃·촉수 같은 부속물이 많은 종족일수록 같은 몸통에 실루엣만 커진다(의도된 결과).
# egg는 BODY_SCALE을 곱하지 않으므로(아래 _static_body_scale 참고) 원본 75px * STAGE_SCALE 이다.
#
# 2026-08-07: egg를 0.72 -> 0.58로 내렸다. 몸통 정규화로 모찌 base(코어 = 블롭 전체)의 실루엣이
# 28% 줄면서 baby가 51.2px가 됐는데, 예전 egg(54.0px)가 그보다 커져 단조증가가 깨졌기 때문이다.
# 2026-08-07(2차): egg를 0.58 -> 0.50으로 한 번 더 내렸다. 사용자 지정 "눈 크기" 기준으로 모찌
# base의 BODY_SCALE이 2.222 -> 1.757(-21%)이 되면서 모찌 baby 실루엣이 55.5 -> 43.9px가 됐고,
# egg(45.8px)가 다시 그보다 커졌다. 지금은 egg 39.5px로 최소 baby(모찌 43.9px)보다 10% 작다.
# egg 아트는 전 종족 공통이고 BODY_SCALE을 곱하지 않으므로, **어느 한 종족의 BODY_SCALE만
# 내려도 egg가 그 종족의 baby를 추월할 수 있다** — BODY_SCALE을 만질 때마다 이 여유를 다시 볼 것.
# adult(0.45)/child(0.38)는 최근 튜닝된 값(발이 작업표시줄에 닿는 위치 등)이라 그대로 둔다.
# bichon의 fit_scale(아래 SPRITE_SIZE 사용부)도 이 표를 같이 쓰지만, 그쪽은 visible_extent로
# 따로 정규화한다 — 아직 실루엣 기준(256 * 0.871 = 223px)이며 몸통 기준으로 옮기지 않았다
# (BICHON_VISIBLE_SIZE_MULTIPLIER 주석 참고).
const STAGE_SCALE := {"egg": 0.50, "baby": 0.32, "child": 0.38, "adult": 0.45}
const POSES := ["idle", "walk1", "walk2", "sleep", "happy", "sulk", "sick", "eat"]
const EGG_POSES := ["idle", "tilt1", "tilt2", "crack"]
const SPRITE_SIZE := 256.0  # bichon fit_scale 전용 정규화 기준 — 실제 파일 크기와 무관, 바꾸지 않는다
# 정지 포즈 캔버스의 **폴백 기본값**. 2026-08-07부터 실제 캔버스 크기는 티어마다 다르다:
# base/egg = 128px, evolved/evolved2 = 256px (body-size-audit.md §12 해상도 복원).
# 그래서 위치 계산에 이 상수를 쓰면 안 된다 — 반드시 _frame_size(= texture.get_size(), 실측)를
# 쓰는 _sprite_anchor()를 거쳐라. 이 상수는 텍스처 로드 실패(_sprite.texture == null)로
# 실측이 불가능할 때만 쓰이는 최후 폴백이다. 2026-08-07 이전에는 celebrate()/play_frolic()/
# reset_sprite_pose()가 이 값을 직접 곱해서, 256px 티어가 화면에서 위아래로 크게 어긋났다.
const STATIC_POSE_FALLBACK_SIZE := 128.0
# 클릭/렌더 영역의 최소 한 변(px). Windows의 SetWindowRgn은 이 영역 밖을 렌더링까지 잘라내는데,
# 스타트업 첫 프레임에는 `_frame_size`가 아직 세팅되지 않아 거의 0인 사각형이 나온다. 그러면
# 창 전체가 잘려 펫이 아예 안 보인다(main v0.8.4 "시작 시 사라짐"이 이 경로였다). 실측값이
# 이 하한보다 작을 일은 정상 동작에서는 없으므로, 넉넉한 쪽으로 틀리는 안전망이다.
const MIN_RENDER_REGION_SIZE := 96.0
# 2026-08-07 주의: 이 값은 **아직 실루엣 기준**이다(256 * 0.871 = 223px = 예전 12종 공통 목표).
# 12종은 몸통(코어) 기준으로 옮겼지만 bichon은 body-size-audit 36장 실측 대상이 아니었고,
# 앉은 자세에서 무엇을 몸통으로 볼지(귀·꼬리 제외 경계)가 실측되지 않아 추정으로 바꾸지 않았다.
# 자동 실측 추정으로는 bichon의 코어가 새 목표(160px)보다 약 15% 크다 — sprite-artist가 Idle
# 0번 프레임 몸통을 정식 실측하면 이 값 하나만 고쳐서 같은 기준에 맞출 수 있다(후속 과제).
const BICHON_VISIBLE_SIZE_MULTIPLIER := 0.871
const BICHON_EDGE_BUFFER := 28.0
const BASE_SPEED := 60.0
const PET_COOLDOWN_SECONDS := 30.0
const DRAG_THRESHOLD := 10.0
const FILE_HOVER_DURATION := 0.34
const FILE_CONSUME_DURATION := 0.70

# 2026-08-06: 아래 시트 원본을 전부 256->128 캔버스 기준(50%)으로 축소하면서, 그 시트에서
# 실측한 픽셀 값인 visible_extent/foot_padding/horizontal_offsets도 전부 절반으로 다시 쟀다.
# fit_scale = SPRITE_SIZE(불변) * MULT / visible_extent 이므로 visible_extent가 절반이 되면
# fit_scale·화면 표시 크기는 그대로 유지된다 (SPRITE_SIZE는 실제 파일 크기와 무관한 정규화 상수).
const BICHON_ANIMATIONS := {
	"Idle": {"path": "res://assets/sprites/bichon/idle_sit_blink_11f_alpha.png", "columns": 2, "rows": 1, "frames": 11, "fps": 4.0, "loop": true, "visible_extent": 358.0, "sprite_frame_sequence": [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0], "horizontal_offsets": [5.25, 5.25, 5.25, 5.25, 5.25, 5.25, 5.25, 5.25, 5.25, 5.5, 5.25], "foot_padding": [76.5, 76.5, 76.5, 76.5, 76.5, 76.5, 76.5, 76.5, 76.5, 76.5, 76.5]},
	"Walk": {"path": "res://assets/sprites/bichon/walk_12f_chromakey.png", "columns": 4, "rows": 3, "frames": 12, "fps": 12.0, "loop": true, "visible_extent": 136.5, "foot_padding": [28.0, 25.5, 24.0, 22.5, 42.5, 40.5, 39.0, 39.5, 59.0, 57.0, 55.5, 52.5]},
	"Sleep": {"path": "res://assets/sprites/bichon/sleep_8f_chromakey.png", "columns": 4, "rows": 2, "frames": 8, "fps": 5.0, "loop": true, "visible_extent": 171.0, "horizontal_offsets": [-6.0, -6.75, 2.0, 7.25, -4.75, -4.0, 7.0, 14.5], "foot_padding": [40.0, 39.5, 38.5, 40.0, 60.0, 58.5, 57.5, 58.5]},
	"Eat": {"path": "res://assets/sprites/bichon/eat_12f_chromakey.png", "columns": 4, "rows": 3, "frames": 12, "fps": 9.0, "loop": true, "visible_extent": 149.5, "horizontal_offsets": [-4.0, 2.75, 4.5, 3.0, 0.75, 1.75, 4.5, 7.25, 0.25, 1.5, 2.0, 6.5], "foot_padding": [12.5, 12.5, 12.5, 12.5, 22.5, 22.5, 22.5, 22.5, 30.5, 31.0, 31.0, 30.5]},
	"FileHover": {"path": "res://assets/sprites/bichon/file_hover_4f_chromakey.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": false, "visible_extent": 232.5, "horizontal_offsets": [-17.5, -2.0, 6.0, 22.25], "foot_padding": [57.5, 57.5, 57.5, 57.5]},
	"FileConsume": {"path": "res://assets/sprites/bichon/file_consume_8f_chromakey.png", "columns": 4, "rows": 2, "frames": 8, "fps": 12.0, "loop": false, "visible_extent": 179.0, "horizontal_offsets": [-11.5, -4.0, 3.0, 16.5, -4.0, 2.5, 4.0, 11.5], "foot_padding": [21.0, 21.0, 20.0, 19.5, 34.5, 32.5, 30.5, 30.5]},
	"Poop": {"path": "res://assets/sprites/bichon/poop_6f_chromakey.png", "columns": 3, "rows": 2, "frames": 6, "fps": 8.0, "loop": true, "visible_extent": 174.0, "horizontal_offsets": [-13.75, -5.75, 10.5, -15.5, -6.75, 15.25], "foot_padding": [22.0, 23.5, 22.5, 57.0, 56.5, 56.0]},
	"Sick": {"path": "res://assets/sprites/bichon/sick_8f_chromakey.png", "columns": 4, "rows": 2, "frames": 8, "fps": 6.0, "loop": true, "visible_extent": 193.0, "horizontal_offsets": [-5.0, 8.0, 11.5, 5.5, 1.5, 6.0, 14.5, 14.5], "foot_padding": [23.5, 24.5, 23.5, 23.0, 45.5, 46.0, 46.0, 42.0]},
	"Sulk": {"path": "res://assets/sprites/bichon/sulk_8f_chromakey.png", "columns": 4, "rows": 2, "frames": 8, "fps": 6.0, "loop": true, "visible_extent": 172.5, "horizontal_offsets": [-16.0, -1.25, 0.25, 11.0, -8.75, -5.0, -1.25, 15.5], "foot_padding": [17.0, 16.5, 15.5, 14.5, 42.0, 42.5, 43.5, 44.0]},
	"Dragged": {"path": "res://assets/sprites/bichon/dragged_4f_chromakey.png", "columns": 4, "rows": 1, "frames": 4, "fps": 10.0, "loop": true, "visible_extent": 220.5, "horizontal_offsets": [0.75, -0.5, 0.5, 11.0], "foot_padding": [64.5, 72.5, 64.0, 66.0]},
	"Fall": {"path": "res://assets/sprites/bichon/fall_4f_chromakey.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": false, "visible_extent": 231.5, "horizontal_offsets": [-14.25, -15.0, 7.0, 20.25], "foot_padding": [77.0, 77.0, 75.0, 55.0]},
	"Land": {"path": "res://assets/sprites/bichon/land_4f_chromakey.png", "columns": 4, "rows": 1, "frames": 4, "fps": 10.0, "loop": false, "visible_extent": 215.5, "horizontal_offsets": [-12.75, 7.0, 1.0, 18.5], "foot_padding": [81.0, 56.0, 72.0, 69.0]},
	"Pet": {"path": "res://assets/sprites/bichon/petted_8f_chromakey.png", "columns": 4, "rows": 2, "frames": 8, "fps": 10.0, "loop": false, "visible_extent": 191.0, "horizontal_offsets": [-1.25, 0.25, 1.0, 3.75, 0.25, 0.5, 1.0, 2.0], "foot_padding": [16.0, 16.0, 16.0, 16.0, 32.5, 32.5, 31.5, 31.5]},
	"Play": {"path": "res://assets/sprites/bichon/play_8f_chromakey.png", "columns": 4, "rows": 2, "frames": 8, "fps": 10.0, "loop": false, "visible_extent": 172.0, "horizontal_offsets": [3.5, 4.5, 8.5, 12.5, 2.0, 6.0, 9.0, 6.5], "foot_padding": [44.5, 42.0, 48.0, 64.5, 52.0, 47.0, 33.5, 30.0]},
}

# 포즈 시트 캐릭터의 상태별 정지 포즈를 다중 프레임 시트로 대체한다 (sprite-gen 산출물).
# 등록이 없는 상태·티어는 그 상태만 기존 단일 이미지(정지 포즈)로 폴백한다.
# 프레임별로 스케일을 다시 계산하는 방식(frame_heights)을 한 번 시도했으나, 모찌처럼
# 세로 높이가 81~160px로 크게 요동치는 스쿼시-스트레치 시트에서는 폭까지 반대로 같이
# 요동쳐(웅크릴 때 넓어지고 늘어날 때 좁아짐) "몸통이 늘어났다 줄었다"하는 것처럼 보였다.
# idle과 똑같은 고정 배율(Characters.get_body_scale) 하나만 쓰면 원본 아트 자체의
# 스쿼시-스트레치만 남고 배율은 흔들리지 않는다 — 다른 포즈/캐릭터가 이미 쓰는 방식과 동일.
#
# 구조: species -> {"sheet_scale"(선택), "states" -> 상태명 -> (tier ->) config}
# 시트가 진화 티어마다 따로 있으면 상태 밑에 tier(base|evolved|evolved2) 한 단을 더 둔다.
# "sheet_scale": tier -> 보정값. 시트 셀 안 몸통 높이를 그 티어 정지 포즈 아트의 몸통 높이에
# 맞춘다(등록 없으면 1.0). BODY_SCALE은 그 티어 정지 포즈 아트(base 128px / evolved·evolved2 256px)
# 정규화된 값이라, 셀이 더 큰 시트를 그대로 쓰면 몸통만 커진다. 티어마다 정지 아트 크기와
# 시트 몸통 높이가 다르므로 보정값도 티어별로 다르다 — 모찌 실측(VISIBLE_ALPHA 기준):
#   base     정지 72px  ÷ 시트 idle f0 129px = 0.5581
#   evolved  정지 226px ÷ 시트 idle f0 158px = 1.4304
#   evolved2 정지 220px ÷ 시트 idle f0 174px = 1.2644
# 2026-08-07 몸통 정규화 전환 시 재확인: sheet_scale은 "같은 티어의 두 자산(정지 아트 / 시트)"
# 사이의 비율이라 BODY_SCALE이 어떤 기준으로 잡히든 그대로 유효하다. 기준을 실루엣에서 몸통으로
# 바꿔 다시 재도 값이 거의 같은지 실측했다(정지 코어 ÷ 시트 코어): 모찌 0.558/0.725/0.627 vs
# 실루엣 기준 0.558/0.722/0.631 — 차이 0.5% 미만. 시트와 정지 아트가 같은 캐릭터를 같은 비율로
# 그리는 한 두 기준이 일치하므로 재계산하지 않았다.
# BODY_SCALE을 대신 고치면 안 된다 — 미등록 상태(Poop/Pet 등)가 폴백하는 정지 포즈 8종이
# 같은 값을 쓰므로 그쪽이 같이 어긋난다.
#
# 산식(2026-08-11 사용자 결정으로 확정 — 이 기준 하나만 쓴다):
#
#     sheet_scale = 정지 아트 몸통 높이 ÷ 시트 Idle f0 몸통 높이
#     두 몸통 모두 VISIBLE_ALPHA(α > 0.125) 알파 bbox 높이로 잰다.
#     정지 아트 = assets/sprites/chars/{종족}{_evolved|_evolved2}/idle.png
#
# 왜 기준을 명시하는가: 이전 값들은 알파 임계값 0(투명이 아닌 모든 픽셀)으로 잡혀 있었다.
# 128px 정지 아트는 외곽 안티에일리어싱 비중이 커서 두 기준이 최대 7.7% 갈린다
# (모찌 base 78px vs 72px). 큰 시트 셀은 둔감하므로 비율이 상쇄되지 않는다. 그래서 임계값을
# 적지 않으면 같은 "규약"으로 계산해도 사람마다 다른 값이 나왔다 — 10개 티어가 -4.6% ~ +4.0%로
# 흩어져 있었고, 그 상태로는 검사로 잠글 수도 없었다(허용차 ±8% > 검출 대상인 진화 사다리 9.26%).
# 지금은 10개 티어 전부 위 산식 하나로 재유도됐다(2026-08-11, 화면 크기 -7.8% ~ +2.4% 변동).
#
# 새 종족·티어를 넣을 때: 위 산식으로 계산한 뒤 **런타임 스모크로 애니메이션 경로와 정지 경로의
# 화면 몸통 높이가 같은지 확인하고** 넣어라. 계산만 믿지 마라 — 2026-08-10에 모찌 하나로 규약을
# 역산해 뚱실이 값을 유도했다가 임계값 차이 때문에 틀렸다(0.800 -> 0.7591).
#
# sheet_scale은 종족-티어 단위에만 둔다. 상태 단위 보정은 의도적으로 지원하지 않는다 —
# 상태마다 배율이 갈리면 "시트가 잘못 뽑혔다"와 "배율이 안 맞는다"를 데이터로 구분할 수 없다.
# 한 상태만 자기 티어 정지 포즈와 어긋나면 그건 그 시트를 다시 뽑으라는 신호다(2026-08-07 결정).
#
# "airborne": true — 그 상태의 foot_padding 프레임 간 변화가 "바운딩 박스 모양 차이"가 아니라
# "캐릭터가 지면에서 얼마나 떠 있는가"를 뜻한다는 선언(점프·매달림·낙하). 기본값 false(접지).
# 접지 상태는 매 프레임 발을 y=0에 재고정하지만, airborne 상태는 ground_padding 하나로만
# 고정 보정해서 프레임 간 padding 차이가 그대로 화면상 상승분이 된다. 이 선언이 없으면
# 재고정이 상승분을 정확히 상쇄해 공중 동작이 화면에서 전혀 보이지 않는다.
# "ground_padding": airborne 상태의 접지 기준값(생략 시 foot_padding 최솟값).
# "runtime_sick_mark": true — Sick 상태에서 sick_state.gd가 @_@ 라벨을 띄운다.
# 시트 그림 자체에 어지럼 표시(소용돌이 눈·부유 기호)가 없는 종족만 켠다(켜야 Sulk와 구분된다).
const ANIMATED_POSE_OVERRIDES := {
	# 모찌 계열: base(모찌)·evolved(프로찌)·evolved2(회찌) 3티어 각각 10상태 시트.
	# 크로마키는 티어마다 다르다(base 시안 / evolved 그린 / evolved2 시안) — 소재색과의 충돌을
	# 티어마다 실측 재판정한 결과다. 관성으로 복사하지 말 것(각 핸드오프 §4).
	# evolved2는 idle이 이미 셀 안전영역 천장(176 = 208-16-16)에 닿아 있어 Fall/Play의 세로
	# 스트레치가 idle보다 길어지지 못한다 — 진폭을 살리려면 그 티어만 셀을 키워 재추출해야 한다.
	"mochi": {
		# 2026-08-07(§12) evolved/evolved2 정지 아트가 256px로 복원되면서 BODY_SCALE이 ~1/2로
		# 내려갔다. 시트 자산은 그대로 128px이므로 sheet_scale에 art_ratio를 곱해 상쇄한다
		# (실효 배율 = BODY_SCALE x sheet_scale 은 크기 사다리 배율만큼만 커진다).
		# base 0.8450 = 정지 아트 코어 109 / 시트 Idle f0 129. 2026-08-12 Task #10에서 정지 아트만
		# 1.497배로 재생성했고(192 캔버스) 시트는 그대로라, 분자만 커진 만큼 이 값이 올라갔다.
		"sheet_scale": {"base": 0.8450, "evolved": 1.4304, "evolved2": 1.2644},
		"tiers": ["base", "evolved", "evolved2"],
		"states": {
			"Idle": {
				"base": {"path": "res://assets/sprites/mochi/idle_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 4.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-1.0, -1.0, -1.0, -1.0]},
				"evolved": {"path": "res://assets/sprites/mochi_evolved/idle_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 4.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-1.0, -1.0, -1.0, -0.5]},
				"evolved2": {"path": "res://assets/sprites/mochi_evolved2/idle_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 4.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-0.5, -0.5, -0.5, 0.0]},
			},
			"Walk": {
				"base": {"path": "res://assets/sprites/mochi/walk_8f_alpha_smooth.png", "columns": 4, "rows": 2, "frames": 8, "fps": 10.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-1.0, 1.0, 1.0, 1.0, 0.0, -1.0, -2.0, -2.0]},
				"evolved": {"path": "res://assets/sprites/mochi_evolved/walk_8f_alpha_smooth.png", "columns": 4, "rows": 2, "frames": 8, "fps": 10.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 1.0]},
				"evolved2": {"path": "res://assets/sprites/mochi_evolved2/walk_8f_alpha_smooth.png", "columns": 4, "rows": 2, "frames": 8, "fps": 10.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 1.0, 1.5, 1.0, 0.0, 1.0, 0.5, 1.0]},
			},
			"Sleep": {
				"base": {"path": "res://assets/sprites/mochi/sleep_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 5.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-0.5, -2.0, -1.5, -0.5]},
				"evolved": {"path": "res://assets/sprites/mochi_evolved/sleep_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 5.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-0.5, 0.0, 1.5, -0.5]},
				"evolved2": {"path": "res://assets/sprites/mochi_evolved2/sleep_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 5.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.0, 0.0, 0.0]},
			},
			"Eat": {
				"base": {"path": "res://assets/sprites/mochi/eat_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 6.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-2.0, -1.5, -1.0, -2.0]},
				"evolved": {"path": "res://assets/sprites/mochi_evolved/eat_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 6.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-0.5, 0.0, -0.5, -0.5]},
				"evolved2": {"path": "res://assets/sprites/mochi_evolved2/eat_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 6.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-1.0, 0.0, -0.5, -0.5]},
			},
			# 두 티어 모두 시트에 어지럼 표시가 없다(눈만 처짐) — 정지 포즈 sick.png가 갖고 있던
			# 소용돌이 눈 역할을 런타임 @_@ 라벨이 대신한다. 없으면 Sulk와 화면상 구분이 안 된다.
			"Sick": {
				"base": {"path": "res://assets/sprites/mochi/sick_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 6.0, "loop": true, "runtime_sick_mark": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-0.5, -4.0, 0.0, -4.0]},
				"evolved": {"path": "res://assets/sprites/mochi_evolved/sick_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 6.0, "loop": true, "runtime_sick_mark": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, -0.5, 0.5, 0.0]},
				# evolved2 시트에는 땀방울이 그려져 있지만 baby 단계에서 3~5px라 사실상 안 보인다 —
				# 세 티어 중 유일하게 시트 표시가 있는 티어이므로 화면 QA에서 중복 여부를 확인해야 한다.
				"evolved2": {"path": "res://assets/sprites/mochi_evolved2/sick_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 6.0, "loop": true, "runtime_sick_mark": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, -0.5, 0.5, 0.0]},
			},
			"Sulk": {
				"base": {"path": "res://assets/sprites/mochi/sulk_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 6.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-3.0, -3.0, -2.0, -1.0]},
				"evolved": {"path": "res://assets/sprites/mochi_evolved/sulk_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 6.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 6.0, 4.0, 4.0]},
				"evolved2": {"path": "res://assets/sprites/mochi_evolved2/sulk_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 6.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.0, 2.0, 6.0]},
			},
			# 놀기 리액션(Play 상태)에서 재생된다 — 정지 포즈 "happy"와 같은 자리.
			# base는 happy 시트, evolved는 play 시트로 파일명만 다르다.
			# 모찌의 공중 3상태(Play/Dragged/Fall)는 foot_padding이 16.0 고정이라(시트가 bottom-align으로
			# 합성됨) airborne 선언을 해도 화면 결과가 기존과 픽셀 단위로 동일하다 — 의도만 명시해 둔다.
			# 시트를 다시 뽑아 진폭을 살리는 날, 이 플래그가 이미 있어야 그 진폭이 화면에 나온다.
			"Play": {
				"base": {"path": "res://assets/sprites/mochi/happy_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 8.0, "loop": true, "airborne": true, "foot_padding": [16.0, 56.0, 28.0, 16.0], "horizontal_offsets": [-1.5, -1.0, -1.0, -1.0]},
				"evolved": {"path": "res://assets/sprites/mochi_evolved/play_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 8.0, "loop": true, "airborne": true, "foot_padding": [16.0, 42.0, 43.0, 16.0], "horizontal_offsets": [0.5, 0.0, 0.5, 0.0]},
				"evolved2": {"path": "res://assets/sprites/mochi_evolved2/play_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 8.0, "loop": true, "airborne": true, "foot_padding": [16.0, 30.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.0, 0.0, 0.0]},
			},
			"Dragged": {
				"base": {"path": "res://assets/sprites/mochi/dragged_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 10.0, "loop": true, "airborne": true, "foot_padding": [54.0, 16.0, 35.0, 49.0], "horizontal_offsets": [5.0, 0.5, 1.0, 4.0]},
				"evolved": {"path": "res://assets/sprites/mochi_evolved/dragged_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 10.0, "loop": true, "airborne": true, "foot_padding": [58.0, 57.0, 16.0, 45.0], "horizontal_offsets": [-1.0, 3.5, 0.5, -1.5]},
				"evolved2": {"path": "res://assets/sprites/mochi_evolved2/dragged_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 10.0, "loop": true, "airborne": true, "foot_padding": [58.0, 49.0, 16.0, 41.0], "horizontal_offsets": [1.0, -6.0, 2.5, 3.5]},
			},
			"Fall": {
				"base": {"path": "res://assets/sprites/mochi/fall_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": false, "airborne": true, "foot_padding": [41.0, 31.0, 23.0, 16.0], "horizontal_offsets": [0.0, 0.0, 0.0, 0.0]},
				"evolved": {"path": "res://assets/sprites/mochi_evolved/fall_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": false, "airborne": true, "foot_padding": [58.0, 39.0, 22.0, 16.0], "horizontal_offsets": [-0.5, 0.0, -0.5, 0.0]},
				"evolved2": {"path": "res://assets/sprites/mochi_evolved2/fall_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": false, "airborne": true, "foot_padding": [58.0, 42.0, 27.0, 16.0], "horizontal_offsets": [0.0, 3.0, 2.5, 2.5]},
			},
			"Land": {
				"base": {"path": "res://assets/sprites/mochi/land_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 10.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, -1.0, -2.0, -1.5]},
				"evolved": {"path": "res://assets/sprites/mochi_evolved/land_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 10.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.0, 0.0, 0.5]},
				"evolved2": {"path": "res://assets/sprites/mochi_evolved2/land_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 10.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, -1.0, 0.0, -0.5]},
			},
			# 아래 4상태는 시트에 소품을 그리지 않는다 — 런타임이 이미 그리기 때문이다.
			# 응아는 별도 엔티티(scenes/pet/poop.tscn)로 월드에 스폰되고, 파일은 드래그 중인 OS
			# 아이콘이며, 쓰다듬는 손 자리에는 마우스 커서가 있다. 시트에 그리면 이중으로 보인다.
			"FileHover": {
				"base": {"path": "res://assets/sprites/mochi/file_hover_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-1.5, -2.5, -2.5, -1.5]},
				"evolved": {"path": "res://assets/sprites/mochi_evolved/file_hover_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-1.0, 0.5, -0.5, -1.0]},
				"evolved2": {"path": "res://assets/sprites/mochi_evolved2/file_hover_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, -0.5, 0.0, -0.5]},
			},
			"FileConsume": {
				"base": {"path": "res://assets/sprites/mochi/file_consume_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-1.5, 0.0, -1.0, -1.0]},
				"evolved": {"path": "res://assets/sprites/mochi_evolved/file_consume_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.0, 0.0, 0.0]},
				"evolved2": {"path": "res://assets/sprites/mochi_evolved2/file_consume_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.0, -1.0, 0.5]},
			},
			"Poop": {
				"base": {"path": "res://assets/sprites/mochi/poop_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 6.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-0.5, 0.5, -0.5, -0.5]},
				"evolved": {"path": "res://assets/sprites/mochi_evolved/poop_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 6.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.0, 0.0, 0.0]},
				"evolved2": {"path": "res://assets/sprites/mochi_evolved2/poop_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 6.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.0, 0.5, -0.5]},
			},
			# Pet(쓰다듬기 반응)과 Play(놀기)는 별개 상태다 — base의 Play는 happy 시트를 쓴다.
			"Pet": {
				"base": {"path": "res://assets/sprites/mochi/pet_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 10.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-2.0, -2.0, -1.0, -2.0]},
				"evolved": {"path": "res://assets/sprites/mochi_evolved/pet_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 10.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-1.0, 0.0, 0.0, -1.0]},
				"evolved2": {"path": "res://assets/sprites/mochi_evolved2/pet_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 10.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.0, 0.0, 0.0]},
			},
		},
	},
	# 삐약 계열: 14상태 전부 애니메이션 시트, 3티어(base/evolved/evolved2) 각각 별도 시트.
	# 2026-08-11 리메이크는 192x208 셀로 올려 실제 표시 크기에서 원본을 확대하지 않고 축소 샘플링한다.
	# 이전 128x128 시트는 정지 포즈 캔버스와 같아 sheet_scale이 필요 없다고 봤지만 틀렸다
	# (2026-08-07 수정). 셀 크기가 같아도 그 안에 그려진 몸통 높이가 정지 포즈 아트와 다르면
	# BODY_SCALE(정지 포즈 몸통 기준으로 정규화된 값)이 그대로 어긋난다. 실측 결과 애니메이션이
	# 자기 정지 포즈보다 base -12.6%, evolved -13.0%로 작았고, evolved2만 우연히 맞아서
	# 진화하는 순간 몸통이 12.7% 커져 보였다("진화는 모양만 바뀐다" 규칙 위반).
	# 보정값 = 그 티어 정지 idle.png 몸통 높이 / 그 티어 시트 몸통 높이.
	# 2026-08-07 재보정: 몸통 실측 기준을 VISIBLE_ALPHA(α>0.125)로 바꾸면서 세 값을 다시 잡았다.
	# 예전 기준(α>0.001)은 거의 보이지 않는 안티에일리어싱 프린지까지 몸통으로 셌는데, 그 양이
	# 시트마다 달라(Idle 시트는 엣지가 하드해 프린지가 없고 Walk·정지 아트는 있다) 비교가 흔들렸다.
	#   base     115 / 98.5 = 1.168   evolved 111 / 93.5 = 1.187   evolved2 96 / 93.5 = 1.027
	# 각 티어에서 Idle/Walk/Eat 편차가 대칭이 되는 값이라 세 상태가 모두 ±0.6% 안에 들어온다.
	# 모찌와 동일한 규약(정지 몸통 / 시트 0번 프레임 몸통)이며, 세 티어 모두 자기 티어 정지 포즈에
	# 수렴한다 — 그 정지 포즈가 2026-08-07부터 몸통 기준(160px)으로 정규화되므로 시트도 같이 따라간다.
	# 같은 날 몸통 기준으로 다시 재본 결과 1.163/1.161/1.013으로 위 값과 ±2.2% 내라 유지했다.
	# Idle이 로드하는 시트는 idle_4f.png가 아니라 idle_blink_6f.png지만(깜박임을 살리려고 교체됨),
	# 위 값은 세 상태(Idle/Walk/Eat)를 함께 맞춘 값이라 상태 단위 보정이 필요 없다 — 실측 편차는
	# Idle -0.5% / Walk +0.5% / Eat -0.5% 수준이다. Land(착지 스쿼시)·Sleep(엎드림)처럼 셀 몸통이
	# 원래 10~20% 낮은 상태는 그게 아트의 의도이므로 애초에 보정 대상이 아니다.
	# 리메이크 접지 상태의 foot_padding은 16.0 고정이고, Happy(=Play)/Dragged/Fall만 의도적으로 공중에
	# 뜨므로 프레임마다 값이 커진다 — 이 값이 점프/부유 높이를 만든다(핸드오프 v3 실측).
	# 그 세 상태는 반드시 "airborne": true 를 달아야 한다. 없으면 매 프레임 발 재고정이
	# 상승분을 그대로 상쇄해 화면에서 전혀 뜨지 않는다(2026-08-06 QA 블로커).
	"ppiyak": {
		# 2026-08-11 리메이크 Idle 몸통 높이 152px을 각 티어 정지 아트 크기에 맞춘 값이다.
		# 실효 배율은 이전 런타임 표시 크기를 유지하되 고해상도 시트를 축소해 선명도를 확보한다.
		"sheet_scale": {"base": 0.7570, "evolved": 1.4416, "evolved2": 1.2505},
		"states": {
			"Idle": {
				# 물리 6칸을 sprite_frame_sequence로 논리 16프레임에 매핑한다(bichon Idle과 같은 방식).
				# frames=6으로 줄이면 눈 감는 셀 4·5에 도달하지 못해 깜박임이 조용히 사라진다.
				"base": {"path": "res://assets/sprites/ppiyak/idle_blink_6f_remake.png", "columns": 6, "rows": 1, "frames": 16, "fps": 8.0, "loop": true, "sprite_frame_sequence": [0, 0, 1, 1, 2, 2, 3, 3, 0, 4, 5, 4, 0, 0, 2, 2], "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.5, 0.5, 0.5, 0.0, 0.0, 0.0, 0.0, 0.5, 0.0, 0.0, 0.0, 0.5, 0.5, 0.0, 0.0]},
				"evolved": {"path": "res://assets/sprites/ppiyak_evolved/idle_blink_6f_remake.png", "columns": 6, "rows": 1, "frames": 16, "fps": 8.0, "loop": true, "sprite_frame_sequence": [0, 0, 1, 1, 2, 2, 3, 3, 0, 4, 5, 4, 0, 0, 2, 2], "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.5, 0.0, 0.0, 0.5, 0.5, 0.0, 0.0, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5]},
				"evolved2": {"path": "res://assets/sprites/ppiyak_evolved2/idle_blink_6f_remake.png", "columns": 6, "rows": 1, "frames": 16, "fps": 8.0, "loop": true, "sprite_frame_sequence": [0, 0, 1, 1, 2, 2, 3, 3, 0, 4, 5, 4, 0, 0, 2, 2], "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.0, 0.0]},
			},
			# 기본 시트는 왼쪽을 향한다(bichon과 동일) — 오른쪽 이동은 flip_h.
			"Walk": {
				"base": {"path": "res://assets/sprites/ppiyak/walk_8f_remake.png", "columns": 4, "rows": 2, "frames": 8, "fps": 10.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.5, 0.5, 0.5, 0.0, 0.5, 0.0, 0.5]},
				"evolved": {"path": "res://assets/sprites/ppiyak_evolved/walk_8f_remake.png", "columns": 4, "rows": 2, "frames": 8, "fps": 10.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.5, 0.5, 0.5, 0.5, 0.5, 0.0, 0.5]},
				"evolved2": {"path": "res://assets/sprites/ppiyak_evolved2/walk_8f_remake.png", "columns": 4, "rows": 2, "frames": 8, "fps": 10.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.5, 0.5, 0.5, 0.0, 0.0, 0.5, 0.0]},
			},
			"Sleep": {
				"base": {"path": "res://assets/sprites/ppiyak/sleep_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 4.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.0, 0.0, 0.5, 0.5, 0.0]},
				"evolved": {"path": "res://assets/sprites/ppiyak_evolved/sleep_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 4.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.5, 0.0, 0.5, 0.5, 0.5]},
				"evolved2": {"path": "res://assets/sprites/ppiyak_evolved2/sleep_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 4.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.0, 0.0, 0.5, 0.5, 0.5]},
			},
			"Eat": {
				"base": {"path": "res://assets/sprites/ppiyak/eat_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 8.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.5, 0.5, 0.5, 0.0, 0.0]},
				"evolved": {"path": "res://assets/sprites/ppiyak_evolved/eat_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 8.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.5, 0.0, 0.0, 0.5, 0.0]},
				"evolved2": {"path": "res://assets/sprites/ppiyak_evolved2/eat_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 8.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.5, 0.5, 0.0, 0.0, 0.0]},
			},
			# 시트에 부유 기호가 없다 — @_@ 라벨은 런타임(sick_state.gd)이 따로 띄운다.
			"Sick": {
				"base": {"path": "res://assets/sprites/ppiyak/sick_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 5.0, "loop": true, "runtime_sick_mark": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.5, 0.5, 0.5, 0.5, 0.0]},
				"evolved": {"path": "res://assets/sprites/ppiyak_evolved/sick_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 5.0, "loop": true, "runtime_sick_mark": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.5, 0.5, 0.5, 0.0, 0.0]},
				"evolved2": {"path": "res://assets/sprites/ppiyak_evolved2/sick_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 5.0, "loop": true, "runtime_sick_mark": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.0, 0.0, 0.0, 0.5, 0.0]},
			},
			"Sulk": {
				"base": {"path": "res://assets/sprites/ppiyak/sulk_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 5.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.5, 0.0, 0.0, 0.5, 0.5]},
				"evolved": {"path": "res://assets/sprites/ppiyak_evolved/sulk_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 5.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.0, 0.0, 0.5, 0.0, 0.5]},
				"evolved2": {"path": "res://assets/sprites/ppiyak_evolved2/sulk_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 5.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.0, 0.5, 0.0, 0.0, 0.0]},
			},
			# happy 시트는 놀기 리액션(Play 상태)에서 재생된다 — state_machine에 "Happy" 상태는 없다.
			"Play": {
				"base": {"path": "res://assets/sprites/ppiyak/happy_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 8.0, "loop": true, "airborne": true, "foot_padding": [16.0, 27.0, 33.0, 21.0, 30.0, 16.0], "horizontal_offsets": [0.5, 0.5, 0.5, 0.5, 0.5, 0.5]},
				"evolved": {"path": "res://assets/sprites/ppiyak_evolved/happy_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 8.0, "loop": true, "airborne": true, "foot_padding": [16.0, 16.0, 31.0, 16.0, 31.0, 16.0], "horizontal_offsets": [0.5, 0.0, 0.5, 0.0, 0.0, 0.5]},
				"evolved2": {"path": "res://assets/sprites/ppiyak_evolved2/happy_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 8.0, "loop": true, "airborne": true, "foot_padding": [16.0, 39.0, 24.0, 39.0, 40.0, 16.0], "horizontal_offsets": [0.0, 0.5, 0.0, 0.0, 0.0, 0.0]},
			},
			"Dragged": {
				"base": {"path": "res://assets/sprites/ppiyak/dragged_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 10.0, "loop": true, "airborne": true, "foot_padding": [19.0, 24.0, 16.0, 21.0], "horizontal_offsets": [0.5, 0.0, 0.5, 0.0]},
				"evolved": {"path": "res://assets/sprites/ppiyak_evolved/dragged_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 10.0, "loop": true, "airborne": true, "foot_padding": [19.0, 19.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.5, 0.0, 0.5]},
				"evolved2": {"path": "res://assets/sprites/ppiyak_evolved2/dragged_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 10.0, "loop": true, "airborne": true, "foot_padding": [22.0, 21.0, 19.0, 16.0], "horizontal_offsets": [0.5, 0.0, 0.5, 0.5]},
			},
			"Fall": {
				"base": {"path": "res://assets/sprites/ppiyak/fall_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": false, "airborne": true, "foot_padding": [18.0, 30.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.0, 0.0, 0.5]},
				"evolved": {"path": "res://assets/sprites/ppiyak_evolved/fall_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": false, "airborne": true, "foot_padding": [34.0, 24.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.0, 0.5, 0.0]},
				"evolved2": {"path": "res://assets/sprites/ppiyak_evolved2/fall_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": false, "airborne": true, "foot_padding": [34.0, 24.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.5, 0.5, 0.0]},
			},
			# 착지 스쿼시 -> 기립 복귀. 9상태 중 유일하게 loop=false (bichon Land와 동일).
			"Land": {
				"base": {"path": "res://assets/sprites/ppiyak/land_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 10.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.0, 0.0, 0.5]},
				"evolved": {"path": "res://assets/sprites/ppiyak_evolved/land_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 10.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.5, 0.5, 0.0]},
				"evolved2": {"path": "res://assets/sprites/ppiyak_evolved2/land_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 10.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.0, 0.5, 0.0]},
			},
			# 아래 4상태는 시트에 소품을 그리지 않는다 — 응아는 별도 엔티티(poop.tscn), 파일은 OS
			# 드래그 아이콘, 쓰다듬는 손 자리에는 마우스 커서가 있다. 그리면 이중으로 보인다.
			# 4상태 전부 접지(발바닥 기준선 16 고정)이므로 airborne 선언이 없다.
			"FileHover": {
				"base": {"path": "res://assets/sprites/ppiyak/file_hover_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.0, 0.0, 0.5]},
				"evolved": {"path": "res://assets/sprites/ppiyak_evolved/file_hover_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.0, 0.0, 0.0]},
				"evolved2": {"path": "res://assets/sprites/ppiyak_evolved2/file_hover_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.5, 0.5, 0.5]},
			},
			"FileConsume": {
				"base": {"path": "res://assets/sprites/ppiyak/file_consume_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 12.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.0, 0.0, 0.5, 0.5, 0.5]},
				"evolved": {"path": "res://assets/sprites/ppiyak_evolved/file_consume_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 12.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.0, 0.0, 0.0, 0.0, 0.5]},
				"evolved2": {"path": "res://assets/sprites/ppiyak_evolved2/file_consume_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 12.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.0, 0.0, 0.0, 0.5, 0.0]},
			},
			"Poop": {
				"base": {"path": "res://assets/sprites/ppiyak/poop_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 6.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.0, 0.5, 0.0, 0.5, 0.5]},
				"evolved": {"path": "res://assets/sprites/ppiyak_evolved/poop_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 6.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.0, 0.5, 0.5, 0.5, 0.5]},
				"evolved2": {"path": "res://assets/sprites/ppiyak_evolved2/poop_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 6.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.5, 0.5, 0.0, 0.5, 0.5]},
			},
			"Pet": {
				"base": {"path": "res://assets/sprites/ppiyak/pet_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 10.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.0, 0.0, 0.0, 0.5, 0.5]},
				"evolved": {"path": "res://assets/sprites/ppiyak_evolved/pet_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 10.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.0, 0.0, 0.5, 0.0, 0.5]},
				"evolved2": {"path": "res://assets/sprites/ppiyak_evolved2/pet_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 10.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.5, 0.5, 0.5, 0.0, 0.0]},
			},
		},
	},
	# 햄찌: base(햄찌)·evolved(함장님)·evolved2(햄왕) 3티어 각 14상태(셀 128x128, 기준선 12.0).
	# 세 티어 모두 애니메이션 시트가 있어 정지 포즈 폴백은 미등록 상태에서만 쓰인다.
	# evolved/evolved2 시트에는 착용물(셰프 토크·앞치마, evolved2는 금관 추가)이 전 프레임 유지되지만
	# 레퍼런스가 들고 있던 머핀과 두루마리(한글 "계약서")는 제외됐다 — Eat/Poop/FileHover 등 소품 금지
	# 상태와 오가며 깜빡이고, 128px에서 텍스트는 뭉개진 얼룩이 되기 때문이다(핸드오프 §4).
	# sheet_scale: base 1.083 = 정지 idle 코어 104 / 시트 idle f0 코어 96,
	#              evolved 1.125 = 정지 99 / 시트 88,
	#              evolved2 1.056 = 정지 94 / 시트 89 (전부 같은 검출기·같은 임계값으로 측정).
	# ⚠️ 여기의 104·96은 검출기 기준값이다. characters.gd의 BODY_CORE_HEIGHT[haemjji][base] = 96.0은
	# 이름이 같아도 다른 것 — 그건 정지 아트를 수작업 시각 실측한 감사 SSoT다(우연히 숫자가 겹친다).
	# 두 기준을 섞어 sheet_scale = 감사96 / 검출기96 = 1.000 으로 유도하면 안 된다. 감사 기준으로
	# 재유도하려면 시트 코어높이도 같은 수작업으로 재야 하고, 그 경우 88.6px이 나와야 1.083과 맞는다.
	# BODY_SCALE(base 1.667 / evolved 1.72)은 감사값을 쓰지만 그 방법은 알고리즘화되어 있지 않아
	# 시트에 적용할 수 없다. 그래서 "두 자산을 같은 자동 기준으로 잰 비율"을 쓴다.
	# 기준을 전체 실루엣으로 바꿔 교차검증하면 티어마다 편차가 다르다:
	#   base     113/104 = 1.087 → 등록값 1.083과 0.4% 차이
	#   evolved  115/104 = 1.106 → 등록값 1.125와 1.7% 차이
	#   evolved2 114/104 = 1.096 → 등록값 1.056과 3.8% 차이
	# ⚠️ 이 편차는 등록값이 틀려서가 아니라 실루엣 기준이 머리 장식이 있는 티어에서 편향돼서다.
	# 토크·금관은 몸통과 함께 축소되지 않는 고정 크기 요소라, 더 작은 시트에서 실루엣 대비 비중이
	# 커지고 그만큼 실루엣 비율만 끌려간다. 장식을 뺀 덩어리로 다시 재면 전부 제자리로 온다:
	#   evolved  105/94 = 1.117 → 등록값과 0.7% (2026-08-07 qa-verifier 실측)
	#   evolved2 101/96 = 1.052 → 등록값과 0.4% (머리 장식 정지 13px vs 시트 8px로 가장 비대칭)
	# 즉 장식이 클수록 실루엣 기준 편차가 커지고(0.4 → 1.7 → 3.8%), 덩어리 기준은 0.4~0.7%로 일정하다.
	# 교훈: 모자·관처럼 고정 크기 장식이 붙는 티어는 실루엣 기준 교차검증을 믿지 말고 장식을 뺀
	# 덩어리로 재라(위에서부터 최대폭 45% 미만인 구간을 장식으로 보면 세 티어 모두 재현된다).
	# 감사 방식 재측정은 권하지 않는다 — 감사값은 자동 재현이 안 되고(구현마다 ±10px) 사람이
	# 다시 재도 또 다른 값이 나온다. 감사값을 분자로 섞으면(93/89 = 1.045) 기준 혼용이 된다.
	# 뚱실이: 3티어 전부 시트가 있다(2026-08-11 완비). 정지 폴백 경로를 타는 티어가 없어져
	# CHARACTERS의 walk_static/walk_face_inverted를 제거했다 — 두 플래그는 walk_state.gd가
	# 시트 재생에 실패했을 때만 읽는데 이제 그 분기에 도달하지 않는다.
	# sleep_art_lacks_zzz는 처음부터 넣지 않았다: 시트 경로는 sleep_state.gd가 라벨을 무조건
	# 붙이므로 불필요하고, 정지 아트에는 z가 그려져 있어 켜면 이중 표시가 된다.
	"ddungsil": {
		# 확정 산식(VISIBLE_ALPHA). 시트 Idle f0은 3티어 공통 135px이고 정지 아트만 다르다:
		#   base 104 / 135 = 0.7704   evolved 200 / 135 = 1.4815   evolved2 158 / 135 = 1.1704
		"sheet_scale": {"base": 0.7704, "evolved": 1.4815, "evolved2": 1.1704},
		"tiers": ["base", "evolved", "evolved2"],
		"states": {
			"Idle": {
				"base": {"path": "res://assets/sprites/ddungsil/idle_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 4.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.5, 0.5, 0.5]},
				"evolved": {"path": "res://assets/sprites/ddungsil_evolved/idle_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 4.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.0, 0.5, 0.5]},
				"evolved2": {"path": "res://assets/sprites/ddungsil_evolved2/idle_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 4.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.5, 0.5, 0.0]},
			},
			"Walk": {
				"base": {"path": "res://assets/sprites/ddungsil/walk_8f_remake.png", "columns": 4, "rows": 2, "frames": 8, "fps": 10.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.0, 0.0, 0.5, 0.0, 0.0, 0.5, 0.0]},
				"evolved": {"path": "res://assets/sprites/ddungsil_evolved/walk_8f_remake.png", "columns": 4, "rows": 2, "frames": 8, "fps": 10.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.5, 0.5, 0.5, 0.0, 0.5, 0.0, 0.5]},
				"evolved2": {"path": "res://assets/sprites/ddungsil_evolved2/walk_8f_remake.png", "columns": 4, "rows": 2, "frames": 8, "fps": 10.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.0, 0.5, 0.0, 0.0, 0.5, 0.5, 0.0]},
			},
			"Sleep": {
				"base": {"path": "res://assets/sprites/ddungsil/sleep_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 4.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.5, 0.5, -0.5, 0.5, 0.5]},
				"evolved": {"path": "res://assets/sprites/ddungsil_evolved/sleep_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 4.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.0, 0.5, -0.5, 0.0, 0.5]},
				"evolved2": {"path": "res://assets/sprites/ddungsil_evolved2/sleep_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 4.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.5, 0.5, -0.5, -0.5, 0.5]},
			},
			"Eat": {
				"base": {"path": "res://assets/sprites/ddungsil/eat_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 6.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.0, 0.5, 0.5]},
				"evolved": {"path": "res://assets/sprites/ddungsil_evolved/eat_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 6.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.5, 0.0, 0.0]},
				"evolved2": {"path": "res://assets/sprites/ddungsil_evolved2/eat_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 6.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.0, 0.0, 0.5]},
			},
			"Sick": {
				"base": {"path": "res://assets/sprites/ddungsil/sick_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 5.0, "loop": true, "runtime_sick_mark": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-0.5, 0.5, 0.0, 0.5, 0.0, 0.0]},
				"evolved": {"path": "res://assets/sprites/ddungsil_evolved/sick_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 5.0, "loop": true, "runtime_sick_mark": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.5, -0.5, 0.5, 0.5, 0.0]},
				"evolved2": {"path": "res://assets/sprites/ddungsil_evolved2/sick_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 5.0, "loop": true, "runtime_sick_mark": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-0.5, 0.0, 0.0, 0.0, 0.0, 0.0]},
			},
			"Sulk": {
				"base": {"path": "res://assets/sprites/ddungsil/sulk_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 5.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-0.5, 0.0, 0.5, 0.5, 0.5, 0.5]},
				"evolved": {"path": "res://assets/sprites/ddungsil_evolved/sulk_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 5.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.0, 0.0, -0.5, 0.0, 0.5]},
				"evolved2": {"path": "res://assets/sprites/ddungsil_evolved2/sulk_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 5.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-0.5, 0.0, 0.0, -0.5, -0.5, 0.0]},
			},
			"Play": {
				"base": {"path": "res://assets/sprites/ddungsil/play_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 8.0, "loop": true, "airborne": true, "foot_padding": [16.0, 49.0, 50.0, 42.0, 19.0, 16.0], "horizontal_offsets": [0.0, -0.5, 0.5, -0.5, 0.5, 0.0]},
				"evolved": {"path": "res://assets/sprites/ddungsil_evolved/play_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 8.0, "loop": true, "airborne": true, "foot_padding": [16.0, 26.0, 53.0, 25.0, 27.0, 16.0], "horizontal_offsets": [0.0, 0.0, -0.5, 0.0, 0.5, 0.0]},
				"evolved2": {"path": "res://assets/sprites/ddungsil_evolved2/play_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 8.0, "loop": true, "airborne": true, "foot_padding": [18.0, 17.0, 39.0, 32.0, 16.0, 16.0], "horizontal_offsets": [-0.5, -0.5, 0.5, 0.0, 0.5, 0.5]},
			},
			"Dragged": {
				"base": {"path": "res://assets/sprites/ddungsil/dragged_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 10.0, "loop": true, "airborne": true, "foot_padding": [32.0, 16.0, 21.0, 31.0], "horizontal_offsets": [0.5, 0.0, 0.0, 0.5]},
				"evolved": {"path": "res://assets/sprites/ddungsil_evolved/dragged_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 10.0, "loop": true, "airborne": true, "foot_padding": [36.0, 33.0, 16.0, 36.0], "horizontal_offsets": [0.5, 0.5, 0.0, 0.5]},
				"evolved2": {"path": "res://assets/sprites/ddungsil_evolved2/dragged_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 10.0, "loop": true, "airborne": true, "foot_padding": [42.0, 38.0, 16.0, 28.0], "horizontal_offsets": [0.5, 0.0, 0.0, 0.5]},
			},
			# Fall은 일회성 하강 호다 — loop이면 착지 직전 스쿼시에서 최고점으로 되돌아 튄다.
			# 1주기 0.333초 = 낙하 133px이라 드래그마다 걸린다(Land와 같은 처리로 맞춘 것이다).
			"Fall": {
				"base": {"path": "res://assets/sprites/ddungsil/fall_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": false, "airborne": true, "foot_padding": [70.0, 51.0, 28.0, 16.0], "horizontal_offsets": [0.5, 0.5, 0.5, 0.5]},
				"evolved": {"path": "res://assets/sprites/ddungsil_evolved/fall_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": false, "airborne": true, "foot_padding": [73.0, 53.0, 35.0, 16.0], "horizontal_offsets": [-0.5, 0.5, 0.0, 0.5]},
				"evolved2": {"path": "res://assets/sprites/ddungsil_evolved2/fall_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": false, "airborne": true, "foot_padding": [67.0, 46.0, 23.0, 16.0], "horizontal_offsets": [-0.5, 0.0, 0.5, 0.0]},
			},
			"Land": {
				"base": {"path": "res://assets/sprites/ddungsil/land_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 10.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.0, 0.0, 0.0]},
				"evolved": {"path": "res://assets/sprites/ddungsil_evolved/land_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 10.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.5, 0.5, 0.5]},
				"evolved2": {"path": "res://assets/sprites/ddungsil_evolved2/land_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 10.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.5, 0.0, 0.5]},
			},
			"FileHover": {
				"base": {"path": "res://assets/sprites/ddungsil/file_hover_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.0, 0.5, 0.5]},
				"evolved": {"path": "res://assets/sprites/ddungsil_evolved/file_hover_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-0.5, 0.0, 0.0, 0.0]},
				"evolved2": {"path": "res://assets/sprites/ddungsil_evolved2/file_hover_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.0, 0.0, 0.5]},
			},
			"FileConsume": {
				"base": {"path": "res://assets/sprites/ddungsil/file_consume_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-0.5, 0.0, 0.5, -0.5]},
				"evolved": {"path": "res://assets/sprites/ddungsil_evolved/file_consume_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.0, 0.5, 0.5]},
				"evolved2": {"path": "res://assets/sprites/ddungsil_evolved2/file_consume_4f_remake.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.5, 0.5, 0.0]},
			},
			"Poop": {
				"base": {"path": "res://assets/sprites/ddungsil/poop_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 6.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.0, 0.5, 0.0, 0.5, 0.5]},
				"evolved": {"path": "res://assets/sprites/ddungsil_evolved/poop_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 6.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-0.5, 0.0, 0.0, -0.5, -0.5, 0.0]},
				"evolved2": {"path": "res://assets/sprites/ddungsil_evolved2/poop_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 6.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.5, 0.0, 0.5, 0.0, 0.5, 0.5]},
			},
			"Pet": {
				"base": {"path": "res://assets/sprites/ddungsil/pet_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 10.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.0, 0.5, 0.5, 0.0, 0.5]},
				"evolved": {"path": "res://assets/sprites/ddungsil_evolved/pet_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 10.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, 0.0, 0.0, 0.5, 0.0, 0.0]},
				"evolved2": {"path": "res://assets/sprites/ddungsil_evolved2/pet_6f_remake.png", "columns": 6, "rows": 1, "frames": 6, "fps": 10.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-0.5, 0.0, 0.5, 0.5, 0.0, 0.0]},
			},
		},
	},
}

const GENERATED_MOTION_SPECIES := [
	"kkubeok", "nyang", "kong", "mundeok", "geobujang", "bulgeumjo",
	"seureureuk", "tokki",
]
# 정지 아트 코어 / 시트 Idle f0 (양쪽 VISIBLE_ALPHA). 분모는 `generated_motion_config()`가
# 로드하는 현행 `_motion` 세대 시트의 f0이다 — 8종 모두 아직 한 세대뿐이라 지금은 어긋남이 없다
# (파리티 24조합 0.00%). 다음 세대 시트로 경로를 바꾸면 f0이 달라지므로 이 표를 함께 재유도해야
# 한다. haemjji가 `_alpha_smooth` -> `_remake` 전환에서 이 표를 안 고쳐 애니메이션 몸통이 +68.9%
# 커진 적이 있다(HAEMJJI_REMAKE_SHEET_SCALE 주석 참고).
const GENERATED_MOTION_SHEET_SCALE := {
	"kkubeok": {"base": 1.0, "evolved": 1.5775, "evolved2": 1.5766},
	"nyang": {"base": 1.0, "evolved": 1.5764, "evolved2": 1.5745},
	"kong": {"base": 1.0, "evolved": 1.2727, "evolved2": 1.5764},
	"mundeok": {"base": 1.0, "evolved": 1.5778, "evolved2": 1.5725},
	"geobujang": {"base": 1.0, "evolved": 1.5745, "evolved2": 1.3293},
	"bulgeumjo": {"base": 1.0, "evolved": 1.5694, "evolved2": 1.3803},
	"seureureuk": {"base": 1.0, "evolved": 1.5734, "evolved2": 1.5778},
	"tokki": {"base": 1.0, "evolved": 1.0241, "evolved2": 1.1469},
}
# 2026-08-14: 위 경고가 그대로 현실이 됐다. `build_keypose_motion.py`의 셀 배율이 "변환 후 실측
# 크기 / (셀-24px)" 기준으로 바뀌면서 Idle f0 몸통이 커진 시트가 5개 생겼는데(bulgeumjo_evolved2,
# geobujang_evolved2, kong_evolved, tokki_evolved, tokki_evolved2) 재유도된 것은 kong뿐이었다.
# 나머지 4개는 애니메이션 몸통만 정지 아트보다 15~25% 크게 그려지고 있었다. 실측 재유도:
#   geobujang/evolved2 222/167, bulgeumjo/evolved2 196/142, tokki/evolved 170/166, tokki/evolved2 164/143
# 정지 아트 코어 / 시트 Idle f0 (양쪽 VISIBLE_ALPHA) = 113/179, 228/173, 226/184.
# 분모는 `haemjji_remake_config()`가 실제로 로드하는 192x208 셀 `_remake` 시트의 f0이다.
# 이전 값(1.066 / 2.1714 / 2.1731)은 128 셀 `_alpha_smooth` f0(106/105/104)에서 유도된 것인데,
# 런타임 경로가 `_remake`로 넘어간 뒤에도 남아 있어 애니메이션 상태에서만 몸통이 +68.9% 커져
# 있었다. `_test_render_path_parity`는 런타임 경로가 아니라 ANIMATED_POSE_OVERRIDES 상수 항목
# (haemjji에서는 이미 죽은 데이터)의 시트를 재기 때문에 이 어긋남을 통과시켰다.
const HAEMJJI_REMAKE_SHEET_SCALE := {"base": 0.6313, "evolved": 1.3179, "evolved2": 1.2283}
const HAEMJJI_REMAKE_AIRBORNE_PADDING := {
	"Play": {
		"base": [17.0, 50.0, 21.0, 16.0, 35.0, 17.0],
		"evolved": [16.0, 45.0, 19.0, 16.0, 47.0, 16.0],
		"evolved2": [16.0, 16.0, 25.0, 29.0, 16.0, 16.0],
	},
	"Dragged": {
		"base": [52.0, 16.0, 63.0, 27.0],
		"evolved": [24.0, 22.0, 16.0, 21.0],
		"evolved2": [22.0, 19.0, 16.0, 21.0],
	},
	"Fall": {
		"base": [29.0, 31.0, 21.0, 16.0],
		"evolved": [24.0, 27.0, 21.0, 16.0],
		"evolved2": [27.0, 23.0, 25.0, 16.0],
	},
}
const GENERATED_MOTION_STATES := {
	"Idle": {"file": "idle_6f_motion.png", "columns": 6, "rows": 1, "frames": 6, "fps": 4.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0]},
	"Walk": {"file": "walk_8f_motion.png", "columns": 4, "rows": 2, "frames": 8, "fps": 10.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0]},
	"Sleep": {"file": "sleep_6f_motion.png", "columns": 6, "rows": 1, "frames": 6, "fps": 4.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0]},
	"Eat": {"file": "eat_6f_motion.png", "columns": 6, "rows": 1, "frames": 6, "fps": 6.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0]},
	"Sick": {"file": "sick_6f_motion.png", "columns": 6, "rows": 1, "frames": 6, "fps": 5.0, "loop": true, "runtime_sick_mark": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0]},
	"Sulk": {"file": "sulk_6f_motion.png", "columns": 6, "rows": 1, "frames": 6, "fps": 5.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0]},
	"Play": {"file": "play_6f_motion.png", "columns": 6, "rows": 1, "frames": 6, "fps": 8.0, "loop": true, "airborne": true, "ground_padding": 16.0, "foot_padding": [16.0, 36.0, 56.0, 44.0, 26.0, 16.0]},
	"Dragged": {"file": "dragged_4f_motion.png", "columns": 4, "rows": 1, "frames": 4, "fps": 10.0, "loop": true, "airborne": true, "ground_padding": 16.0, "foot_padding": [40.0, 46.0, 38.0, 44.0]},
	"Fall": {"file": "fall_4f_motion.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": false, "airborne": true, "ground_padding": 16.0, "foot_padding": [40.0, 32.0, 24.0, 16.0]},
	"Land": {"file": "land_4f_motion.png", "columns": 4, "rows": 1, "frames": 4, "fps": 10.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0]},
	"FileHover": {"file": "file_hover_4f_motion.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0]},
	"FileConsume": {"file": "file_consume_4f_motion.png", "columns": 4, "rows": 1, "frames": 4, "fps": 12.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0]},
	"Poop": {"file": "poop_6f_motion.png", "columns": 6, "rows": 1, "frames": 6, "fps": 6.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0]},
	"Pet": {"file": "pet_6f_motion.png", "columns": 6, "rows": 1, "frames": 6, "fps": 10.0, "loop": false, "foot_padding": [16.0, 16.0, 16.0, 16.0, 16.0, 16.0]},
}


static func generated_motion_config(species: String, tier: String, state_name: String) -> Dictionary:
	if not (species in GENERATED_MOTION_SPECIES) or not GENERATED_MOTION_STATES.has(state_name):
		return {}
	var config: Dictionary = (GENERATED_MOTION_STATES[state_name] as Dictionary).duplicate(true)
	var suffix := "" if tier == "base" else "_" + tier
	config["path"] = "res://assets/sprites/chars/%s%s/%s" % [species, suffix, config["file"]]
	config.erase("file")
	var horizontal_offsets: Array[float] = []
	horizontal_offsets.resize(int(config["frames"]))
	horizontal_offsets.fill(0.0)
	config["horizontal_offsets"] = horizontal_offsets
	return config


static func haemjji_remake_config(tier: String, state_name: String) -> Dictionary:
	if not GENERATED_MOTION_STATES.has(state_name):
		return {}
	var config: Dictionary = (GENERATED_MOTION_STATES[state_name] as Dictionary).duplicate(true)
	var suffix := "" if tier == "base" else "_" + tier
	config["path"] = "res://assets/sprites/haemjji%s/%s" % [suffix, String(config["file"]).replace("_motion", "_remake")]
	config.erase("file")
	if HAEMJJI_REMAKE_AIRBORNE_PADDING.has(state_name):
		config["foot_padding"] = (HAEMJJI_REMAKE_AIRBORNE_PADDING[state_name] as Dictionary)[tier]
	var horizontal_offsets: Array[float] = []
	horizontal_offsets.resize(int(config["frames"]))
	horizontal_offsets.fill(0.0)
	config["horizontal_offsets"] = horizontal_offsets
	return config

var ps: Node
var machine: Node
var probe: Node = null            # scripts/platform/window_probe.gd (main이 주입)
var ground_y := 0.0
var screen_size := Vector2.ZERO
var primary_local: Rect2          # 1번 모니터 로컬 영역 (알 스폰 중앙 계산용)
var platform_id := -1             # 올라가 있는 창 핸들 (-1 = 지상)
var platform_rect := Rect2()
var jump_target_id := -1
var jump_target_rect := Rect2()
var jump_cooldown := 0.0          # 창 위 놀이 사이 휴식 (업무 비방해)

var _sprite: Sprite2D
var _zzz: Label
var _sick_mark: Label
var _food_prop: Sprite2D
var _food_prop_elapsed := 0.0
var _food_prop_duration := 0.0
var _food_prop_frame_count := 0   # 0 = 소품 프레임 진행 없음(숨김 상태)
var _last_food_action := ""     # "feed" | "snack" — Eat 진입 시 어떤 음식 소품을 보여줄지 판별
var _base_scale := Vector2.ONE
var _frame_size := Vector2.ONE * SPRITE_SIZE
var _pet_cooldown := 0.0
var _pressed := false
var _press_pos := Vector2.ZERO
var _bob_tween: Tween
var _wiggle_tween: Tween
var _wobble_tween: Tween
var _frames := {}          # pose -> Texture2D (포즈 시트 있는 캐릭터만)
var _pose := "idle"
var _bichon_animation := ""
var _bichon_elapsed := 0.0
var _bichon_frame := 0
var _bichon_override := ""
var _bichon_frame_foot_padding := []
var _bichon_frame_horizontal_offsets := []
var _bichon_sprite_frame_sequence := []
var _frame_airborne := false      # 현재 시트가 공중 동작인가 (config "airborne")
var _frame_ground_padding := 0.0  # 공중 동작의 접지 기준 foot_padding (config "ground_padding" 또는 배열 최솟값)
var _idle_tween: Tween
var _body_tier := "base"          # refresh_appearance()가 채움: base|evolved|evolved2
var _pose_override_active := false
var _pose_override_state := ""
# 진행 중인 반응 연출(Pet/FileHover/FileConsume)의 상태명. 이 셋은 상태머신 상태가 아니라
# 오버라이드라서, 지속시간이 끝나면 직전 상태로 되돌리기 위해 따로 기억해 둔다.
# 도중에 상태가 바뀌면 play_state_animation()이 비워서 뒤늦은 복귀를 취소한다.
var _pose_reaction_state := ""
var _pose_override_fps := 0.0
var _pose_override_frame_count := 0
var _pose_override_loop := true

# 위장/숨김 모드 (재시작 시 항상 normal — save에 저장 안 함)
var hide_mode: String = "normal"   # "normal" | "disguise" | "invisible"
var _disguise_textures: Array = []
# 익스포트 빌드에서 DirAccess 순회가 불안정하므로 파일명 하드코딩
const DISGUISE_FILES := [
	"calculator.png", "memo.png", "folder.png", "search.png",
	"usb.png", "hoodie.png", "mail.png", "trash.png",
]


func _ready() -> void:
	ps = get_node("/root/PetState")

	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_sprite)
	_zzz = _make_mark("Zzz", Color(0.55, 0.62, 0.85))
	_sick_mark = _make_mark("@_@", Color(0.45, 0.65, 0.45))
	_food_prop = Sprite2D.new()
	_food_prop.visible = false
	add_child(_food_prop)
	_load_disguise_textures()
	refresh_appearance()

	ps.species_assigned.connect(func(_s): refresh_appearance())
	ps.stage_changed.connect(func(_s): refresh_appearance())
	ps.care_performed.connect(_on_care_performed)
	ps.pooped.connect(_on_pooped)

	machine = load("res://scenes/pet/state_machine.gd").new()
	machine.name = "StateMachine"
	add_child(machine)
	machine.setup(self)

	# 초기 스폰: 1번 모니터 중앙 (setup 후 state가 재배치할 수 있음)
	var start_x: float = primary_local.get_center().x if primary_local.size.x > 0.0 else screen_size.x * 0.5
	position = Vector2(start_x, ground_y)


func _process(delta: float) -> void:
	if _pet_cooldown > 0.0:
		_pet_cooldown -= delta
	_advance_bichon_animation(delta)
	_advance_food_prop(delta)
	if jump_cooldown > 0.0:
		jump_cooldown -= delta


func _input(event: InputEvent) -> void:
	# 완전 숨김: 모든 입력 무시
	if hide_mode == "invisible":
		return
	# 위장 중 & 일반 모드: 상호작용 동일 (드래그·우클릭·클릭 모두 허용).
	# 자율 이동만 상태머신에서 별도로 정지시킴.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed and get_click_rect().has_point(event.position):
			care_menu_requested.emit(event.position)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		# 백업 종료 수단 (기본은 트레이 메뉴 '종료')
		if event.pressed and get_click_rect().has_point(event.position):
			_quit_app()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and get_click_rect().has_point(event.position):
			_pressed = true
			_press_pos = event.position
		elif not event.pressed and _pressed:
			_pressed = false
			if machine.current_name() != "Dragged":
				_short_click()
	elif event is InputEventMouseMotion and _pressed:
		if machine.current_name() != "Dragged" and ps.stage != "egg" \
				and event.position.distance_to(_press_pos) > DRAG_THRESHOLD:
			machine.transition_to("Dragged")


func is_mouse_pressed() -> bool:
	return _pressed


func start_jump(target_id: int, target_rect: Rect2) -> void:
	jump_target_id = target_id
	jump_target_rect = target_rect
	machine.transition_to("Jump")


func get_click_rect() -> Rect2:
	# 완전 숨김 중에만 클릭 영역 비움 (Windows SetWindowRgn이 렌더링도 잘라내므로
	# 위장 중에는 렌더 유지를 위해 영역을 그대로 반환. 클릭은 _input에서 차단.)
	if hide_mode == "invisible":
		return Rect2()
	# 애니메이션 시트는 캔버스에 여백이 많아 실제 보이는 크기를 별도로 환산한다.
	if _is_animated_pet():
		var size := SPRITE_SIZE * float(STAGE_SCALE.get(ps.stage, 0.5)) * _animated_visible_size_multiplier()
		return Rect2(global_position + Vector2(-size * 0.5, -size), Vector2(size, size)).grow(8.0)
	# Windows의 mouse-passthrough 영역은 입력뿐 아니라 렌더링도 실제로 자른다. 포즈 캐릭터는
	# 캐릭터마다 캔버스/배율이 크게 다른데 고정 75%x85% 클릭 사각형만 쓰면, 긴 귀·꼬리·당근·
	# 소품이 그 사각형 밖에서 잘린다. 런타임에 실제 그리는 셀 전체를 안전 영역으로 사용한다.
	# 하한을 두는 이유는 따로다: `_frame_size`가 아직 세팅되지 않은 스타트업 첫 프레임에는
	# 거의 0인 사각형이 나오고, 그러면 SetWindowRgn이 창 전체를 잘라 펫이 사라진다(v0.8.4).
	var frame_w: float = maxf(_frame_size.x * absf(_base_scale.x), MIN_RENDER_REGION_SIZE)
	var frame_h: float = maxf(_frame_size.y * absf(_base_scale.y), MIN_RENDER_REGION_SIZE)
	if _has_active_frame_animation():
		return Rect2(
			global_position + _sprite.position - Vector2(frame_w, frame_h) * 0.5,
			Vector2(frame_w, frame_h)
		).grow(_active_frame_edge_padding())
	# 정지 포즈는 캔버스 여백이 넓어 캐릭터가 실제 그려지는 영역만 감지한다(캔버스 대비 ~75%).
	# 나머지 여백까지 클릭을 막으면 펫이 지나가는 궤적이 넓게 blocked 되어 뒤 창 조작이 불편함.
	# 당근이는 긴 귀·당근·등 장식이 몸통 비율 사각형 밖까지 나가므로 정지 포즈에서도 캔버스
	# 전체가 Windows 렌더 영역에 들어가야 한다. 클릭 영역이 조금 넓어지는 대신 잘림을 막는다.
	var visible_ratio := 1.0 if ps.species == "tokki" else 0.75
	var w: float = frame_w * visible_ratio
	var h: float = frame_h * (1.0 if ps.species == "tokki" else 0.85)
	return Rect2(global_position + Vector2(-w * 0.5, -h - 4.0), Vector2(w, h))


## Windows의 mouse-passthrough 다각형은 입력뿐 아니라 실제 렌더링도 자른다. 드래그/낙하는
## 빠른 이동 때문에 이미 전체 영역을 쓰며, Eat은 손·지팡이처럼 셀 가장자리의 가는 소품이
## 32px 영역 갱신 지연에 잘릴 수 있어 재생 중에만 같은 보호를 적용한다.
func requires_full_render_region() -> bool:
	return machine.current_name() in ["Dragged", "Fall", "Eat"] \
		or _pose_override_state == "Eat"


func horizontal_edge_margin() -> float:
	if _is_animated_pet():
		return SPRITE_SIZE * float(STAGE_SCALE.get(ps.stage, 0.5)) * _animated_visible_size_multiplier() * 0.5 + _animated_edge_buffer()
	# 화면 끝에서 이동을 멈추는 기준도 실제 렌더 캔버스와 같아야 한다. 렌더 영역만 넓혀도
	# 중심점이 기존 고정 80px까지 접근하면 긴 귀·당근·소품이 모니터 밖으로 잘릴 수 있다.
	if _has_active_frame_animation() or ps.species == "tokki":
		return maxf(80.0,
			_frame_size.x * absf(_base_scale.x) * 0.5 + _active_frame_edge_padding())
	return 80.0


func _active_frame_edge_padding() -> float:
	return 24.0 if machine.current_name() == "Eat" or _pose_override_state == "Eat" else 16.0


func move_speed() -> float:
	var speed := BASE_SPEED * Characters.get_stat_modifier(ps.species, "move_speed")
	if ps.caffeine_until_min > 0.0:
		speed *= 2.0
	if ps.has_special("morning_speed"):
		var h: int = Time.get_datetime_dict_from_system().hour
		if h >= 7 and h < 10:
			speed *= 2.0
	return speed


## 좌우 반전이 금지된 종족. 시트에 **글자가 그려져 있으면** flip_h가 그 글자까지 뒤집어
## 거울 문자로 만든다 — 거부장은 배낭 명패에 "명예회장"이 그려진 유일한 캐릭터라
## 오른쪽으로 걷고 나면 그 뒤 모든 상태(먹기·잠자기·삐침…)에서 글자가 뒤집힌 채로 남았다.
## flip은 방향 표현이므로 이 종족은 항상 그려진 방향(왼쪽)을 유지한다 — 오른쪽으로 이동할 때
## 뒷걸음처럼 보이는 대신, 읽을 수 있는 명패를 얻는다. 글자 없는 나머지 12종은 그대로 반전한다.
const MIRROR_FORBIDDEN_SPECIES := ["geobujang"]


func _can_mirror() -> bool:
	return ps == null or not (ps.species in MIRROR_FORBIDDEN_SPECIES)


func face_towards(target_x: float) -> void:
	if not _can_mirror():
		_sprite.flip_h = false
		return
	_sprite.flip_h = target_x > position.x


func mirror_face() -> void:
	if _sprite and _can_mirror():
		_sprite.flip_h = not _sprite.flip_h


## 포즈 시트(assets/sprites/chars/<종족>/)가 있으면 프레임 시스템, 없으면 단일 컨셉 이미지 폴백
func has_poses() -> bool:
	return not _frames.is_empty()


func set_pose(pose: String) -> void:
	_pose = pose
	# 위장 중에는 아이콘 텍스처를 유지 (드래그 종료 후 Idle.enter 등에서 pose 리셋해도 안 바뀜)
	if hide_mode == "disguise":
		return
	# 애니메이션 시트가 재생 중이면 정지 포즈로 덮지 않는다. 상태 스크립트들은 enter()에서
	# set_pose()를 부르는데, 상태 전환 직전 play_state_animation()이 이미 시트를 걸어놨다.
	if _pose_override_active:
		return
	if _frames.has(pose):
		_sprite.texture = _frames[pose]


func refresh_appearance() -> void:
	_frames.clear()
	_pose = "idle"
	# 재적용 대상은 "직전에 실제로 재생 중이던 상태"뿐이다. 상태머신의 현재 상태를 쓰면
	# 아직 시트를 걸지 않은 구간(예: 삐약이 구석으로 걸어가는 Sleep 전반)에 시트가 조기 재생된다.
	# 단 반응 연출(Pet/FileHover/FileConsume)만은 예외로 되살리지 않는다 — 아래에서 복귀 예약을
	# 지우기 때문에 되살리면 끝내줄 주체가 없어 그 포즈에 멈춘다. 대신 상태머신의 현재 상태
	# (= 반응 직전 상태)로 되돌린다. 반응은 시간 제한이 있는 일회성이라 "끊긴 연출을 이어붙인다"는
	# resume_state의 취지에 애초에 해당하지 않는다.
	var resume_state := ""
	if _pose_override_active:
		var interrupted_reaction := _pose_override_state == _pose_reaction_state and machine != null
		resume_state = machine.current_name() if interrupted_reaction else _pose_override_state
	_pose_override_active = false
	_pose_override_state = ""
	_pose_reaction_state = ""   # 종족·단계가 바뀌면 진행 중이던 반응 연출의 복귀 예약도 무효다
	if _is_animated_pet():
		var state_name: String = machine.current_name() if machine != null else "Idle"
		var animation_name := _bichon_override if not _bichon_override.is_empty() else _animation_for_state(state_name)
		_set_bichon_animation(animation_name)
		return

	var char_key: String = "egg" if ps.stage == "egg" else ps.species
	var pose_list: Array = EGG_POSES if ps.stage == "egg" else POSES
	# 진화 완료 시 우선순위: evolved2 > evolved > 기본 (아트 없으면 순차 폴백)
	var dirs: Array = ["res://assets/sprites/chars/%s/" % char_key]
	if ps.evolved and ps.stage != "egg":
		dirs.push_front("res://assets/sprites/chars/%s_evolved/" % char_key)
	if ps.evolved_2 and ps.stage != "egg":
		dirs.push_front("res://assets/sprites/chars/%s_evolved2/" % char_key)
	_body_tier = "base"
	for dir_path in dirs:
		if not ResourceLoader.exists(dir_path + "idle.png"):
			continue
		if dir_path.ends_with("_evolved2/"):
			_body_tier = "evolved2"
		elif dir_path.ends_with("_evolved/"):
			_body_tier = "evolved"
		for pose in pose_list:
			var frame_path: String = dir_path + pose + ".png"
			if ResourceLoader.exists(frame_path):
				_frames[pose] = load(frame_path)
		break
	# 진화 모찌는 약 100px 표시 크기에 원본 선화가 1.5px/화면px 정도라 mipmap LOD가
	# 안경·정장 윤곽을 과도하게 무르게 만든다. 이 두 티어만 bilinear로 원본 선화를 보존한다.
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR \
		if ps.species == "mochi" and _body_tier in ["evolved", "evolved2"] \
		else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if _frames.has("idle"):
		_sprite.texture = _frames["idle"]
	else:
		_frames.clear()
		var path := "res://assets/sprites/concept/%s.png" % char_key
		if not ResourceLoader.exists(path):
			path = "res://assets/sprites/concept/mochi.png"  # Design §6: 리소스 폴백
		_sprite.texture = load(path)
	_sprite.hframes = 1
	_sprite.vframes = 1
	_sprite.frame = 0
	_bichon_frame = 0
	_bichon_sprite_frame_sequence = []
	_bichon_frame_foot_padding = []
	_bichon_frame_horizontal_offsets = []
	_frame_airborne = false
	_frame_ground_padding = 0.0
	# 임포트 캐시가 없거나 로드가 실패하면 texture가 null이므로 캔버스 기본값으로 폴백
	_frame_size = _sprite.texture.get_size() if _sprite.texture != null else Vector2.ONE * STATIC_POSE_FALLBACK_SIZE
	_base_scale = Vector2.ONE * _stage_scale() * _static_body_scale()
	_sprite.scale = _base_scale
	_sprite.position = _sprite_anchor()
	# Zzz·@_@ 라벨은 스프라이트 상단 근처에 (진화 배지는 제거됨 — 위쪽 클릭 영역 최소화)
	_update_mark_positions()
	# 포즈 캐릭터도 재생 중이던 시트를 다시 걸어준다 (비숑 분기와 대칭).
	# 이게 없으면 성장(stage_changed)·위장 해제·관리자 콘솔로 refresh가 불릴 때 정지 포즈로 떨어지고,
	# state_machine.transition_to()는 같은 상태로는 조기 반환하므로 다른 상태가 될 때까지 복구되지 않는다.
	if not resume_state.is_empty():
		start_animated_pose(resume_state)


# --- 상태별 표현 (states/*.gd에서 호출) ---

func play_state_animation(state_name: String) -> void:
	if _is_animated_pet():
		if _bichon_override.is_empty():
			_set_bichon_animation(_animation_for_state(state_name))
		return
	# 상태머신이 상태를 바꿨다는 뜻이므로 진행 중이던 반응 연출의 복귀 예약을 취소한다.
	# (취소하지 않으면 타이머가 뒤늦게 깨어나 새 상태를 이전 상태로 덮어쓴다.)
	_pose_reaction_state = ""
	# 포즈 캐릭터: 이 상태에 시트가 있으면 재생하고, 없으면 오버라이드를 끄고 정지 포즈로 돌아간다.
	if not start_animated_pose(state_name):
		stop_animated_pose()


## 반응 연출(케어·파일)이 끝난 뒤 상태머신의 현재 상태 시트로 되돌린다.
func _restore_pose_state_animation() -> void:
	_pose_reaction_state = ""
	play_state_animation(machine.current_name() if machine != null else "Idle")


func set_file_hover(active: bool) -> void:
	if _is_animated_pet():
		if active:
			_bichon_override = "FileHover"
			_set_bichon_animation(_bichon_override)
			return
		_bichon_override = ""
		_restore_bichon_state_animation()
		return
	# 포즈 캐릭터: FileHover는 상태머신 상태가 아니라 오버라이드 연출이라 직접 걸고 직접 되돌린다.
	if active:
		if start_animated_pose("FileHover"):
			_pose_reaction_state = "FileHover"
		return
	if _pose_reaction_state.is_empty():
		return
	_restore_pose_state_animation()


func play_file_drop_reaction() -> void:
	if _is_animated_pet():
		set_file_hover(true)
		await get_tree().create_timer(FILE_HOVER_DURATION).timeout
		if _bichon_override != "FileHover":
			return
		_bichon_override = "FileConsume"
		_set_bichon_animation(_bichon_override)
		await get_tree().create_timer(FILE_CONSUME_DURATION).timeout
		if _bichon_override == "FileConsume":
			set_file_hover(false)
		return
	set_file_hover(true)
	if _pose_reaction_state != "FileHover":
		return          # 이 종족엔 FileHover 시트가 없다 — 연출 없이 넘어간다.
	await get_tree().create_timer(FILE_HOVER_DURATION).timeout
	if _pose_reaction_state != "FileHover":
		return          # 그 사이 상태가 바뀌었다(드래그 등).
	if start_animated_pose("FileConsume"):
		_pose_reaction_state = "FileConsume"
	await get_tree().create_timer(FILE_CONSUME_DURATION).timeout
	if _pose_reaction_state == "FileConsume":
		_restore_pose_state_animation()


## 관리자 콘솔(QA용) — 종족/성장단계/진화단계를 즉시 바꾸고 화면을 새로고침한다.
## tier: "base" | "evolved" | "evolved2"
func debug_set_appearance(species: String, stage: String, tier: String) -> void:
	ps.species = species
	ps.stage = stage
	ps.evolved = tier != "base"
	ps.evolved_2 = tier == "evolved2"
	refresh_appearance()
	if machine != null:
		machine.transition_to("Egg" if stage == "egg" else "Idle")


## 관리자 콘솔(QA용) — 상태머신을 강제 전환한다. Sick/Sulk는 조건 플래그도 맞춰서
## _check_global()이 다음 프레임에 곧바로 되돌리지 않게 하고, 그 외 상태는 두 플래그를 꺼서
## 이전 강제 상태가 남아있지 않게 한다.
func debug_force_state(state_name: String) -> void:
	if machine == null:
		return
	ps.is_sick = state_name == "Sick"
	ps.is_sulking = state_name == "Sulk"
	machine.transition_to(state_name)


func _is_bichon() -> bool:
	return ps != null and ps.stage != "egg" and ps.species == "bichon"


func _is_animated_pet() -> bool:
	return _is_bichon()


## bichon류(전신 애니메이션 펫)뿐 아니라 포즈 캐릭터의 걷기/잠자기 오버라이드가 켜져 있을 때도 참.
## get_click_rect()/horizontal_edge_margin() 등 몸통 크기 계산은 이 조건을 쓰지 않는다 —
## 포즈 캐릭터는 걷는 동안에도 자기 몸통 크기(STAGE_SCALE*BODY_SCALE) 그대로 유지해야 한다.
func _has_active_frame_animation() -> bool:
	return _is_bichon() or _pose_override_active


func _animation_catalog() -> Dictionary:
	return BICHON_ANIMATIONS


func _animated_visible_size_multiplier() -> float:
	return BICHON_VISIBLE_SIZE_MULTIPLIER


func _animated_edge_buffer() -> float:
	return BICHON_EDGE_BUFFER


func _animation_for_state(state_name: String) -> String:
	var catalog := _animation_catalog()
	return state_name if catalog.has(state_name) else "Idle"


func _set_bichon_animation(animation_name: String) -> void:
	var catalog := _animation_catalog()
	var config: Dictionary = catalog.get(animation_name, catalog["Idle"])
	var path: String = config["path"]
	if not ResourceLoader.exists(path):
		push_error("Missing animated pet sprite sheet: %s" % path)
		return
	# 캐시 무시 로드 — 해솔의 상태별 시트는 장당 6~12MB(비압축 RGBA)라, 기본 캐시(load())로
	# 불러오면 한 세션에서 여러 상태를 거칠수록 전부 영구 누적된다(관찰된 상주 메모리 급증의
	# 주원인). CACHE_MODE_IGNORE로 불러오면 _sprite.texture가 교체되는 순간 참조가 끊겨
	# 즉시 해제되고, 현재 활성 상태 한 장만 메모리에 남는다. 같은 상태 재진입 시 디스크에서
	# 다시 디코딩하지만 이 크기(<1MB PNG)는 수십 ms 내로 체감 지연이 없다.
	var texture: Texture2D = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_sprite.texture = texture
	_sprite.hframes = int(config["columns"])
	_sprite.vframes = int(config["rows"])
	_sprite.frame = 0
	_frame_size = texture.get_size() / Vector2(_sprite.hframes, _sprite.vframes)
	var visible_extent: float = float(config.get("visible_extent", maxf(_frame_size.x, _frame_size.y)))
	var fit_scale := SPRITE_SIZE * _animated_visible_size_multiplier() / visible_extent
	_base_scale = Vector2.ONE * _stage_scale() * fit_scale
	_sprite.scale = _base_scale
	_bichon_animation = animation_name
	_bichon_elapsed = 0.0
	_apply_frame_offsets_from_config(config)
	_set_bichon_frame(0)
	_update_mark_positions()


func _advance_bichon_animation(delta: float) -> void:
	if _pose_override_active:
		_advance_override_frame(delta, _pose_override_fps, _pose_override_frame_count, _pose_override_loop)
		return
	if not _is_animated_pet() or _bichon_animation.is_empty():
		return
	var config: Dictionary = _animation_catalog().get(_bichon_animation, {})
	var fps: float = float(config.get("fps", 0.0))
	var frames: int = int(config.get("frames", 0))
	if fps <= 0.0 or frames <= 0:
		return
	_bichon_elapsed += delta
	var next_frame := int(_bichon_elapsed * fps)
	if bool(config.get("loop", true)):
		next_frame %= frames
	else:
		next_frame = mini(next_frame, frames - 1)
	_set_bichon_frame(next_frame)


## 포즈 캐릭터 오버라이드(걷기·잠자기) 공통 프레임 진행. bichon 카탈로그 경로와 달리
## 상태별 config를 매 프레임 조회하지 않고 진입 시 캐시해 둔 fps/frames/loop를 쓴다.
func _advance_override_frame(delta: float, fps: float, frame_count: int, loop: bool) -> void:
	if fps <= 0.0 or frame_count <= 0:
		return
	_bichon_elapsed += delta
	var override_frame := int(_bichon_elapsed * fps)
	if loop:
		override_frame %= frame_count
	else:
		override_frame = mini(override_frame, frame_count - 1)
	_set_bichon_frame(override_frame)


## 현재 종족·티어에서 이 상태에 걸린 시트 설정. 없으면 빈 딕셔너리.
func _pose_override_config(state_name: String) -> Dictionary:
	if ps == null or ps.stage == "egg":
		return {}
	if ps.species == "haemjji":
		return haemjji_remake_config(_body_tier, state_name)
	if ps.species in GENERATED_MOTION_SPECIES:
		return generated_motion_config(ps.species, _body_tier, state_name)
	var entry: Dictionary = ANIMATED_POSE_OVERRIDES.get(ps.species, {})
	# "tiers"가 있으면 그 티어에서만 시트를 쓴다 — 진화 단계 아트가 없는 종족은 정지 포즈로 폴백.
	var tiers: Array = entry.get("tiers", [])
	if not tiers.is_empty() and not (_body_tier in tiers):
		return {}
	var config: Dictionary = entry.get("states", {}).get(state_name, {})
	# 티어별 시트가 따로 있는 상태는 한 단 더 들어간다 (config에 "path"가 없으면 티어 딕셔너리).
	if not config.is_empty() and not config.has("path"):
		return config.get(_body_tier, {})
	return config


## 포즈 캐릭터의 한 상태를 다중 프레임 시트로 재생. state_machine의 상태 전환마다
## play_state_animation()이 호출하며, walk_state/sleep_state는 진입 시점을 직접 잡으려고
## start_animated_walk()/start_animated_sleep() 래퍼로 다시 부른다.
## 등록이 없으면 false를 반환해 호출부가 기존 정지 포즈로 폴백한다.
func start_animated_pose(state_name: String) -> bool:
	var config := _pose_override_config(state_name)
	if config.is_empty():
		return false
	var texture: Texture2D = load(String(config["path"]))
	if texture == null:
		return false
	# 정지 포즈용 호흡 트윈이 돌고 있으면 _sprite.scale이 _base_scale과 달라져
	# 프레임 앵커(_position_sprite_for_current_frame)가 발바닥을 아래로 밀어낸다.
	_kill_idle_breathe()
	_pose_override_active = true
	_pose_override_state = state_name
	_sprite.texture = texture
	_sprite.hframes = int(config["columns"])
	_sprite.vframes = int(config["rows"])
	_frame_size = texture.get_size() / Vector2(_sprite.hframes, _sprite.vframes)
	_apply_frame_offsets_from_config(config)
	_pose_override_fps = float(config.get("fps", 10.0))
	_pose_override_frame_count = int(config.get("frames", int(config["columns"]) * int(config["rows"])))
	_pose_override_loop = bool(config.get("loop", true))
	_bichon_elapsed = 0.0
	# idle과 같은 고정 배율 — 원본 시트의 스쿼시-스트레치만 자연스럽게 보이고 배율 자체는 흔들리지 않는다.
	_base_scale = Vector2.ONE * _stage_scale() * _pose_override_body_scale()
	_sprite.scale = _base_scale
	_set_bichon_frame(0)
	if state_name == "Eat":
		var margin := horizontal_edge_margin()
		position.x = clampf(position.x, margin, screen_size.x - margin)
	# 잠자기 중 Zzz 라벨 등 마커는 몸통 높이를 기준으로 붙는다.
	_update_mark_positions()
	return true


## 시트 재생 종료 후 정지 포즈로 복귀. 등록되지 않은 상태로 전환될 때도 호출된다.
func stop_animated_pose() -> void:
	if not _pose_override_active:
		return
	_pose_override_active = false
	_pose_override_state = ""
	_bichon_frame_foot_padding = []
	_bichon_frame_horizontal_offsets = []
	_bichon_sprite_frame_sequence = []
	_frame_airborne = false
	_frame_ground_padding = 0.0
	# 정적 포즈는 단일 프레임 텍스처라 격자를 되돌린다.
	_sprite.hframes = 1
	_sprite.vframes = 1
	_sprite.frame = 0
	_bichon_frame = 0
	# 시트 텍스처가 그대로 남으면 격자를 되돌린 순간 시트 전체가 한 칸으로 보인다.
	# set_pose가 _frames[_pose]로 정적 텍스처를 로드해 이 문제를 해결한다.
	set_pose(_pose)
	# 안전망: _frames가 비어있어 set_pose가 텍스처를 못 바꿨으면 idle.png를 직접 로드.
	# 그러지 않으면 시트가 한 프레임으로 그려져 캐릭터가 넓게 잘려 보인다.
	if _sprite.texture != null and not _frames.has(_pose):
		var char_key: String = "egg" if ps.stage == "egg" else ps.species
		var candidates: Array = []
		if ps.evolved_2 and ps.stage != "egg":
			candidates.append("res://assets/sprites/chars/%s_evolved2/idle.png" % char_key)
		if ps.evolved and ps.stage != "egg":
			candidates.append("res://assets/sprites/chars/%s_evolved/idle.png" % char_key)
		candidates.append("res://assets/sprites/chars/%s/idle.png" % char_key)
		for p in candidates:
			if ResourceLoader.exists(p):
				_sprite.texture = load(p)
				break
	_frame_size = _sprite.texture.get_size() if _sprite.texture != null else Vector2.ONE * STATIC_POSE_FALLBACK_SIZE
	_base_scale = Vector2.ONE * _stage_scale() * _static_body_scale()
	_sprite.scale = _base_scale
	# foot_padding/horizontal_offsets로 밀어놨던 위치를 정지 포즈 기준으로 복귀
	_position_sprite_for_current_frame()
	_update_mark_positions()


## 상태 스크립트가 시트 설정의 부가 옵션(예: 런타임 마커를 띄울지)을 조회하는 통로.
## 종족·티어를 알 필요 없이 현재 적용될 config만 본다.
func animated_pose_option(state_name: String, key: String, default_value: Variant = null) -> Variant:
	return _pose_override_config(state_name).get(key, default_value)


## sheet_scale 한 값을 현재 티어 기준 실수로 푼다.
## 하위호환 두 형태를 모두 받는다: 단일 숫자(모든 티어 공통) / 티어 딕셔너리(base|evolved|evolved2).
func _resolve_sheet_scale(raw: Variant, fallback: float) -> float:
	if raw is Dictionary:
		return float((raw as Dictionary).get(_body_tier, fallback))
	if raw is float or raw is int:
		return float(raw)
	return fallback


## 시트 셀 안 몸통 높이가 정지 포즈 아트와 달라 생기는 크기 차이를 sheet_scale로 흡수한다.
## 보정 단위는 종족-티어 하나뿐이다. 상태 단위 보정은 의도적으로 두지 않는다(2026-08-07 결정):
## 상태마다 다른 배율을 허용하면 "시트가 잘못 뽑힌 것"과 "배율이 안 맞는 것"을 데이터로 구분할
## 수 없게 되고, 아트 오차를 조용히 덮는 통로가 된다. 한 상태만 자기 티어 정지 포즈와 어긋나면
## 그건 그 시트를 다시 뽑으라는 신호다.
## (실제 사례: 삐약 Idle이 -5.8%로 튀어 상태 단위 보정을 달았지만, 원인은 아트가 아니라 몸통
## 실측 기준이었다 — 거의 안 보이는 알파 프린지까지 세던 것을 VISIBLE_ALPHA로 바꾸자 세 상태가
## 서로 1px 안으로 모였고, 종족-티어 값 재보정만으로 전부 ±0.6%에 들어왔다.)
func _pose_override_body_scale() -> float:
	if ps.species == "haemjji":
		return _static_body_scale() * float(HAEMJJI_REMAKE_SHEET_SCALE.get(_body_tier, 1.0))
	if ps.species in GENERATED_MOTION_SPECIES:
		var generated_scale: Dictionary = GENERATED_MOTION_SHEET_SCALE.get(ps.species, {})
		return _static_body_scale() * float(generated_scale.get(_body_tier, 1.0))
	var entry: Dictionary = ANIMATED_POSE_OVERRIDES.get(ps.species, {})
	return _static_body_scale() * _resolve_sheet_scale(entry.get("sheet_scale"), 1.0)


## 크기 계산의 단일 진입점 — _base_scale을 만드는 모든 곳이 이 두 함수만 쓴다.
## 여러 곳에서 STAGE_SCALE/BODY_SCALE을 각자 곱하다 보니 egg 분기가 한 곳에만 빠져
## 종족마다 알 크기가 3.1배까지 벌어졌던 적이 있다(2026-08-07 수정). 새 계산 지점을
## 추가할 때도 반드시 이 함수를 거쳐라.
func _stage_scale() -> float:
	return float(STAGE_SCALE.get(ps.stage, 0.5)) if ps != null else 0.5


## 몸통 배율(성장 단계 제외). egg는 BODY_SCALE을 곱하지 않는다 — egg 아트(chars/egg/*.png)는
## 전 종족 공통 단일 이미지라, 성체 아트 편차를 정규화하려고 만든 BODY_SCALE을 곱할 이유가 없다.
## 곱하면 알이 종족마다 달라지고(모찌 219px vs 비숑 71px) 심지어 adult보다 커진다.
func _static_body_scale() -> float:
	if ps == null or ps.stage == "egg":
		return 1.0
	return Characters.get_body_scale(ps.species, _body_tier)


## walk_state.gd가 걷기 진입 시 호출 — 기존 walk1/walk2 토글 폴백 판정을 그대로 유지한다.
func start_animated_walk() -> bool:
	return start_animated_pose("Walk")


func stop_animated_walk() -> void:
	stop_animated_pose()


## sleep_state.gd가 구석 도착 시 호출 — 이동 중에는 Walk 시트를 쓰고 도착 후 Sleep으로 바꾼다.
func start_animated_sleep() -> bool:
	return start_animated_pose("Sleep")


func stop_animated_sleep() -> void:
	stop_animated_pose()


func _set_bichon_frame(frame_index: int) -> void:
	_bichon_frame = frame_index
	_sprite.frame = _sprite_frame_for_bichon_frame(frame_index)
	_position_sprite_for_current_frame()


func _sprite_frame_for_bichon_frame(frame_index: int) -> int:
	if frame_index >= 0 and frame_index < _bichon_sprite_frame_sequence.size():
		return clampi(int(_bichon_sprite_frame_sequence[frame_index]), 0, _sprite.hframes * _sprite.vframes - 1)
	return clampi(frame_index, 0, _sprite.hframes * _sprite.vframes - 1)


func _restore_bichon_state_animation() -> void:
	var state_name: String = machine.current_name() if machine != null else "Idle"
	_set_bichon_animation(_animation_for_state(state_name))


func _play_care_reaction(animation_name: String, duration: float) -> void:
	if _is_animated_pet():
		_bichon_override = animation_name
		_set_bichon_animation(animation_name)
		await get_tree().create_timer(duration).timeout
		if _bichon_override == animation_name:
			_bichon_override = ""
			_restore_bichon_state_animation()
		return
	# 포즈 캐릭터: 등록이 없으면(그 종족에 이 반응 시트가 없으면) 아무것도 하지 않는다.
	if not start_animated_pose(animation_name):
		return
	_pose_reaction_state = animation_name
	await get_tree().create_timer(duration).timeout
	if _pose_reaction_state == animation_name:
		_restore_pose_state_animation()


func _sprite_anchor() -> Vector2:
	return Vector2(0.0, -_frame_size.y * _base_scale.y * 0.5)


## 프레임 하단이 y=0에 오는 앵커에서 출발해, foot_padding("프레임 최하단 ~ 캐릭터 발" 빈 공간)만큼
## 아래로 밀어 실제 발을 지면(y=0)에 맞춘다. 접지 상태는 프레임마다 다시 맞추므로(=재고정)
## 걷기처럼 바운딩 박스가 흔들려도 발이 지면에 붙어 있는다.
## 공중 상태(airborne)는 재고정하면 안 된다 — foot_padding의 프레임 간 변화 자체가 "떠오른 높이"라
## 매 프레임 재고정하면 그 상승분을 정확히 상쇄해 점프·부유가 화면에서 사라진다.
## 그래서 공중 상태는 접지 기준값(ground_padding) 하나로만 고정 보정하고, 나머지 차이는
## 그대로 화면상 상승분으로 남긴다 (padding == ground_padding인 프레임이 접지 프레임).
func _position_sprite_for_current_frame() -> void:
	_sprite.position = _sprite_anchor()
	if _has_active_frame_animation() and _bichon_frame < _bichon_frame_horizontal_offsets.size():
		var horizontal_direction: float = -1.0 if _sprite.flip_h else 1.0
		_sprite.position.x += float(_bichon_frame_horizontal_offsets[_bichon_frame]) * _base_scale.x * horizontal_direction
	if _has_active_frame_animation() and _bichon_frame < _bichon_frame_foot_padding.size():
		var padding := _frame_ground_padding if _frame_airborne else float(_bichon_frame_foot_padding[_bichon_frame])
		_sprite.position.y += padding * _base_scale.y


## 현재 프레임에서 캐릭터의 발이 실제로 놓이는 y (펫 노드 로컬, 0 = 지면, 음수 = 공중).
## 접지 상태는 항상 0이고, 공중 상태는 프레임마다 달라져야 한다 — 화면상 진폭의 단일 진실.
## 테스트/QA가 "정말 떠 보이는가"를 _sprite.position.y 대신 이 값으로 검사한다
## (position.y는 공중 상태에서 오히려 고정이라 진폭 회귀를 못 잡는다).
func current_frame_foot_offset() -> float:
	if not _has_active_frame_animation() or _bichon_frame >= _bichon_frame_foot_padding.size():
		return 0.0
	var frame_bottom: float = _sprite.position.y - _sprite_anchor().y
	return frame_bottom - float(_bichon_frame_foot_padding[_bichon_frame]) * _base_scale.y


## foot_padding/horizontal_offsets/시퀀스 + 접지·공중 판정을 시트 config에서 한 번에 읽는다.
## bichon 카탈로그 경로(_set_bichon_animation)와 포즈 오버라이드 경로(start_animated_pose) 공용.
func _apply_frame_offsets_from_config(config: Dictionary) -> void:
	_bichon_frame_foot_padding = config.get("foot_padding", [])
	_bichon_frame_horizontal_offsets = config.get("horizontal_offsets", [])
	_bichon_sprite_frame_sequence = config.get("sprite_frame_sequence", [])
	_frame_airborne = bool(config.get("airborne", false))
	_frame_ground_padding = float(config.get("ground_padding", _minimum_foot_padding()))


func _minimum_foot_padding() -> float:
	var minimum := 0.0
	for index in _bichon_frame_foot_padding.size():
		var value := float(_bichon_frame_foot_padding[index])
		if index == 0 or value < minimum:
			minimum = value
	return minimum


func _update_mark_positions() -> void:
	var mark_y := -_frame_size.y * _base_scale.y - 26.0
	_zzz.position = Vector2(10.0, mark_y)
	_sick_mark.position = Vector2(-16.0, mark_y)


func idle_breathe() -> void:
	if _keep_bichon_grounded():
		return
	if _idle_tween != null:
		_idle_tween.kill()
	_idle_tween = create_tween()
	_idle_tween.tween_property(_sprite, "scale", _base_scale * Vector2(1.03, 0.97), 0.5)
	_idle_tween.tween_property(_sprite, "scale", _base_scale, 0.5)


func walk_bob(on: bool, waddle: bool = false) -> void:
	_kill_bob()
	# 애니메이션 시트 펫은 시트 자체에 보행 모션이 있어 tween bob을 쓰지 않는다.
	if _keep_bichon_grounded():
		return
	if not on:
		return
	_bob_tween = create_tween().set_loops()
	var down := _sprite_anchor().y
	var up := down - 6.0
	_bob_tween.tween_property(_sprite, "position:y", up, 0.18)
	_bob_tween.tween_property(_sprite, "position:y", down, 0.18)
	# walk1/walk2가 동일한 캐릭터(뚱실이 등)는 몸을 좌우로 흔들어 걷는 느낌 부여
	if waddle:
		_wobble_tween = create_tween().set_loops()
		_wobble_tween.tween_property(_sprite, "rotation", 0.08, 0.28)
		_wobble_tween.tween_property(_sprite, "rotation", -0.08, 0.28)


func shake() -> void:
	if _frames.has("tilt1") and _frames.has("tilt2"):
		# 알 프레임 흔들기: 갸우뚱 좌우 교차, 80% 이상이면 금 간 모습으로 복귀
		var base := "crack" if ps.hatch_progress >= 80.0 and _frames.has("crack") else "idle"
		var t := create_tween()
		for i in 2:
			t.tween_callback(set_pose.bind("tilt1"))
			t.tween_interval(0.14)
			t.tween_callback(set_pose.bind("tilt2"))
			t.tween_interval(0.14)
		t.tween_callback(set_pose.bind(base))
		return
	var t := create_tween()
	for i in 3:
		t.tween_property(_sprite, "rotation", 0.12, 0.06)
		t.tween_property(_sprite, "rotation", -0.12, 0.06)
	t.tween_property(_sprite, "rotation", 0.0, 0.06)


func hatch_pop() -> void:
	if _keep_bichon_grounded():
		return
	var t := create_tween()
	t.tween_property(_sprite, "scale", _base_scale * 1.35, 0.15)
	t.tween_property(_sprite, "scale", _base_scale, 0.25)
	_float_text("탄생!")


func eat_munch() -> void:
	if _keep_bichon_grounded():
		return
	var t := create_tween()
	for i in 3:
		t.tween_property(_sprite, "scale", _base_scale * Vector2(1.1, 0.9), 0.15)
		t.tween_property(_sprite, "scale", _base_scale, 0.15)


func squat() -> void:
	if _keep_bichon_grounded():
		return
	var t := create_tween()
	t.tween_property(_sprite, "scale", _base_scale * Vector2(1.12, 0.82), 0.2)
	t.tween_property(_sprite, "scale", _base_scale, 0.3)


func land_squish() -> void:
	if _keep_bichon_grounded():
		return
	var t := create_tween()
	t.tween_property(_sprite, "scale", _base_scale * Vector2(1.25, 0.7), 0.08)
	t.tween_property(_sprite, "scale", _base_scale, 0.2)


func celebrate() -> void:
	# 신나는 세리머니: 폴짝폴짝 3연속 점프 + 음표 + 신남 표정
	# 애니메이션 시트 펫은 좌표를 tween하면 프레임별 발 위치(foot_padding)가 무시된 곳에서 멈춘다.
	if _is_animated_pet():
		_play_care_reaction("Play", 0.8)
		_float_text("♪")
		return
	# 시트 재생 중인 포즈 캐릭터도 같은 이유로 좌표 tween을 쓰지 않는다 (시트가 모션을 갖고 있다).
	if _keep_bichon_grounded():
		_float_text("♪")
		return
	var prev_pose := _pose
	set_pose("happy")
	# 캔버스 크기는 티어마다 다르다(base 128 / evolved 256) — 실측 앵커를 쓴다.
	var base_y := _sprite_anchor().y
	var t := create_tween()
	for i in 3:
		t.tween_property(_sprite, "position:y", base_y - 22.0, 0.14) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(_sprite, "position:y", base_y, 0.14) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		if _pose == "happy":
			set_pose(prev_pose if prev_pose != "happy" else "idle"))
	_float_text("♪")


func play_frolic() -> void:
	# 좌우로 기울며 폴짝폴짝 4연속 (놀기 리액션)
	if _is_animated_pet():
		_play_care_reaction("Play", 0.8)
		_float_text("신난다~♪")
		return
	if _keep_bichon_grounded():
		_float_text("신난다~♪")
		return
	# 캔버스 크기는 티어마다 다르다(base 128 / evolved 256) — 실측 앵커를 쓴다.
	var base_y := _sprite_anchor().y
	var t := create_tween()
	for i in 4:
		var dir := 1.0 if i % 2 == 0 else -1.0
		t.tween_property(_sprite, "rotation", 0.22 * dir, 0.13)
		t.parallel().tween_property(_sprite, "position:y", base_y - 26.0, 0.13) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(_sprite, "position:y", base_y, 0.14) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_sprite, "rotation", 0.0, 0.1)
	_float_text("신난다~♪")


func reset_sprite_pose() -> void:
	_sprite.rotation = 0.0
	if _is_animated_pet():
		_position_sprite_for_current_frame()
		return
	_sprite.position = _sprite_anchor()


func sulk_crouch() -> void:
	if _keep_bichon_grounded():
		return
	var t := create_tween()
	t.tween_property(_sprite, "scale", _base_scale * Vector2(1.05, 0.88), 0.4)


func wiggle(on: bool) -> void:
	if _wiggle_tween != null:
		_wiggle_tween.kill()
		_wiggle_tween = null
		_sprite.rotation = 0.0
	if on:
		_wiggle_tween = create_tween().set_loops()
		_wiggle_tween.tween_property(_sprite, "rotation", 0.18, 0.12)
		_wiggle_tween.tween_property(_sprite, "rotation", -0.18, 0.12)


func show_zzz(on: bool) -> void:
	_zzz.visible = on


func show_sick(on: bool) -> void:
	_sick_mark.visible = on


func set_sprite_tint(color: Color) -> void:
	_sprite.modulate = color


# --- 내부 ---

func _short_click() -> void:
	if ps.stage == "egg":
		ps.click_egg()
		shake()
		return
	if _pet_cooldown <= 0.0:
		ps.care("pet")
		_pet_cooldown = PET_COOLDOWN_SECONDS
		_float_text("♥")
	else:
		idle_breathe()


func _on_care_performed(action: String) -> void:
	if action == "feed" or action == "snack":
		if machine.current_name() not in machine.UNINTERRUPTIBLE:
			_last_food_action = action
			machine.transition_to("Eat")
	elif action == "pet":
		_play_care_reaction("Pet", 0.8)
	elif action == "play":
		if _is_animated_pet():
			_play_care_reaction("Play", 0.8)
		elif not ps.is_sick and machine.current_name() not in machine.UNINTERRUPTIBLE:
			machine.transition_to("Play")
	elif action == "medicine":
		_float_text("+HP")


func _on_pooped() -> void:
	if ps.stage == "egg" or machine.current_name() in machine.UNINTERRUPTIBLE:
		return
	# 시트 재생 중인 캐릭터라도 Poop 시트가 없으면 상태 전이를 하지 않는다.
	# 전이하면 stop_animated_pose가 스프라이트를 정지 배율(예: 0.4966)로 되돌려서
	# 시트 배율(예: 1.179)에서 급격히 작아지는 "똥싸면 캐릭터가 작아지는" 현상이 발생한다.
	# 이 경우엔 현재 재생 중인 시트 위에 squat 애니메이션만 얹어 자연스럽게 표현한다.
	if _pose_override_active and _pose_override_config("Poop").is_empty():
		squat()
		return
	machine.transition_to("Poop")


func _float_text(text: String) -> void:
	# 스프라이트 내부(캐릭터 머리 위 근처)에서 시작해서 살짝만 위로.
	# 스프라이트 밖으로 크게 나가지 않도록 해서 위쪽 클릭 영역을 확장할 필요가 없게.
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.95, 0.4, 0.55))
	var start_y := -_frame_size.y * _base_scale.y * 0.85
	label.position = Vector2(-10.0, start_y)
	add_child(label)
	var t := create_tween()
	t.tween_property(label, "position:y", start_y - 18.0, 0.8)
	t.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	t.tween_callback(label.queue_free)


func _make_mark(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	label.visible = false
	add_child(label)
	return label


## feed/snack 반응 중 캐릭터 옆에 음식 소품을 띄운다. 몸동작(Eat)은 feed/snack 공통이라
## 이 소품 하나로 어떤 걸 먹는지 구분한다. 종족에 등록된 소품이 없으면 아무것도 하지 않는다
## (하위 호환 — 소품 없이 기존 Eat만 재생돼도 정상 동작).
## 2026-08-11: 통째 스케일 축소/페이드가 아니라, 실제로 내용물이 줄어드는 다중 프레임 시트를
## duration(=Eat 지속시간) 동안 순서대로 넘긴다 — 밥은 숟갈째 줄어 빈 그릇만 남고, 간식은
## 한입씩 베어물려 사라진다(_advance_food_prop이 매 프레임 진행시킴).
func show_food_prop(duration: float) -> void:
	if ps == null:
		return
	var path := Characters.get_food_prop(_last_food_action)
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var texture: Texture2D = load(path)
	if texture == null:
		return
	_food_prop.texture = texture
	# 시트는 128px 정사각 칸이 가로로 이어진 구조 — 칸 수를 텍스처 폭에서 그대로 셈한다
	# (frames 값을 따로 등록받지 않아도 시트를 갈아치우면 자동으로 맞는다).
	_food_prop_frame_count = maxi(1, roundi(texture.get_size().x / 128.0))
	_food_prop.hframes = _food_prop_frame_count
	_food_prop.vframes = 1
	_food_prop.frame = 0
	_food_prop_elapsed = 0.0
	_food_prop_duration = duration
	var side := -1.0 if _sprite.flip_h else 1.0
	var prop_half_width: float = _frame_size.x * _base_scale.x * 0.5
	var offset_x: float = _frame_size.x * _base_scale.x * 0.55 * side
	# 펫이 화면 가장자리에 붙어 있으면 소품이 화면 밖으로 나갈 수 있다 — 반대쪽에 놓아 보고,
	# 그래도 안 되면(초소형 화면) 화면 안으로 clamp한다.
	if screen_size.x > 0.0:
		var target_x := global_position.x + offset_x
		if target_x + prop_half_width > screen_size.x or target_x - prop_half_width < 0.0:
			offset_x = -offset_x
			target_x = global_position.x + offset_x
			target_x = clampf(target_x, prop_half_width, screen_size.x - prop_half_width)
			offset_x = target_x - global_position.x
	_food_prop.position = Vector2(offset_x, -_frame_size.y * _base_scale.y * 0.3)
	_food_prop.scale = _base_scale
	_food_prop.modulate.a = 1.0
	_food_prop.visible = true


func hide_food_prop() -> void:
	_food_prop.visible = false
	_food_prop_frame_count = 0


## show_food_prop()의 다중 프레임을 duration에 맞춰 순서대로 넘긴다. 소품이 안 보이거나
## 프레임이 1장뿐이면(자산 미제작 등) 아무것도 하지 않는다.
func _advance_food_prop(delta: float) -> void:
	if not _food_prop.visible or _food_prop_frame_count <= 1 or _food_prop_duration <= 0.0:
		return
	_food_prop_elapsed += delta
	var idx := int(_food_prop_elapsed / _food_prop_duration * _food_prop_frame_count)
	_food_prop.frame = clampi(idx, 0, _food_prop_frame_count - 1)


## 먹기 소품이 떠 있는 동안의 전역 사각형(소품이 안 보이면 빈 Rect2). main.gd의 클릭통과
## 영역이 이 범위를 포함해야 한다 — 이 창은 그 영역 밖을 렌더링 자체에서 잘라내므로(Windows
## SetWindowRgn), 펫 클릭 영역 바깥쪽에 옆으로 뜨는 이 소품은 포함시켜주지 않으면 코드상
## visible=true여도 화면에는 안 보인다.
func food_prop_rect() -> Rect2:
	if not _food_prop.visible or _food_prop.texture == null:
		return Rect2()
	var frame_size: Vector2 = _food_prop.texture.get_size() / Vector2(maxf(1.0, float(_food_prop.hframes)), 1.0)
	var size: Vector2 = frame_size * _food_prop.scale
	var center: Vector2 = global_position + _food_prop.position
	return Rect2(center - size * 0.5, size)


func _kill_bob() -> void:
	if _bob_tween != null:
		_bob_tween.kill()
		_bob_tween = null
		_position_sprite_for_current_frame()
	if _wobble_tween != null:
		_wobble_tween.kill()
		_wobble_tween = null
		_sprite.rotation = 0.0


func _kill_idle_breathe() -> void:
	if _idle_tween != null:
		_idle_tween.kill()
		_idle_tween = null
	_sprite.scale = _base_scale


func _keep_bichon_grounded() -> bool:
	if not _has_active_frame_animation():
		return false
	_kill_idle_breathe()
	_position_sprite_for_current_frame()
	return true


func _quit_app() -> void:
	get_node("/root/SaveManager").save_game()
	get_tree().quit()


## 위장/숨김 모드 설정 — main.gd에서 단축키·케어메뉴로 호출.
## mode: "normal" | "disguise" | "invisible"
func set_hide_mode(mode: String) -> void:
	if mode == hide_mode:
		return
	hide_mode = mode
	# 액세서리(응아 마커·zzz·아픔 마커) 정리
	_zzz.visible = false
	_sick_mark.visible = false
	match mode:
		"invisible":
			_sprite.visible = false
			_kill_bob()
		"disguise":
			_sprite.visible = true
			_kill_bob()
			_sprite.rotation = 0.0
			_sprite.scale = _base_scale
			# 스프라이트 하단이 지면에 닿도록 정렬 (Vector2.ZERO는 지면 아래로 잘림)
			_sprite.position = Vector2(0.0, -SPRITE_SIZE * _base_scale.y * 0.5)
			# 왼쪽 하단(모니터 구석)으로 순간이동 — 실제 데스크톱 아이콘처럼 자리잡음
			var left_min: float = primary_local.position.x + 40.0 if primary_local.size.x > 0.0 else 40.0
			var left_max: float = left_min + 160.0
			position = Vector2(randf_range(left_min, left_max), ground_y)
			if not _disguise_textures.is_empty():
				_sprite.texture = _disguise_textures[randi() % _disguise_textures.size()]
			# 위장 텍스처 없으면 그냥 현재 스프라이트 유지 (그래도 상호작용은 차단됨)
		"normal":
			_sprite.visible = true
			refresh_appearance()
			set_pose(_pose)


func toggle_disguise() -> void:
	set_hide_mode("normal" if hide_mode == "disguise" else "disguise")


func toggle_invisible() -> void:
	set_hide_mode("normal" if hide_mode == "invisible" else "invisible")


func _load_disguise_textures() -> void:
	_disguise_textures.clear()
	for fname in DISGUISE_FILES:
		var res_path: String = "res://assets/sprites/disguise/" + str(fname)
		if not ResourceLoader.exists(res_path):
			continue
		var tex = load(res_path)
		if tex != null and tex is Texture2D:
			_disguise_textures.append(tex)
