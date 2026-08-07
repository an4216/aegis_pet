# 모찌 evolved2 (회찌 / `mochi_evolved2`) 스프라이트 인수인계 — 10상태

> 작성: sprite-artist / character-pipeline, 2026-08-07
> 스펙: `docs/02-design/characters/mochi.spec.md` (§업그레이드 순서 3단계 = evolved2, 최종)
> 제작 기록: `assets/generated/sprites/mochi-evolved2-v1/` (보존)
> **스코프**: `evolved2` 티어 10상태. 이로써 모찌 3티어(base/evolved/evolved2)가 모두 애니메이션화됐다.

## 1. 제작 가이드 §8 인수인계 템플릿

| 항목 | 값 |
|---|---|
| 캐릭터 ID | `mochi_evolved2` (회찌, 최종 진화) |
| 기준 포즈 / 아이덴티티 키 | 파스텔 핑크 젤리 블롭 임원. **필수 식별 요소 4개: 둥근 금테 안경, 검은 턱시도 재킷(피크트 라펠 + 흰 셔츠), 검은 나비넥타이, 금색 원형 배지 2개**(하나는 머리 우측, 하나는 재킷). 그 외 다크로즈 외곽선, 광택 하이라이트, 큰 다크브라운 눈, 블러시 볼, 밑면 작은 발 2개 |
| 기본 걷기 시트 방향 | 정면 대칭 — `flip_h` 무의미 |
| 원본 배경 방식 | chroma + **시안 `#00FFFF`** — 실측으로 재판정했다 (§4). evolved(그린)와 다르다 |
| 표시 목표 몸통 높이 | evolved2 정지 포즈 화면 높이 `232.07` (= 128캔버스 bbox 115 × `BODY_SCALE` 2.018) |
| 발바닥 기준선 | 셀 하단에서 **16px** 위 — **10상태 44프레임 전부 `foot_padding = 16.0`**. base·evolved와 동일 |
| Walk에서만 허용하는 수평 이동 범위 | 전 상태 `horizontal_offsets` −4.0 ~ +6.0의 미세 보정만 |
| Walk 외 동작의 몸통 고정 기준 | 셀 중심 ±6px 이내 (sulk 마지막 프레임 +6.0이 최대) |
| 최대 폭 자세와 좌우 안전 여백 | 최대 폭 156px (192 셀 → 좌우 18px, `safe_margin_x` 충족) |
| Idle 미세 동작 | 미세 호흡 + **3번째 프레임 눈 깜빡임 1회** (안경 유지) |
| 파일 호버 / 파일 드롭 | **미제작** (스코프 외) |
| 상태별 시트 목록 | 아래 §2 |
| 렌더 필터 및 밉맵 | 10장 전부 `mipmaps/generate=true` + **Godot 4.4.1 헤드리스 `--import` 검증 완료** |
| baby·adult 수동 QA | **미실시** — `qa-verifier` 몫 |

## 2. 런타임 등록 실측값

전 상태 공통: **셀 192×208**, `foot_padding` 전 프레임 **16.0**.
경로 접두사: `res://assets/sprites/mochi_evolved2/`

