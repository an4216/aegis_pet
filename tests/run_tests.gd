# 헤드리스 단위 테스트 (Design §8). 실행:
#   godot --headless --path . --script tests/run_tests.gd
extends SceneTree

const Balance := preload("res://scripts/data/balance.gd")
const Characters := preload("res://scripts/data/characters.gd")
const TimeM := preload("res://autoload/time_manager.gd")
const PetStateScript := preload("res://autoload/pet_state.gd")
const PetScript := preload("res://scenes/pet/pet.gd")
const PetScene := preload("res://scenes/pet/pet.tscn")

var fails := 0
var passes := 0

# 공중 3상태에서 화면상 실제로 떠야 하는 조합. 유도값이 아니라 명시 목록인 것이 핵심이다 —
# 기대값을 검사 대상(config)에서 뽑으면 padding이 다시 균일해졌을 때 기대값도 같이 0이 되어
# 단정문이 조용히 꺼진다(2026-08-10 실측으로 확인한 구멍).
const AIRBORNE_MUST_LIFT := [
	"mochi/base/Dragged", "mochi/base/Fall",
	"mochi/evolved/Play", "mochi/evolved2/Play",
	"haemjji/base/Play", "haemjji/base/Fall",
	"haemjji/evolved/Play", "haemjji/evolved/Dragged",
	"haemjji/evolved2/Play", "haemjji/evolved2/Dragged",
	"haemjji/evolved/Fall", "haemjji/evolved2/Fall",
	"mochi/evolved/Dragged", "mochi/evolved2/Dragged",
	"mochi/base/Play", "mochi/evolved/Fall", "mochi/evolved2/Fall",
	"haemjji/base/Dragged",
]
# 아직 0px인 조합(Task #37). 해소될 때마다 여기서 빼고 위 목록으로 옮긴다 —
# 목록이 줄어드는 것으로 진행 상황이 코드에 남는다.
# 2026-08-10: #37 완료로 비었다. 공중 18조합 전부 화면에서 실제로 뜬다.
const AIRBORNE_KNOWN_FLAT := []

# 상태가 실제로 빠져나가는 시점의 지속시간(초). 상태 스크립트/pet.gd 상수와 일치해야 한다.
const STATE_EXIT_DURATION := {
	"Eat": 2.0,             # eat_state.gd: _timer = 2.0
	"FileConsume": 0.70,    # pet.gd: FILE_CONSUME_DURATION
	"Land": 0.45,           # land_state.gd: LAND_DURATION
}
# 종료 프레임 → Idle 첫 프레임 실루엣 변화 허용치(%). 면적이 아니라 폭·높이 각각을 본다 —
# 면적은 폭↓·높이↑가 상쇄되어 통과해버린다(mochi/Eat이 실제 반례였다).
const TRANSITION_POP_LIMIT := 15.0
# 현재 한도를 넘는 조합. 해소되면 여기서 뺀다(빼지 않으면 "해소됨" 실패로 알려준다).
# mochi/evolved/Eat(20.3%)은 기존 건이고 Task #38 대상이다.
# haemjji Eat 3건은 한때 41.5 / 26.0 / 53.4%까지 벌어졌다가(활기를 키우면서 종료칸이 부푼 채
# 끝나게 만든 재생성) 피크를 중간 프레임으로 옮기고 마지막 칸을 Idle 비율로 되돌리는
# 재생성으로 1.9 / 5.5 / 2.7%가 되어 목록에서 빠졌다. 활기와 종료칸 크기는 독립된 축이라
# "면적 변화는 키우되 종료칸은 Idle 대비 +-8%"를 목표로 잡아야 둘 다 만족한다.
# 2026-08-10: mochi/evolved/Eat이 20.3% -> 10.3%로 내려와 비었다(Task #43 재생성).
# 낙하가 마지막 프레임에서 접지되지 않는 조합 — 그 프레임의 발이 접지 기준보다 떠 있어서
# Land로 넘어가는 순간 아래로 튄다. 화면 낙차는 ppiyak/evolved 2.1px, ppiyak/evolved2 2.5px다.
# 2026-08-10: mochi/base가 해소되어 빠졌다. 아트가 [16, 22, 22, 29](낙하 중 10.3px 상승)에서
# [41, 31, 23, 16](19.8px 하강)으로 재생성됐다 — 이 검사를 신설하자마자 잡아낸 건이다.
# 2026-08-10: 목록이 비었다. mochi/base는 아트가 [16,22,22,29](낙하 중 10.3px 상승)에서
# [41,31,23,16]로, ppiyak evolved/evolved2는 마지막 프레임이 최솟값 12에 놓이도록 재생성돼
# 셋 다 해소됐다. ppiyak/evolved는 원래 진폭이 1px로 낙하가 화면에서 죽어 있었고 지금 11px다.
# 비어 있는 게 정상 상태다 — 새 위반이 생기면 else 분기가 바로 실패로 알려준다.
# 등록값이 자산 실측과 어긋나는 것을 잠근다. pet.gd의 같은 두 줄이 2026-08-10에 세 번
# 오염값으로 덮였는데(기준선을 12이 아닌 4/7로 읽은 값), 매니페스트 검사는 최솟값과 배열
# 길이만 보므로 "기준선 계약을 지키면서 틀린" 값은 어느 검사에도 걸리지 않았다.
# 허용차는 설계 여유가 아니라 측정 단위다. 처음엔 "파이프라인 alpha>0 vs 런타임
# alpha>=0.125 차이"를 흡수하려고 padding에 1.0을 뒀는데, 그 뒤 등록값이 alpha>=0.125
# 기준으로 갱신되면서 140개 config 전부 padding 편차가 정확히 0.0이 됐다. 즉 당시 1px
# 불일치는 임계값 노이즈가 아니라 실제 낡음이었다. 1.0을 유지하면 그 1px 낡음을 다시
# 조용히 통과시키므로 0.0(완전 일치)으로 조였다 — padding은 정수라 완전 일치가 가능하다.
# offset은 0.5 단위로 스냅되므로 최소 표현 단위인 0.5를 유지한다(실측 최대 편차도 0.5,
# ppiyak/base/Walk 1건). 참고: 임계값을 0.05/0.02/0.004로 낮추면 1~2px씩 밀리므로
# 파이프라인이 다른 임계값으로 값을 만들면 여기서 실패한다 — 그때는 재측정이 정답이다.
const REGISTRATION_PAD_TOLERANCE := 0.0
# 0.5는 "여유"가 아니라 오프셋의 스냅 단위 그 자체다. 허용차를 표현 단위와 같게 두면
# 표현 가능한 최소 오차(= 한 칸 틀림)가 항상 통과한다 — 2026-08-11에 mochi_evolved/
# file_consume이 등록 [0.0,...] vs 실측 [0.5,...]로 정확히 0.5 어긋났는데 내 검사도
# gd-integrator의 감사도 잡지 못했다. 오프셋도 0.5 단위로 양자화돼 있어 완전 일치가
# 가능하므로 padding과 같은 이유로 0.0이 맞다. 여유가 필요하면 스냅 단위보다 작은 값이어야 한다.
# 오프셋이 정확히 한 스냅 단위(0.5) 어긋난 레거시 시트. 등록이 현행 규약(런타임과 같은
# alpha>=0.125)이 아니라 스프라이트 파이프라인 기준(alpha>0)으로 이뤄져서 bbox가 한 픽셀
# 넓게 잡히고 중심이 0.5 밀린 것이다. 화면 영향은 0.5px로 사실상 보이지 않지만, 런타임의
# 측정 기준과는 어긋나 있다.
# 뚱실이는 0건이다 — 규약 확정 후 등록된 종족이라 168개 시트 중 그쪽만 정확히 맞는다.
# 이 목록은 gd-integrator가 자산 기준 일괄 재산출 1회로 통째로 비울 수 있다(복구 때
# 44건을 그렇게 처리한 전례가 있다). 그때까지 신규 등록은 허용차 0.0으로 엄격히 잡힌다.
const REGISTRATION_OFF_LEGACY := [
	"mochi/evolved2/Idle", "mochi/evolved2/Walk", "mochi/base/Sleep",
	"mochi/evolved/Sleep", "mochi/evolved/Eat", "mochi/base/Sick",
	"mochi/base/Play", "mochi/base/Dragged", "mochi/base/Land",
	"mochi/evolved/Land", "mochi/base/FileHover", "mochi/evolved2/FileHover",
	"mochi/evolved2/Poop", "ppiyak/base/Walk", "ppiyak/evolved/Walk",
	"ppiyak/evolved2/Walk", "ppiyak/base/Sleep", "ppiyak/evolved/Sleep",
	"ppiyak/evolved2/Sleep", "ppiyak/base/Eat", "ppiyak/evolved/Eat",
	"ppiyak/evolved2/Eat", "ppiyak/base/Sick", "ppiyak/evolved/Sick",
	"ppiyak/evolved2/Sick", "ppiyak/base/Sulk", "ppiyak/evolved/Sulk",
	"ppiyak/evolved2/Sulk", "ppiyak/base/Play", "ppiyak/evolved/Play",
	"ppiyak/evolved2/Play", "ppiyak/base/Dragged", "ppiyak/evolved/Dragged",
	"ppiyak/evolved2/Dragged", "ppiyak/base/Fall", "ppiyak/evolved/Fall",
	"ppiyak/evolved2/Fall", "ppiyak/base/Land", "ppiyak/evolved/Land",
	"ppiyak/evolved2/Land", "haemjji/base/Idle", "haemjji/evolved/Idle",
	"haemjji/base/Eat", "haemjji/evolved2/Eat", "haemjji/evolved/Sick",
	"haemjji/base/Play", "haemjji/evolved/Play", "haemjji/base/Fall",
	"haemjji/base/FileHover", "haemjji/evolved2/FileHover", "haemjji/base/FileConsume",
	"haemjji/evolved/FileConsume", "haemjji/evolved2/FileConsume", "haemjji/base/Poop",
	"haemjji/evolved/Poop", "haemjji/base/Pet", "haemjji/evolved/Pet",
]
const REGISTRATION_OFF_TOLERANCE := 0.0
# 허용차를 넘는 조합. ppiyak Idle 3줄은 오프셋이 전부 0.0으로 등록돼 있어 실측된 적이
# 없어 보이고, evolved2가 3.0px까지 벌어진다(128px 셀에서 몸통 폭의 4%).
# ppiyak Idle 3줄은 오프셋이 전부 0.0(플레이스홀더)이었다가 실측값으로 등록되어 빠졌다 —
# 이 검사가 첫 실행에서 잡아낸 건이다.
const REGISTRATION_KNOWN := []
# 종족별 시트 계약. 전수 실측(2026-08-10)에서 셀 크기와 접지 기준선은 종족 안에서 완전히
# 균일했다 — mochi·ppiyak 192x208/16 (각 42개 config), haemjji 128x128/12 (42개),
# ddungsil 192x208/16 (14개). 예외가 하나도 없어 그대로 잠근다. 하드코딩인 이유는 등록
# 데이터에서 유도하면 덮임 사고에서 기대값이 같이 오염돼 검사가 무력해지기 때문이다.
# 오프셋 한도(base +-2.0 / 진화 +-3.5)는 여기 넣지 않았다 — 같은 실측에서 종족마다 갈렸다
# (mochi base 5.0 / ppiyak evolved2 7.0 / haemjji base 2.0). haemjji에만 맞는 값이다.
const SPECIES_SHEET_CONTRACT := {
	"mochi": {"cell_w": 192, "cell_h": 208, "baseline": 16.0},
	"haemjji": {"cell_w": 128, "cell_h": 128, "baseline": 12.0},
	"ppiyak": {"cell_w": 192, "cell_h": 208, "baseline": 16.0},
	"ddungsil": {"cell_w": 192, "cell_h": 208, "baseline": 16.0},
}
# 순환(loop) 상태의 "마지막 프레임 -> 첫 프레임" 이음새. 상태를 나갈 때만 보는 전환 팝
# 검사와 달리, 이 이음새는 재생 중 매 주기 반복해서 보인다. 그래서 한도를 전환 팝(15%)보다
# 조금 타이트하게 잡는다. Fall은 2026-08-10에 loop:false가 되어 이 검사 범위에서 빠졌다.
const LOOP_SEAM_LIMIT := 12.0
# 한도를 넘는 순환 상태. 전부 아트 이음새 문제이고 sprite-artist 담당이다.
const LOOP_SEAM_KNOWN := [
	# 2026-08-11에 8건이 전부 해소되어 비었다. 최악이 67.3%(mochi/evolved/Sick)였고 지금은
	# 전 순환 상태가 3% 이내다. 처방은 하나였다 — "마지막 칸 == 첫 칸, 극단은 중간에".
	# 어긋난 방향은 두 갈래였는데(Sick·Play는 저점에서 끝나 위로 튀고, Poop은 웅크린 채
	# 시작해 서서 끝나 아래로 튄다) 같은 처방이 양쪽에 통했다.
]
# 애니메이션 Sick 시트에 아픔 표시를 그리지 않는 것이 관례다(현재 10장 전부). 그래서
# sick_state.gd가 @_@ 라벨을 대신 띄우고, 그 스위치가 runtime_sick_mark다. 기본값이 false라
# 빼먹으면 라벨이 안 뜨고 Sick이 Sulk와 구분되지 않는다 — 뚱실이 등록 때 실제로 빠져 있었다.
# 아트에 표시를 직접 그린 종족이 생기면 이중 표시가 되므로 여기에 등재해 예외로 둔다.
const SICK_MARK_DRAWN_IN_ART := []
# 애니메이션 시트가 일부 티어에만 있는 종족은 나머지 티어가 정지 포즈로 폴백한다.
# walk_state.gd:21-25가 시트가 있으면 조기 반환하므로 시트 티어는 아래 플래그를 무시하지만,
# 폴백 티어는 여전히 walk_static(waddle 보완)/walk_face_inverted(좌우 반전)를 읽는다.
# 플래그는 종족 단위라 티어별 분리가 불가능해서, "레거시 플래그 정리"로 지우면 폴백 티어의
# 걷기 연출이 조용히 사라진다. 시트가 3티어로 완성되면 이 검사가 "이제 지워도 된다"고 알려준다.
# 2026-08-11에 뚱실이가 3티어를 갖추면서 비었다. 이 검사가 tiers 크기로 분기해
# "이제 정리하라"를 스스로 알려줬고(설계대로), characters.gd의 walk_static·
# walk_face_inverted 제거는 gd-integrator가 처리한다 — 등록 데이터 파일이기 때문이다.
const STATIC_FALLBACK_WALK_FLAGS := {}
# 상태별 loop 규약. 10개 종족-티어 config를 전수 측정한 결과 상태마다 완전히 균일했다(예외 0건)
# 이라 종족별 테이블 대신 상태별 계약으로 잠근다 — 신규 종족이 자동으로 커버되고, 뚱실이·비숑에
# loop 단정이 없어 Fall이 어느 쪽으로 바뀌어도 알려주지 않던 구멍이 닫힌다(gd-integrator 지적).
# 일회성(false): 한 번 재생하고 마지막 칸을 유지한다. Fall은 2026-08-10에 true에서 바뀌었다 —
# 단조 하강 호라 루프면 착지 직전 스쿼시에서 최고점으로 되돌아 튀고, 1주기 0.333초 = 자유낙하
# 133px이라 드래그마다 사실상 매번 되돌았다.
const STATE_LOOP_CONTRACT := {
	"Idle": true, "Walk": true, "Sleep": true, "Eat": true, "Sick": true,
	"Sulk": true, "Play": true, "Dragged": true, "Poop": true,
	"Fall": false, "Land": false, "FileHover": false, "FileConsume": false, "Pet": false,
}
# 비숑 카탈로그는 13상태가 위 계약과 같고 Play만 다르다(일회성 축하 연출).
const BICHON_LOOP_OVERRIDE := {"Play": false}
# 몸통 중심 오프셋의 종족-티어별 천장(라쳇). 목표값이 아니라 "여기서 더 나빠지지 않는다"는
# 비회귀 선이다 — 넘으면 정렬이 나빠진 것이고, 밑돌면 개선됐으니 천장을 내리라고 알려준다.
# 고정 한도를 두지 않는 이유: 오프셋 크기는 종족 고유 속성이 아니라 정렬 방식의 증상이다.
# 2026-08-10에 haemjji Dragged가 -2.5로 한도(±2.0)를 넘겼을 때 원인이 한도가 아니라 정렬 기준
# (알파 가중 중심 vs bbox 중심)이었고, bbox 중심 정렬로 바꾸자 6장 전부 <=0.5가 됐다.
# 그래서 현재값을 "옳은 값"으로 박으면 정렬 오차를 정답으로 박제하게 된다.
# 목표는 <=0.5이고 ddungsil(0.5, bbox 중심 정렬로 제작)이 달성 가능함을 증명한다.
# 레거시 3종의 2.0~7.0은 정렬 재작업이 필요한 아트 백로그다.
const OFFSET_CEILING := {
	# 뚱실이 두 티어가 0.5로 같다 — bbox 중심 정렬로 제작하면 신규 티어에서도 그대로 나온다는
	# 확인이다(레거시 3종의 2.0~7.0과 대비된다).
	# 세 티어 전부 0.5 — bbox 중심 정렬로 제작하면 신규 티어에서도 그대로 재현된다.
	"ddungsil/base": 0.5, "ddungsil/evolved": 0.5, "ddungsil/evolved2": 0.5,
	"haemjji/base": 2.0, "haemjji/evolved": 3.5, "haemjji/evolved2": 3.0,
	"mochi/base": 5.0, "mochi/evolved": 6.0, "mochi/evolved2": 6.0,
	# 2026-08-11 리메이크에서 세 티어 모두 bbox 중심 정렬로 최대 편차를 0.5px까지 낮췄다.
	"ppiyak/base": 0.5, "ppiyak/evolved": 0.5, "ppiyak/evolved2": 0.5,
}
# fps는 설계값이라 픽셀에서 유도할 수 없고, 지금까지 어느 검사도 보지 않던 마지막 필드다
# (gd-integrator가 재구성 때 인계 표에서 손으로 옮기고 손으로 대조해 맞췄다 — 다음엔 못 잡는다).
# 전수 측정 결과 14상태 중 9개는 종족 간 균일하고 5개(Idle/Eat/Sick/Sleep/Sulk)만 갈린다.
# 티어 간에는 항상 균일했다(혼재 0건). 그래서 기준선 + 종족 예외 구조로 동결한다.
const STATE_FPS_BASELINE := {
	"Idle": 4.0, "Walk": 10.0, "Sleep": 5.0, "Eat": 6.0, "Sick": 6.0,
	"Sulk": 6.0, "Play": 8.0, "Dragged": 10.0, "Poop": 6.0,
	"Fall": 12.0, "Land": 10.0, "FileHover": 12.0, "FileConsume": 12.0, "Pet": 10.0,
}
# 종족별 예외. 빈 딕셔너리라도 반드시 선언해야 한다 — 신규 종족이 기준선을 조용히 물려받지
# 못하게 해서, 뚱실이가 미검증으로 들어왔던 구멍을 fps에도 막는다.
# ppiyak Idle 8.0: 물리 6칸을 논리 16프레임으로 펼친 idle_blink 시퀀스라 빠르게 돌려야
# 깜박임이 자연스럽다. ppiyak/ddungsil의 Sick·Sleep·Sulk 5.0/4.0/5.0은 더 느린 호흡 연출이다.
const SPECIES_FPS_OVERRIDE := {
	"mochi": {},
	"haemjji": {},
	"ppiyak": {"Idle": 8.0, "Eat": 8.0, "Sick": 5.0, "Sleep": 4.0, "Sulk": 5.0},
	"ddungsil": {"Sick": 5.0, "Sleep": 4.0, "Sulk": 5.0},
}
const FALL_DIRECTION_KNOWN := []
const TRANSITION_POP_KNOWN := []
# 파일 드롭 연출은 상태머신을 거치지 않는 오버라이드 체인이다(pet.gd play_file_drop_reaction):
# Idle -> FileHover(FILE_HOVER_DURATION) -> FileConsume(FILE_CONSUME_DURATION) -> Idle.
# _test_transition_pop은 STATE_EXIT_DURATION에 든 상태만 보므로 이 체인의 앞 두 단(진입·중간)은
# 어느 검사에도 걸리지 않았다. FileHover 시트를 활기 목적으로 재생성하면서 치켜드는 피크
# 프레임이 셀을 꽉 채우게 되고 그 탓에 시트 전체가 축소돼 정지 프레임 몸통이 HEAD 대비
# 8~36% 줄어든 일이 있었는데(2026-08-10), 3690개 단정문이 전부 통과시킨 구멍이 여기였다.
# BODY_CORE_HEIGHT 기반 몸통 정규화 검사는 정지 포즈 아트(chars/*/idle.png)를 재므로
# 애니메이션 시트가 쪼그라든 것을 원리적으로 잡지 못한다.
# 2026-08-10 재생성으로 중간단 12개 조합 중 10개가 해소됐다. 남은 둘은 FileHover가 아니라
# FileConsume 쪽이 원인이다 — mochi/evolved는 Consume f0(133x143)이 같은 티어
# Idle f0(156x158)보다 작아서 Hover 종료칸(158x156)에서 넘어갈 때 15.8% 튄다.
# 진입단은 Idle 전 프레임 중 최악을 기준으로 잰다. Idle이 loop라 파일이 올라오는 순간
# 펫이 f0에 있을 이유가 없어서인데, mochi/evolved Idle은 자체 높이 변화가 29.9%나 돼
# (f0 156x158 / f2 165x127) f0만 보면 2.6%, 실제 최악은 26.0%다. Idle f2에 걸린 동안
# 파일이 올라오면 실제로 그만큼 튄다 — FileHover가 아니라 Idle f2가 원인이다.
# 2026-08-11에 비었다. 세 건 모두 원인이 FileHover가 아닌 다른 시트였다는 게 공통점이다 —
# "mochi/evolved/진입" 26.0%는 Idle f2의 과도한 진폭이, 중간단 두 건(15.8% / 15.5%)은
# FileConsume f0의 폭이 원인이었고, 그 시트들을 고치자 4.5% / 8.4%로 내려왔다.
# 증상이 나타난 단계(FileHover 전이)와 원인이 있는 시트가 다를 수 있다는 사례다.
# 2026-08-12에 비었다. haemjji/evolved가 `_remake` 전환으로 18.8%까지 벌어졌다가 아트 수정으로
# 5.3%가 되어 빠졌다 — 그 결함은 검사가 죽은 `_alpha_smooth` 상수를 읽는 동안 가려져 있었고,
# `_pose_config`를 런타임 경로로 고치면서 처음 드러났다(제품 보증이 0이던 구간이다).
# 수정 방식이 좋은 선례다: Idle **높이를 프레임별로 원본과 일치**시켜(f0 173 불변) `sheet_scale`을
# 건드리지 않고 폭만 중앙값 133으로 맞췄다. 배율을 손대면 반응 8상태가 함께 축소된다.
# 세 티어 현재값: base 7.7% / evolved 5.3% / evolved2 13.7%(한도 근접이라 계속 지켜볼 것).
const REACTION_CHAIN_POP_KNOWN := []
# 케어 반응 테스트가 야간 판정을 끄고 빌려 쓴 원래 값 (_test_mochi_pose_runtime 끝에서 되돌린다).
var _saved_night_window: Array = []


func _init() -> void:
	# 픽셀 검사 전체의 전제라 가장 먼저 본다 — 캐시가 낡으면 아래 결과를 믿을 수 없다.
	_test_import_cache_fresh()
	_test_referenced_assets_tracked()
	_test_sheet_value_sync()
	_test_decay_basic()
	_test_decay_geobujang()
	_test_care_feed()
	_test_care_modifier()
	_test_offline_cap()
	_test_sick_and_recover()
	_test_egg_hatch_passive()
	_test_hatch_distribution()
	_test_bichon_registration()
	_test_bichon_animation_manifest()
	_test_ppiyak_animated_sleep_manifest()
	_test_ppiyak_idle_blink_sheet()
	_test_mochi_pose_manifest()
	_test_mochi_evolved_walk_keeps_body_width()
	_test_haemjji_pose_manifest()
	_test_generated_motion_catalog()
	_test_serialize_roundtrip()
	_test_stage_progression()
	_test_digest()
	_test_probe_parse()
	_test_reset_to_egg()
	_test_version_compare()
	_test_evolution_keyboard()
	_test_evolution_distinct_days()
	_test_evolution_feed_snack()
	_test_evolution_progress_ratio()
	_test_evolution_persists_across_save()
	_test_evolution_gated_by_egg()
	_test_evolution_2_tier()
	_test_consecutive_days()
	_test_rabbit_full_evolution()
	_test_dialog_evolution_pools()
	_test_species_sheet_contract()
	_test_registration_matches_assets()
	_test_fall_direction_all_species()
	_test_state_loop_contract()
	_test_offset_ceiling()
	_test_state_fps_contract()
	_test_sheet_scale_formula()
	_test_render_path_parity()
	_test_generated_walk_size_continuity()
	_test_kong_walk_torso_stability()
	_test_loop_seam()
	_test_static_fallback_walk_flags()
	_test_transition_pop()
	_test_reaction_chain_pop()
	_test_airborne_lift_coverage()
	_test_bichon_evolution()
	call_deferred("_test_bichon_care_reactions")


func _test_generated_motion_catalog() -> void:
	var expected_species := [
		"kkubeok", "nyang", "kong", "mundeok", "geobujang", "bulgeumjo",
		"seureureuk", "tokki",
	]
	var expected_states := [
		"Idle", "Walk", "Sleep", "Eat", "Sick", "Sulk", "Play", "Dragged",
		"Fall", "Land", "FileHover", "FileConsume", "Poop", "Pet",
	]
	check(PetScript.GENERATED_MOTION_SPECIES == expected_species,
		"해솔 제외 정지 포즈 8종이 등록 순서대로 모션 카탈로그에 등록")
	for species in expected_species:
		for tier in ["base", "evolved", "evolved2"]:
			for state in expected_states:
				var config: Dictionary = PetScript.generated_motion_config(species, tier, state)
				check(not config.is_empty(), "%s/%s/%s 14상태 모션 설정" % [species, tier, state])
				check(ResourceLoader.exists(String(config.get("path", ""))),
					"%s/%s/%s 모션 시트 로드" % [species, tier, state])
				check(int(config.get("frames", 0)) == (config.get("foot_padding", []) as Array).size(),
					"%s/%s/%s 프레임 앵커 수 일치" % [species, tier, state])


func _finish() -> void:
	# 빌려 쓴 야간 설정 복원. SaveManager는 오토로드(전역 상태)이고 설정이 디스크로
	# 저장될 수 있어, 스위트가 사용자 야간 구간을 0으로 남기면 안 된다.
	if not _saved_night_window.is_empty() and root.has_node("SaveManager"):
		var save_manager: Node = root.get_node("SaveManager")
		save_manager.settings["night_start"] = _saved_night_window[0]
		save_manager.settings["night_end"] = _saved_night_window[1]
	print("")
	print("RESULT: %d passed, %d failed" % [passes, fails])
	quit(1 if fails > 0 else 0)


