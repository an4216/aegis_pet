# 뚱실이(ddungsil) base 티어 — 14상태 애니메이션 인수인계

> 작성: sprite-artist / character-pipeline, 2026-08-10
> 제작 기록: `assets/generated/sprites/ddungsil-v1/` (보존)
> **스코프**: base 티어 **14/14 상태 완비**. evolved/evolved2는 base 검증 통과 후 별도 진행.

## 제작 규격

| 항목 | 값 | 근거 |
|---|---|---|
| 셀 | **192 x 208** | 모찌와 동일. 공중 상태에 필요한 머리 위 여유를 확보하려고 정사각 128을 쓰지 않았다 |
| `safe_margin` | 18 | |
| 접지 기준선 | **16px** (`foot_padding` 최솟값) | 모찌 규약과 동일 |
| 크로마키 | **blue `#004DFF`** (auto, score 264.36) | 주황 태비의 보색이라 분리가 가장 좋다. cyan 258.79 / green 227.0 / magenta 215.73 |
| `fit` | `align_x: bbox-center`, `align_y: bottom`, lanczos | **bbox 중심**을 쓴 이유는 아래 §설계 참조 |
| 아이덴티티 앵커 | `assets/sprites/chars/ddungsil/idle.png` | 레거시 정지 아트 8장은 삭제하지 않고 참고용으로만 사용 |

## 등록값 (gd-integrator)

`ANIMATED_POSE_OVERRIDES`에 `"ddungsil"` 항목을 새로 만들고 `tiers`에 `"base"`를 넣는다.
`sheet_scale`은 실측 후 gd-integrator가 계산한다(스펙 명시) — 아래 몸통 높이를 근거로 쓰면 된다.

**Idle 중립 프레임 몸통 높이 = 135px** (전 상태 공통 기준. 아래 §설계 참조)

| 상태 | 파일 | 격자 | frames | fps | loop | airborne | `foot_padding` | `horizontal_offsets` |
|---|---|---|--:|--:|---|---|---|---|
| Idle | `res://assets/sprites/ddungsil/idle_4f.png` | 4 x 1 | 4 | 4 | true | — | `[16, 16, 16, 16]` | `[-0.5, 0.5, 0.0, 0.0]` |
| Walk | `res://assets/sprites/ddungsil/walk_8f.png` | 4 x 2 | 8 | 10 | true | — | `[16, 16, 16, 16, 16, 16, 16, 16]` | `[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]` |
| Sleep | `res://assets/sprites/ddungsil/sleep_6f.png` | 6 x 1 | 6 | 4 | true | — | `[16, 16, 16, 16, 16, 16]` | `[0.5, 0.5, 0.0, 0.5, 0.0, -0.5]` |
| Eat | `res://assets/sprites/ddungsil/eat_4f.png` | 4 x 1 | 4 | 6 | true | — | `[16, 16, 16, 16]` | `[0.5, 0.0, 0.5, 0.5]` |
| Sick | `res://assets/sprites/ddungsil/sick_6f.png` | 6 x 1 | 6 | 5 | true | — | `[16, 16, 16, 16, 16, 16]` | `[0.0, 0.5, -0.5, 0.0, -0.5, 0.0]` |
| Sulk | `res://assets/sprites/ddungsil/sulk_6f.png` | 6 x 1 | 6 | 5 | true | — | `[16, 16, 16, 16, 16, 16]` | `[0.0, -0.5, -0.5, 0.0, 0.5, -0.5]` |
| Play | `res://assets/sprites/ddungsil/play_6f.png` | 6 x 1 | 6 | 8 | true | **true** | `[16, 49, 50, 42, 19, 16]` | `[-0.5, 0.0, 0.5, 0.5, 0.0, 0.0]` |
| Dragged | `res://assets/sprites/ddungsil/dragged_4f.png` | 4 x 1 | 4 | 10 | true | **true** | `[32, 16, 21, 31]` | `[0.0, -0.5, -0.5, -0.5]` |
| Fall | `res://assets/sprites/ddungsil/fall_4f.png` | 4 x 1 | 4 | 12 | true | **true** | `[70, 51, 28, 16]` | `[0.0, 0.5, 0.0, 0.0]` |
| Land | `res://assets/sprites/ddungsil/land_4f.png` | 4 x 1 | 4 | 10 | false | — | `[16, 16, 16, 16]` | `[0.0, 0.0, 0.0, 0.5]` |
| FileHover | `res://assets/sprites/ddungsil/file_hover_4f.png` | 4 x 1 | 4 | 12 | false | — | `[16, 16, 16, 16]` | `[0.0, -0.5, -0.5, 0.0]` |
| FileConsume | `res://assets/sprites/ddungsil/file_consume_4f.png` | 4 x 1 | 4 | 12 | false | — | `[16, 16, 16, 16]` | `[0.5, 0.5, 0.0, 0.0]` |
| Poop | `res://assets/sprites/ddungsil/poop_6f.png` | 6 x 1 | 6 | 6 | true | — | `[16, 16, 16, 16, 16, 16]` | `[0.0, 0.0, 0.0, 0.0, 0.0, 0.0]` |
| Pet | `res://assets/sprites/ddungsil/pet_6f.png` | 6 x 1 | 6 | 10 | false | — | `[16, 16, 16, 16, 16, 16]` | `[0.0, 0.0, 0.5, -0.5, 0.5, 0.5]` |