| 상태 | 파일 | 그리드 | frames / fps / loop | horizontal_offsets | 몸통 높이 | 특수 키 |
|---|---|---:|---|---|---:|---|
| Idle | `idle_4f_alpha_smooth.png` | 4×1 | 4 / 4.0 / true | `[0.0, 0.0, 0.0, 0.0]` | 176~176 | — |
| Walk | `walk_8f_alpha_smooth.png` | 4×2 | 8 / 10.0 / true | `[0.0, 1.0, 1.0, 1.0, 0.0, 1.0, 0.5, 0.5]` | 176~176 | — |
| Sleep | `sleep_4f_alpha_smooth.png` | 4×1 | 4 / 5.0 / true | `[0.0, 0.0, 0.0, 0.0]` | 82~129 | — |
| Eat | `eat_4f_alpha_smooth.png` | 4×1 | 4 / 6.0 / true | `[0.0, 0.0, 0.0, 0.0]` | 163~164 | — |
| Sick | `sick_4f_alpha_smooth.png` | 4×1 | 4 / 6.0 / true | `[0.0, 1.0, 2.0, 2.0]` | 94~171 | **`runtime_sick_mark`: §5 판단 참고** |
| Sulk | `sulk_4f_alpha_smooth.png` | 4×1 | 4 / 6.0 / true | `[0.0, 0.0, 2.0, 6.0]` | 168~176 | — |
| Play | `play_4f_alpha_smooth.png` | 4×1 | 4 / 8.0 / true | `[0.0, 0.0, 0.0, 0.0]` | 122~176 | **`airborne: true`** |
| Dragged | `dragged_4f_alpha_smooth.png` | 4×1 | 4 / 10.0 / true | `[2.5, 1.0, -4.0, 0.0]` | 168~176 | **`airborne: true`** |
| Fall | `fall_4f_alpha_smooth.png` | 4×1 | 4 / 12.0 / true | `[-1.5, 0.0, 0.5, 0.0]` | 139~176 | **`airborne: true`** |
| Land | `land_4f_alpha_smooth.png` | 4×1 | 4 / 10.0 / **false** | `[0.0, -1.0, 0.0, -0.5]` | 87~176 | — |

`foot_padding`: 4프레임 상태 `[16.0]×4`, Walk `[16.0]×8`.
`ground_padding` 생략 가능 (airborne 3상태 최솟값이 16.0 = 자동 기본값).

### `sheet_scale` (evolved2) = **0.653**

```gdscript
"sheet_scale": {"base": 0.605, "evolved": 0.753, "evolved2": 0.653},
```

`BODY_SCALE["mochi"]["evolved2"] = 2.018`은 **그대로 둔다** (정지 포즈 폴백용).

```text
evolved2 정지 몸통 115px ÷ 시트 idle 휴지프레임 176px = 0.6534 → 0.653
검산: 2.018 × 0.653 = 1.3178 ; 176 × 1.3178 = 231.9 ≈ 정지 232.07 ✅
보정 없으면: 176 × 2.018 = 355.2 = 153% 과대
```

기준 프레임: idle 프레임0, 알파 bbox `(22, 16, 170, 192)` → 높이 **176**.

### ⚠️ 회찌는 idle이 이미 셀 안전영역 천장에 닿아 있다

`176 = 208 − 16(하단) − 16(상단)`. 즉 **idle 자세가 이미 셀이 허용하는 최대 높이**다.
그 결과 세로로 늘어나야 하는 상태(Fall/Dragged/Sulk/Play 최고점)도 전부 176에서 잘려
**idle보다 더 커 보일 수 없다** — 스트레치 다이내믹이 압축됐다.

base(idle 129)·evolved(idle 158)는 여유가 있어 Fall이 idle보다 확실히 길었지만, evolved2는
차이가 나지 않는다. 화면 크기 정합성에는 문제가 없고(sheet_scale이 흡수) 발 위치도 정확하지만,
**"쭉 늘어나는 낙하" 연출이 약하다.** 개선하려면 이 티어만 셀 높이를 208 → 256 정도로 키워
다시 뽑아야 한다 — **이번 스코프 밖**이며, 3티어 셀 규격이 달라지는 변경이라 별도 판단이 필요하다.

## 3. 등록 구조

- 포즈 오버라이드는 `visible_extent`를 읽지 않는다. 크기는
  `STAGE_SCALE × get_body_scale(species, tier) × sheet_scale`(`pet.gd:653`).
- `ANIMATED_POSE_OVERRIDES["mochi"]`에 **evolved2 티어를 추가**한다:
  `"tiers": ["base", "evolved", "evolved2"]`, `sheet_scale`은 위 3티어 맵,
  각 상태 밑에 `"evolved2"` 설정 추가.
- **Play 키 이름**: 파일명은 `play_4f_...`이지만 **런타임 키는 `Play`** — base(`happy_4f_...`)와 같은 키다.

## 4. 크로마키 재판정 — 실측 결과 **시안 `#00FFFF`** (evolved의 그린과 다르다)

지시대로 관성 복사하지 않고 매번 새로 판정했다. 회찌는 넥타이가 **파랑이 아니라 검정**이라
evolved에서 시안을 탈락시켰던 충돌 요인이 사라졌고, 새로 추가된 색(검정 턱시도, 흰 셔츠,
금색 배지)은 어느 것도 시안과 가깝지 않다.