func check(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("PASS  " + test_name)
	else:
		fails += 1
		print("FAIL  " + test_name)


func approx(a: float, b: float, eps := 0.01) -> bool:
	return absf(a - b) < eps


## 등록 데이터에서 실효 몸통 배율을 유도한다. 곱을 리터럴로 박으면 sheet_scale이 바뀔 때마다
## 91곳이 함께 썩는다(2026-08-11 Task #50에서 실제로 그랬다). 여기서 유도하면 값 변경에는
## 무반응이고, 런타임이 BODY_SCALE이나 sheet_scale을 빼먹는 회귀에는 그대로 실패한다 —
## 원래 이 검사가 잡으려던 회귀가 그것이다(sheet_scale 누락 -> evolved2만 12.7% 큼).
## sheet_scale "값이 옳은가"는 _test_sheet_scale_formula()가 아트와 대조해 따로 본다.
func effective_body_scale(species: String, tier: String) -> float:
	if species == "haemjji":
		return float((Characters.BODY_SCALE.get(species, {}) as Dictionary).get(tier, 1.0)) * float(PetScript.HAEMJJI_REMAKE_SHEET_SCALE.get(tier, 1.0))
	if species in PetScript.GENERATED_MOTION_SPECIES:
		var generated: Dictionary = PetScript.GENERATED_MOTION_SHEET_SCALE.get(species, {})
		return float((Characters.BODY_SCALE.get(species, {}) as Dictionary).get(tier, 1.0)) * float(generated.get(tier, 1.0))
	var entry: Dictionary = PetScript.ANIMATED_POSE_OVERRIDES.get(species, {})
	var raw: Variant = entry.get("sheet_scale", 1.0)
	var sheet: float = float((raw as Dictionary).get(tier, 1.0)) if raw is Dictionary else float(raw)
	return float((Characters.BODY_SCALE.get(species, {}) as Dictionary).get(tier, 1.0)) * sheet


## 비숑 케어 반응이 Idle로 복귀할 때까지 기다린다. 고정 대기(create_timer(0.81))로는 안 된다 —
## 반응 지속이 0.8s인데 대기가 0.81s라 여유가 10ms뿐이고, 헤드리스에서 한 프레임이 그보다
## 길어지면 복귀 전에 단정문이 돌아 간헐적으로 실패한다(2026-08-10 실패 2건의 원인).
## 벽시계 대신 복귀 완료를 관측하고, 상한을 둬서 회귀 시 무한 대기가 되지 않게 한다.
func await_bichon_restored(pet: Node2D, limit := 3.0) -> bool:
	var waited := 0.0
	while waited < limit:
		if pet._bichon_override.is_empty():
			return true
		await create_timer(0.02).timeout
		waited += 0.02
	return false


## 앵커 복귀 실패 시 원인을 한 번의 재발로 가릴 수 있게 상태를 함께 찍는다. 2026-08-11 기준
## 원인 미규명(약 15회 중 1회)이고, 가설 두 개가 반증된 상태라 다음 재발의 진단 정보가 필요하다.
## 좌표 차이가 0이 아닌 채 정착했다면 복귀 대상 시트가 달랐다는 뜻이고(상태명·애니메이션이
## 가른다), 차이가 0인데 실패했다면 폴링 상한 안에 복귀 자체가 안 끝난 것이다.
func bichon_anchor_diag(pet: Node2D, target_y: float) -> String:
	var state_name: String = pet.machine.current_name() if pet.machine != null else "(machine 없음)"
	return "상태=%s 애니=%s override='%s' 좌표차=%.2f" % [
		state_name, pet._bichon_animation, pet._bichon_override, pet._sprite.position.y - target_y]


## 반응이 끝나고 스프라이트가 Idle 프레임 앵커로 "수렴하는지" 본다. 오버라이드 해제와
## 앵커 재계산이 같은 프레임에 일어난다는 보장이 없어서, 해제만 기다리고 좌표를 즉시 재면
## 여전히 간헐적으로 Play 시트 앵커를 읽는다(2026-08-10 폴링 도입 후에도 남은 실패).
## 수렴을 관측하되 상한을 둬서, 정말 복귀하지 않는 회귀는 그대로 실패로 잡는다.
func await_bichon_anchor(pet: Node2D, target_y: float, limit := 3.0) -> bool:
	var waited := 0.0
	while waited < limit:
		if pet._bichon_override.is_empty() and approx(pet._sprite.position.y, target_y):
			return true
		await create_timer(0.02).timeout
		waited += 0.02
	return false


func make_pet(species := "mochi") -> Node:
	var pet: Node = PetStateScript.new()
	pet.debug_set_species(species)
	return pet


# 1시간 경과: hunger -4, happiness -3 (모찌 = 무보정)
func _test_decay_basic() -> void:
	var pet := make_pet("mochi")
	pet.activity = pet.Activity.IDLE
	pet.advance_minutes(60.0, {"hour": 10, "weekday": 2})
	check(approx(pet.stats["hunger"], 76.0), "1시간 감소: hunger 80→76")
	check(approx(pet.stats["happiness"], 67.0), "1시간 감소: happiness 70→67")


# 거부장 all_decay 0.7: hunger -2.8
func _test_decay_geobujang() -> void:
	var pet := make_pet("geobujang")
	pet.advance_minutes(60.0, {"hour": 10, "weekday": 2})
	check(approx(pet.stats["hunger"], 77.2), "거부장 항상성: hunger 80→77.2")


func _test_care_feed() -> void:
	var pet := make_pet("mochi")
	pet.stats["hunger"] = 50.0
	pet.care("feed")
	check(approx(pet.stats["hunger"], 80.0), "먹이: hunger 50→80")


# 햄찌 간식 2배: hunger +20, happiness +10
func _test_care_modifier() -> void:
	var pet := make_pet("haemjji")
	pet.stats["hunger"] = 50.0
	pet.stats["happiness"] = 50.0
	pet.care("snack")
	check(approx(pet.stats["hunger"], 70.0), "햄찌 간식 2배: hunger +20")
	check(approx(pet.stats["happiness"], 60.0), "햄찌 간식 2배: happiness +10")


# 오프라인 12시간 → 8시간 캡 × 50% = 유효 4시간
func _test_offline_cap() -> void:
	check(approx(TimeM.compute_offline_hours(12.0 * 3600.0), 4.0), "오프라인 캡: 12h→유효 4h")
	check(approx(TimeM.compute_offline_hours(2.0 * 3600.0), 1.0), "오프라인 비율: 2h→유효 1h")
	check(approx(TimeM.compute_offline_hours(-100.0), 0.0), "시계 역행: 페널티 0")


func _test_sick_and_recover() -> void:
	var pet := make_pet("mochi")
	pet.stats["health"] = 25.0
	pet.advance_minutes(1.0, {"hour": 10, "weekday": 2})
	check(pet.is_sick, "건강 30 미만 → 병듦")
	pet.care("medicine")
	check(not pet.is_sick and pet.stats["health"] >= 50.0, "약 → 회복")


# 알: 방치 4시간이면 부화 (HATCH_HOURS_MAX)
func _test_egg_hatch_passive() -> void:
	var pet: Node = PetStateScript.new()
	check(pet.stage == "egg" and pet.species == "", "초기 상태는 알")
	pet.advance_minutes(Balance.HATCH_HOURS_MAX * 60.0, {"hour": 10, "weekday": 2})
	check(pet.stage == "baby" and pet.species != "", "4시간 후 부화")


# 부화 확률: 기본 분포 ±2%p, 금요일 가중치 시 불금조 ~11.1%
func _test_hatch_distribution() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260721
	var n := 20000
	var counts := {}
	for i in n:
		var s := Characters.pick_species([], rng)
		counts[s] = counts.get(s, 0) + 1
	var total_weight := 0.0
	for species in Characters.CHARACTERS:
		if not Characters.is_hatchable(species):
			continue
		total_weight += float(Characters.RARITY_WEIGHT[Characters.CHARACTERS[species]["rarity"]])
	var mochi_weight: float = Characters.RARITY_WEIGHT[Characters.CHARACTERS["mochi"]["rarity"]]
	check(absf(counts.get("mochi", 0) / float(n) - mochi_weight / total_weight) < 0.02, "기본 확률: 모찌 가중치 비율")
	check(absf(counts.get("seureureuk", 0) / float(n) - 0.04) < 0.015, "기본 확률: 스르륵 ~4%")
	check(not Characters.is_hatchable("bichon"), "해솔은 부화 후보에서 숨김 처리됨")
	check(counts.get("bichon", 0) == 0, "해솔은 2만 회 샘플링에서 한 번도 뽑히지 않음")
	var fri := 0
	for i in n:
		if Characters.pick_species(["friday_hatch"], rng) == "bulgeumjo":
			fri += 1
	check(absf(fri / float(n) - 12.0 / 116.0) < 0.02, "금요일 가중치: 불금조 ~10.3%")


func _test_bichon_registration() -> void:
	check(Characters.CHARACTERS.has("bichon"), "비숑이 부화 캐릭터로 등록됨")
	check(Characters.CHARACTERS.get("bichon", {}).get("name_kr", "") == "해솔", "비숑 한글 이름 등록")


func _test_bichon_animation_manifest() -> void:
	var expected := {
		"Idle": 11, "Walk": 12, "Sleep": 8, "FileHover": 4,
		"FileConsume": 8, "Poop": 6, "Sick": 8, "Sulk": 8,
		"Dragged": 4, "Fall": 4, "Land": 4, "Pet": 8, "Play": 8,
	}
	for animation in expected:
		var config: Dictionary = PetScript.BICHON_ANIMATIONS.get(animation, {})
		check(config.get("frames", 0) == expected[animation], "비숑 %s 프레임 수" % animation)
		# 비숑은 airborne 선언을 쓰지 않는다 — 이 시트들의 foot_padding 변동은 "떠오른 높이"가
		# 아니라 프레임별 바운딩 박스 차이라, 매 프레임 발 재고정(기본 접지 처리)이 정답이다.
		# 출시 후 정상 동작 중인 시각 결과를 바꾸지 않기 위한 잠금 (2026-08-06).
		check(not bool(config.get("airborne", false)), "비숑 %s airborne 미선언 (접지 재고정 유지)" % animation)


# 삐약 계열: 14상태 x 3티어(base/evolved/evolved2) 애니메이션 오버라이드 매니페스트.
# 리메이크 셀은 전부 192x208, 접지 상태의 foot_padding은 16.0 고정. Happy(=Play)/Dragged/Fall만
# 의도적으로 공중에 떠서 프레임마다 값이 커진다. Land만 loop=false.
const PPIYAK_TIERS := ["base", "evolved", "evolved2"]
const PPIYAK_SHEET_DIR := {"base": "ppiyak", "evolved": "ppiyak_evolved", "evolved2": "ppiyak_evolved2"}
const PPIYAK_EXPECTED_STATES := {
	# Idle만 물리 6칸을 sprite_frame_sequence로 논리 16프레임에 매핑한다 — 격자 칸 수 != frames.
	"Idle": {"file": "idle_blink_6f_remake.png", "frames": 16, "columns": 6, "rows": 1, "loop": true, "grounded": true, "sequence": [0, 0, 1, 1, 2, 2, 3, 3, 0, 4, 5, 4, 0, 0, 2, 2]},
	"Walk": {"file": "walk_8f_remake.png", "frames": 8, "columns": 4, "rows": 2, "loop": true, "grounded": true},
	"Sleep": {"file": "sleep_6f_remake.png", "frames": 6, "columns": 6, "rows": 1, "loop": true, "grounded": true},
	"Eat": {"file": "eat_6f_remake.png", "frames": 6, "columns": 6, "rows": 1, "loop": true, "grounded": true},
	"Sick": {"file": "sick_6f_remake.png", "frames": 6, "columns": 6, "rows": 1, "loop": true, "grounded": true},
	"Sulk": {"file": "sulk_6f_remake.png", "frames": 6, "columns": 6, "rows": 1, "loop": true, "grounded": true},
	# Happy 시트는 state_machine에 없는 "Happy"가 아니라 "Play" 상태 키로 등록된다.
	"Play": {"file": "happy_6f_remake.png", "frames": 6, "columns": 6, "rows": 1, "loop": true, "grounded": false},
	"Dragged": {"file": "dragged_4f_remake.png", "frames": 4, "columns": 4, "rows": 1, "loop": true, "grounded": false},
	# Fall은 loop:false다(2026-08-10 변경). 시트가 단조 하강 호이고 마지막 칸이 착지 직전
	# 스쿼시라, 루프면 그 스쿼시에서 최고점의 늘어난 포즈로 되돌아 튄다(mochi/base 83.3%).
	# 낙하 1주기가 4프레임/12fps = 0.333초 = 133px이라 드래그마다 사실상 매번 되돌았다.
	# 지금은 Land와 같은 처리 — 호를 한 번 재생하고 착지 직전 프레임을 유지한다.
	"Fall": {"file": "fall_4f_remake.png", "frames": 4, "columns": 4, "rows": 1, "loop": false, "grounded": false},
	"Land": {"file": "land_4f_remake.png", "frames": 4, "columns": 4, "rows": 1, "loop": false, "grounded": true},
	# 잔여 4상태(2026-08-10 추가) — 이로써 삐약 3티어가 비숑과 동일한 14상태를 갖춘다.
	"FileHover": {"file": "file_hover_4f_remake.png", "frames": 4, "columns": 4, "rows": 1, "loop": false, "grounded": true},
	"FileConsume": {"file": "file_consume_6f_remake.png", "frames": 6, "columns": 6, "rows": 1, "loop": false, "grounded": true},
	"Poop": {"file": "poop_6f_remake.png", "frames": 6, "columns": 6, "rows": 1, "loop": true, "grounded": true},
	"Pet": {"file": "pet_6f_remake.png", "frames": 6, "columns": 6, "rows": 1, "loop": false, "grounded": true},
}


func _test_ppiyak_animated_sleep_manifest() -> void:
	var entry: Dictionary = PetScript.ANIMATED_POSE_OVERRIDES.get("ppiyak", {})
	check(not entry.is_empty(), "삐약 포즈 오버라이드 등록됨")
	var states: Dictionary = entry.get("states", {})
	check(states.size() == PPIYAK_EXPECTED_STATES.size(),
		"삐약 등록 상태 수 %d == 기대 %d (14상태 커버리지)" % [states.size(), PPIYAK_EXPECTED_STATES.size()])
	# 삐약은 3티어 전부 전용 시트가 있으므로 "tiers" 제한을 걸면 안 된다 (모찌와 다른 점).
	check(entry.get("tiers", []).is_empty(), "삐약 tiers 제한 없음 (base/evolved/evolved2 전부 시트 보유)")
	# sheet_scale은 tier -> 보정값 딕셔너리다(모찌와 같은 형식). 티어를 등록해 두지 않으면
	# 그 티어만 보정 없이(1.0) 렌더돼 진화 시 몸통 크기가 튄다 — 3티어 전부 값이 있어야 한다.
	var ppiyak_sheet_scale: Dictionary = entry.get("sheet_scale", {})
	for tier in ["base", "evolved", "evolved2"]:
		check(float(ppiyak_sheet_scale.get(tier, 0.0)) > 0.0,
			"삐약 sheet_scale[%s] 등록됨 (%.3f)" % [tier, float(ppiyak_sheet_scale.get(tier, 0.0))])
	# state_machine이 정의하지 않는 상태명은 등록되면 안 된다 (Happy는 Play로 들어간다).
	for illegal in ["Happy", "Jump", "Perch", "Egg"]:
		check(not states.has(illegal), "삐약 %s 미등록 (state_machine에 없는 키)" % illegal)

	for state in PPIYAK_EXPECTED_STATES:
		var expected: Dictionary = PPIYAK_EXPECTED_STATES[state]
		var by_tier: Dictionary = states.get(state, {})
		check(not by_tier.is_empty(), "삐약 %s 등록됨" % state)
		for tier in PPIYAK_TIERS:
			check(by_tier.has(tier), "삐약 %s/%s 티어 등록" % [state, tier])
			var config: Dictionary = by_tier.get(tier, {})
			if config.is_empty():
				continue
			var frames: int = int(config.get("frames", 0))
			var columns: int = int(config.get("columns", 0))
			var rows: int = int(config.get("rows", 0))
			check(frames == expected["frames"], "삐약 %s/%s 프레임 수 %d == %d" % [state, tier, frames, expected["frames"]])
			check(columns == expected["columns"] and rows == expected["rows"],
				"삐약 %s/%s 격자 %dx%d == %dx%d" % [state, tier, columns, rows, expected["columns"], expected["rows"]])
			var want_sequence: Array = expected.get("sequence", [])
			if want_sequence.is_empty():
				check(columns * rows == frames, "삐약 %s/%s 격자 칸 수(%d) == frames(%d)" % [state, tier, columns * rows, frames])
			else:
				# 셀 재사용 상태는 등록된 시퀀스가 기대값과 정확히 같아야 한다. 시퀀스가 빠지면
				# 런타임이 조용히 물리 칸만 순서대로 돌려 깜박임이 사라진다.
				check(config.get("sprite_frame_sequence", []) == want_sequence,
					"삐약 %s/%s sprite_frame_sequence == 기대 시퀀스" % [state, tier])
			check(bool(config.get("loop", false)) == expected["loop"], "삐약 %s/%s loop == %s" % [state, tier, expected["loop"]])
			check(float(config.get("fps", 0.0)) > 0.0, "삐약 %s/%s fps > 0" % [state, tier])
			var path: String = String(config.get("path", ""))
			var want_path: String = "res://assets/sprites/%s/%s" % [PPIYAK_SHEET_DIR[tier], expected["file"]]
			check(path == want_path, "삐약 %s/%s path == %s" % [state, tier, want_path])
			check(ResourceLoader.exists(path), "삐약 %s/%s 시트 존재: %s" % [state, tier, path])
			var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
			check(texture != null, "삐약 %s/%s 시트 로드" % [state, tier])
			if texture != null:
				var size: Vector2 = texture.get_size()
				check(int(size.x) == 192 * columns and int(size.y) == 208 * rows,
					"삐약 %s/%s 시트 크기 %dx%d == 192x208 격자" % [state, tier, int(size.x), int(size.y)])
			for key in ["foot_padding", "horizontal_offsets"]:
				var arr: Array = config.get(key, [])
				check(arr.size() == frames, "삐약 %s/%s %s 길이(%d) == frames(%d)" % [state, tier, key, arr.size(), frames])
			# 접지 상태는 발바닥 기준선이 전 프레임 16.0으로 고정 — 상태를 바꿔도 발이 튀지 않는다.
			# 공중 상태(Play/Dragged/Fall)는 foot_padding이 점프·부유 높이를 만들므로 16 이상이면 된다.
			var padding_ok := true
			for value in config.get("foot_padding", []):
				if expected["grounded"]:
					if not approx(float(value), 16.0):
						padding_ok = false
				elif float(value) < 16.0:
					padding_ok = false
			check(padding_ok, "삐약 %s/%s foot_padding %s" % [state, tier,
				"전 프레임 16.0" if expected["grounded"] else ">= 16.0 (공중 진폭)"])
			# 공중 상태는 "airborne": true 가 반드시 있어야 한다 — 없으면 런타임이 매 프레임 발을
			# 지면에 재고정해 foot_padding 진폭을 그대로 상쇄한다(2026-08-06 블로커 회귀 방지).
			var want_airborne: bool = not bool(expected["grounded"])
			check(bool(config.get("airborne", false)) == want_airborne,
				"삐약 %s/%s airborne == %s" % [state, tier, want_airborne])
			# 몸통 중심 좌우 흔들림은 셀 중심 기준 +-7px 이내 (핸드오프 실측 -7.0 ~ +3.5)
			var offsets_bounded := true
			for value in config.get("horizontal_offsets", []):
				if absf(float(value)) > 7.0:
					offsets_bounded = false
			check(offsets_bounded, "삐약 %s/%s horizontal_offsets 절댓값 <= 7.0" % [state, tier])
			var seq: Array = config.get("sprite_frame_sequence", [])
			if not seq.is_empty():
				check(seq.size() == frames, "삐약 %s/%s sprite_frame_sequence 길이" % [state, tier])
				var in_range := true
				for v in seq:
					if int(v) < 0 or int(v) >= columns * rows:
						in_range = false
				check(in_range, "삐약 %s/%s sprite_frame_sequence 값이 격자 범위 내" % [state, tier])

	# 공중 상태는 실제로 프레임 간 높이 변화가 있어야 한다 (foot_padding 등록 누락 회귀 방지).
	for state in ["Play", "Dragged", "Fall"]:
		for tier in PPIYAK_TIERS:
			var padding: Array = states.get(state, {}).get(tier, {}).get("foot_padding", [])
			var varies := false
			for value in padding:
				if not approx(float(value), 16.0):
					varies = true
			check(varies, "삐약 %s/%s 공중 진폭 존재 (foot_padding이 전부 16.0이 아님)" % [state, tier])

	# Sick 시트에는 어지럼 기호가 없다 — 런타임 @_@ 라벨을 띄우도록 플래그가 켜져 있어야 한다.
	for tier in PPIYAK_TIERS:
		check(bool(states.get("Sick", {}).get(tier, {}).get("runtime_sick_mark", false)),
			"삐약 Sick/%s runtime_sick_mark == true (@_@ 라벨 런타임 렌더)" % tier)

	# 밉맵: 축소 렌더링 자산이므로 42장 전부 mipmaps/generate=true여야 한다 (제작 가이드 §2).
	for tier in PPIYAK_TIERS:
		for state in PPIYAK_EXPECTED_STATES:
			var import_path: String = "res://assets/sprites/%s/%s.import" % [PPIYAK_SHEET_DIR[tier], PPIYAK_EXPECTED_STATES[state]["file"]]
			var f := FileAccess.open(import_path, FileAccess.READ)
			check(f != null and f.get_as_text().contains("mipmaps/generate=true"),
				"삐약 %s/%s .import 밉맵 생성 켜짐" % [state, tier])

	# 레거시 정지 포즈 8종은 삭제하지 않고 보존한다 (회귀 비교용).
	for dir_name in ["ppiyak", "ppiyak_evolved", "ppiyak_evolved2"]:
		for pose in ["idle", "walk1", "walk2", "sleep", "happy", "sulk", "sick", "eat"]:
			check(FileAccess.file_exists("res://assets/sprites/chars/%s/%s.png" % [dir_name, pose]),
				"삐약 %s 레거시 정지 %s.png 잔존(보존)" % [dir_name, pose])


# 삐약 Idle 눈 깜박임: 물리 6칸(1152x208) 시트를 논리 16프레임에 매핑한다.
# 인덱스 4/5가 "눈 감은" 셀이라, 시퀀스에서 이 둘이 빠지면 시트만 교체되고 깜박임은 사라진다.
const PPIYAK_BLINK_CELLS := [4, 5]


func _test_ppiyak_idle_blink_sheet() -> void:
	var states: Dictionary = PetScript.ANIMATED_POSE_OVERRIDES.get("ppiyak", {}).get("states", {})
	var idle_by_tier: Dictionary = states.get("Idle", {})
	for tier in PPIYAK_TIERS:
		var config: Dictionary = idle_by_tier.get(tier, {})
		check(not config.is_empty(), "삐약 블링크 Idle/%s 등록됨" % tier)
		if config.is_empty():
			continue
		check(int(config.get("frames", 0)) == 16, "삐약 블링크 Idle/%s frames == 16" % tier)
		for key in ["foot_padding", "horizontal_offsets"]:
			check(Array(config.get(key, [])).size() == 16,
				"삐약 블링크 Idle/%s %s 길이 == 16" % [tier, key])

		var seq: Array = config.get("sprite_frame_sequence", [])
		check(seq.size() == 16, "삐약 블링크 Idle/%s sprite_frame_sequence 길이 == 16" % tier)
		var in_range := true
		for v in seq:
			if int(v) < 0 or int(v) > 5:
				in_range = false
		check(in_range, "삐약 블링크 Idle/%s 시퀀스 값 전부 0~5 (물리 6칸)" % tier)
		var blink_hits := 0
		for v in seq:
			if int(v) in PPIYAK_BLINK_CELLS:
				blink_hits += 1
		check(blink_hits > 0, "삐약 블링크 Idle/%s 시퀀스에 눈 감은 셀(4/5) %d회 포함" % [tier, blink_hits])

		var path: String = String(config.get("path", ""))
		var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
		check(texture != null, "삐약 블링크 Idle/%s 시트 로드: %s" % [tier, path])
		if texture == null:
			continue
		var image: Image = texture.get_image()
		check(image.get_width() == 1152 and image.get_height() == 208,
			"삐약 블링크 Idle/%s 시트 크기 %dx%d == 1152x208" % [tier, image.get_width(), image.get_height()])
		if image.get_width() != 1152 or image.get_height() != 208:
			continue
		# 6칸이 서로 다른 그림이어야 한다 — 복사된 칸이 섞이면 매니페스트는 통과하는데
		# 화면에서는 깜박이지 않는다(2026-08-07 헤드리스 QA에서 픽셀로 확인).
		var cells: Array[Image] = []
		for index in 6:
			cells.append(image.get_region(Rect2i(index * 192, 0, 192, 208)))
		var duplicates := ""
		for i in 6:
			for j in range(i + 1, 6):
				if _image_diff_pixels(cells[i], cells[j]) == 0:
					duplicates += " %d==%d" % [i, j]
		check(duplicates.is_empty(), "삐약 블링크 Idle/%s 6칸 전부 서로 다른 그림%s" % [tier, duplicates])


## 두 동일 크기 이미지에서 RGBA 중 한 채널이라도 0.05 넘게 다른 픽셀 수.
func _image_diff_pixels(a: Image, b: Image) -> int:
	var count := 0
	for y in a.get_height():
		for x in a.get_width():
			var pa: Color = a.get_pixel(x, y)
			var pb: Color = b.get_pixel(x, y)
			if absf(pa.r - pb.r) > 0.05 or absf(pa.g - pb.g) > 0.05 \
					or absf(pa.b - pb.b) > 0.05 or absf(pa.a - pb.a) > 0.05:
				count += 1
	return count


# 모찌 base: 10상태 포즈 오버라이드 매니페스트. 셀 192x208, foot_padding 전 프레임 16.0.
# 햄찌 base 14상태 — 셀 128x128, 접지 기준선 12.0 고정, evolved/evolved2는 아트 미제작.
const HAEMJJI_EXPECTED_STATES := {
	"Idle": {"frames": 6, "columns": 6, "rows": 1, "loop": true},
	"Walk": {"frames": 8, "columns": 4, "rows": 2, "loop": true},
	"Sleep": {"frames": 6, "columns": 6, "rows": 1, "loop": true},
	"Eat": {"frames": 6, "columns": 6, "rows": 1, "loop": true},
	"Sick": {"frames": 6, "columns": 6, "rows": 1, "loop": true},
	"Sulk": {"frames": 6, "columns": 6, "rows": 1, "loop": true},
	"Play": {"frames": 6, "columns": 6, "rows": 1, "loop": true},
	"Dragged": {"frames": 4, "columns": 4, "rows": 1, "loop": true},
	# Fall은 loop:false다 — 단조 하강 호라 루프면 착지 직전 스쿼시에서 최고점으로 되돌아 튄다.
	"Fall": {"frames": 4, "columns": 4, "rows": 1, "loop": false},
	"Land": {"frames": 4, "columns": 4, "rows": 1, "loop": false},
	"FileHover": {"frames": 4, "columns": 4, "rows": 1, "loop": false},
	"FileConsume": {"frames": 4, "columns": 4, "rows": 1, "loop": false},
	"Poop": {"frames": 6, "columns": 6, "rows": 1, "loop": true},
	"Pet": {"frames": 6, "columns": 6, "rows": 1, "loop": false},
}


# 2026-08-12 재작성. 이전 판은 `ANIMATED_POSE_OVERRIDES["haemjji"]`(구세대 `_alpha_smooth`
# 128셀)를 검증했는데, 런타임은 `pet.gd:1085`의 무조건 early return으로 이미
# `haemjji_remake_config`(신세대 `_remake` 192x208셀)를 쓰고 있었다. 즉 이 검사는 **제품이
# 쓰지 않는 데이터를 검증하며 초록을 유지**하고 있었고, 그 구조가 화면 몸통 +68.9% 결함을
# 가린 것과 같은 뿌리다. 그래서 런타임 config를 직접 보게 고쳤다.
#
# 셀 규약이 128 -> 192x208로 바뀌었으므로 접지 기준선도 12.0 -> 16.0이다(mochi와 같은 208 규약).
# 실측으로 확인했다: 42조합 전부 셀 192x208, 접지 상태 foot_padding 전 프레임 16.0 균일,
# 공중 3상태만 편차, horizontal_offsets 전부 0.0(조립 시 0으로 채워진다).
func _test_haemjji_pose_manifest() -> void:
	var scale_map: Dictionary = PetScript.HAEMJJI_REMAKE_SHEET_SCALE
	check(scale_map.size() == 3, "햄찌 sheet_scale 티어맵 구조 (HAEMJJI_REMAKE_SHEET_SCALE %d개)" % scale_map.size())
	for tier in ["base", "evolved", "evolved2"]:
		check(float(scale_map.get(tier, 0.0)) > 0.0,
			"햄찌 sheet_scale[%s] 등록됨 (%.4f)" % [tier, float(scale_map.get(tier, 0.0))])
	var covered := 0

	for state in HAEMJJI_EXPECTED_STATES:
		var expected: Dictionary = HAEMJJI_EXPECTED_STATES[state]
		for tier in ["base", "evolved", "evolved2"]:
			var label: String = "햄찌 %s %s" % [tier, state]
			var config: Dictionary = PetScript.haemjji_remake_config(tier, state)
			covered += 1
			check(not config.is_empty(), "%s 등록됨" % label)
			if config.is_empty():
				continue
			var frames: int = int(config.get("frames", 0))
			var columns: int = int(config.get("columns", 0))
			var rows: int = int(config.get("rows", 0))
			check(frames == expected["frames"] and columns == expected["columns"] and rows == expected["rows"],
				"%s 격자 %dx%d / %d프레임" % [label, columns, rows, frames])
			check(columns * rows == frames, "%s 격자 칸 수(%d) == frames(%d)" % [label, columns * rows, frames])
			check(bool(config.get("loop", false)) == expected["loop"], "%s loop == %s" % [label, expected["loop"]])
			check(float(config.get("fps", 0.0)) > 0.0, "%s fps > 0" % label)
			var path: String = String(config.get("path", ""))
			var expected_dir: String = "res://assets/sprites/haemjji%s/" % ("" if tier == "base" else "_" + tier)
			check(path.begins_with(expected_dir) and ResourceLoader.exists(path),
				"%s 시트 경로·존재: %s" % [label, path.get_file()])
			var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
			check(texture != null, "%s 시트 로드" % label)
			if texture != null:
				# 신세대 `_remake`는 192x208 셀이다(구 128 정사각이 아니다).
				var size: Vector2 = texture.get_size()
				check(int(size.x) == 192 * columns and int(size.y) == 208 * rows,
					"%s 시트 크기 %dx%d == 격자 x 192x208" % [label, int(size.x), int(size.y)])
			for key in ["foot_padding", "horizontal_offsets"]:
				var arr: Array = config.get(key, [])
				check(arr.size() == frames, "%s %s 길이(%d) == frames(%d)" % [label, key, arr.size(), frames])
			# 접지 상태는 전 프레임 12.0 — 프레임 간 상하 튐이 없어야 한다.
			# 공중 상태(airborne)는 다르다: foot_padding의 프레임 간 편차가 곧 화면상 부양 높이라
			# 균일하면 오히려 점프·낙하가 0px로 죽는다. 대신 최솟값이 12.0인지 본다.
			# 주의: 이 최솟값은 발 정렬의 필요조건이 아니다. ground_padding을 생략하면 런타임이
			# 최솟값을 접지 기준으로 잡으므로(pet.gd _minimum_foot_padding) 최솟값이 4든 16든
			# 접지 프레임의 발 높이는 항상 0이다 — 2026-08-10 헤드리스 실측으로 18개 조합 전부
			# 확인했다. 그래서 이 검사가 지키는 것은 "시트가 셀 안에서 같은 높이 예산을 쓴다"는
			# 규약이며, 실제 발 어긋남을 막는 것은 아래 ground_padding 검사다.
			var is_airborne: bool = bool(config.get("airborne", false))
			var paddings: Array = config.get("foot_padding", [])
			if is_airborne:
				var min_pad: float = 9999.0
				for value in paddings:
					min_pad = minf(min_pad, float(value))
				check(approx(min_pad, 16.0),
					"%s 공중 상태 foot_padding 최솟값 16.0 (편차 = 부양 높이)" % label)
				_check_airborne_ground_reference(label, config, min_pad)
				_check_fall_descends(label, state, paddings)
			else:
				var padding_uniform := true
				for value in paddings:
					if not approx(float(value), 16.0):
						padding_uniform = false
				check(padding_uniform, "%s foot_padding 전 프레임 16.0" % label)
			# evolved는 셰프 토크·앞치마 때문에 base(±2.0)보다 중심 흔들림이 크다(핸드오프 실측 ±3.5).
			# 진화 티어는 착용물(토크·앞치마·금관) 때문에 base(±2.0)보다 중심 흔들림이 크다.
			var offset_bound: float = 2.0 if tier == "base" else 3.5
			var offsets_bounded := true
			for value in config.get("horizontal_offsets", []):
				if absf(float(value)) > offset_bound:
					offsets_bounded = false
			check(offsets_bounded, "%s horizontal_offsets 절댓값 <= %.1f" % [label, offset_bound])
			# 공중 3상태만 airborne (없으면 매 프레임 발 재고정이 부양분을 상쇄한다).
			check(bool(config.get("airborne", false)) == (state in ["Play", "Dragged", "Fall"]),
				"%s airborne == %s" % [label, state in ["Play", "Dragged", "Fall"]])
			# Sick 시트에 부유 기호가 없으므로 런타임 @_@ 라벨이 어지럼 표시를 대신해야 한다.
			check(bool(config.get("runtime_sick_mark", false)) == (state == "Sick"),
				"%s runtime_sick_mark == %s" % [label, state == "Sick"])


const MOCHI_EXPECTED_STATES := {
	"Idle": {"frames": 4, "columns": 4, "rows": 1, "loop": true},
	"Walk": {"frames": 8, "columns": 4, "rows": 2, "loop": true},
	"Sleep": {"frames": 4, "columns": 4, "rows": 1, "loop": true},
	"Eat": {"frames": 4, "columns": 4, "rows": 1, "loop": true},
	"Sick": {"frames": 4, "columns": 4, "rows": 1, "loop": true},
	"Sulk": {"frames": 4, "columns": 4, "rows": 1, "loop": true},
	"Play": {"frames": 4, "columns": 4, "rows": 1, "loop": true},
	"Dragged": {"frames": 4, "columns": 4, "rows": 1, "loop": true},
	# Fall은 loop:false다 — 단조 하강 호라 루프면 착지 직전 스쿼시에서 최고점으로 되돌아 튄다.
	"Fall": {"frames": 4, "columns": 4, "rows": 1, "loop": false},
	"Land": {"frames": 4, "columns": 4, "rows": 1, "loop": false},
	# 잔여 4상태(2026-08-07 추가) — 이로써 모찌가 bichon과 동일한 14상태를 갖춘다.
	"FileHover": {"frames": 4, "columns": 4, "rows": 1, "loop": false},
	"FileConsume": {"frames": 4, "columns": 4, "rows": 1, "loop": false},
	"Poop": {"frames": 4, "columns": 4, "rows": 1, "loop": true},
	"Pet": {"frames": 4, "columns": 4, "rows": 1, "loop": false},
}


func _test_mochi_pose_manifest() -> void:
	var entry: Dictionary = PetScript.ANIMATED_POSE_OVERRIDES.get("mochi", {})
	check(not entry.is_empty(), "모찌 포즈 오버라이드 등록됨")
	var states: Dictionary = entry.get("states", {})
	check(states.size() == MOCHI_EXPECTED_STATES.size(),
		"모찌 등록 상태 수 %d == 기대 %d" % [states.size(), MOCHI_EXPECTED_STATES.size()])
	# base(모찌)·evolved(프로찌)·evolved2(회찌) 3티어 전부 애니메이션 시트를 갖는다.
	check(entry.get("tiers", []) == ["base", "evolved", "evolved2"], "모찌 tiers == 3티어 전부")
	# 시트 셀(208px)이 정지 포즈 캔버스(128px)보다 커서 sheet_scale로 몸통 크기를 맞춘다.
	# 정지 경로와 같은 화면 높이를 내는 실효 배율 (핸드오프 실측).
	# 티어마다 정지 아트 몸통(78 / 119 / 115)과 시트 몸통(129 / 158 / 176)이 달라 보정값도 티어별이다.
	# BODY_SCALE 변경 이력: 3.076/1.956/2.018 (구 실루엣 기준) -> 2.222/1.441/1.553 (몸통 정규화)
	# -> 1.757/1.757/1.866 (2026-08-07 사용자 지정 "눈 크기" 기준, body-size-audit.md §8.1)
	# -> 1.757/0.9598/1.1109 (2026-08-07 §12: evolved 계열 아트가 256px로 복원돼 BODY_SCALE이
	#    ~1/2로 내려가고, 그 위에 크기 사다리 x1.0926/x1.1852가 곱해졌다).
	# sheet_scale은 "같은 티어의 정지 아트 / 시트" 비율인데 정지 아트만 2배가 됐으므로
	# 0.605/0.753/0.653 -> 0.605/1.5060/1.3001 로 같이 올라갔다(시트 자산은 128px 그대로).
	# 그래서 실효 배율은 base 불변, evolved/evolved2만 사다리 배율만큼 커진다.
	# 실효 배율은 등록 데이터에서 유도한다 — 곱을 리터럴로 박으면 sheet_scale 변경마다 썩는다.
	var sheet_scale_by_tier: Dictionary = entry.get("sheet_scale", {})
	for tier in ["base", "evolved", "evolved2"]:
		check(float(sheet_scale_by_tier.get(tier, 0.0)) > 0.0,
			"모찌 sheet_scale[%s] 등록됨 (%.4f)" % [tier, float(sheet_scale_by_tier.get(tier, 0.0))])
		check(effective_body_scale("mochi", tier) > 0.0,
			"모찌 %s 실효 몸통 배율 %.4f 산출 가능 (BODY_SCALE x sheet_scale)" % [tier, effective_body_scale("mochi", tier)])
	# 티어별 몸통 중심 흔들림 허용 범위 (핸드오프 실측: base -4.0~+5.0, evolved -3.0~+6.0, evolved2 -4.0~+6.0)
	var offset_bounds := {"base": 5.0, "evolved": 6.0, "evolved2": 6.0}
	var tier_dirs := {"base": "mochi", "evolved": "mochi_evolved", "evolved2": "mochi_evolved2"}

	for state in MOCHI_EXPECTED_STATES:
		var expected: Dictionary = MOCHI_EXPECTED_STATES[state]
		var by_tier: Dictionary = states.get(state, {})
		check(not by_tier.is_empty(), "모찌 %s 등록됨" % state)
		check(not by_tier.has("path"), "모찌 %s 는 티어맵 구조 (티어별 분기)" % state)
		for tier in ["base", "evolved", "evolved2"]:
			var label: String = "모찌 %s %s" % [tier, state]
			var config: Dictionary = by_tier.get(tier, {})
			check(not config.is_empty(), "%s 등록됨" % label)
			if config.is_empty():
				continue
			var frames: int = int(config.get("frames", 0))
			var columns: int = int(config.get("columns", 0))
			var rows: int = int(config.get("rows", 0))
			check(frames == expected["frames"], "%s 프레임 수 %d == %d" % [label, frames, expected["frames"]])
			check(columns == expected["columns"] and rows == expected["rows"],
				"%s 격자 %dx%d == %dx%d" % [label, columns, rows, expected["columns"], expected["rows"]])
			check(columns * rows == frames, "%s 격자 칸 수(%d) == frames(%d)" % [label, columns * rows, frames])
			check(bool(config.get("loop", false)) == expected["loop"], "%s loop == %s" % [label, expected["loop"]])
			check(float(config.get("fps", 0.0)) > 0.0, "%s fps > 0" % label)
			var path: String = String(config.get("path", ""))
			check(path.begins_with("res://assets/sprites/%s/" % tier_dirs[tier]),
				"%s 경로가 티어 폴더(%s)를 가리킴: %s" % [label, tier_dirs[tier], path])
			check(ResourceLoader.exists(path), "%s 시트 존재: %s" % [label, path])
			var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
			check(texture != null, "%s 시트 로드" % label)
			if texture != null:
				var size: Vector2 = texture.get_size()
				check(int(size.x) == 192 * columns and int(size.y) == 208 * rows,
					"%s 시트 크기 %dx%d == 격자 x 192x208" % [label, int(size.x), int(size.y)])
			for key in ["foot_padding", "horizontal_offsets"]:
				var arr: Array = config.get(key, [])
				check(arr.size() == frames, "%s %s 길이(%d) == frames(%d)" % [label, key, arr.size(), frames])
			# 접지 상태는 전 프레임 셀 하단 16px — 프레임 간 상하 튐이 없어야 한다.
			# 공중 상태(airborne)는 편차가 곧 부양 높이라 균일하면 안 된다 — 최솟값만 검사한다.
			# 최솟값 자체가 발 정렬을 보장하는 게 아니라는 점은 haemjji 쪽 같은 위치 주석 참고.
			var is_airborne: bool = bool(config.get("airborne", false))
			var paddings: Array = config.get("foot_padding", [])
			if is_airborne:
				var min_pad: float = 9999.0
				for value in paddings:
					min_pad = minf(min_pad, float(value))
				check(approx(min_pad, 16.0),
					"%s 공중 상태 foot_padding 최솟값 16.0 (편차 = 부양 높이)" % label)
				_check_airborne_ground_reference(label, config, min_pad)
				_check_fall_descends(label, state, paddings)
			else:
				var padding_uniform := true
				for value in paddings:
					if not approx(float(value), 16.0):
						padding_uniform = false
				check(padding_uniform, "%s foot_padding 전 프레임 16.0" % label)
			var offsets_bounded := true
			for value in config.get("horizontal_offsets", []):
				if absf(float(value)) > float(offset_bounds[tier]):
					offsets_bounded = false
			check(offsets_bounded, "%s horizontal_offsets 절댓값 <= %.1f" % [label, offset_bounds[tier]])
			# 공중 3상태는 airborne 선언이 있어야 한다 (모찌는 padding 고정이라 화면 결과는 동일하지만,
			# 시트를 다시 뽑아 진폭이 생기는 순간 이 선언이 없으면 그대로 상쇄된다).
			var want_airborne: bool = state in ["Play", "Dragged", "Fall"]
			check(bool(config.get("airborne", false)) == want_airborne,
				"%s airborne == %s" % [label, want_airborne])
			# Sick 시트에 어지럼 표시가 없으므로 런타임 @_@ 라벨을 반드시 켜야 한다.
			# (2026-08-06 회귀: 이 키가 빠져 모찌 Sick이 Sulk와 화면상 구분되지 않았다.)
			check(bool(config.get("runtime_sick_mark", false)) == (state == "Sick"),
				"%s runtime_sick_mark == %s" % [label, state == "Sick"])

	# 이번 스코프에서 미제작인 상태는 등록되지 않아야 한다 (정지 포즈 폴백 유지).
	# 모찌는 bichon과 동일한 14상태를 갖췄다 — state_machine에 없는 키가 섞이면 안 된다.
	for illegal in ["Happy", "Jump", "Perch", "Egg"]:
		check(not states.has(illegal), "모찌 %s 미등록 (Happy는 Play 키로 들어간다)" % illegal)


func _test_bichon_evolution() -> void:
	var pet := make_pet("bichon")
	for i in 14:
		pet.note_file_dropped()
	check(not pet.evolved, "비숑 진화 미충족 (파일 14개)")
	pet.note_file_dropped()
	check(pet.evolved, "비숑 진화: 파일 15개 정리")
	for i in 45:
		pet.note_file_dropped()
	check(pet.evolved_2, "비숑 최종 진화: 파일 60개 누적 - 별솔")


func _test_bichon_care_reactions() -> void:
	var pet_state := make_pet("bichon")
	var pet: Node2D = PetScene.instantiate()
	pet.screen_size = Vector2(1280.0, 720.0)
	pet.ground_y = 714.0
	root.add_child(pet)
	await process_frame
	pet.ps = pet_state
	pet.refresh_appearance()
	# 벽시계 의존 제거: 케어 반응 후 복귀 애니메이션은 "그 시점의 상태"라서, 실행 시각이
	# 야간(기본 22~7시)에 걸리면 대기 중 _check_global()이 Sleep으로 넘겨 "Idle 복귀"가 깨진다.
	# night_start == night_end면 is_night()가 항상 false이므로 must_sleep()을 확실히 끈다.
	var save_manager: Node = root.get_node("SaveManager")
	_saved_night_window = [save_manager.settings["night_start"], save_manager.settings["night_end"]]
	save_manager.settings["night_start"] = 0
	save_manager.settings["night_end"] = 0
	check(not pet.machine.must_sleep(), "케어 반응 테스트 전제: 강제 수면 조건 해제됨")
	# 이 테스트의 대상은 반응→복귀 경로이지 자율 전환이 아니므로 상태머신을 멈춰 격리한다
	# (_test_pose_reaction_triggers가 같은 이유로 이미 쓰는 방식이다).
	# ⚠️ 이것이 아래 앵커 복귀 간헐 실패(약 15회 중 1회)의 원인이라는 근거는 아직 없다.
	# 2026-08-11에 두 가설을 세우고 둘 다 실측으로 반증했다:
	#   (1) 반응 시퀀스의 잔여 상태 — celebrate+play_frolic 쌍 12회, play_frolic 단독 12회
	#       격리 실행에서 실패 0건이라 시퀀스 자체는 원인이 아니다.
	#   (2) 반응 창(0.8초) 중 idle_state의 자율 Walk 전환으로 복귀 대상 시트가 바뀜 —
	#       상태머신을 켠 채 20회 관측했으나 Idle 이탈 0건이라 반증됐다.
	# 즉 원인 미규명 상태이고, 이 줄은 격리 목적일 뿐 수정으로 간주하면 안 된다.
	pet.machine.set_process(false)
	check(pet._is_animated_pet(), "비숑이 애니메이션 펫 경로를 사용")
	check(pet._animation_catalog() == PetScript.BICHON_ANIMATIONS, "비숑 전용 애니메이션 카탈로그 선택")
	for care_reaction in ["Pet", "Play"]:
		pet._on_care_performed(care_reaction.to_lower())
		check(pet._bichon_override == care_reaction and pet._bichon_animation == care_reaction and pet._sprite.texture != null, "비숑 %s 케어 반응 경로와 에셋 로드" % care_reaction)
		var reaction_restored: bool = await await_bichon_restored(pet)
		check(reaction_restored and pet._bichon_animation == "Idle", "비숑 %s 후 Idle 복귀" % care_reaction)
	# 좌표 밀림 회귀: celebrate/play_frolic이 tween으로 SPRITE_SIZE 기준 좌표를 직접 옮기면
	# 애니메이션 상태 복귀 후에도 프레임별 발 위치(foot_padding)가 깨진 채 남는다.
	# 비숑은 상태마다 별도 시트(크기 다름)를 쓰므로, Idle로 복귀했을 때의 앵커만 비교한다.
	var idle_anchor_y: float = pet._sprite.position.y
	pet.celebrate()
	check(pet._bichon_override == "Play", "비숑 celebrate가 Play 시트 재생 경로 사용")
	var celebrate_ok: bool = await await_bichon_anchor(pet, idle_anchor_y)
	check(celebrate_ok, "비숑 celebrate 후 Idle 프레임 앵커로 복귀 (%s)" % bichon_anchor_diag(pet, idle_anchor_y))
	pet.play_frolic()
	check(pet._bichon_override == "Play", "비숑 play_frolic이 Play 시트 재생 경로 사용")
	# 복귀를 관측하지 않고 위치만 보면, 복귀가 늦었을 때 Play 시트 프레임 앵커를 재게 된다 —
	# reset_sprite_pose 검사까지 연쇄로 무너뜨렸던 경로다.
	var frolic_ok: bool = await await_bichon_anchor(pet, idle_anchor_y)
	check(frolic_ok, "비숑 play_frolic 후 Idle 프레임 앵커로 복귀 (%s)" % bichon_anchor_diag(pet, idle_anchor_y))
	pet._sprite.position.y = idle_anchor_y - 40.0
	pet.reset_sprite_pose()
	check(approx(pet._sprite.position.y, idle_anchor_y), "비숑 reset_sprite_pose가 프레임 앵커로 복귀 (%s)" % bichon_anchor_diag(pet, idle_anchor_y))
	pet.queue_free()
	pet_state.free()
	call_deferred("_test_mochi_pose_runtime")


# 모찌 10상태를 실제 씬에서 재생해 시트가 걸리는지·프레임 앵커가 흔들리지 않는지 확인.
# 매니페스트 검사(_test_mochi_pose_manifest)가 데이터만 보는 것과 달리 런타임 경로를 통과시킨다.
func _test_mochi_pose_runtime() -> void:
	var pet_state := make_pet("mochi")
	var pet: Node2D = PetScene.instantiate()
	pet.screen_size = Vector2(1280.0, 720.0)
	pet.ground_y = 714.0
	root.add_child(pet)
	await process_frame
	pet.ps = pet_state
	pet.refresh_appearance()
	check(not pet._is_animated_pet(), "모찌는 비숑 카탈로그 경로를 쓰지 않음 (포즈 오버라이드 경로)")

	for state in MOCHI_EXPECTED_STATES:
		var expected: Dictionary = MOCHI_EXPECTED_STATES[state]
		pet.play_state_animation(state)
		check(pet._pose_override_active and pet._pose_override_state == state,
			"모찌 %s 시트 오버라이드 활성" % state)
		check(pet._sprite.texture != null
			and pet._sprite.hframes == expected["columns"] and pet._sprite.vframes == expected["rows"],
			"모찌 %s 텍스처 로드 + 격자 %dx%d 적용" % [state, expected["columns"], expected["rows"]])
		# 발바닥 기준선: foot_padding이 전 프레임 16.0이므로 프레임을 넘겨도 y 앵커가 고정이어야 한다.
		var anchor_y: float = pet._sprite.position.y
		var y_stable := true
		var x_bounded := true
		for frame_index in int(expected["frames"]):
			pet._set_bichon_frame(frame_index)
			if not approx(pet._sprite.position.y, anchor_y):
				y_stable = false
			# 몸통 중심 흔들림은 horizontal_offsets(<=5px) x 배율만큼만 허용
			if absf(pet._sprite.position.x) > 5.0 * pet._base_scale.x + 0.01:
				x_bounded = false
		check(y_stable, "모찌 %s 전 프레임 발바닥 앵커 고정" % state)
		check(x_bounded, "모찌 %s 전 프레임 몸통 중심 흔들림 한계 내" % state)

	# Walk 좌우 반전: 모찌 시트는 정면 대칭이라 walk_face_inverted가 없어야 하고,
	# flip_h가 걸리면 horizontal_offsets도 같이 부호가 뒤집혀 몸통 중심 보정이 유지되어야 한다.
	check(not Characters.is_walk_face_inverted("mochi"),
		"모찌 walk_face_inverted 없음 (정면 대칭 시트 — 반전 보정 불필요)")
	pet.play_state_animation("Walk")
	pet._sprite.flip_h = false
	pet._set_bichon_frame(6)   # horizontal_offsets[6] == -2.0 (0이 아닌 프레임)
	var unflipped_x: float = pet._sprite.position.x
	pet._sprite.flip_h = true
	pet._set_bichon_frame(6)
	check(approx(pet._sprite.position.x, -unflipped_x),
		"모찌 Walk flip_h 시 horizontal_offsets 부호 반전 (%.3f → %.3f)" % [unflipped_x, pet._sprite.position.x])
	pet._sprite.flip_h = false

	# 미등록 상태로 전환하면 정지 포즈로 폴백하고 격자를 1x1로 되돌려야 한다
	# (되돌리지 않으면 128px 정지 이미지가 4칸으로 잘려 몸통 1/4만 보인다).
	# Jump/Perch는 상태머신에는 있지만 어느 종족도 시트를 등록하지 않은 상태다 —
	# 모찌가 14상태를 전부 갖춘 뒤에도 폴백 경로를 검증할 수 있는 실제 사례.
	pet.play_state_animation("Jump")
	check(not pet._pose_override_active, "모찌 미등록 상태(Jump) → 포즈 오버라이드 해제")
	check(pet._sprite.hframes == 1 and pet._sprite.vframes == 1, "모찌 폴백 시 격자 1x1 복원")

	# 실효 몸통 배율이 정지 경로와 같은 화면 높이를 내는지 (sheet_scale 적용 확인)
	pet.play_state_animation("Idle")
	var stage_scale: float = float(PetScript.STAGE_SCALE[pet_state.stage])
	# 1.063 = BODY_SCALE 1.757(사용자 지정 눈 크기 기준) x sheet_scale 0.605.
	# 이력: 1.860(구 실루엣 기준) -> 1.344(몸통 정규화) -> 1.063.
	# base 티어는 §12 256px 복원 대상이 아니므로 이 값은 그대로다.
	check(approx(pet._base_scale.y, stage_scale * effective_body_scale("mochi", "base"), 0.01),
		"모찌 Idle 실효 배율 %.4f == STAGE_SCALE x BODY_SCALE x sheet_scale" % pet._base_scale.y)

	# Sick 옵션 조회 경로 (sick_state.gd가 @_@ 라벨 여부를 이 값으로 결정한다).
	pet.play_state_animation("Sick")
	check(bool(pet.animated_pose_option("Sick", "runtime_sick_mark", false)),
		"모찌 animated_pose_option(Sick, runtime_sick_mark) == true")
	# 실제 sick_state.gd를 태워 화면에 아픔 신호가 남는지 확인 — 옵션 조회만으로는
	# "Sick이 Sulk와 구분되지 않는다"는 회귀를 못 잡는다.
	var sick_state: Node = load("res://scripts/states/sick_state.gd").new()
	sick_state.pet = pet
	sick_state.enter()
	check(pet._sick_mark.visible, "모찌 Sick 진입 시 @_@ 라벨 표시 (Sulk와 구분됨)")
	sick_state.exit()
	check(not pet._sick_mark.visible, "모찌 Sick 이탈 시 @_@ 라벨 해제")
	sick_state.free()
	check(not bool(pet.animated_pose_option("Sulk", "runtime_sick_mark", false)),
		"모찌 Sulk에는 runtime_sick_mark 없음 (기본값 반환)")
	# 공중 3상태(Play/Dragged/Fall)는 foot_padding 편차가 화면상 부양으로 나와야 한다.
	# 2026-08-10 이전에는 padding이 전 프레임 고정이라 airborne을 켜도 상승분이 0px이었고,
	# 이 테스트가 그 한계를 "회귀 없음"으로 박제하고 있었다. 시트를 재합성해 진폭을 살렸으므로
	# 이제는 반대로 "실제로 뜨는가"를 잠근다 — 다시 균일해지면 여기서 잡힌다.
	# foot_offset은 0 = 지면, 음수 = 공중이다(pet.gd:1091 규약).
	# 진폭 기대값은 시트 config에서 유도한다 — 아직 재합성되지 않아 padding이 균일한 시트가
	# 남아 있어서, 전부 뜬다고 단정하면 그쪽이 거짓 실패로 잡힌다.
	for state in ["Play", "Dragged", "Fall"]:
		pet.play_state_animation(state)
		var paddings: Array = pet.animated_pose_option(state, "foot_padding", [])
		var pad_min: float = 9999.0
		var pad_max: float = -9999.0
		for value in paddings:
			pad_min = minf(pad_min, float(value))
			pad_max = maxf(pad_max, float(value))
		# 기대값을 config에서 유도하면 안 된다 — padding이 다시 균일해지는 회귀가 나면
		# expects_lift도 같이 false가 되어 아래 단정문이 조용히 꺼진다. 명시 목록으로 잠근다.
		var expects_lift: bool = "mochi/base/%s" % state in AIRBORNE_MUST_LIFT
		check(expects_lift == (pad_max - pad_min > 0.01),
			"모찌 base %s 부양 여부가 AIRBORNE_MUST_LIFT 목록과 일치" % state)
		var deepest := 0.0
		var never_sinks := true
		for frame_index in pet._pose_override_frame_count:
			pet._set_bichon_frame(frame_index)
			var offset: float = pet.current_frame_foot_offset()
			deepest = minf(deepest, offset)
			if offset > 0.01:
				never_sinks = false
		if expects_lift:
			check(deepest < -0.5, "모찌 %s 공중 프레임이 실제로 뜬다 (최대 %.1fpx)" % [state, -deepest])
		check(never_sinks, "모찌 %s 어느 프레임도 지면 아래로 내려가지 않는다" % state)
	# Land는 접지 상태다 — 착지 연출이라 발이 떠 있으면 안 된다.
	pet.play_state_animation("Land")
	var land_grounded := true
	for frame_index in pet._pose_override_frame_count:
		pet._set_bichon_frame(frame_index)
		if not approx(pet.current_frame_foot_offset(), 0.0):
			land_grounded = false
	check(land_grounded, "모찌 Land는 전 프레임 발이 지면 고정 (접지 상태)")

	# 회귀 1: refresh_appearance()가 재생 중이던 시트를 다시 걸어야 한다.
	# 성장(stage_changed)·위장 해제·관리자 콘솔이 이 함수를 부르는데, 시트를 잃으면
	# transition_to()가 같은 상태로는 조기 반환하므로 다른 상태가 될 때까지 정지 포즈가 남는다.
	pet.play_state_animation("Idle")
	var sheet_texture: String = pet._sprite.texture.resource_path
	var sheet_scale_y: float = pet._base_scale.y
	pet.refresh_appearance()
	check(pet._pose_override_active and pet._pose_override_state == "Idle",
		"모찌 refresh_appearance() 후 시트 오버라이드 유지")
	check(pet._sprite.hframes == 4 and pet._sprite.vframes == 1,
		"모찌 refresh_appearance() 후 격자 4x1 유지 (정지 포즈로 안 떨어짐)")
	check(pet._sprite.texture != null and pet._sprite.texture.resource_path == sheet_texture,
		"모찌 refresh_appearance() 후 같은 시트 텍스처 유지")
	check(approx(pet._base_scale.y, sheet_scale_y),
		"모찌 refresh_appearance() 후 시트 배율 유지 (정지 배율로 안 튐)")
	# 재생 중이 아니었으면 되살리지 않아야 한다 — 삐약이 구석으로 걸어가는 Sleep 전반처럼
	# 아직 시트를 걸지 않은 구간에서 시트가 조기 재생되면 안 된다.
	pet.play_state_animation("Jump")   # 미등록 → 정지 포즈
	pet.refresh_appearance()
	check(not pet._pose_override_active,
		"모찌 재생 중이 아닐 때 refresh_appearance()가 시트를 되살리지 않음")

	# 회귀 2: 호흡 트윈이 도는 중에 시트가 걸리면 앵커와 실제 배율이 어긋난다.
	# _position_sprite_for_current_frame()은 _base_scale로 앵커를 잡는데 _sprite.scale은
	# 트윈된 값이라, 트윈을 죽이지 않으면 발바닥이 최대 3px 아래로 밀린다.
	pet.idle_breathe()   # 정지 포즈 상태라 트윈이 실제로 생성된다
	check(pet._idle_tween != null, "모찌 정지 포즈에서 호흡 트윈 생성됨 (전제 조건)")
	pet.play_state_animation("Idle")
	check(pet._idle_tween == null, "모찌 시트 적용 시 호흡 트윈 종료")
	check(pet._sprite.scale.is_equal_approx(pet._base_scale),
		"모찌 시트 적용 직후 _sprite.scale == _base_scale (앵커 기준과 일치)")
	await process_frame
	check(pet._sprite.scale.is_equal_approx(pet._base_scale),
		"모찌 다음 프레임에도 배율 유지 (트윈이 되살아나지 않음)")
	check(approx(pet.current_frame_foot_offset(), 0.0),
		"모찌 시트 적용 후 발이 지면에 정확히 접지")

	# 야간 설정은 여기서 되돌리지 않는다 — 되돌리면 뒤따르는 반응 복귀 테스트들이 실제
	# 벽시계 야간(기본 22~7시)에 노출되고, must_sleep()이 상태를 Sleep으로 끌어가 9건이
	# 무더기로 깨진다. 2026-08-10 22:05에 실제로 그렇게 터졌다. 복원은 _finish에서 한다.
	# ps를 먼저 해제하면 남은 프레임의 state_machine._check_global()이 해제된 인스턴스를 참조한다.
	root.remove_child(pet)
	pet.free()
	pet_state.free()
	call_deferred("_test_mochi_tier_runtime")


# 진화 후 Walk 시트가 Idle보다 홀쭉해지면 이동을 시작하는 순간 캐릭터 체형이 바뀐다.
# 한두 프레임만 보는 대신 전 프레임 최솟값을 검사해 보행 주기 중 반복되는 수축을 잡는다.
func _test_mochi_evolved_walk_keeps_body_width() -> void:
	for tier: String in ["evolved", "evolved2"]:
		var idle := _pose_config("mochi", tier, "Idle")
		var walk := _pose_config("mochi", tier, "Walk")
		var idle_width := _frame_visible_size(idle, 0).x
		var minimum_ratio := 9999.0
		for frame: int in int(walk["frames"]):
			minimum_ratio = minf(minimum_ratio, _frame_visible_size(walk, frame).x / idle_width)
		check(minimum_ratio >= 0.9,
			"모찌 %s Walk 전 프레임 폭이 Idle의 90%% 이상 (최솟값 %.1f%%)" % [tier, minimum_ratio * 100.0])


# 모찌 10상태 x 티어(base/evolved/evolved2)를 실제 씬에서 재생.
# 매니페스트 검사는 딕셔너리만 보므로 "진화 후 실제로 프로찌 시트가 걸리는가"를 잡지 못한다 —
# 티어 전환(_body_tier)을 태워 base 시트로 새지 않는지, evolved2는 정지 포즈로 폴백하는지 확인한다.
func _test_mochi_tier_runtime() -> void:
	var pet_state := make_pet("mochi")
	var pet: Node2D = PetScene.instantiate()
	pet.screen_size = Vector2(1280.0, 720.0)
	pet.ground_y = 714.0
	root.add_child(pet)
	await process_frame
	pet.ps = pet_state

	# 티어별 기대값: 시트 디렉토리, 실효 배율(BODY_SCALE x sheet_scale), 몸통 중심 흔들림 상한
	var tier_expect := {
		# effective는 하드코딩하지 않고 effective_body_scale()로 유도한다.
		"base": {"dir": "mochi", "offset_bound": 5.0},
		"evolved": {"dir": "mochi_evolved", "offset_bound": 6.0},
		"evolved2": {"dir": "mochi_evolved2", "offset_bound": 6.0},
	}
	for tier in ["base", "evolved", "evolved2"]:
		var expect: Dictionary = tier_expect[tier]
		pet_state.evolved = tier != "base"
		pet_state.evolved_2 = tier == "evolved2"
		pet.refresh_appearance()
		check(pet._body_tier == tier, "모찌 티어 전환 %s → _body_tier == %s" % [tier, pet._body_tier])
		var stage_scale: float = float(PetScript.STAGE_SCALE[pet_state.stage])
		for state in MOCHI_EXPECTED_STATES:
			var frames: int = int(MOCHI_EXPECTED_STATES[state]["frames"])
			pet.play_state_animation(state)
			check(pet._pose_override_active and pet._pose_override_state == state,
				"모찌[%s] %s 시트 오버라이드 활성" % [tier, state])
			# 티어 누수 검사: evolved인데 base 시트(assets/sprites/mochi/)를 물면 화면상 진화가 안 보인다.
			var path: String = pet._sprite.texture.resource_path if pet._sprite.texture != null else ""
			check(path.begins_with("res://assets/sprites/%s/" % expect["dir"]),
				"모찌[%s] %s 시트 경로가 %s/ (티어 누수 없음): %s" % [tier, state, expect["dir"], path.get_file()])
			check(approx(pet._base_scale.y, stage_scale * effective_body_scale("mochi", tier), 0.01),
				"모찌[%s] %s 실효 배율 %.4f == STAGE_SCALE x BODY_SCALE x sheet_scale" % [tier, state, pet._base_scale.y])
			if state == "Walk" and tier in ["evolved", "evolved2"]:
				check(pet._sprite.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR,
					"모찌[%s] Walk는 작은 선화 보존용 linear 필터" % tier)
			# 공중 3상태는 프레임마다 뜨는 것이 정상이라 앵커 고정·접지 검사에서 제외한다.
			var airborne: bool = state in ["Play", "Dragged", "Fall"]
			var anchor_y: float = pet._sprite.position.y
			var y_stable := true
			var x_bounded := true
			var grounded := true
			for frame_index in frames:
				pet._set_bichon_frame(frame_index)
				if not airborne and not approx(pet._sprite.position.y, anchor_y):
					y_stable = false
				if absf(pet._sprite.position.x) > float(expect["offset_bound"]) * pet._base_scale.x + 0.01:
					x_bounded = false
				if not airborne and not approx(pet.current_frame_foot_offset(), 0.0):
					grounded = false
			check(y_stable, "모찌[%s] %s 전 프레임 발바닥 앵커 고정" % [tier, state])
			check(x_bounded, "모찌[%s] %s 몸통 중심 흔들림 <= %.1fpx" % [tier, state, expect["offset_bound"]])
			check(grounded, "모찌[%s] %s 전 프레임 발이 지면 고정" % [tier, state])

	# 시트가 없는 상태(공중 이동 Jump/Perch)는 3티어 모두 정지 포즈로 폴백해야 한다.
	# 폴백 시 격자를 1x1로 되돌리지 않으면 128px 정지 이미지가 4칸으로 잘려 몸통 1/4만 보인다.
	for tier in ["base", "evolved", "evolved2"]:
		pet_state.evolved = tier != "base"
		pet_state.evolved_2 = tier == "evolved2"
		pet.refresh_appearance()
		check(pet._body_tier == tier, "모찌 티어 전환 %s → _body_tier == %s" % [tier, pet._body_tier])
		for state in ["Jump", "Perch"]:
			pet.play_state_animation(state)
			check(not pet._pose_override_active,
				"모찌[%s] %s 시트 미등록 → 정지 포즈 폴백" % [tier, state])
			check(pet._sprite.hframes == 1 and pet._sprite.vframes == 1,
				"모찌[%s] %s 폴백 시 격자 1x1" % [tier, state])
	# 정지 폴백 아트가 실제로 있어야 한다 (없으면 몸통이 base 아트로 되돌아가 진화가 사라진다).
	for pose in ["idle", "walk1", "sleep", "happy", "sulk", "sick", "eat"]:
		check(FileAccess.file_exists("res://assets/sprites/chars/mochi_evolved2/%s.png" % pose),
			"모찌 evolved2 정지 포즈 %s.png 존재 (폴백 아트)" % pose)

	root.remove_child(pet)
	pet.free()
	pet_state.free()
	call_deferred("_test_ppiyak_pose_runtime")


# 삐약 10상태 x 3티어를 실제 씬에서 재생. 모찌와 달리 진화 티어마다 시트가 따로 있으므로
# tier 전환(_body_tier)까지 통과시켜, evolved/evolved2가 base 시트로 새지 않는지 확인한다.
func _test_ppiyak_pose_runtime() -> void:
	var pet_state := make_pet("ppiyak")
	var pet: Node2D = PetScene.instantiate()
	pet.screen_size = Vector2(1280.0, 720.0)
	pet.ground_y = 714.0
	root.add_child(pet)
	await process_frame
	pet.ps = pet_state
	check(not pet._is_animated_pet(), "삐약은 비숑 카탈로그 경로를 쓰지 않음 (포즈 오버라이드 경로)")

	for tier in PPIYAK_TIERS:
		pet_state.evolved = tier != "base"
		pet_state.evolved_2 = tier == "evolved2"
		pet.refresh_appearance()
		check(pet._body_tier == tier, "삐약 티어 전환 %s → _body_tier == %s" % [tier, pet._body_tier])
		for state in PPIYAK_EXPECTED_STATES:
			var expected: Dictionary = PPIYAK_EXPECTED_STATES[state]
			pet.play_state_animation(state)
			check(pet._pose_override_active and pet._pose_override_state == state,
				"삐약 %s/%s 시트 오버라이드 활성" % [state, tier])
			check(pet._sprite.texture != null
				and pet._sprite.hframes == expected["columns"] and pet._sprite.vframes == expected["rows"],
				"삐약 %s/%s 텍스처 로드 + 격자 %dx%d" % [state, tier, expected["columns"], expected["rows"]])
			# 해당 티어의 시트가 실제로 걸렸는지 (티어 폴백 누수 회귀 방지)
			check(String(pet._sprite.texture.resource_path).contains("/%s/" % PPIYAK_SHEET_DIR[tier]),
				"삐약 %s/%s 티어 전용 시트 로드 (%s)" % [state, tier, pet._sprite.texture.resource_path])
			check(pet._pose_override_loop == expected["loop"], "삐약 %s/%s 런타임 loop == %s" % [state, tier, expected["loop"]])
			check(pet._pose_override_frame_count == int(expected["frames"]),
				"삐약 %s/%s 런타임 프레임 수 %d" % [state, tier, pet._pose_override_frame_count])
			var anchor_y: float = pet._sprite.position.y
			var y_stable := true
			var x_bounded := true
			# 화면상 실제 발 위치(0 = 지면). 접지 상태는 전 프레임 0이어야 하고,
			# 공중 상태는 접지 프레임만 0이고 나머지는 음수(떠 있음)여야 한다.
			var foot_min := 0.0
			var foot_max := 0.0
			for frame_index in int(expected["frames"]):
				pet._set_bichon_frame(frame_index)
				if expected["grounded"] and not approx(pet._sprite.position.y, anchor_y):
					y_stable = false
				if absf(pet._sprite.position.x) > 7.0 * pet._base_scale.x + 0.01:
					x_bounded = false
				var foot: float = pet.current_frame_foot_offset()
				if frame_index == 0:
					foot_min = foot
					foot_max = foot
				foot_min = minf(foot_min, foot)
				foot_max = maxf(foot_max, foot)
			check(y_stable, "삐약 %s/%s 전 프레임 발바닥 앵커 고정" % [state, tier])
			check(x_bounded, "삐약 %s/%s 전 프레임 몸통 중심 흔들림 한계 내" % [state, tier])
			# 접지 프레임(공중 상태의 최저점 포함)은 발이 정확히 지면에 닿아야 한다.
			check(approx(foot_max, 0.0), "삐약 %s/%s 최저 프레임 발 == 지면(y=0)" % [state, tier])
			if expected["grounded"]:
				check(approx(foot_min, 0.0), "삐약 %s/%s 전 프레임 발 == 지면(y=0)" % [state, tier])
			else:
				# 공중 상태는 화면상 발이 실제로 떠올라야 한다 (진폭 0이면 점프가 안 보인다).
				check(foot_min < -1.0,
					"삐약 %s/%s 공중 진폭 %.2fpx (화면상 발이 실제로 뜸)" % [state, tier, -foot_min])

	# 공중 상태는 프레임을 넘기면 화면상 캐릭터 최하단(= 발)이 실제로 움직여야 한다.
	# 예전 버전은 _sprite.position.y가 변하는지만 봤는데, 그 값은 발을 매 프레임 지면에
	# 재고정하느라 움직인 것이라 화면 결과(최하단 고정, span 0px)와 정반대였다.
	# 이제는 스프라이트 프레임 안의 실제 발 위치까지 반영한 world y로 검사한다.
	pet_state.evolved = false
	pet_state.evolved_2 = false
	pet.refresh_appearance()
	for state in ["Play", "Dragged", "Fall"]:
		pet.play_state_animation(state)
		var lowest := 0.0
		var highest := 0.0
		for frame_index in pet._pose_override_frame_count:
			pet._set_bichon_frame(frame_index)
			var foot: float = pet.current_frame_foot_offset()
			if frame_index == 0:
				lowest = foot
				highest = foot
			lowest = maxf(lowest, foot)    # y가 클수록 아래 = 접지에 가까움
			highest = minf(highest, foot)
		check(lowest - highest > 1.0,
			"삐약 %s 화면상 발 높이 span %.2fpx > 0 (점프/부유가 실제로 보임)" % [state, lowest - highest])
		check(approx(lowest, 0.0), "삐약 %s 최저 프레임은 지면에 닿음 (y=0)" % state)
	# 접지 상태는 대조군: 프레임을 다 넘겨도 화면상 발이 지면에서 떨어지지 않는다.
	for state in ["Idle", "Walk", "Eat", "Sick", "Sulk", "Sleep", "Land"]:
		pet.play_state_animation(state)
		var grounded_all := true
		for frame_index in pet._pose_override_frame_count:
			pet._set_bichon_frame(frame_index)
			if not approx(pet.current_frame_foot_offset(), 0.0):
				grounded_all = false
		check(grounded_all, "삐약 %s 접지 상태는 전 프레임 발이 지면 고정" % state)

	# Walk 좌우 반전: 시트 기본이 왼쪽이므로 오른쪽 이동 시 flip_h + offsets 부호 반전.
	pet.play_state_animation("Walk")
	pet._sprite.flip_h = false
	pet._set_bichon_frame(3)   # horizontal_offsets[3] == 2.0 (0이 아닌 프레임)
	var unflipped_x: float = pet._sprite.position.x
	pet._sprite.flip_h = true
	pet._set_bichon_frame(3)
	check(approx(pet._sprite.position.x, -unflipped_x),
		"삐약 Walk flip_h 시 horizontal_offsets 부호 반전 (%.3f → %.3f)" % [unflipped_x, pet._sprite.position.x])
	pet._sprite.flip_h = false

	# 삐약은 14상태 전부 시트가 있으므로 폴백은 시트 없는 상태(Jump)로 검증한다.
	pet.play_state_animation("Jump")
	check(not pet._pose_override_active, "삐약 미등록 상태(Jump) → 포즈 오버라이드 해제")
	check(pet._sprite.hframes == 1 and pet._sprite.vframes == 1, "삐약 폴백 시 격자 1x1 복원")

	# Sick 옵션 조회 경로 (sick_state.gd가 @_@ 라벨 여부를 이 값으로 결정한다).
	check(bool(pet.animated_pose_option("Sick", "runtime_sick_mark", false)),
		"삐약 animated_pose_option(Sick, runtime_sick_mark) == true")
	var ppiyak_sick: Node = load("res://scripts/states/sick_state.gd").new()
	ppiyak_sick.pet = pet
	ppiyak_sick.enter()
	check(pet._sick_mark.visible, "삐약 Sick 진입 시 @_@ 라벨 표시")
	ppiyak_sick.exit()
	check(not pet._sick_mark.visible, "삐약 Sick 이탈 시 @_@ 라벨 해제")
	ppiyak_sick.free()
	check(not bool(pet.animated_pose_option("Idle", "runtime_sick_mark", false)),
		"삐약 Idle에는 runtime_sick_mark 없음 (기본값 반환)")

	root.remove_child(pet)
	pet.free()
	pet_state.free()
	call_deferred("_test_size_rules")


# ============================================================================
# 크기 규칙 (2026-08-07 개정): 크기 축이 **둘**이다.
#   A) 성장(stage): egg < baby < child < adult — 여전히 단조증가여야 한다.
#   B) 진화(tier): 같은 성장단계에서 base < evolved < evolved2 로 커진다.
#      예전 규칙("진화는 모양만 바뀐다 = 크기 불변")은 사용자가 명시적으로 철회했다.
#      Characters.TIER_SIZE_LADDER = 1.0 / 1.0926 / 1.1852 (화면 몸통 108 / 118 / 128px).
#
# ⚠️ 두 축의 **전역 9단계 순서는 검사하지 않는다**(예: "evolved 아기 > base 성체").
# 성장 폭(baby→adult 0.32→0.45 = 1.406배)이 진화 폭(1.0926배)보다 크므로 수학적으로 양립
# 불가능하고, 사용자가 "순서 규칙은 느슨하게"로 결정했다. 같은 성장단계 안에서만 진화
# 순서를 보장한다. 이 항목을 "빠진 검사"로 오해해 추가하지 마라 — 반드시 실패한다.
#
# 이 테스트가 잠그는 과거 회귀:
#   1) egg가 BODY_SCALE(성체 아트 정규화용)을 잘못 곱해 종족마다 3.1배까지 벌어지고 adult보다 컸다.
#   2) baby와 child의 STAGE_SCALE이 같아(0.378) 4단계 중 실질 3단계뿐이었다.
#   3) 삐약 애니메이션 시트에 sheet_scale이 없어 진화 시 몸통이 12.7% 커졌다.
#   4) 진화 티어 아트가 확대 렌더(BODY_SCALE x STAGE_SCALE > 1.0)라 뿌옇게 나왔다 (§12).
# 화면상 몸통 높이 = (현재 프레임 알파 바운딩박스 높이) x _base_scale.y 로 실측한다.
# ============================================================================

## 현재 걸린 텍스처의 "현재 프레임" 알파 바운딩박스 높이 x 배율 = 화면상 몸통 높이(px).
## 화면에 보이는 실루엣으로 치는 알파 하한. 이보다 옅은 픽셀은 몸통 크기에 포함하지 않는다.
const VISIBLE_ALPHA := 0.125


## visible_only=true면 α>VISIBLE_ALPHA인 픽셀만 몸통으로 친다. 서로 다른 자산의 크기를 비교할
## 때 필요하다 — 기본 get_used_rect()는 α>0이라 자산마다 두께가 다른 투명 헤일로까지 세기 때문이다.
## 기본값을 바꾸면 헤일로에 기대어 보정값이 잡힌 기존 캐릭터(seureureuk 등)가 함께 흔들린다.
func _rendered_body_height(pet: Node2D, visible_only := false) -> float:
	var tex: Texture2D = pet._sprite.texture
	if tex == null:
		return 0.0
	var img: Image = tex.get_image()
	if img == null:
		return 0.0
	var cols: int = maxi(pet._sprite.hframes, 1)
	var rows: int = maxi(pet._sprite.vframes, 1)
	var cell_w: int = img.get_width() / cols
	var cell_h: int = img.get_height() / rows
	var index: int = pet._sprite.frame
	var cell: Image = img.get_region(Rect2i(
		(index % cols) * cell_w, (index / cols) * cell_h, cell_w, cell_h))
	if not visible_only:
		return float(cell.get_used_rect().size.y) * pet._base_scale.y
	var top := -1
	var bottom := -1
	for y in range(cell.get_height()):
		for x in range(cell.get_width()):
			if cell.get_pixel(x, y).a > VISIBLE_ALPHA:
				if top < 0:
					top = y
				bottom = y
				break
	if top < 0:
		return 0.0
	return float(bottom - top + 1) * pet._base_scale.y


## 정지 포즈(idle) 상태의 화면상 몸통 높이. stage/tier를 세팅하고 다시 그린다.
func _static_body_height(pet: Node2D, pet_state: Node, stage: String, tier := "base", visible_only := false) -> float:
	pet_state.stage = stage
	pet_state.evolved = tier != "base"
	pet_state.evolved_2 = tier == "evolved2"
	pet.refresh_appearance()
	return _rendered_body_height(pet, visible_only)


## 현재 걸린 정지 포즈 텍스처에서 "캐릭터 발"이 지면(y=0)에서 얼마나 떨어져 있는지(px, 화면 기준).
## 0이면 정확히 접지, 양수면 공중에 뜬 것, 음수면 지면 아래로 파고든 것.
## 캔버스 크기가 티어마다 다르므로(base 128 / evolved·evolved2 256) 반드시 실측 텍스처 크기로
## 계산한다 — 상수 128을 곱하면 256px 티어가 화면에서 크게 어긋난다(2026-08-07 §12 회귀 방지).
func _static_foot_gap(pet: Node2D) -> float:
	var tex: Texture2D = pet._sprite.texture
	if tex == null:
		return 999.0
	var img: Image = tex.get_image()
	if img == null:
		return 999.0
	var h: int = img.get_height()
	var bottom := -1
	for y in range(h - 1, -1, -1):
		var found := false
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > VISIBLE_ALPHA:
				found = true
				break
		if found:
			bottom = y
			break
	if bottom < 0:
		return 999.0
	# 스프라이트는 중앙 정렬이라 텍스처 상단이 position.y - h * scale / 2 에 놓인다.
	return -(pet._sprite.position.y + (float(bottom + 1) - float(h) * 0.5) * pet._base_scale.y)


func _test_size_rules() -> void:
	var pet_state := make_pet("mochi")
	var pet: Node2D = PetScene.instantiate()
	pet.screen_size = Vector2(1280.0, 720.0)
	pet.ground_y = 714.0
	root.add_child(pet)
	await process_frame
	pet.ps = pet_state

	# --- 1. 성장 단계 단조증가: egg < baby < child < adult ---
	# 예전에는 baby == child(둘 다 0.378)라 실질 3단계였다.
	for species in ["mochi", "tokki", "ppiyak", "bichon"]:
		pet_state.debug_set_species(species)
		var heights: Array[float] = []
		for stage in ["egg", "baby", "child", "adult"]:
			heights.append(_static_body_height(pet, pet_state, stage))
		var monotonic := true
		for i in range(1, heights.size()):
			if heights[i] <= heights[i - 1]:
				monotonic = false
		check(monotonic, "[%s] 성장 단계 단조증가 egg<baby<child<adult (%.1f/%.1f/%.1f/%.1f)"
			% [species, heights[0], heights[1], heights[2], heights[3]])

	# --- 2. egg는 종족과 무관하게 같은 크기 ---
	# egg 아트(chars/egg/*.png)는 전 종족 공통 단일 이미지이므로 화면 크기도 공통이어야 한다.
	# BODY_SCALE을 곱하던 시절엔 모찌 219px vs 비숑 71px로 3.1배 벌어졌다.
	var egg_heights := {}
	for species in ["mochi", "tokki", "ppiyak", "bichon", "ddungsil", "kong"]:
		pet_state.debug_set_species(species)
		egg_heights[species] = _static_body_height(pet, pet_state, "egg")
	var egg_values: Array = egg_heights.values()
	var egg_min: float = egg_values.min()
	var egg_max: float = egg_values.max()
	check(egg_max - egg_min <= 1.0,
		"egg 크기가 종족과 무관하게 동일 (편차 %.2fpx <= 1px, %s)" % [egg_max - egg_min, egg_heights])
	check(egg_min > 0.0, "egg가 화면에 보이는 크기 (%.1fpx > 0)" % egg_min)

	# --- 3. 몸통(코어) 정규화: 진화 단계 크기 불변 + 12종 크로스-종족 균일 ---
	# 2026-08-07: 정규화 기준이 전체 실루엣 -> 몸통(코어 덩어리)으로 바뀌었다.
	# 예전 테스트는 알파 바운딩박스 높이가 티어끼리 +-5%인지 봤지만, 이제 실루엣은 **의도적으로**
	# 벌어진다(귀·불꽃·촉수 같은 부속물이 몸통에서 빠졌으므로). 대신 코어 몸통 높이 실측값
	# (Characters.BODY_CORE_HEIGHT, body-size-audit.md 36장 전수 실측)에 BODY_SCALE을 곱한 값이
	# 전 종족·전 티어에서 같은 목표(2 x BODY_SCALE_TARGET_TORSO)로 수렴하는지 본다 —
	# "진화는 모양만 바뀐다"(티어 불변)와 "12종 몸집이 서로 비슷하다"(크로스-종족)를 한 번에 잠근다.
	# 2026-08-07 후속: mochi/mundeok/tokki 3종은 사용자가 몸통 높이가 아닌 별도 지표를 직접
	# 지정했다(모찌=눈 크기 중앙값 13.44px, 문덕이=머리끝 높이 중앙값 75.85px, 당근이=발 접지 + 5% 축소).
	# 그래서 이 3종은 공통 목표에서 -32% ~ +22%까지 벗어나며, 그것이 정상이다
	# (근거는 Characters.TORSO_NORMALIZATION_EXEMPT의 reason과 body-size-audit.md §8).
	# 예외 종족은 검사에서 빼지 않는다 — 공통 목표(160) 대신 그 종족의 기대값 +-2%로 검사한다.
	# 2026-08-07: 공통 목표가 티어별로 달라졌다 — 크기 사다리를 곱한다(160 / 174.8 / 189.6).
	var torso_target_base: float = 2.0 * Characters.BODY_SCALE_TARGET_TORSO
	var adult_scale: float = float(PetScript.STAGE_SCALE["adult"])
	# 예외가 슬금슬금 늘어나는 것을 막는 상한. 늘리려면 육안 QA 근거를 남기고 이 수를 올려라.
	check(Characters.TORSO_NORMALIZATION_EXEMPT.size() <= 3,
		"몸통 정규화 예외가 3종 이하 (현재 %d종: %s)"
		% [Characters.TORSO_NORMALIZATION_EXEMPT.size(),
			", ".join(Characters.TORSO_NORMALIZATION_EXEMPT.keys())])
	for exempt_species in Characters.TORSO_NORMALIZATION_EXEMPT.keys():
		var entry: Dictionary = Characters.TORSO_NORMALIZATION_EXEMPT[exempt_species]
		check(Characters.BODY_SCALE.has(exempt_species)
			and not String(entry.get("reason", "")).is_empty()
			and entry.get("expected_torso", {}).size() == 3,
			"[%s] 예외 항목이 사유 + 3티어 기대값을 갖춤" % exempt_species)
	for species in Characters.BODY_SCALE.keys():
		check(Characters.BODY_CORE_HEIGHT.has(species),
			"[%s] 코어 몸통 실측값 등록됨 (BODY_CORE_HEIGHT)" % species)
		pet_state.debug_set_species(species)
		var exempt: bool = Characters.TORSO_NORMALIZATION_EXEMPT.has(species)
		for tier in ["base", "evolved", "evolved2"]:
			var core: float = Characters.get_body_core_height(species, tier)
			var scale: float = Characters.get_body_scale(species, tier)
			# 예외 종족은 자기 기대값으로, 나머지 10종은 공통 목표 160으로 엄격히 검사한다.
			var expected: float = Characters.get_expected_torso(species, tier)
			var torso_target: float = torso_target_base * Characters.get_tier_size_ladder(tier)
			if not exempt:
				check(is_equal_approx(expected, torso_target),
					"[%s/%s] 예외가 아니므로 기대값이 티어 목표 %.1f (160 x 사다리 %.4f)"
					% [species, tier, torso_target, Characters.get_tier_size_ladder(tier)])
			check(core > 0.0 and absf(core * scale - expected) / expected <= 0.02,
				"[%s/%s] 몸통 정규화 코어 %.0f x BODY_SCALE %.3f = %.1f == 기대값 %.1f (+-2%%%s)"
				% [species, tier, core, scale, core * scale, expected,
					", 사용자 지정 기준 예외" if exempt else ""])
			# 실제 렌더 경로(_base_scale)까지 태워서 확인한다 — 위 검사는 테이블만 보므로
			# egg 분기(_static_body_scale)나 티어 해석이 깨져도 잡지 못한다.
			var silhouette: float = _static_body_height(pet, pet_state, "adult", tier)
			var rendered_core: float = core * pet._base_scale.y
			check(absf(rendered_core - expected * adult_scale) / (expected * adult_scale) <= 0.02,
				"[%s/%s] adult 화면상 몸통 %.1fpx == %.1fpx (+-2%%, 실루엣 %.1fpx)"
				% [species, tier, rendered_core, expected * adult_scale, silhouette])
			# 실루엣은 균일하지 않아도 되지만, 몸통 정규화가 폭주하면(예: 코어 오측정) 여기서 걸린다.
			# 상한은 크기 사다리(evolved2 x1.1852)만큼 함께 올렸다: 145 -> 172.
			check(silhouette > 60.0 and silhouette < 172.0,
				"[%s/%s] adult 실루엣 %.1fpx 가 상식 범위(60~172px)" % [species, tier, silhouette])

	# --- 4. 삐약 애니메이션 경로도 진화 단계 크기 불변 ---
	# sheet_scale이 없던 시절 evolved2 Idle이 base/evolved보다 12.7% 컸다.
	# 각 티어의 시트 몸통이 (a) 티어끼리 서로, (b) 자기 티어 정지 포즈와 +-5% 이내여야 한다.
	# 시트와 정지 포즈는 별개 자산이라 투명 헤일로 두께가 다르다 — 양쪽 다 visible_only로 잰다.
	# (ppiyak Idle 시트를 idle_blink_6f로 교체할 때 α>0 측정은 실루엣이 같은데도 -5.8%로 읽혔다.)
	# 2026-08-07: 티어 간 비교는 "시트 실루엣이 서로 같다"에서 "시트가 자기 티어 정지 포즈에
	# 붙어 있는 정도가 티어끼리 같다"로 바꿨다. 정지 포즈 쪽이 이제 몸통 기준으로 정규화되므로
	# (실루엣은 티어마다 다르다) 시트 실루엣의 절대 비교는 더 이상 의미가 없다. 원래 잡으려던
	# 회귀(sheet_scale 누락 -> evolved2만 12.7% 큼)는 아래 비율 비교로 그대로 걸린다.
	# 2026-08-10: 이 검사가 ppiyak에만 걸려 있었다. sheet_scale이 낡으면 화면 크기가 어긋나는데
	# 그 위험은 전 종족 공통이고, 신규 종족(뚱실이)은 아무 방어막이 없었다. 종족 목록을 데이터로
	# 받아 넓혔다 — 티어 아트가 없는 종족은 tiers로 걸러 자기 티어만 본다.
	# sheet_scale을 "정지 bbox / 시트 bbox"로 역산해 잠그는 방안은 기각했다: 그 비율은 알파
	# 임계값에 민감해 전 종족 재현 배수가 0.976~1.084로 흩어지고(실측), 필요한 허용차 ±8%가
	# 정작 잡아야 할 진화 사다리 폭(9.26%)보다 커서 오라클이 못 된다. 반면 아래 렌더 높이 비교는
	# 양쪽을 같은 방식(visible_only)으로 재므로 임계값에 무관하다.
	# 전 종족으로 넓혀봤다가 되돌렸다(2026-08-10). mochi/haemjji/ddungsil에서 13건이 실패하는데
	# 결함이 아니라 이 계약이 보편적이지 않기 때문이다: (a) Walk/Eat은 몸통을 변형시키므로
	# 정지 Idle 포즈와의 높이 비교가 애초에 사과-오렌지다(mochi Walk 19.3%), (b) mochi는
	# TORSO_NORMALIZATION_EXEMPT라 정지 아트가 몸통 기준으로 정규화되지 않아 비교 기준이 없다.
	# ppiyak만 이 대역에 맞춰 조정돼 있다. 넓히려면 종족별 기준값이 먼저 정의돼야 한다.
	for species in ["ppiyak"]:
		var entry: Dictionary = PetScript.ANIMATED_POSE_OVERRIDES.get(species, {})
		if entry.is_empty():
			continue
		var covered: Array = entry.get("tiers", ["base", "evolved", "evolved2"])
		pet_state.debug_set_species(species)
		for state in ["Idle", "Walk", "Eat"]:
			var anim_heights: Array[float] = []
			var anim_ratios: Array[float] = []
			for tier in ["base", "evolved", "evolved2"]:
				if not (tier in covered):
					continue
				var static_h: float = _static_body_height(pet, pet_state, "adult", tier, true)
				pet.play_state_animation(state)
				var anim_h: float = _rendered_body_height(pet, true)
				anim_heights.append(anim_h)
				anim_ratios.append(anim_h / maxf(static_h, 0.001))
				check(static_h > 0.0 and absf(anim_h - static_h) / static_h <= 0.05,
					"[%s/%s] %s 시트가 자기 티어 정지 포즈와 +-5%% (시트 %.1f vs 정지 %.1f, %.1f%%)"
					% [species, tier, state, anim_h, static_h, 100.0 * (anim_h - static_h) / maxf(static_h, 0.001)])
				pet.stop_animated_pose()
			# 티어가 하나뿐인 종족은 티어 간 비교가 성립하지 않는다.
			if anim_ratios.size() < 2:
				continue
			var alo: float = anim_ratios.min()
			var ahi: float = anim_ratios.max()
			check(alo > 0.0 and (ahi - alo) / alo <= 0.05,
				"[%s] %s 시트/정지 비율이 티어끼리 +-5%% (%s)"
				% [species, state, str(anim_ratios)])

	# --- 5. 진화 크기 사다리: 같은 성장단계에서 base < evolved < evolved2 ---
	# 2026-08-07 사용자 지시로 "진화해도 크기 불변" 규칙을 뒤집었다. 검사를 지운 게 아니라
	# 기대값을 뒤집은 것이다 — 이전 규칙으로 되돌리려면 여기와 Characters.TIER_SIZE_LADDER를
	# 같이 고쳐야 한다. 비교 지표는 실루엣이 아니라 화면상 코어 몸통(부속물 제외)이다.
	# 성장단계 간 비교는 하지 않는다(위 ⚠️ 주석 참고 — 성장 폭 > 진화 폭이라 양립 불가).
	# 예외 3종(mochi/mundeok/tokki)은 코어 몸통이 아니라 사용자가 지정한 다른 지표(눈 크기 /
	# 머리끝 높이 / 발 접지)로 정규화돼 있어, base와 evolved의 **코어 몸통 절대값 비교가
	# 애초에 성립하지 않는다** — 예: mundeok은 머리끝 높이를 맞추느라 evolved의 코어가 base보다
	# 원래 작다(121.2 vs 108.4, 사다리 이전부터). 이 3종은 (a) evolved < evolved2 렌더 검사와
	# (b) 사다리가 기대값에 실제로 곱해졌는지를 데이터로 검사한다.
	var ladder_exempt_before := {
		"mochi": {"evolved": 195.0, "evolved2": 192.3},
		"mundeok": {"evolved": 108.4, "evolved2": 108.4},
		"tokki": {"evolved": 164.1, "evolved2": 157.4},
	}
	for species in Characters.BODY_SCALE.keys():
		pet_state.debug_set_species(species)
		var ladder_exempt: bool = Characters.TORSO_NORMALIZATION_EXEMPT.has(species)
		for stage in ["baby", "child", "adult"]:
			var ladder_heights: Array[float] = []
			for tier in ["base", "evolved", "evolved2"]:
				pet_state.stage = stage
				pet_state.evolved = tier != "base"
				pet_state.evolved_2 = tier == "evolved2"
				pet.refresh_appearance()
				ladder_heights.append(Characters.get_body_core_height(species, tier) * pet._base_scale.y)
			if ladder_exempt:
				check(ladder_heights[1] < ladder_heights[2],
					"[%s/%s] 진화 사다리 evolved < evolved2 (%.1f < %.1f px, base %.1f는 사용자 지정 지표라 제외)"
					% [species, stage, ladder_heights[1], ladder_heights[2], ladder_heights[0]])
			else:
				check(ladder_heights[0] < ladder_heights[1] and ladder_heights[1] < ladder_heights[2],
					"[%s/%s] 진화 사다리 base < evolved < evolved2 (%.1f < %.1f < %.1f px)"
					% [species, stage, ladder_heights[0], ladder_heights[1], ladder_heights[2]])
	for species in ladder_exempt_before.keys():
		for tier in ["evolved", "evolved2"]:
			var before: float = float(ladder_exempt_before[species][tier])
			var after: float = Characters.get_expected_torso(species, tier)
			var want: float = before * Characters.get_tier_size_ladder(tier)
			check(absf(after - want) / want <= 0.005,
				"[%s/%s] 예외 종족 기대값에 사다리 적용됨 %.1f x %.4f = %.1f (등록 %.1f)"
				% [species, tier, before, Characters.get_tier_size_ladder(tier), want, after])

	# --- 6. 확대 렌더 금지 (이번 작업의 핵심 성과를 잠근다) ---
	# 렌더 배율 = BODY_SCALE x STAGE_SCALE. 1.0을 넘으면 원본에 없는 픽셀을 보간으로 만들어
	# 뿌옇게 보인다(§12.1: kong/evolved 1.22x, bulgeumjo/evolved2 1.14x 등이 그랬다).
	# 12종 x 3티어 x 3성장단계 = 108조합 전부 1.0 미만이어야 한다.
	# egg는 BODY_SCALE을 곱하지 않으므로(전 종족 공통 아트) 이 검사 대상이 아니다.
	var worst_zoom := 0.0
	var worst_label := ""
	for species in Characters.BODY_SCALE.keys():
		for tier in ["base", "evolved", "evolved2"]:
			var body_scale: float = Characters.get_body_scale(species, tier)
			for stage in ["baby", "child", "adult"]:
				var zoom: float = body_scale * float(PetScript.STAGE_SCALE[stage])
				if zoom > worst_zoom:
					worst_zoom = zoom
					worst_label = "%s/%s/%s" % [species, tier, stage]
				check(zoom <= 1.0,
					"[%s/%s/%s] 확대 렌더 금지 BODY_SCALE %.4f x STAGE_SCALE %.2f = %.4f <= 1.0"
					% [species, tier, stage, body_scale, PetScript.STAGE_SCALE[stage], zoom])
	check(worst_zoom <= 1.0, "108개 조합 최대 렌더 배율 %.4f (%s) <= 1.0" % [worst_zoom, worst_label])

	# --- 7. 캔버스 크기 혼재 + 발 접지 ---
	# 2026-08-07 §12부터 아트 캔버스가 티어마다 다르다: base/egg 128px, evolved/evolved2 256px.
	# 그래서 위치 계산은 상수(STATIC_POSE_FALLBACK_SIZE)가 아니라 실측 텍스처 크기를 써야 한다.
	# 이 검사가 없으면 256px 티어가 화면에서 위아래로 절반쯤 어긋난 채 조용히 통과한다.
	# 종족-티어 단위 예외만 둔다. 전역으로 느슨하게 만들면 위 주석의 버그(상수 128을 256px
	# 티어에 곱하던 것)가 다시 조용히 통과한다 — 그래서 기본 맵은 그대로 두고 덮어쓴다.
	# mochi/base 192: 눈 크기 기준(사용자 지정 "눈이 다른 애들과 비슷하게")을 지키면서 진화
	# 사다리를 맞추려면 몸통을 1.497배(코어 72 -> 109) 키워야 했는데, 그러면 폭이 139가 되어
	# 128 캔버스를 넘는다. 그래서 그 티어만 캔버스를 넓혔다(Task #10, 2026-08-12).
	var expected_canvas := {"base": 128, "evolved": 256, "evolved2": 256}
	var canvas_override := {"mochi": {"base": 192}}
	for species in Characters.BODY_SCALE.keys():
		pet_state.debug_set_species(species)
		for tier in ["base", "evolved", "evolved2"]:
			pet_state.stage = "adult"
			pet_state.evolved = tier != "base"
			pet_state.evolved_2 = tier == "evolved2"
			pet.refresh_appearance()
			var tex: Texture2D = pet._sprite.texture
			var canvas: int = int(tex.get_size().y) if tex != null else 0
			var want_canvas: int = int(expected_canvas[tier])
			var per_species: Dictionary = canvas_override.get(species, {})
			if per_species.has(tier):
				want_canvas = int(per_species[tier])
			check(canvas == want_canvas,
				"[%s/%s] 정지 포즈 캔버스 %dpx == %dpx" % [species, tier, canvas, want_canvas])
			# 캔버스 크기와 무관하게 발이 지면(y=0)에 닿아야 한다. 아트 하단 여백은 0px 규약이라
			# 허용 오차는 1px(반올림)로 충분하다.
			# 허용 오차가 티어별로 다르다. evolved/evolved2는 §12.3에서 하단 여백을 0px로 맞춰
			# 재생성했으므로 1px(반올림) 안에 들어와야 한다. base/egg 128px 아트는 §12에서
			# **의도적으로 손대지 않았고**(§12.9) 원래 하단 여백이 조금 남아 있다 — 현재 실측
			# 2.1~2.9px, seureureuk만 8.6px(배경 소품이 그려진 풀신 아트라 bbox가 크게 잡힌다).
			# 그래서 base는 9px로 둔다. 이 값을 넘으면 캔버스-위치 계산이 어긋난 것이다
			# (상수 128을 256px 티어에 곱하던 버그는 화면상 수십 px로 벌어져 여기서 걸린다).
			var gap: float = _static_foot_gap(pet)
			var gap_bound: float = 1.0 if tier != "base" else 9.0
			check(absf(gap) <= gap_bound,
				"[%s/%s] 발이 지면에 접지 (지면과의 거리 %.2fpx <= %.1f, 캔버스 %dpx)"
				% [species, tier, gap, gap_bound, canvas])

	root.remove_child(pet)
	pet.free()
	pet_state.free()
	call_deferred("_test_pose_reaction_triggers")


# 반응 연출(Pet/FileHover/FileConsume)은 상태머신 상태가 아니라 오버라이드라, 등록만 있고
# 트리거가 막혀 있어도 매니페스트 테스트는 전부 통과한다 — 실제로 2026-08-07에 그랬다
# (등록은 끝났는데 비숑 게이트에 막혀 3상태가 화면에 안 나왔다).
# 그래서 이 테스트는 등록이 아니라 **트리거를 실제로 태워서** 시트가 걸리는지만 본다.
func _test_pose_reaction_triggers() -> void:
	var pet_state := make_pet("mochi")
	pet_state.stage = "adult"
	var pet: Node2D = PetScene.instantiate()
	pet.screen_size = Vector2(1280.0, 720.0)
	pet.ground_y = 714.0
	root.add_child(pet)
	await process_frame
	pet.ps = pet_state
	pet.refresh_appearance()
	# 반응 연출의 복귀 대상은 "상태머신 현재 상태"다. 상태머신을 돌린 채로 두면 대기 중에
	# idle_state가 자율적으로 Walk로 넘어가 복귀 대상이 바뀌고, 검사가 시간에 따라 흔들린다.
	# 여기서 보려는 건 자율 전이가 아니라 반응 오버라이드라서 상태머신 처리를 멈춘다.
	pet.machine.set_process(false)

	# 1) 쓰다듬기 — _on_care_performed → _play_care_reaction → Pet 시트
	pet.play_state_animation("Idle")
	pet._on_care_performed("pet")
	check(pet._pose_override_state == "Pet" and _sheet_dir(pet) == "mochi",
		"모찌 care(pet) → Pet 시트 재생 (state=%s)" % pet._pose_override_state)
	await create_timer(0.9).timeout
	check(pet._pose_override_state == "Idle",
		"모찌 Pet 반응 종료 후 Idle 복귀 (state=%s)" % pet._pose_override_state)

	# 2) 파일 호버 — 켜고 끄기
	pet.set_file_hover(true)
	check(pet._pose_override_state == "FileHover",
		"모찌 set_file_hover(true) → FileHover 시트 (state=%s)" % pet._pose_override_state)
	pet.set_file_hover(false)
	check(pet._pose_override_state == "Idle",
		"모찌 set_file_hover(false) → Idle 복귀 (state=%s)" % pet._pose_override_state)

	# 3) 파일 드롭 — Hover(0.34s) → Consume(0.70s) → 복귀
	pet.play_file_drop_reaction()
	check(pet._pose_override_state == "FileHover", "모찌 파일 드롭 1단계 FileHover")
	await create_timer(0.45).timeout
	check(pet._pose_override_state == "FileConsume",
		"모찌 파일 드롭 2단계 FileConsume (state=%s)" % pet._pose_override_state)
	await create_timer(0.85).timeout
	check(pet._pose_override_state == "Idle",
		"모찌 파일 드롭 종료 후 Idle 복귀 (state=%s)" % pet._pose_override_state)

	# 4) 회귀 방지 — 반응 중 상태가 바뀌면 복귀 예약이 취소되어야 한다.
	# 취소되지 않으면 뒤늦은 타이머가 새 상태를 Pet으로 덮어써 "케어 후 상태가 되돌아가는" 버그가 된다.
	pet._on_care_performed("pet")
	check(pet._pose_override_state == "Pet", "모찌 반응 취소 검증: Pet 재생 시작")
	pet.play_state_animation("Sulk")
	await create_timer(0.9).timeout
	check(pet._pose_override_state == "Sulk",
		"모찌 반응 중 상태 전환 시 복귀 예약 취소 (state=%s, Pet으로 안 되돌아감)" % pet._pose_override_state)

	# 5) refresh_appearance()(성장·위장해제·관리자 콘솔)가 반응 연출 중에 끼어든 경우.
	# 반응 연출은 시간 제한이 있는 일회성이라, 시트만 되살리면 끝내줄 주체가 없어 그 포즈에 멈춘다.
	# 그래서 반응 상태만 예외로 두고 상태머신 현재 상태로 복귀시킨다(2026-08-07 결정).
	pet.play_state_animation("Idle")
	pet._on_care_performed("pet")
	check(pet._pose_override_state == "Pet", "모찌 refresh 취소 검증: Pet 재생 시작")
	pet.refresh_appearance()
	check(pet._pose_reaction_state.is_empty(),
		"모찌 반응 중 refresh_appearance() → 복귀 예약 해제 (_pose_reaction_state 비움)")
	check(pet._pose_override_state == "Idle",
		"모찌 반응 중 refresh → 반응 시트를 되살리지 않고 상태머신 현재 상태(Idle) 복귀 (state=%s)"
		% pet._pose_override_state)
	await create_timer(0.9).timeout
	check(pet._pose_override_state == "Idle",
		"모찌 refresh 후 뒤늦은 복귀 없음 (state=%s)" % pet._pose_override_state)

	# 5-b) 경계 고정 — **반응만 예외**다. 일반 상태 연출(Sulk 등)은 기존대로 이어붙여야 한다.
	# 이 단정문이 없으면 "반응 예외" 처리가 일반 상태까지 삼켜도 아무도 못 잡는다.
	pet.play_state_animation("Sulk")
	pet.refresh_appearance()
	check(pet._pose_override_state == "Sulk",
		"모찌 일반 상태 연출(Sulk) 중 refresh → 그대로 이어붙임 (반응만 예외, state=%s)"
		% pet._pose_override_state)

	# 5-c) 실제 도달 경로 — 성장(stage_changed)이 반응 중에 발생하면 시트도 배율도 갱신되어야 한다.
	pet.play_state_animation("Idle")
	pet._on_care_performed("pet")
	check(pet._pose_override_state == "Pet", "모찌 성장 경로 검증: Pet 재생 시작")
	var scale_before: float = pet._base_scale.y
	pet_state.stage = "child"
	pet.refresh_appearance()
	check(pet._pose_override_state == "Idle",
		"모찌 반응 중 성장 → Idle 시트 복귀 (state=%s)" % pet._pose_override_state)
	check(not approx(pet._base_scale.y, scale_before),
		"모찌 반응 중 성장 → 단계 배율 갱신 (%.4f → %.4f)" % [scale_before, pet._base_scale.y])
	pet_state.stage = "adult"
	pet.refresh_appearance()

	root.remove_child(pet)
	pet.free()
	pet_state.free()

	# 6) 삐약도 14상태를 갖췄으므로 반응 시트가 자기 폴더에서 재생돼야 한다 (2026-08-10).
	var ppiyak_state := make_pet("ppiyak")
	ppiyak_state.stage = "adult"
	var ppiyak: Node2D = PetScene.instantiate()
	ppiyak.screen_size = Vector2(1280.0, 720.0)
	ppiyak.ground_y = 714.0
	root.add_child(ppiyak)
	await process_frame
	ppiyak.ps = ppiyak_state
	ppiyak.refresh_appearance()
	ppiyak.play_state_animation("Idle")
	ppiyak._on_care_performed("pet")
	check(ppiyak._pose_override_state == "Pet" and _sheet_dir(ppiyak) == "ppiyak",
		"삐약 care(pet) → Pet 시트 재생 (state=%s, dir=%s)" % [ppiyak._pose_override_state, _sheet_dir(ppiyak)])
	ppiyak.set_file_hover(true)
	check(ppiyak._pose_override_state == "FileHover" and _sheet_dir(ppiyak) == "ppiyak",
		"삐약 set_file_hover → FileHover 시트 재생 (state=%s)" % ppiyak._pose_override_state)
	ppiyak.set_file_hover(false)

	# 7) 새로 등록한 종족도 케어·파일 반응이 자기 모션 시트로 연결되어야 한다.
	var tokki_state := make_pet("tokki")
	tokki_state.stage = "adult"
	var tokki: Node2D = PetScene.instantiate()
	tokki.screen_size = Vector2(1280.0, 720.0)
	tokki.ground_y = 714.0
	root.add_child(tokki)
	await process_frame
	tokki.ps = tokki_state
	tokki.refresh_appearance()
	tokki._on_care_performed("pet")
	check(tokki._pose_override_state == "Pet" and tokki._pose_override_active,
		"당근이 care(pet) → Pet 모션")
	tokki.set_file_hover(true)
	check(tokki._pose_override_state == "FileHover" and tokki._pose_override_active,
		"당근이 set_file_hover → FileHover 모션")
	root.remove_child(tokki)
	tokki.free()
	tokki_state.free()

	root.remove_child(ppiyak)
	ppiyak.free()
	ppiyak_state.free()
	call_deferred("_test_haemjji_pose_runtime")


# 햄찌 14상태를 실제 씬에서 재생. 매니페스트는 딕셔너리만 보므로 "정말 그 시트가 걸리는가"와
# "진화 티어가 정지 포즈로 폴백하는가"는 여기서만 잡힌다.
func _test_haemjji_pose_runtime() -> void:
	var pet_state := make_pet("haemjji")
	pet_state.stage = "adult"
	var pet: Node2D = PetScene.instantiate()
	pet.screen_size = Vector2(1280.0, 720.0)
	pet.ground_y = 714.0
	root.add_child(pet)
	await process_frame
	pet.ps = pet_state
	pet.refresh_appearance()
	# 아래 반응 트리거 검사가 대기 중 자율 전이(idle_state → Walk)에 흔들리지 않도록 멈춘다.
	pet.machine.set_process(false)

	var stage_scale: float = float(PetScript.STAGE_SCALE[pet_state.stage])
	# 실효 배율 = STAGE_SCALE x BODY_SCALE(티어별) x sheet_scale(티어별)
	var tier_runtime := {
		"base": {"dir": "haemjji"},
		# 2026-08-07 §12: evolved 계열 정지 아트 256px 복원으로 BODY_SCALE이 내려가고 sheet_scale이
		# 같은 비율로 올라갔다. 곱은 크기 사다리(x1.0926 / x1.1852)만큼만 커진다.
		"evolved": {"dir": "haemjji_evolved"},
		"evolved2": {"dir": "haemjji_evolved2"},
	}
	for tier in ["base", "evolved", "evolved2"]:
		var expect: Dictionary = tier_runtime[tier]
		pet_state.evolved = tier != "base"
		pet_state.evolved_2 = tier == "evolved2"
		pet.refresh_appearance()
		check(pet._body_tier == tier, "햄찌 티어 전환 %s → _body_tier == %s" % [tier, pet._body_tier])
		var expected_scale: float = stage_scale * effective_body_scale("haemjji", tier)
		for state in HAEMJJI_EXPECTED_STATES:
			var expected: Dictionary = HAEMJJI_EXPECTED_STATES[state]
			var label: String = "햄찌[%s] %s" % [tier, state]
			pet.play_state_animation(state)
			check(pet._pose_override_active and pet._pose_override_state == state,
				"%s 시트 오버라이드 활성" % label)
			var path: String = pet._sprite.texture.resource_path if pet._sprite.texture != null else ""
			# 티어 누수 검사: evolved인데 base 시트를 물면 화면상 진화가 보이지 않는다.
			check(path.begins_with("res://assets/sprites/%s/" % expect["dir"]),
				"%s 시트가 %s/ 폴더 (%s)" % [label, expect["dir"], path.get_file()])
			check(pet._sprite.hframes == expected["columns"] and pet._sprite.vframes == expected["rows"],
				"%s 격자 %dx%d 적용" % [label, expected["columns"], expected["rows"]])
			check(approx(pet._base_scale.y, expected_scale, 0.01),
				"%s 실효 배율 %.4f == STAGE_SCALE x BODY_SCALE x sheet_scale" % [label, pet._base_scale.y])
			# 접지 상태는 foot_padding이 전 프레임 12.0이라 발이 지면에 고정돼야 한다.
			# 공중 3상태는 반대로 편차가 부양 높이이므로 "실제로 뜨는가"를 본다.
			# foot_offset은 0 = 지면, 음수 = 공중이다. 접지 상태는 0 고정, 공중 상태는 0 이하.
			var airborne: bool = state in ["Play", "Dragged", "Fall"]
			var grounded := true
			for frame_index in int(expected["frames"]):
				pet._set_bichon_frame(frame_index)
				var offset: float = pet.current_frame_foot_offset()
				if offset > 0.01 or (not airborne and not approx(offset, 0.0)):
					grounded = false
			if airborne:
				check(grounded, "%s 공중 상태가 지면 아래로 내려가지 않음" % label)
			else:
				check(grounded, "%s 전 프레임 발이 지면 고정" % label)

	# 아래 반응 트리거 검사는 base 티어에서 수행한다.
	pet_state.evolved = false
	pet_state.evolved_2 = false
	pet.refresh_appearance()

	# 반응 연출(Pet/FileHover/FileConsume)은 상태머신 상태가 아니라 오버라이드라, 등록만 있고
	# 트리거가 막혀 있어도 위 매니페스트·재생 검사는 전부 통과한다 — 모찌에서 실제로 그랬다.
	# 그래서 종족이 늘 때마다 트리거를 직접 태워봐야 한다.
	pet.play_state_animation("Idle")
	pet._on_care_performed("pet")
	check(pet._pose_override_state == "Pet"
		and String(pet._sprite.texture.resource_path).begins_with("res://assets/sprites/haemjji/"),
		"햄찌 care(pet) → Pet 시트 재생 (state=%s)" % pet._pose_override_state)
	await create_timer(0.9).timeout
	check(pet._pose_override_state == "Idle",
		"햄찌 Pet 반응 종료 후 Idle 복귀 (state=%s)" % pet._pose_override_state)

	pet.set_file_hover(true)
	check(pet._pose_override_state == "FileHover",
		"햄찌 set_file_hover(true) → FileHover 시트 (state=%s)" % pet._pose_override_state)
	pet.set_file_hover(false)
	check(pet._pose_override_state == "Idle",
		"햄찌 set_file_hover(false) → Idle 복귀 (state=%s)" % pet._pose_override_state)

	pet.play_file_drop_reaction()
	check(pet._pose_override_state == "FileHover", "햄찌 파일 드롭 1단계 FileHover")
	await create_timer(0.45).timeout
	check(pet._pose_override_state == "FileConsume",
		"햄찌 파일 드롭 2단계 FileConsume (state=%s)" % pet._pose_override_state)
	await create_timer(0.85).timeout
	check(pet._pose_override_state == "Idle",
		"햄찌 파일 드롭 종료 후 Idle 복귀 (state=%s)" % pet._pose_override_state)

	# 반응 중 상태가 바뀌면 복귀 예약이 취소되어야 한다 (뒤늦은 타이머가 새 상태를 덮으면 안 됨).
	pet._on_care_performed("pet")
	check(pet._pose_override_state == "Pet", "햄찌 반응 취소 검증: Pet 재생 시작")
	pet.play_state_animation("Sulk")
	await create_timer(0.9).timeout
	check(pet._pose_override_state == "Sulk",
		"햄찌 반응 중 상태 전환 시 복귀 예약 취소 (state=%s)" % pet._pose_override_state)

	# 햄찌는 3티어 전부 시트가 있으므로, 폴백 경로는 시트가 없는 상태(Jump/Perch)로 검증한다.
	# 폴백 시 격자를 1x1로 되돌리지 않으면 128px 정지 이미지가 6칸으로 잘려 몸통 1/6만 보인다.
	for tier in ["base", "evolved", "evolved2"]:
		pet_state.evolved = tier != "base"
		pet_state.evolved_2 = tier == "evolved2"
		pet.refresh_appearance()
		for state in ["Jump", "Perch"]:
			pet.play_state_animation(state)
			check(not pet._pose_override_active, "햄찌[%s] %s 시트 미등록 → 정지 포즈 폴백" % [tier, state])
			check(pet._sprite.hframes == 1 and pet._sprite.vframes == 1,
				"햄찌[%s] %s 폴백 시 격자 1x1" % [tier, state])

	root.remove_child(pet)
	pet.free()
	pet_state.free()
	call_deferred("_test_food_prop_render_clip")


# 2026-08-11 회귀: 먹기 소품(밥그릇/간식)이 펫 클릭 영역 밖에 옆으로 떠서, main.gd의
# 클릭통과 영역(_update_passthrough)이 펫 사각형만 포함하면 소품이 코드상 visible=true여도
# Windows가 렌더링 자체를 잘라내서 화면에 안 보였다. food_prop_rect()가 정확한 전역
# 사각형을 돌려주는지, 그리고 그 사각형이 실제로 펫 클릭 영역 밖(합쳐줘야 하는 영역)에
# 있는지 잠근다. main.gd 쪽 병합 로직 자체는 DisplayServer가 필요해 여기서 검사할 수 없다.
#
# 2026-08-11: 소품이 종족별 전용에서 13종 공용(FOOD_PROPS가 action만 키)으로 바뀌었다 —
# 그래서 ppiyak/bichon도 이제 다른 종족과 똑같이 소품이 보여야 한다(예전엔 미등록이라
# 빈 사각형이 정상이었지만, 지금 빈 사각형이면 그게 회귀다).
func _test_food_prop_render_clip() -> void:
	# Windows의 mouse-passthrough 영역은 스프라이트 렌더링도 자른다. 당근이는 정지 포즈의
	# 긴 귀·당근과 14개 애니메이션 상태의 셀 전체가 이 영역 안에 들어가야 한다.
	for tier in ["base", "evolved", "evolved2"]:
		var tokki_state: Node = PetStateScript.new()
		tokki_state.debug_set_species("tokki", "adult")
		tokki_state.evolved = tier != "base"
		tokki_state.evolved_2 = tier == "evolved2"
		var tokki: Node2D = PetScene.instantiate()
		tokki.screen_size = Vector2(1280.0, 720.0)
		tokki.ground_y = 714.0
		root.add_child(tokki)
		await process_frame
		tokki.ps = tokki_state
		tokki.refresh_appearance()
		var static_canvas: Vector2 = tokki._frame_size * tokki._base_scale.abs()
		check(tokki.get_click_rect().size.x >= static_canvas.x
			and tokki.get_click_rect().size.y >= static_canvas.y,
			"당근이[%s] 정지 포즈 전체 캔버스가 렌더 영역 안" % tier)
		check(tokki.horizontal_edge_margin() >= static_canvas.x * 0.5,
			"당근이[%s] 정지 포즈가 화면 가장자리 밖으로 나가지 않음" % tier)
		for state in ["Idle", "Walk", "Sleep", "Eat", "Sick", "Sulk", "Play",
				"Dragged", "Fall", "Land", "FileHover", "FileConsume", "Poop", "Pet"]:
			tokki.play_state_animation(state)
			var motion_canvas: Vector2 = tokki._frame_size * tokki._base_scale.abs()
			var motion_config: Dictionary = tokki._pose_override_config(state)
			check(_sheet_cells_have_alpha_inset(
				String(motion_config["path"]),
				int(motion_config["columns"]),
				int(motion_config["rows"])
			), "당근이[%s] %s 모든 프레임에 투명 경계 여백" % [tier, state])
			check(tokki.get_click_rect().size.x >= motion_canvas.x
				and tokki.get_click_rect().size.y >= motion_canvas.y,
				"당근이[%s] %s 셀 전체가 렌더 영역 안" % [tier, state])
			check(tokki.horizontal_edge_margin() >= motion_canvas.x * 0.5,
				"당근이[%s] %s가 화면 가장자리 밖으로 나가지 않음" % [tier, state])
		root.remove_child(tokki)
		tokki.free()
		tokki_state.free()
	# 거부장 2진화 Eat의 지팡이·하트도 같은 경로에서 잘렸던 회귀를 직접 잠근다.
	var geobujang_state: Node = PetStateScript.new()
	geobujang_state.debug_set_species("geobujang", "adult")
	geobujang_state.evolved = true
	geobujang_state.evolved_2 = true
	var geobujang: Node2D = PetScene.instantiate()
	root.add_child(geobujang)
	await process_frame
	geobujang.ps = geobujang_state
	geobujang.refresh_appearance()
	geobujang.position.x = 1.0
	geobujang.play_state_animation("Eat")
	check(geobujang.requires_full_render_region(),
		"거부장[evolved2] 밥/간식 Eat 동안 Windows 렌더 영역 지연의 영향을 받지 않음")
	var eat_canvas: Vector2 = geobujang._frame_size * geobujang._base_scale.abs()
	check(geobujang.get_click_rect().size.x >= eat_canvas.x
		and geobujang.get_click_rect().size.y >= eat_canvas.y,
		"거부장[evolved2] Eat 셀 전체가 렌더 영역 안")
	check(geobujang.get_click_rect().size.x >= eat_canvas.x + 48.0
		and geobujang.get_click_rect().size.y >= eat_canvas.y + 48.0,
		"거부장[evolved2] Eat 손·지팡이 안티앨리어스용 24px 렌더 여백")
	check(geobujang.position.x >= eat_canvas.x * 0.5 + 24.0,
		"거부장[evolved2] Eat 시작 시 왼쪽 화면 끝에서 지팡이 여백 확보")
	check(geobujang.horizontal_edge_margin() >= eat_canvas.x * 0.5 + 24.0,
		"거부장[evolved2] Eat가 화면 가장자리 밖으로 나가지 않음")
	root.remove_child(geobujang)
	geobujang.free()
	geobujang_state.free()
	for species in ["mochi", "haemjji", "ppiyak", "bichon"]:
		var pet_state: Node = PetStateScript.new()
		pet_state.debug_set_species(species, "adult")
		var pet: Node2D = PetScene.instantiate()
		pet.screen_size = Vector2(1280.0, 720.0)
		pet.ground_y = 714.0
		root.add_child(pet)
		await process_frame
		pet.ps = pet_state
		pet.refresh_appearance()
		pet.machine.transition_to("Idle")
		check(pet.food_prop_rect() == Rect2(), "%s 먹기 전엔 food_prop_rect가 빈 사각형" % species)
		pet._on_care_performed("feed")
		var rect: Rect2 = pet.food_prop_rect()
		check(rect.size.x > 0.0 and rect.size.y > 0.0, "%s feed 중 food_prop_rect가 실제 크기를 가짐(공용 소품)" % species)
		check(not pet.get_click_rect().encloses(rect), "%s 먹기 소품은 펫 클릭 영역 밖에 있음(main.gd가 병합해야 함)" % species)
		pet.hide_food_prop()
		check(pet.food_prop_rect() == Rect2(), "%s hide_food_prop 후 food_prop_rect 다시 빈 사각형" % species)
		root.remove_child(pet)
		pet.free()
		pet_state.free()
	check(Characters.get_food_prop("feed") == "res://assets/sprites/food/food_feed.png", "공용 feed 소품 경로")
	check(Characters.get_food_prop("snack") == "res://assets/sprites/food/food_snack.png", "공용 snack 소품 경로")
	check(ResourceLoader.exists(Characters.get_food_prop("feed")), "공용 feed 소품 파일 존재")
	check(ResourceLoader.exists(Characters.get_food_prop("snack")), "공용 snack 소품 파일 존재")

	# 2026-08-11: 통째 스케일 축소 대신 다중 프레임을 duration에 맞춰 순서대로 넘긴다 — 밥은
	# 숟갈째 줄어 빈 그릇만 남고, 간식은 한입씩 사라진다. 시트가 아직 1프레임이어도(자산 준비
	# 전) 안전하게 통과하고, N프레임 시트로 교체되면 그대로 진행 검증까지 잠근다.
	for action in ["feed", "snack"]:
		var pet_state: Node = PetStateScript.new()
		pet_state.debug_set_species("mochi", "adult")
		var pet: Node2D = PetScene.instantiate()
		pet.screen_size = Vector2(1280.0, 720.0)
		pet.ground_y = 714.0
		root.add_child(pet)
		await process_frame
		pet.ps = pet_state
		pet.refresh_appearance()
		pet.machine.transition_to("Idle")
		pet._last_food_action = action
		var duration := 2.0
		pet.show_food_prop(duration)
		var frame_count: int = pet._food_prop_frame_count
		check(frame_count >= 1, "%s 소품 프레임 수 >= 1 (실측 %d)" % [action, frame_count])
		check(pet._food_prop.frame == 0, "%s 소품 재생 시작 시 0번 프레임" % action)
		pet._advance_food_prop(duration * 0.5)
		var mid_frame: int = pet._food_prop.frame
		check(mid_frame >= 0 and mid_frame < frame_count, "%s 소품 절반 지난 시점 프레임(%d)이 범위 내" % [action, mid_frame])
		pet._advance_food_prop(duration * 0.6)  # 총 1.1배 경과 — duration을 넘어도 안전해야 함
		check(pet._food_prop.frame == frame_count - 1, "%s 소품 재생 종료 시 마지막 프레임(%d)에 도달" % [action, frame_count - 1])
		if frame_count > 1:
			check(mid_frame > 0, "%s 소품 절반 지난 시점엔 첫 프레임을 벗어나 있음(다중 프레임일 때만 의미 있음)" % action)
		root.remove_child(pet)
		pet.free()
		pet_state.free()
	call_deferred("_finish")


## 현재 걸린 시트가 속한 자산 폴더 이름 (티어·종족 누수 검사용).
func _sheet_dir(pet: Node2D) -> String:
	if pet._sprite.texture == null:
		return "<null>"
	return pet._sprite.texture.resource_path.get_base_dir().get_file()


func _test_serialize_roundtrip() -> void:
	var pet := make_pet("nyang")
	pet.stats["hunger"] = 42.0
	pet.poop_count = 2
	pet.age_minutes = 1234.0
	var restored: Node = PetStateScript.new()
	restored.deserialize(pet.serialize())
	check(
		restored.species == "nyang"
		and approx(restored.stats["hunger"], 42.0)
		and restored.poop_count == 2
		and approx(restored.age_minutes, 1234.0),
		"직렬화 왕복 보존"
	)


# 소화: 먹이 후 30분 내 응아
func _test_digest() -> void:
	var pet := make_pet("mochi")
	pet.care("feed")
	pet.advance_minutes(Balance.DIGEST_MINUTES_MAX + 1.0, {"hour": 10, "weekday": 2})
	check(pet.poop_count >= 1, "먹이 후 30분 내 응아")


# Plan FR-15 v3: 활동 기반 진화
func _test_evolution_keyboard() -> void:
	var pet := make_pet("mochi")
	var got_tier := [0]
	pet.evolution_ready.connect(func(_s, tier): got_tier[0] = tier)
	pet.add_input_delta({"kb": 15000, "mouse": 0, "active_sec": 0.0, "friday_active_sec": 0.0})
	check(not pet.evolved, "모찌 진화 미충족 (kb 절반)")
	pet.add_input_delta({"kb": 15001, "mouse": 0, "active_sec": 0.0, "friday_active_sec": 0.0})
	check(pet.evolved and got_tier[0] == 1, "모찌 1차 진화: 키보드 30,000 달성 (tier=1)")
	check(pet.stage == "adult", "진화 시 성체로 자동 승격")


# 최종 진화 (2단계) — 1차 완료 후 임계값 상향된 조건 달성
func _test_evolution_2_tier() -> void:
	var pet := make_pet("mochi")
	var tiers: Array = []
	pet.evolution_ready.connect(func(_s, tier): tiers.append(tier))
	pet.add_input_delta({"kb": 30000, "mouse": 0, "active_sec": 0.0, "friday_active_sec": 0.0})
	check(pet.evolved and not pet.evolved_2, "1차 진화만 완료 상태")
	pet.add_input_delta({"kb": 70000, "mouse": 0, "active_sec": 0.0, "friday_active_sec": 0.0})
	check(pet.evolved_2, "모찌 최종 진화: 키보드 누적 100,000 달성")
	check(tiers == [1, 2], "진화 신호가 1→2 순서로 발화")


# 연속 출근일수 지표 (당근이 진화 조건)
func _test_consecutive_days() -> void:
	var pet := make_pet("tokki")
	pet.note_activity_day("2026-07-25")
	check(pet.work_stats["consecutive_days"] == 1, "첫 활성일: 연속 1일")
	pet.note_activity_day("2026-07-25")
	check(pet.work_stats["consecutive_days"] == 1, "같은 날 중복: 카운트 유지")
	pet.note_activity_day("2026-07-26")
	pet.note_activity_day("2026-07-27")
	check(pet.work_stats["consecutive_days"] == 3, "연속 3일: 3")
	pet.note_activity_day("2026-07-29")  # 하루 건너뜀
	check(pet.work_stats["consecutive_days"] == 1, "하루 공백 → 리셋")


# 대사 pool: 캐릭터 진화 유무에 따라 base / (e1) / (e2) 각각 검증
func _test_dialog_evolution_pools() -> void:
	var Dialog := preload("res://scripts/data/dialog.gd")
	var Chars := preload("res://scripts/data/characters.gd")
	var Balance := preload("res://scripts/data/balance.gd")
	var missing: Array = []
	var missing_triggers: Array = []
	for species in Chars.CHARACTERS.keys():
		var entry = Dialog.BY_CHARACTER.get(species)
		if not (entry is Dictionary):
			missing.append(species + ":not-dict")
			continue
		var stages: Array = ["base"]
		if Balance.EVOLUTION.has(species):
			stages.append("e1")
		if Balance.EVOLUTION_2.has(species):
			stages.append("e2")
		for key in stages:
			var stage_data = entry.get(key)
			var lines: Array = []
			var trigger_count: int = 0
			if stage_data is Dictionary:
				lines = stage_data.get("random", [])
				for k in stage_data.keys():
					if k != "random":
						trigger_count += 1
			elif stage_data is Array:
				lines = stage_data
			if lines.size() < 3:
				missing.append("%s.%s.random(%d)" % [species, key, lines.size()])
			if trigger_count < 3:
				missing_triggers.append("%s.%s.triggers(%d)" % [species, key, trigger_count])
	check(missing.is_empty(), "랜덤 대사 3줄 이상: %s" % str(missing))
	check(missing_triggers.is_empty(), "각 캐릭터·단계별 트리거 override 3개 이상: %s" % str(missing_triggers))


# 토끼: 3일 연속 → 다이어토, 14일 연속 → 헬토
func _test_rabbit_full_evolution() -> void:
	var pet := make_pet("tokki")
	pet.note_activity_day("2026-07-01")
	pet.note_activity_day("2026-07-02")
	check(not pet.evolved, "당근이: 2일 연속 (미충족)")
	pet.note_activity_day("2026-07-03")
	check(pet.evolved, "당근이 → 다이어토: 3일 연속")
	for d in range(4, 15):
		pet.note_activity_day("2026-07-%02d" % d)
	check(pet.evolved_2, "다이어토 → 헬토: 14일 연속")


func _test_evolution_distinct_days() -> void:
	var pet := make_pet("ppiyak")
	for i in 4:
		pet.note_activity_day("2026-07-%02d" % (20 + i))
	check(not pet.evolved, "삐약 진화 미충족 (4일)")
	pet.note_activity_day("2026-07-24")
	check(pet.evolved, "삐약 진화: 서로 다른 날 5일")
	# 중복 날짜는 카운트 안 됨
	var pet2 := make_pet("ppiyak")
	for i in 10:
		pet2.note_activity_day("2026-07-21")
	check(not pet2.evolved, "중복 날짜는 진화 카운트 안 됨")


func _test_evolution_feed_snack() -> void:
	var pet := make_pet("haemjji")
	for i in 39:
		pet.care("feed" if i % 2 == 0 else "snack")
	check(not pet.evolved, "햄찌 진화 미충족 (39회)")
	pet.care("feed")
	check(pet.evolved, "햄찌 진화: 먹이/간식 40회")


func _test_evolution_progress_ratio() -> void:
	var pet := make_pet("kong")
	pet.add_input_delta({"kb": 0, "mouse": 5000, "active_sec": 0.0, "friday_active_sec": 0.0})
	var p: Dictionary = pet.evolution_progress()
	check(approx(p["ratio"], 0.25), "진화 진행률: 5000/20000 = 25%")
	check(p["hint"] != "", "진행률에 힌트 문구 포함")


func _test_evolution_persists_across_save() -> void:
	var pet := make_pet("mundeok")
	for i in 30:
		pet.note_todo_complete()
	check(pet.evolved, "문덕 진화: 할 일 30개")
	var restored: Node = PetStateScript.new()
	restored.deserialize(pet.serialize())
	check(restored.evolved and restored.work_stats["todos_done"] == 30,
		"진화 상태·카운터 직렬화 왕복 보존")


func _test_evolution_gated_by_egg() -> void:
	var pet: Node = PetStateScript.new()  # 알 상태
	pet.add_input_delta({"kb": 999999, "mouse": 999999, "active_sec": 0.0, "friday_active_sec": 0.0})
	check(not pet.evolved, "알 상태에서는 진화 불가")


# 업데이트 버전 비교 (FR-29)
func _test_version_compare() -> void:
	var Updater := preload("res://scripts/updater.gd")
	check(Updater.is_newer("v0.3.0", "0.2.0"), "버전 비교: 0.3.0 > 0.2.0")
	check(Updater.is_newer("1.0.0", "0.9.9"), "버전 비교: 1.0.0 > 0.9.9")
	check(not Updater.is_newer("v0.2.0", "0.2.0"), "버전 비교: 동일 버전은 미갱신")
	check(not Updater.is_newer("0.1.9", "0.2.0"), "버전 비교: 구버전은 미갱신")
	check(Updater.is_newer("0.2.1", "0.2"), "버전 비교: 자릿수 부족 보정")


# 알로 리셋: 성체+병듦 상태에서도 완전 초기화
func _test_reset_to_egg() -> void:
	var pet := make_pet("haemjji")
	pet.stage = "adult"
	pet.stats["health"] = 10.0
	pet.is_sick = true
	pet.poop_count = 3
	pet.age_minutes = 99999.0
	pet.reset_to_egg()
	check(
		pet.stage == "egg" and pet.species == "" and not pet.is_sick
		and pet.poop_count == 0 and pet.hatch_progress == 0.0
		and approx(pet.stats["health"], 100.0),
		"알로 리셋: 전체 상태 초기화"
	)
	pet.advance_minutes(Balance.HATCH_HOURS_MAX * 60.0, {"hour": 10, "weekday": 2})
	check(pet.stage == "baby" and pet.species != "", "알로 리셋 후 재부화 정상")


# 창 감지 JSON 파싱
func _test_probe_parse() -> void:
	var Probe := preload("res://scripts/platform/window_probe.gd")
	var parsed: Array = Probe.parse_windows(
		'[{"i":123,"x":100,"y":200,"w":800,"h":600,"z":0,"t":0},{"i":9,"x":1500,"y":900,"w":360,"h":150,"z":1,"t":1}]'
	)
	check(parsed.size() == 2, "probe 파싱: 창 2개")
	check(parsed[0]["rect"] == Rect2(100, 200, 800, 600) and not parsed[0]["toast"], "probe 파싱: 일반 창")
	check(parsed[1]["toast"], "probe 파싱: 토스트 판별")
	check(Probe.parse_windows("깨진 json").is_empty(), "probe 파싱: 손상 입력 → 빈 배열")


## 등록된 모든 스프라이트 시트 경로. 애니메이션 카탈로그 두 갈래(포즈 오버라이드 / 비숑)를
## 모두 훑는다. 티어별 시트는 config에 "path"가 없고 티어 딕셔너리가 한 단 더 있다.
func _all_sheet_paths() -> Array:
	var paths := []
	for species in PetScript.ANIMATED_POSE_OVERRIDES:
		var states: Dictionary = (PetScript.ANIMATED_POSE_OVERRIDES[species] as Dictionary).get("states", {})
		for state in states:
			var entry: Dictionary = states[state]
			if entry.has("path"):
				paths.append(String(entry["path"]))
				continue
			for tier in entry:
				var tier_config: Dictionary = entry[tier]
				if tier_config.has("path"):
					paths.append(String(tier_config["path"]))
	for state in PetScript.BICHON_ANIMATIONS:
		var config: Dictionary = PetScript.BICHON_ANIMATIONS[state]
		if config.has("path"):
			paths.append(String(config["path"]))
	return paths


# 임포트 캐시가 원본 PNG보다 낡으면 load()가 옛 픽셀을 돌려주고, 이 파일의 모든 픽셀 검사가
# 조용히 잘못된 값으로 통과한다. 2026-08-10에 캐시가 7시간 낡은 채로(캐시 09:19 / PNG 16:11)
# 스위트가 초록이었고, 그 탓에 "새 아트가 접지 기준선을 깼다"는 잘못된 진단까지 나왔다.
# 픽셀 검사 신뢰도의 전제라 다른 검사보다 먼저 돌린다. 해소: godot --headless --import --path .
# 시트를 다시 뽑았는데 pet.gd의 foot_padding이 안 따라오면 발이 실제 그림과 다른 높이에 놓인다.
# 이 desync는 2026-08-10 하루에 세 번 재발했고(FileHover 6장 / #37 공중 6장 / mochi Fall),
# 매니페스트 검사는 배열 "길이"만 보므로 원리적으로 못 잡는다. 방향 검사(_check_fall_descends)도
# pet.gd 배열을 읽기 때문에 "아트가 틀렸다"와 "코드가 낡았다"를 구분하지 못한다 — 실제로 mochi
# Fall에서 후자를 전자로 오진했다. 그래서 아트를 직접 재서 등록값과 맞춰본다.
#
# foot_padding만 본다. horizontal_offsets는 반픽셀 반올림 관례가 시트 세대마다 달라 오탐이 나고,
# 화면 영향도 1px 이하다. bichon은 이 딕셔너리에 없어 자동으로 빠진다 — chromakey 시트는
# 알파 잔여 픽셀 때문에 실측 자체를 신뢰할 수 없어서 대상에서 제외하는 것이 맞다.
const SHEET_SYNC_TOLERANCE := 1.0


func _test_sheet_value_sync() -> void:
	var checked := 0
	for species in PetScript.ANIMATED_POSE_OVERRIDES:
		var states: Dictionary = (PetScript.ANIMATED_POSE_OVERRIDES[species] as Dictionary).get("states", {})
		for state in states:
			var entry: Dictionary = states[state]
			if entry.has("path"):
				checked += _check_sheet_sync("%s/%s" % [species, state], entry)
				continue
			for tier in entry:
				checked += _check_sheet_sync("%s/%s/%s" % [species, tier, state], entry[tier])
	check(checked > 0, "시트-등록값 동기 검사가 실제로 시트를 읽었다 (%d개)" % checked)


## 등록된 foot_padding이 시트의 실제 바닥 여백과 맞는지 한 장 검사한다. 검사했으면 1을 돌려준다.
func _check_sheet_sync(label: String, config: Dictionary) -> int:
	# 논리 프레임이 물리 칸과 1:1이 아니면 칸 단위 비교가 성립하지 않는다.
	if not config.has("path") or not config.get("sprite_frame_sequence", []).is_empty():
		return 0
	var paddings: Array = config.get("foot_padding", [])
	var columns := int(config.get("columns", 0))
	var rows := int(config.get("rows", 0))
	if paddings.is_empty() or columns <= 0 or rows <= 0 or paddings.size() != columns * rows:
		return 0
	var path := String(config["path"])
	if not ResourceLoader.exists(path):
		return 0
	var texture: Texture2D = load(path)
	if texture == null:
		return 0
	var image: Image = texture.get_image()
	var cell_w: int = image.get_width() / columns
	var cell_h: int = image.get_height() / rows
	var worst := 0.0
	var worst_frame := 0
	var any_measured := false
	var measured := []
	for index in paddings.size():
		var col: int = index % columns
		var row: int = index / columns
		var bottom := -1
		# 아래에서 위로 훑어 첫 불투명 행에서 멈춘다 — 전체 스캔보다 훨씬 싸다.
		for offset in range(cell_h - 1, -1, -1):
			for x in range(cell_w):
				if image.get_pixel(col * cell_w + x, row * cell_h + offset).a >= 0.125:
					bottom = offset
					break
			if bottom >= 0:
				break
		if bottom < 0:
			continue
		var actual := float(cell_h - (bottom + 1))
		measured.append(int(actual))
		any_measured = true
		var gap: float = absf(actual - float(paddings[index]))
		if gap > worst:
			worst = gap
			worst_frame = index
	# 완전히 일치해도 단정문을 남긴다 — 조기 반환하면 통과 시트가 검사 기록에서 사라져
	# 나중에 이 검사가 실제로 무엇을 봤는지 알 수 없게 된다(초안에서 실제로 그랬다).
	if not any_measured:
		return 0
	check(worst <= SHEET_SYNC_TOLERANCE,
		"%s foot_padding이 시트와 일치 (f%d에서 %.0fpx 차이, 등록 %s / 실측 %s) — 시트를 다시 뽑았으면 값도 재산출하라"
		% [label, worst_frame, worst, str(paddings), str(measured)])
	return 1


# pet.gd가 참조하는 PNG가 git에 올라가 있지 않으면, 워킹트리에는 있으니 스위트는 전부 통과하지만
# 커밋에서 빠진 채 다른 머신에서 런타임 경로가 깨진다. 2026-08-11에 ppiyak 12장
# (file_hover_4f / file_consume_6f / pet_6f / poop_6f x 3티어)이 정확히 그 상태였고,
# 그대로 커밋됐으면 ppiyak 3티어의 12개 상태가 전부 깨졌다.
# 사람 절차로는 두 번 연속 과소 보고됐다(참조 여부만 보고 untracked 전수를 뜨지 않아서
# "2장"으로 보고 → 실제 12장). 그래서 검사로 잠근다.
#
# .import도 쌍으로 본다: Godot은 PNG와 .import가 함께 있어야 uid가 안정적이고, PNG만 커밋하면
# 다른 머신에서 uid가 재배정돼 .tscn/.gd 참조가 흔들린다.
#
# 한계: _all_sheet_paths()가 도는 것은 상수로 박힌 시트 경로다. 정지 포즈 아트
# (chars/{종족}/{포즈}.png)는 런타임에 문자열을 조립해 만들므로 여기서 커버되지 않는다.
func _test_referenced_assets_tracked() -> void:
	var root := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var output := []
	# git ls-files는 인덱스 내용을 찍으므로 "추적 중"과 "새로 스테이징됨"을 한 번에 잡는다.
	var code := OS.execute("git", ["-C", root, "ls-files"], output, true)
	var listing := "" if output.is_empty() else String(output[0])
	check(code == 0 and not listing.is_empty(),
		"git ls-files 실행 가능 (종료코드 %d, %d바이트) — 실패하면 이 검사는 아무것도 보증하지 못한다"
		% [code, listing.length()])
	if code != 0 or listing.is_empty():
		return
	var indexed := {}
	for line in listing.split("\n", false):
		indexed[line.strip_edges()] = true
	var missing_png := []
	var missing_import := []
	var checked := 0
	for path in _all_sheet_paths() + _runtime_assembled_sheet_paths():
		var rel := String(path).trim_prefix("res://")
		checked += 1
		if not indexed.has(rel):
			missing_png.append(rel)
		# .import는 디스크에 있을 때만 쌍을 요구한다(아직 임포트되지 않은 신규 자산은 제외).
		if FileAccess.file_exists(String(path) + ".import") and not indexed.has(rel + ".import"):
			missing_import.append(rel + ".import")
	check(checked > 0, "참조 시트 경로를 수집했다 (%d개)" % checked)
	check(missing_png.is_empty(),
		"참조 PNG %d개 전부 git에 올라가 있다%s" % [checked, _tracking_hint(missing_png, "git add 하라")])
	check(missing_import.is_empty(),
		"참조 PNG의 .import가 쌍으로 올라가 있다%s"
			% _tracking_hint(missing_import, "PNG만 커밋하면 uid가 재배정된다"))


## 누락 목록을 읽을 수 있는 길이로 요약한다. 84개를 한 줄에 쏟으면 실패 메시지가 화면을 덮어
## 다른 실패를 못 보게 된다(실제로 그랬다) — 디렉터리별 개수 + 예시 3개까지만 남긴다.
func _tracking_hint(missing: Array, advice: String) -> String:
	if missing.is_empty():
		return ""
	var by_dir := {}
	for path in missing:
		var dir := String(path).get_base_dir()
		by_dir[dir] = int(by_dir.get(dir, 0)) + 1
	var groups := []
	for dir in by_dir:
		groups.append("%s x%d" % [String(dir).trim_prefix("assets/sprites/"), int(by_dir[dir])])
	groups.sort()
	var sample := []
	for i in range(mini(3, missing.size())):
		sample.append(String(missing[i]).get_file())
	return " — 누락 %d개 [%s] 예: %s (%s)" % [
		missing.size(), ", ".join(groups), ", ".join(sample), advice]


## 런타임이 문자열로 조립하는 시트 경로. `_all_sheet_paths()`는 상수로 박힌 경로만 보므로
## 이쪽이 추적 검사의 사각지대였다 — 그리고 하필 그 사각지대가 가장 큰 자산 묶음이다.
## `_pose_override_config`(pet.gd:1082)는 haemjji와 GENERATED_MOTION_SPECIES 8종에 대해
## **조건 없이** 조립 경로를 먼저 반환하므로, 이 9종의 런타임은 전적으로 이 경로들에 의존한다.
## (haemjji의 ANIMATED_POSE_OVERRIDES 항목은 그 early return 뒤에 있어 포즈 오버라이드에는
##  더 이상 도달하지 않는다 — 상수는 남아 있지만 이 경로가 실제로 쓰이는 것이다.)
##
## 경로를 문자열로 다시 조립하지 않고 런타임 함수를 그대로 호출한다. 재조립하면 규칙이
## 갈릴 때 검사만 조용히 옛 경로를 보게 된다.
func _runtime_assembled_sheet_paths() -> Array:
	var paths := []
	for tier in ["base", "evolved", "evolved2"]:
		for state in PetScript.GENERATED_MOTION_STATES:
			var haemjji: Dictionary = PetScript.haemjji_remake_config(tier, state)
			if haemjji.has("path"):
				paths.append(String(haemjji["path"]))
			for species in PetScript.GENERATED_MOTION_SPECIES:
				var generated: Dictionary = PetScript.generated_motion_config(species, tier, state)
				if generated.has("path"):
					paths.append(String(generated["path"]))
	return paths


func _test_import_cache_fresh() -> void:
	var stale := []
	var checked := 0
	for path in _all_sheet_paths():
		var import_path: String = String(path) + ".import"
		if not FileAccess.file_exists(import_path):
			continue
		var import_config := ConfigFile.new()
		if import_config.load(import_path) != OK:
			continue
		var cached := String(import_config.get_value("remap", "path", ""))
		if cached.is_empty():
			continue
		# mtime 비교는 쓰면 안 된다 — 내용이 이미 최신이면 Godot이 .ctex를 다시 쓰지 않아서
		# 캐시 mtime이 PNG보다 옛것으로 남는다. 실제로 mochi/idle이 그 경우로 거짓 양성이었다.
		# 임포트가 기록한 source_md5와 원본의 현재 md5를 비교하는 것이 정확한 판정이다.
		var digest_path := cached.get_basename() + ".md5"
		if not FileAccess.file_exists(digest_path):
			continue
		var digest := ConfigFile.new()
		var recorded := ""
		if digest.load(digest_path) == OK:
			recorded = String(digest.get_value("", "source_md5", ""))
		if recorded.is_empty():
			# ConfigFile이 섹션 없는 형식을 못 읽으면 직접 파싱한다.
			var handle := FileAccess.open(digest_path, FileAccess.READ)
			if handle == null:
				continue
			while not handle.eof_reached():
				var line := handle.get_line().strip_edges()
				if line.begins_with("source_md5="):
					recorded = line.substr(11).replace("\"", "")
					break
		if recorded.is_empty():
			continue
		checked += 1
		if FileAccess.get_md5(path) != recorded:
			# 파일명만으로는 어느 티어인지 모른다(idle_4f_alpha_smooth.png가 티어마다 있다).
			stale.append("%s/%s" % [path.get_base_dir().get_file(), path.get_file()])
	check(checked > 0, "임포트 캐시 검사가 시트를 찾았다 (%d장)" % checked)
	check(stale.is_empty(),
		"임포트 캐시 최신 — 낡은 시트 %d장%s. 해소: godot --headless --import --path ."
		% [stale.size(), (": " + ", ".join(stale)) if not stale.is_empty() else ""])


## 한 시트의 프레임별 하단여백·중심편차를 잰다. 등록 규약과 같은 식이다:
## foot_padding = 셀높이 - 1 - bbox하단, horizontal_offsets = 셀중심 - bbox중심(0.5 단위).
func _measure_sheet_anchors(config: Dictionary) -> Dictionary:
	var path := String(config.get("path", ""))
	if not ResourceLoader.exists(path):
		return {}
	var texture: Texture2D = load(path)
	if texture == null:
		return {}
	var image := texture.get_image()
	var columns := int(config["columns"])
	var cell_w: int = image.get_width() / columns
	var cell_h: int = image.get_height() / int(config["rows"])
	var sequence: Array = config.get("sprite_frame_sequence", [])
	var paddings := []
	var offsets := []
	for frame in int(config["frames"]):
		var cell := frame if sequence.is_empty() else int(sequence[frame])
		var min_x := cell_w
		var max_x := -1
		var max_y := -1
		for y in range(cell_h):
			for x in range(cell_w):
				if image.get_pixel((cell % columns) * cell_w + x, (cell / columns) * cell_h + y).a >= 0.125:
					min_x = mini(min_x, x)
					max_x = maxi(max_x, x)
					max_y = maxi(max_y, y)
		if max_x < 0:
			return {}
		paddings.append(float(cell_h - 1 - max_y))
		offsets.append(snappedf(float(cell_w) / 2.0 - (float(min_x + max_x + 1) / 2.0), 0.5))
	return {"pad": paddings, "off": offsets}


# 등록된 foot_padding/horizontal_offsets가 실제 PNG와 맞는지 전 시트(140개)에 대해 잠근다.
# 세 에이전트가 같은 파일을 쓰는 동안 사람 손 대조는 놓친다 — 실제로 세 번 놓쳤다.
func _test_registration_matches_assets() -> void:
	for species in PetScript.ANIMATED_POSE_OVERRIDES:
		var states: Dictionary = (PetScript.ANIMATED_POSE_OVERRIDES[species] as Dictionary).get("states", {})
		for state in states:
			var raw: Dictionary = states[state]
			var tiers := {}
			if raw.has("path"):
				tiers["-"] = raw
			else:
				for tier in raw:
					tiers[tier] = raw[tier]
			for tier in tiers:
				var config: Dictionary = tiers[tier]
				if not config.has("path"):
					continue
				var measured := _measure_sheet_anchors(config)
				if measured.is_empty():
					continue
				var combo := "%s/%s/%s" % [species, tier, state]
				var pad_gap := _anchor_gap(config.get("foot_padding", []), measured["pad"])
				var off_gap := _anchor_gap(config.get("horizontal_offsets", []), measured["off"])
				# 레거시 시트는 한 스냅 단위(0.5)까지만 봐준다 — 그보다 큰 오차는 여전히 잡힌다.
				var off_limit: float = 0.5 if combo in REGISTRATION_OFF_LEGACY else REGISTRATION_OFF_TOLERANCE
				var within: bool = pad_gap <= REGISTRATION_PAD_TOLERANCE and off_gap <= off_limit
				if combo in REGISTRATION_KNOWN:
					check(not within,
						"%s 등록값 편차 (알려진 미해결, pad %.1f / off %.1f) — 이 검사가 실패하면 해소된 것이니 REGISTRATION_KNOWN에서 제거하라"
						% [combo, pad_gap, off_gap])
				else:
					check(within,
						"%s 등록값이 자산 실측과 일치 (pad 최대차 %.1f <= %.1f, off 최대차 %.1f <= %.1f)"
						% [combo, pad_gap, REGISTRATION_PAD_TOLERANCE, off_gap, off_limit])


## 두 배열의 최대 절대차. 길이가 다르면 계약 위반이라 허용차와 무관하게 크게 돌려준다.
func _anchor_gap(registered: Array, measured: Array) -> float:
	if registered.size() != measured.size():
		return 9999.0
	var gap := 0.0
	for i in registered.size():
		gap = maxf(gap, absf(float(registered[i]) - float(measured[i])))
	return gap


# 셀 격자와 접지 기준선을 전 종족에 대해 잠근다. 종족 전용 매니페스트 테스트가 있는 3종은
# 이미 검사되지만 신규 종족(뚱실이)은 아무 방어막이 없었다 — 여기서 종족 목록을 데이터로 받아
# 그 구멍을 막는다. 특히 접지 기준선은 pet.gd가 세 번 오염값(최솟값 4/7)으로 덮인 축이다.
func _test_species_sheet_contract() -> void:
	for species in PetScript.ANIMATED_POSE_OVERRIDES:
		# 신규 종족은 계약을 명시하지 않으면 여기서 실패한다 — 조용히 미검증으로 들어오지 못한다.
		check(SPECIES_SHEET_CONTRACT.has(species),
			"%s 시트 계약이 SPECIES_SHEET_CONTRACT에 선언됨 (신규 종족은 셀 크기·접지 기준선을 명시하라)" % species)
		if not SPECIES_SHEET_CONTRACT.has(species):
			continue
		var contract: Dictionary = SPECIES_SHEET_CONTRACT[species]
		var states: Dictionary = (PetScript.ANIMATED_POSE_OVERRIDES[species] as Dictionary).get("states", {})
		for state in states:
			var raw: Dictionary = states[state]
			var tiers := {}
			if raw.has("path"):
				tiers["-"] = raw
			else:
				for tier in raw:
					tiers[tier] = raw[tier]
			for tier in tiers:
				var config: Dictionary = tiers[tier]
				if not config.has("path"):
					continue
				var path := String(config["path"])
				if not ResourceLoader.exists(path):
					continue
				var texture: Texture2D = load(path)
				if texture == null:
					continue
				var combo := "%s/%s/%s" % [species, tier, state]
				var size: Vector2 = texture.get_size()
				var cell_w: int = int(size.x) / int(config["columns"])
				var cell_h: int = int(size.y) / int(config["rows"])
				check(cell_w == int(contract["cell_w"]) and cell_h == int(contract["cell_h"]),
					"%s 셀 격자 %dx%d == 종족 계약 %dx%d"
					% [combo, cell_w, cell_h, int(contract["cell_w"]), int(contract["cell_h"])])
				if state == "Sick" and not (combo in SICK_MARK_DRAWN_IN_ART):
					check(bool(config.get("runtime_sick_mark", false)),
						"%s runtime_sick_mark == true (없으면 @_@ 라벨이 안 떠 Sulk와 구분되지 않는다)" % combo)
				var paddings: Array = config.get("foot_padding", [])
				if paddings.is_empty():
					continue
				var min_pad := 9999.0
				for value in paddings:
					min_pad = minf(min_pad, float(value))
				# 공중 상태도 최솟값은 접지 기준선이어야 한다 — 편차가 부양이고 최솟값이 지면이다.
				check(approx(min_pad, float(contract["baseline"])),
					"%s foot_padding 최솟값 %.1f == 접지 기준선 %.1f"
					% [combo, min_pad, float(contract["baseline"])])


# 정지 폴백 티어가 남아 있는 종족의 걷기 보완 플래그를 잠근다. gd-integrator가 뚱실이 등록 때
# "지우면 뚱과장·뚱대박의 걷기 반전·waddle이 사라진다"는 근거로 남겨둔 결정인데, 그 결정을
# 지키는 검사가 없어서 누군가 정리하면 조용히 깨지는 상태였다(2026-08-10 그가 직접 지적).
func _test_static_fallback_walk_flags() -> void:
	for species in PetScript.ANIMATED_POSE_OVERRIDES:
		var tiers: Array = (PetScript.ANIMATED_POSE_OVERRIDES[species] as Dictionary).get("tiers", [])
		# tiers가 비어 있으면 전 티어에 시트가 있다는 뜻이라 폴백이 없다.
		if tiers.is_empty() or tiers.size() >= 3:
			check(not STATIC_FALLBACK_WALK_FLAGS.has(species),
				"%s: 전 티어에 시트가 생겼다 — STATIC_FALLBACK_WALK_FLAGS에서 빼고 레거시 플래그도 정리하라" % species)
			continue
		check(STATIC_FALLBACK_WALK_FLAGS.has(species),
			"%s: 정지 폴백 티어(%s 외)가 있으니 걷기 보완 플래그 기대값을 선언하라" % [species, str(tiers)])
		if not STATIC_FALLBACK_WALK_FLAGS.has(species):
			continue
		var expected: Dictionary = STATIC_FALLBACK_WALK_FLAGS[species]
		check(Characters.is_walk_static(species) == bool(expected["walk_static"]),
			"%s walk_static == %s (정지 폴백 티어의 waddle 보완)" % [species, str(expected["walk_static"])])
		check(Characters.is_walk_face_inverted(species) == bool(expected["walk_face_inverted"]),
			"%s walk_face_inverted == %s (정지 폴백 티어의 좌우 반전)" % [species, str(expected["walk_face_inverted"])])


# 애니메이션 경로와 정지 폴백 경로가 화면에서 같은 몸통 높이를 내는지 본다. sheet_scale의
# 존재 이유가 이 일치이므로, 이게 두 렌더 경로를 비교하는 가장 직접적인 오라클이다.
# 2026-08-10에 이걸 전 종족으로 넓혔다가 13건 실패로 되돌렸는데, 원인은 계약이 아니라
# sheet_scale이 α>0 기준으로 유도돼 있었던 것이었다. 2026-08-11 Task #50에서 기준이
# VISIBLE_ALPHA로 확정·재유도된 뒤 10개 티어 전부 오차 0.00%가 되어 이제 성립한다.
# 범위는 Idle f0 한정이다 — Walk/Eat 등은 스쿼시 진폭이라 정지 Idle 포즈와 비교 대상이 아니다.
const PATH_PARITY_TOLERANCE := 0.01


func _test_render_path_parity() -> void:
	for species in _checked_species():
		var entry: Dictionary = PetScript.ANIMATED_POSE_OVERRIDES.get(species, {})
		var covered: Array = entry.get("tiers", ["base", "evolved", "evolved2"])
		for tier in ["base", "evolved", "evolved2"]:
			if not (tier in covered):
				continue
			var idle_config := _pose_config_of(species, tier, "Idle")
			if idle_config.is_empty():
				continue
			# 정지 경로 몸통 = 정지 아트 bbox x (STAGE_SCALE x BODY_SCALE)
			# 애니 경로 몸통 = 시트 Idle f0 bbox x (STAGE_SCALE x BODY_SCALE x sheet_scale)
			# STAGE_SCALE은 양쪽에 공통이라 약분된다.
			var static_h := _bbox_height("res://assets/sprites/chars/%s%s/idle.png" % [species, String(STATIC_ART_DIR[tier])], 1, 1, 0)
			var sequence: Array = idle_config.get("sprite_frame_sequence", [])
			var neutral: int = 0 if sequence.is_empty() else int(sequence[0])
			var sheet_h := _bbox_height(String(idle_config["path"]), int(idle_config["columns"]), int(idle_config["rows"]), neutral)
			if static_h <= 0.0 or sheet_h <= 0.0:
				continue
			var body: float = float((Characters.BODY_SCALE.get(species, {}) as Dictionary).get(tier, 1.0))
			var static_screen := static_h * body
			var anim_screen := sheet_h * effective_body_scale(species, tier)
			var gap: float = absf(anim_screen / maxf(static_screen, 0.001) - 1.0)
			check(gap <= PATH_PARITY_TOLERANCE,
				"%s/%s 애니 경로 몸통 %.1f == 정지 경로 %.1f (오차 %.2f%% <= %.0f%%)"
				% [species, tier, anim_screen, static_screen, gap * 100.0, PATH_PARITY_TOLERANCE * 100.0])


# Walk 진입 첫 프레임은 Idle과 같은 크기여야 하며, 한 보행 주기의 상하 움직임은 자연스러운
# 바운스 범위 안에 있어야 한다. 2026-08-12 Walk 시트가 Idle보다 최대 1.63배 크게 보여
# 걷기 시작 순간 몸집이 튀었던 회귀를 실제 표시 bbox 기준으로 잠근다.
const WALK_ENTRY_SIZE_TOLERANCE := 0.05
const WALK_BOUNCE_TOLERANCE := 0.15


func _test_generated_walk_size_continuity() -> void:
	for species in PetScript.GENERATED_MOTION_SPECIES:
		for tier in ["base", "evolved", "evolved2"]:
			var idle_config := _pose_config_of(species, tier, "Idle")
			var walk_config := _pose_config_of(species, tier, "Walk")
			var idle_area := _bbox_area(
				String(idle_config["path"]),
				int(idle_config["columns"]),
				int(idle_config["rows"]),
				0
			)
			var walk_areas: Array[float] = []
			for frame_index in range(int(walk_config["frames"])):
				walk_areas.append(_bbox_area(
					String(walk_config["path"]),
					int(walk_config["columns"]),
					int(walk_config["rows"]),
					frame_index
				))
			var entry_gap := absf(walk_areas[0] / maxf(idle_area, 0.001) - 1.0)
			check(entry_gap <= WALK_ENTRY_SIZE_TOLERANCE,
				"%s/%s Walk 진입 몸통 면적 오차 %.2f%% <= %.0f%%"
				% [species, tier, entry_gap * 100.0, WALK_ENTRY_SIZE_TOLERANCE * 100.0])
			var minimum: float = walk_areas.min()
			var maximum: float = walk_areas.max()
			check(
				minimum >= idle_area * (1.0 - WALK_BOUNCE_TOLERANCE)
				and maximum <= idle_area * (1.0 + WALK_BOUNCE_TOLERANCE),
				"%s/%s Walk 몸통 면적 %.1f~%.1f가 Idle %.1f의 ±%.0f%% 이내"
				% [species, tier, minimum, maximum, idle_area, WALK_BOUNCE_TOLERANCE * 100.0]
			)


func _test_kong_walk_torso_stability() -> void:
	for tier in ["base", "evolved", "evolved2"]:
		var config := _pose_config_of("kong", tier, "Walk")
		var centers: Array[float] = []
		for frame_index in range(int(config["frames"])):
			centers.append(_bbox_torso_center(
				String(config["path"]), int(config["columns"]), int(config["rows"]), frame_index
			))
		check(centers.max() - centers.min() <= 1.0,
			"kong/%s Walk 몸통 중심 흔들림 %.2fpx <= 1px" % [tier, centers.max() - centers.min()])


# sheet_scale이 확정 산식과 일치하는지 아트와 직접 대조한다.
#   sheet_scale = 정지 아트 몸통 높이 / 시트 Idle f0 몸통 높이   (양쪽 VISIBLE_ALPHA bbox)
# 2026-08-11 team-lead가 기준을 VISIBLE_ALPHA로 확정하고 10개 값을 재유도한 뒤 성립하게 됐다.
# 그 전에는 재현 배수가 0.976~1.084로 흩어져(측정 표준 2개 공존) 필요 허용차 ±8%가 검출 대상인
# 진화 사다리 폭 9.26%보다 커서 오라클이 못 됐고, 그래서 내가 기각했던 검사다.
# 범위를 Idle f0으로 한정한다 — Walk/Eat 등 비-Idle은 스쿼시 진폭이라 비교 대상이 아니다.
const SHEET_SCALE_TOLERANCE := 0.005
const STATIC_ART_DIR := {
	"base": "", "evolved": "_evolved", "evolved2": "_evolved2",
}


## 애니메이션 계약 검사가 돌아야 하는 종족 전체. `ANIMATED_POSE_OVERRIDES`만 돌면
## GENERATED_MOTION_SPECIES 8종이 테이블에 없어 조용히 건너뛰어진다 — 2026-08-12까지 그 8종은
## 3티어 x 14상태 전부가 어떤 애니메이션 검사에도 들어오지 않았다(12종 중 4종만 보고 있었다).
##
## 주의: 이 목록을 **모든** 루프에 쓰면 안 된다. OFFSET_CEILING·SPECIES_FPS_OVERRIDE처럼
## 종족별 선언 테이블을 요구하는 검사는 8종 항목이 없어 "선언되지 않음"으로 대량 실패한다.
## 지금은 실패 0건을 실측으로 확인한 세 검사(파리티 / sheet_scale 산식 / 낙하 방향)에만 쓴다.
## 나머지 검사로 넓히려면 그 종족별 테이블을 먼저 채워야 한다.
func _checked_species() -> Array:
	var names := []
	for species in PetScript.ANIMATED_POSE_OVERRIDES:
		names.append(String(species))
	for species in PetScript.GENERATED_MOTION_SPECIES:
		if not (String(species) in names):
			names.append(String(species))
	# haemjji는 두 목록 어디에도 없다 — 상수 항목은 2026-08-12에 삭제됐고
	# GENERATED_MOTION_SPECIES에도 없다(자기 전용 haemjji_remake_config를 쓴다).
	# 명시하지 않으면 파리티·sheet_scale 산식·낙하 방향 세 검사에서 조용히 빠진다.
	# 실제로 삭제 직후 그 상태였고, 그래서 "파리티가 불변인지" 확인 자체가 불가능했다.
	if not ("haemjji" in names):
		names.append("haemjji")
	return names


## 그 종족·티어에 런타임이 실제로 곱하는 sheet_scale. `effective_body_scale()`과 같은 우선순위다.
func _resolved_sheet_scale(species: String, tier: String, raw: Variant) -> float:
	if species == "haemjji":
		return float(PetScript.HAEMJJI_REMAKE_SHEET_SCALE.get(tier, 0.0))
	if species in PetScript.GENERATED_MOTION_SPECIES:
		var generated: Dictionary = PetScript.GENERATED_MOTION_SHEET_SCALE.get(species, {})
		return float(generated.get(tier, 0.0))
	if raw is Dictionary:
		return float((raw as Dictionary).get(tier, 0.0))
	return float(raw) if raw != null else 0.0


func _test_sheet_scale_formula() -> void:
	for species in _checked_species():
		var entry: Dictionary = PetScript.ANIMATED_POSE_OVERRIDES.get(species, {})
		var raw: Variant = entry.get("sheet_scale", null)
		var covered: Array = entry.get("tiers", ["base", "evolved", "evolved2"])
		for tier in ["base", "evolved", "evolved2"]:
			if not (tier in covered):
				continue
			# 런타임이 실제로 곱하는 값을 봐야 한다. haemjji는 HAEMJJI_REMAKE_SHEET_SCALE을 쓰므로
			# ANIMATED_POSE_OVERRIDES의 sheet_scale은 죽은 값이다(그걸 읽으면 거짓 실패한다).
			var registered := _resolved_sheet_scale(species, tier, raw)
			if registered <= 0.0:
				continue
			var static_path := "res://assets/sprites/chars/%s%s/idle.png" % [species, String(STATIC_ART_DIR[tier])]
			var static_h := _bbox_height(static_path, 1, 1, 0)
			var idle_config := _pose_config_of(species, tier, "Idle")
			if idle_config.is_empty():
				continue
			var sequence: Array = idle_config.get("sprite_frame_sequence", [])
			var neutral: int = 0 if sequence.is_empty() else int(sequence[0])
			var sheet_h := _bbox_height(String(idle_config["path"]), int(idle_config["columns"]), int(idle_config["rows"]), neutral)
			var combo := "%s/%s" % [species, tier]
			check(static_h > 0.0 and sheet_h > 0.0,
				"%s sheet_scale 산식 입력 측정 (정지 %.0f / 시트 %.0f)" % [combo, static_h, sheet_h])
			if static_h <= 0.0 or sheet_h <= 0.0:
				continue
			var derived := static_h / sheet_h
			check(absf(derived - registered) <= SHEET_SCALE_TOLERANCE,
				"%s sheet_scale %.4f == 정지 %.0f / 시트 Idle f0 %.0f = %.4f (오차 %.4f <= %.3f)"
				% [combo, registered, static_h, sheet_h, derived, absf(derived - registered), SHEET_SCALE_TOLERANCE])


## 단일 셀의 보이는 픽셀 높이. 정지 아트는 columns=rows=1로 부르면 이미지 전체를 잰다.
func _bbox_height(path: String, columns: int, rows: int, cell: int) -> float:
	if not ResourceLoader.exists(path):
		return -1.0
	var texture: Texture2D = load(path)
	if texture == null:
		return -1.0
	var image := texture.get_image()
	var cell_w: int = image.get_width() / columns
	var cell_h: int = image.get_height() / rows
	var min_y := cell_h
	var max_y := -1
	for y in range(cell_h):
		for x in range(cell_w):
			if image.get_pixel((cell % columns) * cell_w + x, (cell / columns) * cell_h + y).a >= 0.125:
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
	if max_y < 0:
		return -1.0
	return float(max_y - min_y + 1)


func _bbox_area(path: String, columns: int, rows: int, cell: int) -> float:
	var texture: Texture2D = load(path)
	var image := texture.get_image()
	var cell_w: int = image.get_width() / columns
	var cell_h: int = image.get_height() / rows
	var visible_pixels := 0
	for y in range(cell_h):
		for x in range(cell_w):
			if image.get_pixel((cell % columns) * cell_w + x, (cell / columns) * cell_h + y).a >= 0.125:
				visible_pixels += 1
	return float(visible_pixels)


func _sheet_cells_have_alpha_inset(path: String, columns: int, rows: int) -> bool:
	var image: Image = (load(path) as Texture2D).get_image()
	var cell_w: int = image.get_width() / columns
	var cell_h: int = image.get_height() / rows
	for row in range(rows):
		for column in range(columns):
			for x in range(cell_w):
				if image.get_pixel(column * cell_w + x, row * cell_h).a > 0.0 \
					or image.get_pixel(column * cell_w + x, (row + 1) * cell_h - 1).a > 0.0:
					return false
			for y in range(cell_h):
				if image.get_pixel(column * cell_w, row * cell_h + y).a > 0.0 \
					or image.get_pixel((column + 1) * cell_w - 1, row * cell_h + y).a > 0.0:
					return false
	return true


func _bbox_torso_center(path: String, columns: int, rows: int, cell: int) -> float:
	var texture: Texture2D = load(path)
	var image := texture.get_image()
	var cell_w: int = image.get_width() / columns
	var cell_h: int = image.get_height() / rows
	var origin := Vector2i((cell % columns) * cell_w, (cell / columns) * cell_h)
	var min_y := cell_h
	var max_y := -1
	for y in range(cell_h):
		for x in range(cell_w):
			if image.get_pixelv(origin + Vector2i(x, y)).a >= 0.125:
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
	var torso_bottom := min_y + roundi(float(max_y - min_y + 1) * 0.7)
	var total := 0.0
	var pixels := 0
	for y in range(min_y, torso_bottom):
		for x in range(cell_w):
			if image.get_pixelv(origin + Vector2i(x, y)).a >= 0.125:
				total += x
				pixels += 1
	return total / maxf(float(pixels), 1.0)


# fps를 전 종족·전 티어에 대해 동결값과 대조한다. 티어 간 fps가 갈리는 것도 함께 잡는다 —
# 같은 종족의 같은 상태가 티어마다 다른 속도로 재생되면 진화 시 체감 속도가 튄다.
func _test_state_fps_contract() -> void:
	for species in PetScript.ANIMATED_POSE_OVERRIDES:
		check(SPECIES_FPS_OVERRIDE.has(species),
			"%s: fps 예외 테이블에 선언됨 (예외가 없으면 빈 딕셔너리라도 명시하라)" % species)
		var overrides: Dictionary = SPECIES_FPS_OVERRIDE.get(species, {})
		var states: Dictionary = (PetScript.ANIMATED_POSE_OVERRIDES[species] as Dictionary).get("states", {})
		for state in states:
			check(STATE_FPS_BASELINE.has(state),
				"%s: 상태 %s의 fps 기준선이 STATE_FPS_BASELINE에 선언됨" % [species, state])
			if not STATE_FPS_BASELINE.has(state):
				continue
			var expected: float = float(overrides[state]) if overrides.has(state) else float(STATE_FPS_BASELINE[state])
			var raw: Dictionary = states[state]
			var tiers := {}
			if raw.has("path"):
				tiers["-"] = raw
			else:
				for tier in raw:
					tiers[tier] = raw[tier]
			for tier in tiers:
				var config: Dictionary = tiers[tier]
				if not config.has("path"):
					continue
				check(approx(float(config.get("fps", 0.0)), expected),
					"%s/%s/%s fps %.1f == %.1f" % [species, tier, state, float(config.get("fps", 0.0)), expected])


# 몸통 중심 오프셋이 종족-티어별 천장을 넘지 않는지(정렬 회귀), 그리고 천장 아래로 내려갔으면
# 천장을 내리라고 알리는지(개선 반영) 양방향으로 본다. 허용차 0이라 1px 회귀도 잡힌다.
func _test_offset_ceiling() -> void:
	var observed := {}
	for species in PetScript.ANIMATED_POSE_OVERRIDES:
		var states: Dictionary = (PetScript.ANIMATED_POSE_OVERRIDES[species] as Dictionary).get("states", {})
		for state in states:
			var raw: Dictionary = states[state]
			var tiers := {}
			if raw.has("path"):
				tiers["-"] = raw
			else:
				for tier in raw:
					tiers[tier] = raw[tier]
			for tier in tiers:
				var config: Dictionary = tiers[tier]
				if not config.has("path"):
					continue
				var key := "%s/%s" % [species, tier]
				var worst := 0.0
				for value in config.get("horizontal_offsets", []):
					worst = maxf(worst, absf(float(value)))
				if worst > float(observed.get(key, 0.0)):
					observed[key] = worst
	for key in observed:
		check(OFFSET_CEILING.has(key),
			"%s: 오프셋 천장이 OFFSET_CEILING에 선언됨 (신규 종족-티어는 현재 최대값을 등재하라)" % key)
		if not OFFSET_CEILING.has(key):
			continue
		var ceiling: float = float(OFFSET_CEILING[key])
		var worst_seen: float = float(observed[key])
		check(worst_seen <= ceiling + 0.001,
			"%s 최대 |offset| %.2f <= 천장 %.2f (넘으면 정렬이 나빠진 것이다)" % [key, worst_seen, ceiling])
		check(worst_seen >= ceiling - 0.001,
			"%s 최대 |offset| %.2f 가 천장 %.2f 아래로 내려갔다 — 개선됐으니 OFFSET_CEILING을 내려라" % [key, worst_seen, ceiling])


# 상태별 loop 값을 전 종족·전 티어 + 비숑 카탈로그에 대해 잠근다. 기존에는 종족 전용 매니페스트
# 테이블에만 loop 단정이 있어서 뚱실이·비숑이 검사 밖이었다.
func _test_state_loop_contract() -> void:
	for species in PetScript.ANIMATED_POSE_OVERRIDES:
		var states: Dictionary = (PetScript.ANIMATED_POSE_OVERRIDES[species] as Dictionary).get("states", {})
		for state in states:
			check(STATE_LOOP_CONTRACT.has(state),
				"%s: 상태 %s의 loop 규약이 STATE_LOOP_CONTRACT에 선언됨 (신규 상태는 명시하라)" % [species, state])
			if not STATE_LOOP_CONTRACT.has(state):
				continue
			var raw: Dictionary = states[state]
			var tiers := {}
			if raw.has("path"):
				tiers["-"] = raw
			else:
				for tier in raw:
					tiers[tier] = raw[tier]
			for tier in tiers:
				var config: Dictionary = tiers[tier]
				if not config.has("path"):
					continue
				check(bool(config.get("loop", true)) == bool(STATE_LOOP_CONTRACT[state]),
					"%s/%s/%s loop == %s" % [species, tier, state, str(STATE_LOOP_CONTRACT[state])])
	for state in PetScript.BICHON_ANIMATIONS:
		if not STATE_LOOP_CONTRACT.has(state):
			continue
		var expected: bool = bool(BICHON_LOOP_OVERRIDE[state]) if BICHON_LOOP_OVERRIDE.has(state) else bool(STATE_LOOP_CONTRACT[state])
		var config: Dictionary = PetScript.BICHON_ANIMATIONS[state]
		check(bool(config.get("loop", true)) == expected,
			"비숑 %s loop == %s" % [state, str(expected)])


# 순환 상태의 이음새(마지막 -> 첫 프레임)를 잠근다. 전환 팝 검사는 상태를 나갈 때만 보므로
# 재생 중 매 주기 반복되는 이 이음새를 놓쳤다 — 2026-08-10 뚱실이 화면 확인 중 발견했다.
func _test_loop_seam() -> void:
	for species in PetScript.ANIMATED_POSE_OVERRIDES:
		var states: Dictionary = (PetScript.ANIMATED_POSE_OVERRIDES[species] as Dictionary).get("states", {})
		for state in states:
			var raw: Dictionary = states[state]
			var tiers := {}
			if raw.has("path"):
				tiers["-"] = raw
			else:
				for tier in raw:
					tiers[tier] = raw[tier]
			for tier in tiers:
				var config: Dictionary = tiers[tier]
				if not config.has("path") or not bool(config.get("loop", true)):
					continue
				var last := _frame_visible_size(config, int(config["frames"]) - 1)
				var first := _frame_visible_size(config, 0)
				if last.x <= 0.0 or first.x <= 0.0:
					continue
				var combo := "%s/%s/%s" % [species, tier, state]
				var seam: float = maxf(
					absf(first.x / last.x - 1.0),
					absf(first.y / last.y - 1.0)) * 100.0
				if combo in LOOP_SEAM_KNOWN:
					check(seam > LOOP_SEAM_LIMIT,
						"%s 루프 이음새 %.1f%% (알려진 미해결) — 이 검사가 실패하면 해소된 것이니 LOOP_SEAM_KNOWN에서 제거하라"
						% [combo, seam])
				else:
					check(seam <= LOOP_SEAM_LIMIT,
						"%s 루프 이음새 %.1f%% <= %.0f%% (마지막 f%d -> 첫 f0)"
						% [combo, seam, LOOP_SEAM_LIMIT, int(config["frames"]) - 1])


# 낙하 방향 검사를 전 종족으로 넓힌다. `_check_fall_descends`는 mochi·haemjji 매니페스트
# 루프에서만 불려서 ppiyak 3장이 검사 밖이었고, 그 사이에 ppiyak evolved·evolved2가 같은
# 방향 결함을 갖고 있었다(2026-08-10 발견). 종족을 늘릴 때 빠뜨리지 않도록 한 곳에서 훑는다.
func _test_fall_direction_all_species() -> void:
	for species in _checked_species():
		for tier in ["base", "evolved", "evolved2"]:
			var config := _pose_config_of(species, tier, "Fall")
			if config.is_empty():
				continue
			var paddings: Array = config.get("foot_padding", [])
			if paddings.is_empty():
				continue
			var min_pad := 9999.0
			for value in paddings:
				min_pad = minf(min_pad, float(value))
			var last_pad := float(paddings[paddings.size() - 1])
			var combo := "%s/%s" % [species, tier]
			var descends: bool = approx(last_pad, min_pad)
			if combo in FALL_DIRECTION_KNOWN:
				check(not descends,
					"%s 낙하 방향 (알려진 미해결, 마지막 %.0f > 최솟값 %.0f) — 이 검사가 실패하면 해소된 것이니 FALL_DIRECTION_KNOWN에서 제거하라"
					% [combo, last_pad, min_pad])
			else:
				check(descends,
					"%s 낙하 마지막 프레임이 접지 프레임 (foot_padding %s, 최솟값 %.0f)"
					% [combo, str(paddings), min_pad])


## 종족·티어·상태 config. `_pose_config`와 달리 tiers 제한까지 본다 — 티어 아트가 없는
## 종족을 "등록됐다"고 잘못 집어서 거짓 실패를 내지 않게 한다.
## 런타임과 **같은 우선순위**로 시트 config를 해석한다. pet.gd `_pose_override_config`(:1082)가
## haemjji와 GENERATED_MOTION_SPECIES 8종에 대해 조건 없이 조립 config를 먼저 반환하므로,
## 상수 테이블만 읽으면 그 9종에 대해 **런타임이 쓰지 않는 파일**을 재게 된다.
##
## 실제로 그래서 오판이 두 번 났다(2026-08-12):
##  1) haemjji 파리티가 오차 0.00%로 통과했다 — 죽은 _alpha_smooth(f0 106)에 옛 배율(1.066)을
##     곱하면 마침 정지 경로와 같아졌기 때문이다. 그때 런타임은 _remake(f0 179)를 쓰고 있었고
##     화면 몸통이 +32.5~42.7% 어긋나 있었다.
##  2) sheet_scale이 0.6313으로 고쳐져 런타임이 정상(188.4 == 정지 188.4)이 된 뒤에는 반대로
##     같은 검사가 111.6 vs 188.4로 **거짓 실패**했다 — 106 x 1.0524 = 111.6, 여전히 죽은 시트다.
## 두 방향 모두 원인이 하나였다: 검사와 런타임이 다른 파일을 본다.
func _pose_config_of(species: String, tier: String, state: String) -> Dictionary:
	if species == "haemjji":
		return PetScript.haemjji_remake_config(tier, state)
	if species in PetScript.GENERATED_MOTION_SPECIES:
		return PetScript.generated_motion_config(species, tier, state)
	var entry: Dictionary = PetScript.ANIMATED_POSE_OVERRIDES.get(species, {})
	var tiers: Array = entry.get("tiers", [])
	if not tiers.is_empty() and not (tier in tiers):
		return {}
	var config: Dictionary = (entry.get("states", {}) as Dictionary).get(state, {})
	if config.is_empty():
		return {}
	if not config.has("path"):
		return config.get(tier, {})
	return config


## 종족·티어·상태에 걸린 시트 config. 티어 딕셔너리 한 단을 알아서 푼다.
## `_pose_config_of`와 같은 이유로 런타임 우선순위를 따른다(그쪽 주석 참고).
## 이걸 빠뜨리면 조립 경로 종족이 빈 config를 받아 검사가 조용히 `continue`한다 —
## 2026-08-12에 haemjji 죽은 항목을 지웠을 때 `_test_airborne_lift_coverage`가
## "haemjji 9조합이 등록에서 사라졌다"로 실패한 원인이 이것이었다.
func _pose_config(species: String, tier: String, state: String) -> Dictionary:
	if species == "haemjji":
		return PetScript.haemjji_remake_config(tier, state)
	if species in PetScript.GENERATED_MOTION_SPECIES:
		return PetScript.generated_motion_config(species, tier, state)
	var entry: Dictionary = PetScript.ANIMATED_POSE_OVERRIDES.get(species, {})
	var config: Dictionary = entry.get("states", {}).get(state, {})
	if config.is_empty():
		return {}
	if not config.has("path"):
		return config.get(tier, {})
	return config


## 한 프레임의 보이는 픽셀 경계 상자 크기(셀 좌표계). 알파 임계값은 런타임과 같은 0.125.
func _frame_visible_size(config: Dictionary, frame: int) -> Vector2:
	var path: String = String(config.get("path", ""))
	if not ResourceLoader.exists(path):
		return Vector2.ZERO
	var texture: Texture2D = load(path)
	if texture == null:
		return Vector2.ZERO
	var image: Image = texture.get_image()
	var columns := int(config["columns"])
	var sequence: Array = config.get("sprite_frame_sequence", [])
	var cell := frame if sequence.is_empty() else int(sequence[frame])
	var cell_w: int = image.get_width() / columns
	var cell_h: int = image.get_height() / int(config["rows"])
	var min_x := cell_w
	var max_x := -1
	var min_y := cell_h
	var max_y := -1
	for y in range(cell_h):
		for x in range(cell_w):
			if image.get_pixel((cell % columns) * cell_w + x, (cell / columns) * cell_h + y).a >= 0.125:
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
	if max_x < 0:
		return Vector2.ZERO
	return Vector2(float(max_x - min_x + 1), float(max_y - min_y + 1))


## 상태머신이 실제로 빠져나가는 순간 "화면에 남아 있는" 프레임 번호.
## 주의: int(duration x fps)가 아니다. 전이가 나는 프레임에서 exit()가 같은 프레임 안에
## 시트를 갈아치우므로 그 프레임은 렌더되지 않는다 — 직전 프레임이 마지막이라 ceil - 1이다.
## 두 식은 duration x fps가 정확히 정수일 때만 갈리는데, Eat(2.0 x 6 = 12)이 그 경우다.
func _exit_frame(config: Dictionary, duration: float) -> int:
	var frames := int(config["frames"])
	var index: int = int(ceil(duration * float(config["fps"]))) - 1
	if bool(config.get("loop", true)):
		return posmod(index, frames)
	return clampi(index, 0, frames - 1)


# 상태를 빠져나가는 프레임과 복귀할 Idle 첫 프레임의 실루엣이 크게 다르면 한 프레임 만에
# 몸이 튄다. 팀 셋이 각각 다른 방식으로 이 계산을 틀렸던 지점이라(전이 대상 착각/종료 프레임
# 착각) 식과 임계값을 테스트로 고정한다.
func _test_transition_pop() -> void:
	for species in ["mochi", "haemjji"]:
		for tier in ["base", "evolved", "evolved2"]:
			var idle := _frame_visible_size(_pose_config(species, tier, "Idle"), 0)
			if idle.x <= 0.0:
				continue
			for state in STATE_EXIT_DURATION:
				var config := _pose_config(species, tier, state)
				if config.is_empty():
					continue
				var combo := "%s/%s/%s" % [species, tier, state]
				var exit_frame := _exit_frame(config, float(STATE_EXIT_DURATION[state]))
				check(exit_frame >= 0 and exit_frame < int(config["frames"]),
					"%s 종료 프레임 f%d이 시트 범위 안" % [combo, exit_frame])
				var size := _frame_visible_size(config, exit_frame)
				if size.x <= 0.0:
					check(false, "%s 종료 프레임 f%d에 보이는 픽셀 없음" % [combo, exit_frame])
					continue
				var pop: float = maxf(
					absf(size.x / idle.x - 1.0),
					absf(size.y / idle.y - 1.0)) * 100.0
				if combo in TRANSITION_POP_KNOWN:
					# 미해결 목록에 올려둔 건 "아직 크다"는 사실 자체를 잠근다 — 해소되면
					# 여기서 실패하므로 목록에서 빼라고 알려준다.
					check(pop > TRANSITION_POP_LIMIT,
						"%s 전환 팝 %.1f%% (알려진 미해결) — 이 검사가 실패하면 해소된 것이니 TRANSITION_POP_KNOWN에서 제거하라" % [combo, pop])
				else:
					check(pop <= TRANSITION_POP_LIMIT,
						"%s 전환 팝 %.1f%% <= %.0f%% (종료 f%d → Idle f0)" % [combo, pop, TRANSITION_POP_LIMIT, exit_frame])


# 파일 드롭 연출 체인의 앞 두 단을 잠근다. 복귀단(FileConsume -> Idle)은 FileConsume이
# STATE_EXIT_DURATION에 있으므로 _test_transition_pop이 이미 본다.
func _test_reaction_chain_pop() -> void:
	var hover_duration: float = float(PetScript.FILE_HOVER_DURATION)
	for species in ["mochi", "haemjji", "ppiyak"]:
		for tier in ["base", "evolved", "evolved2"]:
			var idle_config := _pose_config(species, tier, "Idle")
			var hover_config := _pose_config(species, tier, "FileHover")
			var consume_config := _pose_config(species, tier, "FileConsume")
			if idle_config.is_empty() or hover_config.is_empty() or consume_config.is_empty():
				continue
			var idle := _frame_visible_size(idle_config, 0)
			var hover_first := _frame_visible_size(hover_config, 0)
			var hover_last := _frame_visible_size(hover_config, _exit_frame(hover_config, hover_duration))
			var consume_first := _frame_visible_size(consume_config, 0)
			if idle.x <= 0.0 or hover_first.x <= 0.0 or hover_last.x <= 0.0 or consume_first.x <= 0.0:
				check(false, "%s/%s 파일 반응 체인에 빈 프레임이 있다" % [species, tier])
				continue
			# Idle은 loop이라 파일이 올라오는 순간 펫이 f0에 있을 이유가 없다 — 전 프레임 중
			# 가장 크게 튀는 조합으로 재야 한다. Idle f0만 보면 mochi/evolved가 2.6%로
			# 통과하지만 실제 최악은 f2(165x127) 기준 26.0%다(2026-08-10 실측).
			var worst_idle := idle
			var worst_pop := -1.0
			for frame in int(idle_config["frames"]):
				var candidate := _frame_visible_size(idle_config, frame)
				if candidate.x <= 0.0:
					continue
				var candidate_pop: float = maxf(
					absf(hover_first.x / candidate.x - 1.0),
					absf(hover_first.y / candidate.y - 1.0))
				if candidate_pop > worst_pop:
					worst_pop = candidate_pop
					worst_idle = candidate
			_check_chain_pop("%s/%s/진입" % [species, tier], hover_first, worst_idle,
				"Idle 최악 프레임 -> FileHover f0")
			_check_chain_pop("%s/%s/중간" % [species, tier], consume_first, hover_last,
				"FileHover 종료칸 -> FileConsume f0")
			# 드롭하지 않고 파일이 떠나는 경로(set_file_hover(false) -> _restore_pose_state_animation).
			# FileConsume을 거치지 않고 FileHover가 멈춰 있던 칸에서 곧바로 Idle로 돌아온다.
			# loop:false라 멈춰 있던 칸은 마지막 칸이다. 2026-08-10 기준 9조합 전부 10% 이내라
			# 예외 없이 잠근다 — 깨끗할 때 넣어야 예외 목록이 늘지 않는다.
			var hover_held := _frame_visible_size(hover_config, int(hover_config["frames"]) - 1)
			if hover_held.x > 0.0:
				_check_chain_pop("%s/%s/호버취소" % [species, tier], idle, hover_held,
					"FileHover 마지막칸 -> Idle f0")


## 두 실루엣의 폭·높이 변화 중 큰 쪽을 한도와 비교한다. 면적이 아니라 축별로 보는 이유는
## TRANSITION_POP_LIMIT 주석과 같다 — 폭↓·높이↑가 상쇄되어 통과해버린다.
func _check_chain_pop(combo: String, after: Vector2, before: Vector2, label: String) -> void:
	var pop: float = maxf(
		absf(after.x / before.x - 1.0),
		absf(after.y / before.y - 1.0)) * 100.0
	if combo in REACTION_CHAIN_POP_KNOWN:
		check(pop > TRANSITION_POP_LIMIT,
			"%s 체인 팝 %.1f%% (알려진 미해결, %s) — 이 검사가 실패하면 해소된 것이니 REACTION_CHAIN_POP_KNOWN에서 제거하라"
			% [combo, pop, label])
	else:
		check(pop <= TRANSITION_POP_LIMIT,
			"%s 체인 팝 %.1f%% <= %.0f%% (%s)" % [combo, pop, TRANSITION_POP_LIMIT, label])


## 공중 상태의 접지 프레임 발 높이가 접지 상태와 이어지는지를 데이터 수준에서 잠근다.
## 런타임은 ground_padding을 생략하면 foot_padding 최솟값을 접지 기준으로 삼으므로
## (pet.gd _minimum_foot_padding) 그때만 접지 프레임의 발 높이가 정확히 0이 된다.
## ground_padding을 최솟값과 다르게 명시하면 공중 상태 전체가 그 차이만큼 어긋난다 —
## 실제 발 어긋남을 막는 검사는 최솟값 상수 검사가 아니라 이것이다.
func _check_airborne_ground_reference(label: String, config: Dictionary, min_pad: float) -> void:
	if not config.has("ground_padding"):
		return
	check(approx(float(config["ground_padding"]), min_pad),
		"%s ground_padding %.1f == foot_padding 최솟값 %.1f (다르면 공중 상태 발이 접지 상태와 어긋난다)"
		% [label, float(config["ground_padding"]), min_pad])


## 낙하는 화면에서 내려가야 한다 — 마지막 프레임이 접지 프레임(foot_padding 최솟값)이어야
## 낙하 끝과 Land 진입의 발 높이가 이어진다. 배열이 거꾸로 들어가면 펫이 떨어지면서 오히려
## 위로 올라가는데, mochi/base Fall이 실제로 그랬다([16, 22, 22, 29] → 화면에서 10.3px 상승).
## 부양 진폭 검사(_test_airborne_lift_coverage)는 편차 크기만 보므로 방향을 못 잡는다.
func _check_fall_descends(label: String, state: String, paddings: Array) -> void:
	if state != "Fall" or paddings.is_empty():
		return
	var min_pad: float = 9999.0
	for value in paddings:
		min_pad = minf(min_pad, float(value))
	check(approx(float(paddings[paddings.size() - 1]), min_pad),
		"%s 낙하 마지막 프레임이 접지 프레임 (foot_padding %s, 최솟값 %.0f)"
		% [label, str(paddings), min_pad])


# 공중 상태가 화면에서 실제로 뜨는지를 조합 목록으로 잠근다. foot_padding 편차 x 실효 배율이
# 곧 부양 높이다(런타임 앵커가 padding 최솟값을 지면으로 잡으므로).
func _test_airborne_lift_coverage() -> void:
	var seen := []
	for species in ["mochi", "haemjji"]:
		for tier in ["base", "evolved", "evolved2"]:
			var body: float = float((Characters.BODY_SCALE.get(species, {}) as Dictionary).get(tier, 0.0))
			# 런타임이 실제로 곱하는 배율을 써야 한다 — haemjji는 HAEMJJI_REMAKE_SHEET_SCALE이다.
			var raw: Variant = PetScript.ANIMATED_POSE_OVERRIDES.get(species, {}).get("sheet_scale", null)
			var sheet: float = _resolved_sheet_scale(species, tier, raw)
			if sheet <= 0.0:
				sheet = 1.0
			var scale: float = float(PetScript.STAGE_SCALE["adult"]) * body * sheet
			for state in ["Play", "Dragged", "Fall"]:
				var config := _pose_config(species, tier, state)
				if config.is_empty():
					continue
				var combo := "%s/%s/%s" % [species, tier, state]
				seen.append(combo)
				check(bool(config.get("airborne", false)), "%s airborne 플래그" % combo)
				var paddings: Array = config.get("foot_padding", [])
				var pad_min := 9999.0
				var pad_max := -9999.0
				for value in paddings:
					pad_min = minf(pad_min, float(value))
					pad_max = maxf(pad_max, float(value))
				var lift: float = (pad_max - pad_min) * scale
				if combo in AIRBORNE_MUST_LIFT:
					check(lift > 0.5, "%s 화면상 부양 %.1fpx > 0.5px" % [combo, lift])
				elif combo in AIRBORNE_KNOWN_FLAT:
					# 해소되면 여기서 실패한다 — 목록을 옮기라는 신호다.
					check(lift <= 0.5, "%s 부양 %.1fpx (알려진 0px) — 이 검사가 실패하면 해소된 것이니 AIRBORNE_MUST_LIFT로 옮겨라" % [combo, lift])
				else:
					check(false, "%s 가 두 목록 어디에도 없다 (신규 조합은 명시적으로 분류하라)" % combo)
	# 목록에만 있고 실제로는 사라진 조합을 잡는다 — 양방향으로 막아야 목록이 썩지 않는다.
	for combo in AIRBORNE_MUST_LIFT + AIRBORNE_KNOWN_FLAT:
		check(combo in seen, "%s 가 등록에서 사라졌다 (목록을 갱신하라)" % combo)


# 성장: 3일 → 소년기, 7일 → 성체
func _test_stage_progression() -> void:
	var pet := make_pet("mochi")
	pet.stats["hunger"] = 100.0
	# 케어를 반복하며 시간을 흘림 (스탯 고갈로 인한 부작용 무시, 단계만 검증)
	for day in 3:
		pet.advance_minutes(1440.0, {"hour": 10, "weekday": 2})
		pet.care("feed")
		pet.care("clean")
	check(pet.stage == "child", "3일 경과 → 소년기")
	for day in 4:
		pet.advance_minutes(1440.0, {"hour": 10, "weekday": 2})
	check(pet.stage == "adult", "7일 경과 → 성체")
	check(pet.care_quality_samples.size() >= 2, "단계 전환 시 케어 품질 샘플 기록")