`airborne: true`인 3상태(Play/Dragged/Fall)는 `foot_padding` 편차가 곧 화면상 부양 높이다.
최솟값이 전부 16이라 `ground_padding`은 **명시하지 않아도 된다**(배열 최솟값으로 자동 산출).

## 실측값

| 상태 | 몸통 폭 | 몸통 높이 | 폭 변화 | 높이 변화 | 종료칸 높이 | 부양 |
|---|---|---|--:|--:|--:|--:|
| Idle | [153, 163, 148, 150] | [137, 145, 132, 135] | 10.1% | 9.8% | 135 | — |
| Walk | [132, 148, 128, 126, 128, 150, 128, 128] | [134, 124, 143, 136, 134, 122, 134, 135] | 19.0% | 17.2% | 135 | — |
| Sleep | [171, 175, 184, 175, 172, 165] | [141, 150, 158, 149, 142, 135] | 11.5% | 17.0% | 135 | — |
| Eat | [139, 162, 139, 139] | [136, 89, 132, 135] | 16.5% | 52.8% | 135 | — |
| Sick | [154, 155, 157, 158, 157, 154] | [135, 123, 112, 94, 110, 135] | 2.6% | 43.6% | 135 | — |
| Sulk | [136, 121, 121, 126, 119, 133] | [135, 113, 107, 119, 130, 135] | 14.3% | 26.2% | 135 | — |
| Play | [149, 120, 127, 123, 138, 148] | [135, 125, 129, 131, 115, 135] | 24.2% | 17.4% | 135 | 34px |
| Dragged | [78, 89, 85, 73] | [137, 112, 128, 135] | 21.9% | 22.3% | 135 | 16px |
| Fall | [142, 143, 144, 134] | [135, 136, 132, 103] | 7.5% | 32.0% | 103 | 54px |
| Land | [162, 150, 144, 143] | [71, 82, 115, 135] | 13.3% | 90.1% | 135 | — |
| FileHover | [154, 153, 165, 156] | [135, 121, 85, 135] | 7.8% | 58.8% | 135 | — |
| FileConsume | [155, 167, 152, 150] | [143, 147, 136, 135] | 11.3% | 8.9% | 135 | — |
| Poop | [150, 146, 144, 144, 142, 144] | [138, 125, 107, 128, 122, 135] | 5.6% | 29.0% | 135 | — |
| Pet | [148, 148, 155, 169, 151, 147] | [135, 127, 114, 92, 119, 135] | 15.0% | 46.7% | 135 | — |

## 설계 — 이번 라운드(mochi/haemjji/ppiyak) 교훈을 처음부터 반영했다

모찌·햄찌·삐약에서 여러 번 재작업했던 실패를 설계 단계에서 차단했다. **결과적으로 지표 관련 재작업이 0회**다.

### 1. 종료칸을 Idle에 맞추는 것을 배율 기준으로 삼았다

전환 팝(상태 종료 시 크기 튐)은 종료칸과 Idle 첫 프레임의 종횡비가 다르면 **재합성으로 고칠 수 없다** —
균일 배율은 한 축을 맞추면 다른 축을 그만큼 악화시킨다(모찌 Eat에서 확인).

그래서 두 단계로 막았다:
- **프롬프트**: 모든 상태의 마지막 프레임을 "중립 자세로 복귀, 프레임 1과 폭·높이가 같아야 한다"로 명시
- **재합성 배율**: 각 행의 배율을 **"마지막(중립) 프레임 높이 == Idle 중립 높이(135px)"**로 잡았다