정지 아트 3장(idle/happy/sick)의 불투명 피사체 픽셀 대 후보 키 거리(1퍼센타일):

| 키 | evolved2 idle | happy | sick | 판정 |
|---|---:|---:|---:|---|
| **cyan** | **222.6** | **219.7** | **222.6** | ✅ 최고 |
| green | 210.9 | 210.7 | 211.0 | 차선 |
| blue | 190.1 | 188.7 | 190.6 | |
| magenta | 168.1 | 164.5 | 167.2 | ❌ 핑크와 충돌 |

**판정 방법 자체를 대조군으로 검증했다** — 같은 스크립트를 기존 티어에 돌리면
evolved는 green(220.6) > cyan(152.5)으로 **내가 실패를 겪고 알아낸 답을 그대로 재현**하고,
base는 cyan(219.5)을 고른다. 방법이 맞다는 근거다.

**정지 아트만으로 끝내지 않았다.** 생성된 실제 row에도 같은 검사를 돌리고(시안 p1 216.9),
batch 1(4상태)만 먼저 뽑아 **컨테이너에서 시험 추출 → `ok: true`** 를 확인한 뒤 나머지 6상태를
생성했다. evolved 때는 10장을 다 뽑고 나서야 추출이 거부해 전량 재생성했으므로, 이번엔
게이트를 앞으로 당겼다.

최종 결과: `edge_pixels` 전 상태 0, `chroma_adjacent_pixels` 0~14(fall 13 / land 14 —
base·evolved의 land와 같은 수준), 추출 `ok: true` errors/warnings 없음. 검정·금색·핑크 모두 보존.

## 5. `runtime_sick_mark` 판단 — **시트에 땀방울이 있다** (base·evolved와 다름)

Sick 시트 4프레임을 3배 확대해 확인했다:

- **소용돌이 눈(@_@)은 없다** — 눈은 안경 뒤 반쯤 감긴 처진 실눈
- **땀방울이 그려져 있다** — 2프레임 얼굴 좌상단에 물방울 1개, 4프레임 우측에 물방울과 김이 오르는 표시
- 연결성 검사 결과 **모든 프레임이 단일 컴포넌트(components=1)** → 땀방울이 실루엣에 붙어 있고
  분리된 부유 기호가 아니다 (제작 가이드의 "분리 이펙트 금지" 위반 아님)
- 아픔은 땀방울 + **몸이 점점 주저앉는 실루엣**(171px → 94px)으로 표현된다

**권장: `runtime_sick_mark: true` 유지** — 근거와 함께 gd-integrator 판단에 맡긴다.

- 켜야 하는 이유: 땀방울이 실제 표시 크기에서 너무 작다. baby 단계(`STAGE_SCALE` 0.378)면
  몸통이 약 88px로 그려지고 땀방울은 **3~5px**에 불과해 사실상 안 보인다. Sulk도 처진 눈에
  침울한 표정이라 얼굴만으로는 구분이 어렵다.
- 끌 수도 있는 이유: base·evolved와 달리 **이 티어는 시트가 이미 어지럼/불편 표시를 갖고 있다.**
  실제 화면에서 땀방울이 읽힌다면 `@_@` 라벨이 중복·과잉으로 보일 수 있다.

→ `qa-verifier`가 실제 화면에서 땀방울 가독성을 확인한 뒤 최종 결정하는 것을 제안한다.
**세 티어 중 이 티어만 시트에 표시가 있다는 점**이 판단 포인트다.

## 6. `airborne` 판단 — Play / Dragged / Fall = **true**

| 상태 | airborne | 근거 |
|---|---|---|
| Play | **true** | 바운스 — 몸이 들리고 밑면 발이 지면에서 떨어지는 프레임이 있다 |
| Dragged | **true** | 4프레임 전부 공중에 매달린 자세 |
| Fall | **true** | 4프레임 전부 낙하, 접지 없음 |
| Idle/Walk/Sleep/Eat/Sick/Sulk/Land | false | 상시 접지 (Land 1프레임은 지면 충격 스쿼시) |