그 결과 **Fall을 뺀 13상태의 종료칸 높이가 전부 정확히 135px**이다 — 전환 팝이 구조적으로 0에 가깝다.
Fall만 예외인 이유는 `Fall -> Land`로 이어져 마지막 칸이 중립이 아니라 가장 낮게 웅크린 칸이기 때문이고,
그 행만 중앙값 기준으로 잡아 몸통 크기를 다른 상태와 맞췄다.

### 2. 활기와 전환 팝을 프롬프트에서 분리해 지정했다

두 축은 독립이라 하나만 지정하면 다른 것이 무너진다(햄찌 Eat에서 회귀 2회). 그래서 상태마다
**"어느 프레임이 피크인지"**와 **"마지막 칸은 중립으로 돌아온다"**를 따로 못박았다.
또 **"두 축이 모두 변해야 한다"**를 명시해, 한 축이 정확히 0.0%가 되는 결함을 예방했다 —
**14상태 전부 폭 2.6~24.2% / 높이 8.9~90.1%로 어느 축도 고정되지 않았다.**

### 3. 공중 상태는 "위로 뻗기" 대신 "아래로 웅크리기/늘어뜨리기"로 설계했다

셀 머리 위 여유가 적어 위로 뻗는 연출은 물리적으로 안 들어간다(FileHover에서 확인). 그래서
Play는 "웅크려 압축하며 떠오름", Dragged는 "무게로 늘어져 매달림", FileHover는 "아래로 코일"로 잡고
모든 공중 상태 프롬프트에 **"어떤 프레임도 프레임 1보다 커질 수 없다"**를 넣었다.

실제 부양: Play **34px**, Dragged **16px**, Fall **54px**. 셀을 뚫는 경우엔 궤적 모양을 유지하고
진폭만 한 계수로 축소했다(Fall k=0.58).

### 4. Fall 궤적 방향을 직접 검사했다

진폭만 보면 방향 결함을 놓친다(모찌 base Fall이 낙하 중 상승했던 건). 프롬프트에 **"프레임 1이 가장 높고
이후 계속 낮아지며 마지막이 가장 낮다, 절대 올라가지 않는다"**를 넣고 실측으로 확인했다:
`foot_padding [70, 51, 28, 16]` — **단조 하강이고 마지막 칸이 접지**다.

### 5. 가로 정렬을 bbox 중심으로 했다

등록 관례가 "셀 중심 − 전체 알파 bbox 중심"이므로 합성 정렬도 bbox 중심이어야 한다. 알파 가중 중심을
쓰면 비대칭 실루엣(매달림·기울임)에서 오프셋이 최대 3px까지 벌어진다(#37에서 확인).
**결과: 14상태 전부 `horizontal_offsets` 절댓값 ≤ 0.5px.**

## 자체 검수

- [x] 14행 추출 `ok: true`, errors 0
- [x] **84프레임 전부 셀 4변 접촉 0** — 잘림 없음
- [x] **84프레임 전부 단일 연결 컴포넌트** — 부유 파편 0 (연결성분 스캔)
- [x] `foot_padding` 최솟값 **전 상태 16** — 발이 기준선을 뚫지 않는다
- [x] `horizontal_offsets` 전 상태 ≤ 0.5px
- [x] 종료칸 높이 13상태 135px 일치 (Fall 제외, 사유 위 §1)
- [x] 한 축도 고정되지 않음 (폭 2.6~24.2% / 높이 8.9~90.1%)
- [x] Fall 단조 하강 + 마지막 칸 접지
- [x] 금지 요소 없음 — 음식·그릇·파일·손·배설물·Zzz·별·말풍선 미포함
- [x] 밉맵 14/14 `mipmaps/generate=true` + Godot 4.4.1 임포트(uid 발급) 확인
- [x] 회귀 테스트 **3859 passed / 0 failed**
- [ ] **실제 화면 QA 미실시** — qa-verifier 담당

## qa-verifier에게 — 화면에서 봐줬으면 하는 것

1. **Walk의 다리 교대가 읽히는지** (이번 라운드 유일한 판단 보류 항목). 뚱실이는 몸이 거의 구형이고
   다리가 몸에 묻혀 있어 해부학적으로 다리 교대를 크게 그릴 수 없다. 8프레임 전부 **왼쪽 profile**로
   통일돼 있고(뒤돌아섬 없음) 몸통 흔들림은 폭 19.0% / 높이 17.2%로 확실히 들어갔지만, 다리 자체의
   교대는 앞발 위치가 조금씩 바뀌는 수준이다. **레거시 `walk_static: true` 문제는 해소됐다**
   (프레임이 전부 다르다). 화면에서 waddle로 읽히면 통과, 안 읽히면 재생성하겠다.
2. **Poop의 힘주기가 읽히는지** — 앉은 자세와 실루엣이 비슷해 높이 29.0% 변화가 화면에서 보이는지.
3. **Dragged 실루엣** — 매달릴 때 폭이 73~89px로 앉은 자세(148~163px)의 절반이다. 늘어진 물방울
   형태로 의도한 것이지만, 화면에서 "갑자기 홀쭉해진다"로 읽히면 알려달라.

## gd-integrator에게

- `walk_face_inverted` 레거시 플래그: 신규 Walk는 **8프레임 전부 왼쪽 profile**이므로 반전 처리가
  필요 없다. 스펙의 재검토 요청대로 **플래그를 빼는 것이 맞다**.
- `walk_static` 플래그도 해소됐다(8프레임 실제 애니메이션).
- 레거시 정지 8장(`assets/sprites/chars/ddungsil/`)은 삭제하지 않았다.
- 등록값은 위 표를 그대로 쓰면 된다. 나는 `pet.gd`를 편집하지 않는다(작성자 단일화 준수).

## 제작 기록

| 항목 | 내용 |
|---|---|
| 런 | `assets/generated/sprites/ddungsil-v1/` |
| 생성 | 14행 + 재생성 2행(`play`/`poop` 포즈 겹침으로 추출 실패) = 16회 |
| 반려본 | `raw/rejected/play.merged-poses.png`, `poop.merged-poses.png` |
| 재합성본 | `recomposed/` (런타임 자산과 동일) |
| 대조표 | `docs/02-design/characters/ddungsil-base-contact.png` (14행 84프레임) |
| Walk 확대 | `assets/generated/sprites/ddungsil-v1/walk-zoom.png` |

**추출·합성 환경 메모**: 이번 라운드에 Docker Desktop이 시작 불가 상태가 되어 **WSL(Ubuntu)** 에서
추출·합성을 돌렸다. `runio.py`의 `fcntl` 가드는 수정하지 않았다 — WSL이 진짜 Linux라 가드가 그대로 동작한다.
WSL에 전용 venv(`~/sgvenv/env`, numpy+pillow)를 만들어 두었으니 다음 작업에서 재사용하면 된다.

---

# 뚱실이 evolved(뚱과장) — 14상태 애니메이션 인수인계

> 작성: sprite-artist, 2026-08-11 / 제작 기록: `assets/generated/sprites/ddungsil_evolved-v1/`
> **base와 동일한 설계**를 그대로 적용했다. 셀 192x208, 접지 16, 종료칸=Idle 중립 135px,
> bbox 중심 정렬, 공중은 웅크리기 방향. 규격 상세는 base 절 참조.

## 아이덴티티 판단 — 넥타이 유지, 커피컵 제외

레거시 정지 아트는 **흰 셔츠깃 + 감색 넥타이**와 **커피컵**을 함께 갖고 있다.
**넥타이·셔츠깃은 "과장"이라는 진화 정체성이라 영구 아이덴티티로 유지**했고, **커피컵은 제외**했다:

- 손에 든 소품은 14상태에서 일관 유지되지 않아 깜빡인다 (삐약 evolved에서 8포즈 중 6포즈만 커피컵이 있었다)
- Eat / Poop / FileHover / FileConsume 은 **소품 금지가 계약**이다 (게임 코드가 따로 그린다)
- 스펙(`ddungsil.spec.md`)에 소품 언급이 없다

확대 검수 결과 **넥타이는 84프레임 전부에 있고 커피컵은 어디에도 없다.**

## 크로마키 — 넥타이 때문에 blue 를 피했다

자동 선택이 **cyan #00FFFF (score 254.03)** 을 골랐고 **blue 는 181.19 로 최하위**였다 — 감색 넥타이 때문이다.
모찌 evolved 가 파란 넥타이 때문에 cyan 에서 실패했던 것과 대칭이며, 자동 측정이 그 충돌을 정확히 걸러냈다.

## 등록값

**Idle 중립 프레임 몸통 높이 = 135px** (base 와 같은 값으로 맞췄다 — `sheet_scale` 계산 근거).
`foot_padding` 최솟값이 전 상태 16 이라 `ground_padding` 은 명시 불필요.

| 상태 | 파일 | 격자 | frames | fps | loop | airborne | `foot_padding` | `horizontal_offsets` |
|---|---|---|--:|--:|---|---|---|---|
| Idle | `res://assets/sprites/ddungsil_evolved/idle_4f.png` | 4 x 1 | 4 | 4 | true | — | `[16, 16, 16, 16]` | `[0.5, 0.0, 0.0, 0.0]` |
| Walk | `res://assets/sprites/ddungsil_evolved/walk_8f.png` | 4 x 2 | 8 | 10 | true | — | `[16, 16, 16, 16, 16, 16, 16, 16]` | `[0.5, 0.5, 0.5, 0.5, 0.5, -0.5, 0.5, 0.5]` |
| Sleep | `res://assets/sprites/ddungsil_evolved/sleep_6f.png` | 6 x 1 | 6 | 4 | true | — | `[16, 16, 16, 16, 16, 16]` | `[-0.5, 0.0, 0.0, 0.0, 0.0, -0.5]` |
| Eat | `res://assets/sprites/ddungsil_evolved/eat_4f.png` | 4 x 1 | 4 | 6 | true | — | `[16, 16, 16, 16]` | `[0.0, -0.5, 0.0, 0.0]` |
| Sick | `res://assets/sprites/ddungsil_evolved/sick_6f.png` | 6 x 1 | 6 | 5 | true | — | `[16, 16, 16, 16, 16, 16]` | `[0.0, -0.5, -0.5, 0.0, 0.0, -0.5]` |
| Sulk | `res://assets/sprites/ddungsil_evolved/sulk_6f.png` | 6 x 1 | 6 | 5 | true | — | `[16, 16, 16, 16, 16, 16]` | `[0.5, 0.0, -0.5, -0.5, 0.0, -0.5]` |
| Play | `res://assets/sprites/ddungsil_evolved/play_6f.png` | 6 x 1 | 6 | 8 | true | **true** | `[16, 26, 53, 25, 27, 16]` | `[0.0, 0.0, 0.5, 0.0, -0.5, 0.5]` |
| Dragged | `res://assets/sprites/ddungsil_evolved/dragged_4f.png` | 4 x 1 | 4 | 10 | true | **true** | `[36, 33, 16, 36]` | `[0.0, 0.0, 0.0, 0.5]` |
| Fall | `res://assets/sprites/ddungsil_evolved/fall_4f.png` | 4 x 1 | 4 | 12 | true | **true** | `[73, 53, 35, 16]` | `[0.0, 0.0, -0.5, 0.0]` |
| Land | `res://assets/sprites/ddungsil_evolved/land_4f.png` | 4 x 1 | 4 | 10 | false | — | `[16, 16, 16, 16]` | `[0.5, -0.5, -0.5, 0.5]` |
| FileHover | `res://assets/sprites/ddungsil_evolved/file_hover_4f.png` | 4 x 1 | 4 | 12 | false | — | `[16, 16, 16, 16]` | `[0.0, 0.5, -0.5, 0.0]` |
| FileConsume | `res://assets/sprites/ddungsil_evolved/file_consume_4f.png` | 4 x 1 | 4 | 12 | false | — | `[16, 16, 16, 16]` | `[0.5, 0.0, -0.5, -0.5]` |
| Poop | `res://assets/sprites/ddungsil_evolved/poop_6f.png` | 6 x 1 | 6 | 6 | true | — | `[16, 16, 16, 16, 16, 16]` | `[0.0, 0.0, 0.5, 0.0, 0.0, -0.5]` |
| Pet | `res://assets/sprites/ddungsil_evolved/pet_6f.png` | 6 x 1 | 6 | 10 | false | — | `[16, 16, 16, 16, 16, 16]` | `[-0.5, 0.0, 0.0, 0.0, 0.0, -0.5]` |

## 실측값

| 상태 | 폭 변화 | 높이 변화 | 종료칸 높이 | 루프 이음새 | 부양 |
|---|--:|--:|--:|--:|--:|
| Idle | 7.1% | 2.2% | 135 | 0.8% | — |
| Walk | 6.7% | 6.0% | 135 | 6.7% | — |
| Sleep | 15.5% | 12.6% | 135 | 3.0% | — |
| Eat | 9.3% | 32.4% | 135 | 0.0% | — |
| Sick | 7.9% | 50.0% | 135 | 2.3% | — |
| Sulk | 10.2% | 18.4% | 135 | 1.4% | — |
| Play | 13.4% | 25.2% | 135 | 0.7% | 37px |
| Dragged | 9.1% | 7.4% | 135 | 1.4% | 20px |
| Fall | 2.7% | 8.7% | 127 | 3.9% | 57px |
| Land | 11.2% | 101.5% | 135 | —(비반복) | — |
| FileHover | 14.6% | 50.0% | 135 | —(비반복) | — |
| FileConsume | 18.1% | 5.9% | 135 | —(비반복) | — |
| Poop | 7.1% | 20.0% | 135 | 0.6% | — |
| Pet | 11.4% | 95.7% | 135 | —(비반복) | — |

Fall 은 `Fall -> Land` 로 이어져 마지막 칸이 중립이 아니므로 종료칸 135 규칙에서 제외된다(그 행만 중앙값 기준).

## 자체 검수

- [x] 14행 추출 ok, errors 0 (`sulk` / `pet` 2행은 포즈 겹침으로 1회 재생성)
- [x] 84프레임 셀 경계 접촉 0 / 부유 파편 0
- [x] `foot_padding` 최솟값 전 상태 16 — 발이 기준선을 뚫지 않는다
- [x] `horizontal_offsets` 전 상태 ≤ 0.5px (bbox 중심 정렬)
- [x] **종료칸 높이 13상태 135px 일치** (Fall 제외)
- [x] **루프 이음새 목표 ≤12% 충족**
- [x] 축 고정 없음
- [x] Fall `[73, 53, 35, 16]` 단조 하강, 마지막 칸 접지
- [x] 넥타이 전 프레임 유지 / 커피컵·기타 소품 미포함
- [x] 밉맵 14/14 + uid, 회귀 테스트 **4886 passed / 0 failed**
- [ ] 실제 화면 QA — qa-verifier 담당

## 대조표

- `docs/02-design/characters/ddungsil-evolved-contact.png` (14행 84프레임)
- `assets/generated/sprites/ddungsil_evolved-v1/walk-zoom.png` (Walk 8프레임 확대)

## 작업 메모

**축소된 대조표만 보고 프레임 내용을 판정하지 말 것.** 이번 라운드에 base·evolved 두 번 모두
작은 대조표에서 Walk 후반 프레임을 "뒤돌아섰다"고 잘못 읽었고, 확대해 보니 8프레임 전부
왼쪽 profile 이었다. 앞으로 프레임 내용 판정은 확대본으로만 한다.

**원본 분할은 연결성분 폴백이 필요하다.** `sick` 행에서 두 포즈가 실제로 맞닿아 열-공백 분할이
6개가 아니라 5개를 냈다(추출기는 연결성분을 쓰므로 정상 분리). 재합성 스크립트에 연결성분
폴백을 넣어 해결했다 — 다음 캐릭터에도 그대로 적용된다.

---

# 뚱실이 evolved2(뚱대박) — 14상태 애니메이션 인수인계

> 작성: sprite-artist, 2026-08-11 / 제작 기록: `assets/generated/sprites/ddungsil_evolved2-v1/`
> base·evolved 와 동일한 설계. 셀 192x208, 접지 16, 종료칸 = Idle 중립 135px, bbox 중심 정렬.

> **이로써 뚱실이 3티어 42상태가 전부 완성됐다.**

## 아이덴티티 판단 — 금목걸이만 유지 (team-lead 승인)

레거시 정지 아트는 **금목걸이** 외에 **돈다발·금괴·날리는 지폐·로또 용지·반짝임**을 함께 갖고 있다.
**금목걸이만 영구 아이덴티티로 유지**하고 나머지는 전부 제외했다:

- 날리는 지폐·반짝임은 몸에서 **분리된 성분**이라 "전 프레임 단일 연결 컴포넌트" 검수를 위반한다
- 돈다발·금괴·로또는 손에 든/바닥에 쌓인 소품이라 Poop / FileHover / Eat 의 소품 금지 계약과 충돌하고,
  14상태에서 일관 유지가 불가능하다
- 삐약 evolved2 도 같은 방식으로 태블릿을 빼고 볏·육수·명찰만 남겼다

확대 검수 결과 **금목걸이는 84프레임 전부에 있고, 돈·금괴·지폐·반짝임은 어디에도 없다.**
"대박" 정체성은 금목걸이 + 활짝 웃는 표정으로 전달된다.

## 등록값

**Idle 중립 프레임 몸통 높이 = 135px** (3티어 공통 — `sheet_scale` 계산 근거).
`foot_padding` 최솟값이 전 상태 16 이라 `ground_padding` 은 명시 불필요.

| 상태 | 파일 | 격자 | frames | fps | loop | airborne | `foot_padding` | `horizontal_offsets` |
|---|---|---|--:|--:|---|---|---|---|
| Idle | `res://assets/sprites/ddungsil_evolved2/idle_4f.png` | 4 x 1 | 4 | 4 | true | — | `[16, 16, 16, 16]` | `[0.0, 0.0, 0.0, 0.5]` |
| Walk | `res://assets/sprites/ddungsil_evolved2/walk_8f.png` | 4 x 2 | 8 | 10 | true | — | `[16, 16, 16, 16, 16, 16, 16, 16]` | `[0.0, -0.5, 0.0, 0.0, -0.5, 0.5, -0.5, -0.5]` |
| Sleep | `res://assets/sprites/ddungsil_evolved2/sleep_6f.png` | 6 x 1 | 6 | 4 | true | — | `[16, 16, 16, 16, 16, 16]` | `[0.0, 0.0, -0.5, 0.5, -0.5, 0.0]` |
| Eat | `res://assets/sprites/ddungsil_evolved2/eat_4f.png` | 4 x 1 | 4 | 6 | true | — | `[16, 16, 16, 16]` | `[0.5, 0.0, -0.5, 0.0]` |
| Sick | `res://assets/sprites/ddungsil_evolved2/sick_6f.png` | 6 x 1 | 6 | 5 | true | — | `[16, 16, 16, 16, 16, 16]` | `[-0.5, 0.0, 0.0, 0.5, -0.5, 0.5]` |
| Sulk | `res://assets/sprites/ddungsil_evolved2/sulk_6f.png` | 6 x 1 | 6 | 5 | true | — | `[16, 16, 16, 16, 16, 16]` | `[0.5, 0.0, 0.0, 0.5, 0.5, -0.5]` |
| Play | `res://assets/sprites/ddungsil_evolved2/play_6f.png` | 6 x 1 | 6 | 8 | true | **true** | `[18, 17, 39, 32, 16, 16]` | `[-0.5, 0.0, 0.0, 0.0, 0.0, 0.0]` |
| Dragged | `res://assets/sprites/ddungsil_evolved2/dragged_4f.png` | 4 x 1 | 4 | 10 | true | **true** | `[42, 38, 16, 28]` | `[-0.5, 0.0, 0.0, 0.0]` |
| Fall | `res://assets/sprites/ddungsil_evolved2/fall_4f.png` | 4 x 1 | 4 | 12 | true | **true** | `[67, 46, 23, 16]` | `[0.0, 0.0, 0.0, 0.0]` |
| Land | `res://assets/sprites/ddungsil_evolved2/land_4f.png` | 4 x 1 | 4 | 10 | false | — | `[16, 16, 16, 16]` | `[0.5, 0.0, 0.0, 0.5]` |
| FileHover | `res://assets/sprites/ddungsil_evolved2/file_hover_4f.png` | 4 x 1 | 4 | 12 | false | — | `[16, 16, 16, 16]` | `[0.0, 0.0, 0.5, 0.0]` |
| FileConsume | `res://assets/sprites/ddungsil_evolved2/file_consume_4f.png` | 4 x 1 | 4 | 12 | false | — | `[16, 16, 16, 16]` | `[0.0, 0.0, 0.0, 0.0]` |
| Poop | `res://assets/sprites/ddungsil_evolved2/poop_6f.png` | 6 x 1 | 6 | 6 | true | — | `[16, 16, 16, 16, 16, 16]` | `[0.0, 0.0, 0.0, -0.5, 0.0, 0.0]` |
| Pet | `res://assets/sprites/ddungsil_evolved2/pet_6f.png` | 6 x 1 | 6 | 10 | false | — | `[16, 16, 16, 16, 16, 16]` | `[0.0, -0.5, 0.0, -0.5, -0.5, 0.5]` |

## 실측값

| 상태 | 폭 변화 | 높이 변화 | 종료칸 높이 | 루프 이음새 | 부양 |
|---|--:|--:|--:|--:|--:|
| Idle | 10.1% | 5.2% | 135 | 0.7% | — |
| Walk | 15.6% | 9.7% | 135 | 5.6% | — |
| Sleep | 8.6% | 11.9% | 135 | 1.3% | — |
| Eat | 23.0% | 27.4% | 135 | 2.2% | — |
| Sick | 20.1% | 31.7% | 135 | 1.5% | — |
| Sulk | 11.4% | 29.5% | 135 | 5.0% | — |
| Play | 8.5% | 50.0% | 135 | 0.8% | 23px |
| Dragged | 15.6% | 12.6% | 135 | 4.5% | 26px |
| Fall | 11.4% | 49.5% | 93 | — | 51px |
| Land | 7.4% | 107.7% | 135 | — | — |
| FileHover | 16.9% | 45.2% | 135 | — | — |
| FileConsume | 16.4% | 8.1% | 135 | — | — |
| Poop | 2.3% | 27.4% | 135 | 0.0% | — |
| Pet | 25.0% | 31.1% | 135 | — | — |

## 자체 검수

- [x] 14행 추출 ok, errors 0 — **포즈 겹침 재생성 0회** (base 2행 / evolved 2행과 달리 한 번에 통과)
- [x] 84프레임 셀 경계 접촉 0 / 부유 파편 0
- [x] `foot_padding` 최솟값 전 상태 16
- [x] `horizontal_offsets` 전 상태 ≤ 0.5px
- [x] **종료칸 높이 13상태 135px 일치** (Fall 제외)
- [x] 루프 이음새 전부 목표 이내
- [x] 축 고정 없음
- [x] Fall `[67, 46, 23, 16]` 단조 하강, 마지막 칸 접지
- [x] 금목걸이 전 프레임 유지 / 돈·금괴·지폐·반짝임 미포함
- [x] 밉맵 14/14 + uid, 회귀 테스트 **4998 passed / 0 failed**
- [ ] 실제 화면 QA — qa-verifier 담당

재생성 1회: `idle` 호흡이 높이 1.5% 로 거의 감지되지 않아 진폭을 명시해 다시 뽑았다 (10.1% / 5.2%).
가장 오래 노출되는 상태라 눈에 띄는 수준이 필요하다고 판단했다.

## 3티어 완성에 따른 후속 (gd-integrator)

`tiers` 가 `["base", "evolved", "evolved2"]` 로 3티어 전부가 되면, 그동안 유지해온
**`walk_static` / `walk_face_inverted` / `sleep_art_lacks_zzz` 세 레거시 플래그가 비로소 제거 대상**이 된다.
이 플래그들은 정지 폴백 경로에서만 읽히는데, 이제 모든 티어가 시트를 갖기 때문이다.
`runtime_sick_mark` 은 상태 config 값이라 **3티어 Sick 전부에 계속 필요하다**(어느 티어 시트에도 어지럼 표시를 그리지 않았다).

## 대조표

- `docs/02-design/characters/ddungsil-evolved2-contact.png` (14행 84프레임)
- `assets/generated/sprites/ddungsil_evolved2-v1/walk-zoom.png` (Walk 8프레임 확대)

---

## 정정 — Fall 의 `loop` 는 3티어 전부 `false` 다

위 세 티어 등록 표 중 **Fall 행의 `loop` 값을 `false` 로 읽어라.** 표를 생성한 스크립트의
일회성 상태 목록에 Fall 이 빠져 있어 `true` 로 출력됐다.

상태별 `loop` 계약(qa-verifier 가 검사로 잠근 값):

| 구분 | 상태 |
|---|---|
| **일회성 `loop: false`** | **Fall** / Land / FileHover / FileConsume / Pet |
| 반복 `loop: true` | Idle / Walk / Sleep / Eat / Sick / Sulk / Play / Dragged / Poop |

Fall 은 한 번 재생하고 마지막(접지) 칸을 유지한 채 Land 로 넘어간다. `loop: true` 로 두면
낙하 1주기(4프레임 / 12fps = 0.333초, 자유낙하 약 133px)마다 시트가 맨 위로 되돌아가
드래그할 때마다 낙하가 반복해서 튄다.

**같은 실수를 두 번 했다** — base 인계 때 기존 3종의 등록 관례를 그대로 복사하다 Fall 을
`true` 로 넘겼고, 그 원인이 스크립트 기본값에 남아 있어 evolved2 에서 재발했다. 스크립트의
일회성 목록에 Fall 을 넣어 근본을 고쳤으므로 다음 캐릭터부터는 반복되지 않는다.