base·evolved와 동일한 3종이다. ⚠️ 같은 한계도 그대로다 — `align_y: bottom` 정렬로
`foot_padding`이 44프레임 전부 16.0 고정이라 **화면상 상승분은 나오지 않는다**(선언은 의미상
정확하고, 지금 켜도 회귀 없음). 진폭을 살리려면 그 3상태를 재추출해야 한다.

## 7. 자체 검수 (제작 가이드 §6)

- [x] 10상태 투명 배경, `frames-manifest.ok = true`, errors/warnings 없음
- [x] `edge_pixels` 전 상태 0
- [x] `chroma_adjacent_pixels` 0~14 — 시안 잔여 없음, 검정 턱시도·금 배지·핑크 보존
- [x] 열×행 × 프레임 일치 (아틀라스 10 rows / 44 cells)
- [x] `foot_padding`·`horizontal_offsets` 길이 == frames
- [x] **44프레임 전부 기준선 16.0** — 상하 튐 0
- [x] **안경·턱시도·나비넥타이·금배지 2개가 44프레임 전부 유지** (컨택트 시트 확인)
- [x] 전 프레임 단일 컴포넌트 — 분리된 파편/부유 기호 없음
- [x] 밉맵 + Godot 임포트 검증
- [ ] 실제 화면 QA 미실시 — `qa-verifier` 담당

### 상태별 모션 판정

| 상태 | 판정 | 비고 |
|---|---|---|
| Idle | 통과 | 미세 호흡 + f3 깜빡임 |
| Walk | 통과 | 밑면 발 교대 접지 8프레임 2보 사이클 (base의 "다리 없는 홉" 실수 반복 없음) |
| Sleep | 통과 | 납작 누움, 눈 감김 |
| Eat | 통과 | 입·볼만으로 씹기, **음식 소품 없음** |
| Sick | 통과 | 처짐 + 땀방울 (§5) |
| Sulk | 통과 | 삐진 입·아래로 내린 눈 |
| Play | 통과 | 스쿼시-스트레치 바운스 |
| Dragged | 통과 | 매달려 늘어짐, 손 안 그려짐 |
| Fall | 통과(단서) | 낙하 표현은 맞으나 §2의 천장 문제로 idle보다 길어 보이지 않는다 |
| Land | 통과 | 납작 스쿼시 → 복귀, 비반복 |

**보류 상태 없음. 반려·재생성 0회** (evolved의 크로마키 교훈을 선반영해 게이트를 앞당긴 효과).

## 8. 미제작

- FileHover / FileConsume / Poop / Pet 4종 (스코프 외)
- 정지 포즈 8장(`assets/sprites/chars/mochi_evolved2/*.png`)은 **보존** — 참고·폴백용

## 9. 제작 기록

`assets/generated/sprites/mochi-evolved2-v1/` — 삭제 금지.
구조·생성 방법은 `mochi.handoff.md` §7과 동일(요청 SSoT / raw 10 / frames 44 / curated 44 /
아틀라스 / state-sheets 10 / qa 프리뷰). 상태별 시트는 `curated/`의 최종 셀을 1:1 무손실 paste.

`base-source.png`는 `chars/mochi_evolved2/idle.png`(128px)를 ×4 LANCZOS 업스케일한 512² —
아이덴티티 참조용이며 최종 자산이 아니다.

## 10. 실행 메모

- row 1장 12~15분, 4병렬 3배치(4+4+2). **재생성 0회**.
- 배치 사이 잔류 프로세스 정리 필요(evolved 때 19개 누적으로 OOM 발생). 다만 **정리와 배치 실행을
  한 명령에 묶지 말 것** — 프로세스 정리가 자기 셸 체인을 죽여 배치가 실행되지 않는다(이번에 발생).
- 세션↔상태 매칭은 캐릭터 설명(`"Hoechi (mochi evolved2"`)을 필수 마커로 요구해 격리했다.
  **모찌 3티어의 action 문구가 거의 동일**하므로 이 마커 없이는 다른 티어 이미지가 섞인다.
- 추출·compose는 Linux 컨테이너(`runio.py` fcntl 가드 무수정).
