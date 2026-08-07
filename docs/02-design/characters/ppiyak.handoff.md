# 삐약(ppiyak) 계열 — Sleep 애니메이션 인수인계

> **[2026-08-06 갱신] 이 절의 스코프 경고는 해소되었다.** 아래 Sleep 절은 v2 작업 당시의 기록이며,
> 나머지 9상태(Idle/Walk/Eat/Sick/Sulk/Happy/Dragged/Fall/Land)는 이 문서 뒤쪽
> **"나머지 9상태 애니메이션 인수인계 (v3)"** 절에서 3티어 전부 완성됐다.
> 따라서 ppiyak 3티어는 현재 **10/10 상태 애니메이션 완비**다.
>
> 아래 Sleep 표의 시트 크기(1536x256)와 `foot_padding`(24)은 **생성 중간 산출물** 기준값이라
> 실제 런타임 자산과 다르다. 런타임 `sleep_6f.png`는 **768x128 / 셀 128 / `foot_padding` 12**이며
> `pet.gd`에 등록된 값도 12다. v3 절의 표는 전부 이 128셀 기준으로 통일되어 있다.

## 제작 기록 위치 (보존)

- `assets/generated/sprites/ppiyak-v2/`
- `assets/generated/sprites/ppiyak_evolved-v2/`
- `assets/generated/sprites/ppiyak_evolved2-v2/`

각 폴더에 `sprite-request.json`(SSoT), `raw/sleep.png`, `frames/`, `curation.json`,
`sprite-sheet-alpha.png`, `manifest.json`, `qa/sleep.gif`, `qa-notes.md`가 있다.

## 런타임 등록값 (gd-integrator가 그대로 옮길 표)

세 티어 모두 동일한 격자/타이밍이다. `pet.gd`의 `ANIMATED_WALK_OVERRIDES`(mochi walk 방식)와
같은 형태의 Sleep 오버라이드로 등록한다.

| 항목 | ppiyak | ppiyak_evolved | ppiyak_evolved2 |
|---|---|---|---|
| `path` | `res://assets/sprites/ppiyak/sleep_6f.png` | `res://assets/sprites/ppiyak_evolved/sleep_6f.png` | `res://assets/sprites/ppiyak_evolved2/sleep_6f.png` |
| 시트 크기 | 1536×256 | 1536×256 | 1536×256 |
| `columns` × `rows` | 6 × 1 | 6 × 1 | 6 × 1 |
| 프레임 크기 | 256×256 | 256×256 | 256×256 |
| 논리 `frames` | 6 | 6 | 6 |
| `fps` (권장) | 4.0 | 4.0 | 4.0 |
| `loop` | true | true | true |
| `foot_padding` | `[24,24,24,24,24,24]` | `[24,24,24,24,24,24]` | `[24,24,24,24,24,24]` |
| `horizontal_offsets` | `[-6.0,-6.0,-5.5,-5.5,-5.5,-6.5]` | `[-9.5,-10.0,-10.0,-9.5,-9.0,-9.0]` | `[-13.5,-14.0,-14.0,-13.5,-13.5,-12.5]` |
| 실측 몸통 높이 (프레임별) | 202/192/191/196/202/207 | 168/158/157/162/168/172 | 174/166/165/169/174/179 |
| 실측 몸통 폭 (프레임별) | 205/219/220/210/202/198 | 204/219/219/210/201/195 | 204/219/219/210/202/196 |

**fps 4.0 근거:** 6프레임 = 정확히 호흡 1회이므로 4fps에서 1.5초/호흡(분당 40회). 수면 호흡으로
자연스러운 속도다. 이 값을 바꾸려면 프레임 수도 같이 바꿔야 한다(`recommended_breathe_frames`).

**`foot_padding`은 반드시 넣어야 한다.** 레거시 정지 `sleep.png`는 몸통이 캔버스 바닥에서 7px
위였는데 새 시트는 24px이다. `foot_padding`을 생략하면 펫이 작업표시줄에서 17px 떠 보인다.

**`horizontal_offsets`는 몸통 중심을 셀 중심으로 되돌리는 값**이다(측정 중심 x가 셀 중심 128보다
오른쪽이라 전부 음수). 프레임 간 편차가 1px 이내라 좌우 흔들림은 없다. 좌우 반전 시 부호를 뒤집는
기존 규칙 그대로 적용된다.

## §8 인수인계 템플릿

```text
캐릭터 ID: ppiyak / ppiyak_evolved / ppiyak_evolved2
기준 포즈 / 아이덴티티 키:
  - ppiyak: 노란 병아리, 머리 위 노란 뿔깃 1가닥, 파란 넥스트랩 + 흰 사각 사원증
  - ppiyak_evolved: 노란 닭, 빨간 하트 볏, 목끈 + 사원증
  - ppiyak_evolved2: 노란 수탉, 큰 빨간 볏 + 빨간 육수 + 빨간 꼬리깃, 빨간 목끈 + "팀장" 금색 명찰
기본 걷기 시트 방향: 이번 작업 범위 아님 (Walk 미제작)
원본 배경 방식: chroma green #00FF00 → 알파 변환 완료 (잔여 0px 검증)
표시 목표 몸통 높이: Sleep 평균 198(base) / 164(evolved) / 171(evolved2) px @256셀
발바닥 기준선: 프레임 하단에서 24px 위 (전 프레임 동일, foot_padding=24)
Walk에서만 허용하는 수평 이동 범위: 해당 없음 (Sleep은 수평 이동 0)
Walk 외 동작의 몸통 고정 기준: 몸통 중심 x=134±0.5 고정, 좌우 대칭 스쿼시만 허용
최대 폭 자세와 좌우 안전 여백: 최대폭 220px(f2) → 셀 좌우 여백 각 18px 확보
Idle 미세 동작: 이번 범위 아님
파일 호버(입 열기) 표현: 이번 범위 아님
파일 드롭(먹기) 표현: 이번 범위 아님
상태별 시트 목록: sleep_6f.png / 6×1 / 6프레임 / 4fps / loop=true (3티어 동일)
프레임별 foot_padding / horizontal_offsets: 위 표 참조
렌더 필터 및 밉맵 확인: ★ 미완 — 아래 "gd-integrator 조치 필요" 참조
baby·adult 수동 QA 결과: ★ 미완 — 실기 화면 QA는 qa-verifier 담당
```

## gd-integrator 조치 필요

1. **밉맵**: 새 PNG 3개의 `.import`에 `mipmaps/generate=true`가 필요하다(제작 가이드 §2).
   아직 `.import`가 없으므로 Godot 최초 임포트 후 설정해야 한다.
2. **기존 버그**: `assets/sprites/mochi/walk_8f.png.import`는 `mipmaps/generate=false`다.
   축소 렌더링 자산이므로 가이드 §2 위반이며, 이번 건과 별개로 고칠 값이다.
3. **레거시 정지 이미지 보존됨**: `assets/sprites/chars/ppiyak*/sleep.png` 3장은 삭제하지 않았다.
   등록 전환이 끝나고 회귀 비교까지 마친 뒤에 정리 여부를 판단한다.

## qa-verifier에게 미리 공유할 것

- **온스크린 몸통 크기 변화**: 새 Sleep 포즈는 레거시보다 눈에 띄게 **넓고 낮다**
  (base 기준 폭 176→209px, 높이 217→198px). 제대로 누운 자세라 의도된 방향이지만,
  화면에서 "잘 때 갑자기 커진다"로 읽히면 스케일 보정이 필요하다. **이 항목을 화면 QA에서
  반드시 눈으로 확인**해야 한다 — 수치만으로는 판정할 수 없다.
- **보류 상태 없음**: 3티어 전부 완성했다. ~~다만 Sleep 외 9개 상태는 애니메이션이 아니므로
  상태 커버리지 테스트의 기대값에서 제외해야 한다.~~
  **[2026-08-06 갱신] 이 제외 지침은 더 이상 유효하지 않다** — 나머지 9상태가 v3에서 전부
  제작되어 ppiyak은 10/10 커버리지다. 상태 커버리지 테스트에서 제외하지 말 것.


---

# 삐약(ppiyak) 계열 — 나머지 9상태 애니메이션 인수인계 (v3)

> **스코프:** Idle / Walk / Eat / Sick / Sulk / Happy(=`Play`) / Dragged / Fall / Land
> **9개 상태 x 3티어 = 27장 전부 신규 제작 완료.** 보류 상태 없음.
> Sleep은 기존 `sleep_6f.png`(v2) 그대로이며 이번 작업에서 건드리지 않았다.
> 이로써 ppiyak 3티어는 2026-08-06 단일 기준의 **10/10 상태 애니메이션 완비**가 된다.

## 제작 기록 위치 (보존)

- `assets/generated/sprites/ppiyak-v3/`
- `assets/generated/sprites/ppiyak_evolved-v3/`
- `assets/generated/sprites/ppiyak_evolved2-v3/`

각 폴더에 `sprite-request.json`(SSoT), `raw/<state>.png` 9장, `frames/`, `sprite-sheet-alpha.png`, `manifest.json`, `qa/`, `runtime-measurements.json`이 있다. 재제작으로 폐기한 1차 시도본은 `raw/rejected/`에 남겼다.

## 런타임 등록값 (gd-integrator가 그대로 옮길 표)

모든 시트의 셀은 **128x128**이다 (프로젝트의 `STATIC_POSE_SIZE`, 기존 `sleep_6f.png`와 동일). `foot_padding` 기준선도 Sleep과 같은 **12.0**으로 맞췄으므로 상태가 바뀌어도 발바닥이 튀지 않는다.

### Idle — `idle_4f.png`

고개 갸웃 + 미세 호흡. 몸통·발 위치 고정.

| 항목 | ppiyak | ppiyak_evolved | ppiyak_evolved2 |
|---|---|---|---|
| `path` | `res://assets/sprites/ppiyak/idle_4f.png` | `res://assets/sprites/ppiyak_evolved/idle_4f.png` | `res://assets/sprites/ppiyak_evolved2/idle_4f.png` |
| 시트 크기 | 512x128 | 512x128 | 512x128 |
| `columns` x `rows` | 4 x 1 | 4 x 1 | 4 x 1 |
| 프레임 크기 | 128x128 | 128x128 | 128x128 |
| 논리 `frames` | 4 | 4 | 4 |
| `fps` | 4 | 4 | 4 |
| `loop` | true | true | true |
| `foot_padding` | `[12, 12, 12, 12]` | `[12, 12, 12, 12]` | `[12, 12, 12, 12]` |
| `horizontal_offsets` | `[0.5, -1.5, 0, 1]` | `[-2, -2.5, -2.5, -1]` | `[-3, -4.5, -3.5, -1.5]` |
| 실측 몸통 높이 (프레임별) | 98/95/98/93 | 94/93/92/92 | 94/90/93/90 |
| 실측 몸통 폭 (프레임별) | 75/73/74/72 | 70/71/69/68 | 72/71/71/71 |
| 셀 경계 접촉 픽셀 | 0 | 0 | 0 |

### Walk — `walk_8f.png`

**기본 시트는 왼쪽을 향한다** (bichon과 동일). 오른쪽 이동은 `flip_h`. 8프레임 = 2보 1주기.

| 항목 | ppiyak | ppiyak_evolved | ppiyak_evolved2 |
|---|---|---|---|
| `path` | `res://assets/sprites/ppiyak/walk_8f.png` | `res://assets/sprites/ppiyak_evolved/walk_8f.png` | `res://assets/sprites/ppiyak_evolved2/walk_8f.png` |
| 시트 크기 | 512x256 | 512x256 | 512x256 |
| `columns` x `rows` | 4 x 2 | 4 x 2 | 4 x 2 |
| 프레임 크기 | 128x128 | 128x128 | 128x128 |
| 논리 `frames` | 8 | 8 | 8 |
| `fps` | 10 | 10 | 10 |
| `loop` | true | true | true |
| `foot_padding` | `[12, 12, 12, 12, 12, 12, 12, 12]` | `[12, 12, 12, 12, 12, 12, 12, 12]` | `[12, 12, 12, 12, 12, 12, 12, 12]` |
| `horizontal_offsets` | `[1, 1, 1.5, 2, 1.5, 1.5, 1.5, 1.5]` | `[0, 0, -0.5, -0.5, -0.5, 0.5, -0.5, 0]` | `[-3.5, -3, -3.5, -3, -2.5, -3.5, -3, -3.5]` |
| 실측 몸통 높이 (프레임별) | 98/97/97/97/96/96/96/95 | 93/93/93/92/93/93/92/92 | 92/92/91/91/91/91/91/91 |
| 실측 몸통 폭 (프레임별) | 62/62/61/62/61/61/61/61 | 66/64/63/63/63/63/63/64 | 59/60/61/60/59/59/60/59 |
| 셀 경계 접촉 픽셀 | 0 | 0 | 0 |

### Eat — `eat_6f.png`

짧게 쪼았다 드는 루프. 머리만 이동, 발·몸통 고정.

| 항목 | ppiyak | ppiyak_evolved | ppiyak_evolved2 |
|---|---|---|---|
| `path` | `res://assets/sprites/ppiyak/eat_6f.png` | `res://assets/sprites/ppiyak_evolved/eat_6f.png` | `res://assets/sprites/ppiyak_evolved2/eat_6f.png` |
| 시트 크기 | 768x128 | 768x128 | 768x128 |
| `columns` x `rows` | 6 x 1 | 6 x 1 | 6 x 1 |
| 프레임 크기 | 128x128 | 128x128 | 128x128 |
| 논리 `frames` | 6 | 6 | 6 |
| `fps` | 8 | 8 | 8 |
| `loop` | true | true | true |
| `foot_padding` | `[12, 12, 12, 12, 12, 12]` | `[12, 12, 12, 12, 12, 12]` | `[12, 12, 12, 12, 12, 12]` |
| `horizontal_offsets` | `[0, 0, 0, 0, 0, 0]` | `[-2.5, -2.5, -2, -2, -2, -1.5]` | `[-3.5, -3.5, -3.5, -2.5, -3.5, -3.5]` |
| 실측 몸통 높이 (프레임별) | 97/86/82/97/96/97 | 91/93/92/93/94/92 | 91/91/90/94/91/92 |
| 실측 몸통 폭 (프레임별) | 74/74/74/74/74/74 | 73/69/70/70/70/69 | 69/69/69/67/69/69 |
| 셀 경계 접촉 픽셀 | 0 | 0 | 0 |

### Sick — `sick_6f.png`

축 처진 자세 + 반쯤 감긴 눈. 부유 기호 없음(런타임이 `@_@`를 따로 그림).

| 항목 | ppiyak | ppiyak_evolved | ppiyak_evolved2 |
|---|---|---|---|
| `path` | `res://assets/sprites/ppiyak/sick_6f.png` | `res://assets/sprites/ppiyak_evolved/sick_6f.png` | `res://assets/sprites/ppiyak_evolved2/sick_6f.png` |
| 시트 크기 | 768x128 | 768x128 | 768x128 |
| `columns` x `rows` | 6 x 1 | 6 x 1 | 6 x 1 |
| 프레임 크기 | 128x128 | 128x128 | 128x128 |
| 논리 `frames` | 6 | 6 | 6 |
| `fps` | 5 | 5 | 5 |
| `loop` | true | true | true |
| `foot_padding` | `[12, 12, 12, 12, 12, 12]` | `[12, 12, 12, 12, 12, 12]` | `[12, 12, 12, 12, 12, 12]` |
| `horizontal_offsets` | `[-0.5, 0.5, -0.5, 0, -1, -0.5]` | `[-3, -3.5, -3, -4, -1.5, -0.5]` | `[-5.5, -5.5, -5, -5.5, -5.5, -5.5]` |
| 실측 몸통 높이 (프레임별) | 98/98/91/98/91/96 | 96/91/89/93/92/95 | 95/89/86/96/80/94 |
| 실측 몸통 폭 (프레임별) | 65/65/65/64/64/65 | 72/75/72/76/69/67 | 71/75/70/71/75/69 |
| 셀 경계 접촉 픽셀 | 0 | 0 | 0 |

### Sulk — `sulk_6f.png`

정면 3/4 각도 삐침. 얼굴이 항상 보인다.

| 항목 | ppiyak | ppiyak_evolved | ppiyak_evolved2 |
|---|---|---|---|
| `path` | `res://assets/sprites/ppiyak/sulk_6f.png` | `res://assets/sprites/ppiyak_evolved/sulk_6f.png` | `res://assets/sprites/ppiyak_evolved2/sulk_6f.png` |
| 시트 크기 | 768x128 | 768x128 | 768x128 |
| `columns` x `rows` | 6 x 1 | 6 x 1 | 6 x 1 |
| 프레임 크기 | 128x128 | 128x128 | 128x128 |
| 논리 `frames` | 6 | 6 | 6 |
| `fps` | 5 | 5 | 5 |
| `loop` | true | true | true |
| `foot_padding` | `[12, 12, 12, 12, 12, 12]` | `[12, 12, 12, 12, 12, 12]` | `[12, 12, 12, 12, 12, 12]` |
| `horizontal_offsets` | `[0, 0, -0.5, 0, 0.5, 0]` | `[-1.5, -0.5, -1, -1, -1, -2]` | `[-4.5, -4.5, -4, -3.5, -5, -4]` |
| 실측 몸통 높이 (프레임별) | 97/97/97/97/94/97 | 94/92/93/92/93/94 | 92/91/91/95/91/91 |
| 실측 몸통 폭 (프레임별) | 64/62/63/62/63/62 | 69/61/68/62/68/68 | 69/69/70/73/70/70 |
| 셀 경계 접촉 픽셀 | 0 | 0 | 0 |

### Play — `happy_6f.png`

**상태명은 `Play`** — `happy_6f.png` 파일이 `Play` 상태에 등록된다(mochi와 동일 규칙). 날개 파닥임 + 제자리 깡충. `foot_padding`이 점프 높이를 만든다.

| 항목 | ppiyak | ppiyak_evolved | ppiyak_evolved2 |
|---|---|---|---|
| `path` | `res://assets/sprites/ppiyak/happy_6f.png` | `res://assets/sprites/ppiyak_evolved/happy_6f.png` | `res://assets/sprites/ppiyak_evolved2/happy_6f.png` |
| 시트 크기 | 768x128 | 768x128 | 768x128 |
| `columns` x `rows` | 6 x 1 | 6 x 1 | 6 x 1 |
| 프레임 크기 | 128x128 | 128x128 | 128x128 |
| 논리 `frames` | 6 | 6 | 6 |
| `fps` | 8 | 8 | 8 |
| `loop` | true | true | true |
| `foot_padding` | `[12, 19, 23, 15, 22, 12]` | `[12, 12, 22, 12, 21, 12]` | `[13, 27, 18, 26, 27, 12]` |
| `horizontal_offsets` | `[-0.5, -1.5, -0.5, -0.5, -0.5, 0]` | `[-2, 0.5, 1, 0, 1, -1.5]` | `[-1, 0, 0.5, 1, 0, -0.5]` |
| 실측 몸통 높이 (프레임별) | 95/97/101/97/100/95 | 91/93/93/90/93/92 | 93/93/92/91/89/87 |
| 실측 몸통 폭 (프레임별) | 75/77/75/73/75/74 | 68/81/80/82/80/69 | 74/68/69/68/68/69 |
| 셀 경계 접촉 픽셀 | 0 | 0 | 0 |

### Dragged — `dragged_4f.png`

공중에 매달려 좌우로 흔들림. 발이 아래로 늘어진다.

| 항목 | ppiyak | ppiyak_evolved | ppiyak_evolved2 |
|---|---|---|---|
| `path` | `res://assets/sprites/ppiyak/dragged_4f.png` | `res://assets/sprites/ppiyak_evolved/dragged_4f.png` | `res://assets/sprites/ppiyak_evolved2/dragged_4f.png` |
| 시트 크기 | 512x128 | 512x128 | 512x128 |
| `columns` x `rows` | 4 x 1 | 4 x 1 | 4 x 1 |
| 프레임 크기 | 128x128 | 128x128 | 128x128 |
| 논리 `frames` | 4 | 4 | 4 |
| `fps` | 10 | 10 | 10 |
| `loop` | true | true | true |
| `foot_padding` | `[15, 18, 12, 15]` | `[14, 14, 12, 12]` | `[16, 15, 14, 12]` |
| `horizontal_offsets` | `[-2, 0.5, -2.5, 0.5]` | `[-0.5, 0.5, 0, -0.5]` | `[-2.5, 0, -3.5, 0]` |
| 실측 몸통 높이 (프레임별) | 95/97/96/97 | 92/97/93/89 | 89/94/89/96 |
| 실측 몸통 폭 (프레임별) | 66/69/69/69 | 73/79/76/73 | 67/64/69/66 |
| 셀 경계 접촉 픽셀 | 0 | 0 | 0 |

### Fall — `fall_4f.png`

자유낙하. 날개를 위로 펼치고 다리를 버둥댄다.

| 항목 | ppiyak | ppiyak_evolved | ppiyak_evolved2 |
|---|---|---|---|
| `path` | `res://assets/sprites/ppiyak/fall_4f.png` | `res://assets/sprites/ppiyak_evolved/fall_4f.png` | `res://assets/sprites/ppiyak_evolved2/fall_4f.png` |
| 시트 크기 | 512x128 | 512x128 | 512x128 |
| `columns` x `rows` | 4 x 1 | 4 x 1 | 4 x 1 |
| 프레임 크기 | 128x128 | 128x128 | 128x128 |
| 논리 `frames` | 4 | 4 | 4 |
| `fps` | 12 | 12 | 12 |
| `loop` | true | true | true |
| `foot_padding` | `[14, 22, 13, 12]` | `[12, 13, 13, 14]` | `[24, 17, 12, 14]` |
| `horizontal_offsets` | `[0.5, 1, 1, 2]` | `[1, -0.5, -2, -3.5]` | `[-1, 3.5, 2.5, 3.5]` |
| 실측 몸통 높이 (프레임별) | 101/97/95/96 | 103/97/80/87 | 91/87/95/91 |
| 실측 몸통 폭 (프레임별) | 89/84/88/88 | 86/91/90/97 | 78/79/81/75 |
| 셀 경계 접촉 픽셀 | 0 | 0 | 0 |

### Land — `land_4f.png`

착지 스쿼시 → 기립 복귀. **`loop=false`** (bichon Land와 동일).

| 항목 | ppiyak | ppiyak_evolved | ppiyak_evolved2 |
|---|---|---|---|
| `path` | `res://assets/sprites/ppiyak/land_4f.png` | `res://assets/sprites/ppiyak_evolved/land_4f.png` | `res://assets/sprites/ppiyak_evolved2/land_4f.png` |
| 시트 크기 | 512x128 | 512x128 | 512x128 |
| `columns` x `rows` | 4 x 1 | 4 x 1 | 4 x 1 |
| 프레임 크기 | 128x128 | 128x128 | 128x128 |
| 논리 `frames` | 4 | 4 | 4 |
| `fps` | 10 | 10 | 10 |
| `loop` | false | false | false |
| `foot_padding` | `[12, 12, 12, 12]` | `[12, 12, 12, 12]` | `[12, 12, 12, 12]` |
| `horizontal_offsets` | `[0.5, 0, 0, 0]` | `[0.5, -2, -2, -2]` | `[0, -1.5, -3, -3.5]` |
| 실측 몸통 높이 (프레임별) | 87/87/106/106 | 82/84/102/107 | 77/81/102/107 |
| 실측 몸통 폭 (프레임별) | 91/90/74/66 | 89/84/72/72 | 86/83/72/73 |
| 셀 경계 접촉 픽셀 | 0 | 0 | 0 |

## 잘림(clipping) 전수 점검 결과

작업 전에 ppiyak 3티어의 **기존 정지 이미지 24장 전부**(idle/walk1/walk2/eat/sick/sulk/happy/sleep)와
**이미 완성된 `sleep_6f.png` 18프레임**을 384~512px로 확대해 육안 검수하고, 동시에 캔버스 4변에
닿는 불투명 픽셀(α>128)을 수치로 측정했다.

### 1. 캔버스 경계 잘림 — 1건 발견

| 대상 | 내용 | 이번 재제작으로 해결? |
|---|---|---|
| `chars/ppiyak_evolved/walk2.png` | **좌측 경계에 불투명 픽셀 13개** — 커피컵 소품이 캔버스 밖으로 잘림 | **해결** (Walk 신규 제작, 소품 자체를 제외) |

나머지 23장은 4변 접촉 픽셀 0으로, 캔버스 경계 잘림 없음. `sleep_6f.png` 18프레임도 전부 0.

### 2. 볼터치(blush)가 윤곽선에 잘리는 문제 — 광범위하게 발견

Sleep 작업에서 발견됐던 것과 **동일한 유형**이다. 볼터치 원이 얼굴/턱 윤곽선에 가로막혀
반달 모양으로 잘려 보인다.

| 티어 | 잘림이 보이는 정지 포즈 | 이번 재제작으로 해결? |
|---|---|---|
| `ppiyak` | idle, sulk | **해결** |
| `ppiyak_evolved` | idle, walk1, sick, sulk, happy (3티어 중 가장 심함) | **해결** |
| `ppiyak_evolved2` | idle | **해결** |
| `sleep_6f.png` (3티어) | 없음 — 온전한 원으로 보임 | 해당 없음 (v2에서 이미 해결) |

**해결 방법:** v2 Sleep 작업에서 쓴 스타일 계약 문구를 그대로 이어받아, 모든 프롬프트의
style 항목에 "볼터치 원은 얼굴·볼·턱 윤곽선 **위에** 그려 반드시 끊기지 않은 완전한 원으로
보이게 하고, 윤곽선이 볼터치를 가로지르거나 반달로 자르지 않는다"를 명시했다.
신규 27장 전부 확대 검수에서 볼터치가 완전한 원으로 확인됐다.

### 3. 눈·부리·볏·소품 잘림

신규/기존 모두 눈·부리·볏이 캔버스나 다른 레이어에 잘린 사례는 **없었다**.
단 위 1번의 evolved walk2 커피컵 1건만 예외.

### 4. 점검 중 추가로 발견한 문제 (요청 범위 밖이지만 보고)

**(a) 제작 가이드 §2가 금지한 "분리된 이펙트·텍스트"가 기존 정지 이미지 전반에 있었다.**

| 대상 | 금지 요소 |
|---|---|
| 전 티어 `sleep.png` | 떠 있는 `Zzz` 문자 |
| 전 티어 `sick.png` | 소용돌이 눈 / 부유 기호, evolved2는 말풍선 |
| 전 티어 `happy.png` | 별·반짝임·집중선 |
| `walk2.png`, `eat.png` (evolved 계열) | 속도선, 떠 있는 하트 |

특히 `Zzz`와 `@_@`는 **런타임(`pet.gd`의 `_zzz` / `_sick_mark` Label)이 이미 그리고 있어서**
그림에도 있으면 이중으로 표시된다. 신규 27장은 이 요소를 프롬프트에서 전부 금지했고,
결과물에 하나도 없음을 확인했다.

**(b) 스펙에 없는 포즈별 소품이 진화 티어에 붙어 있었다.**

- `ppiyak_evolved`: 8포즈 중 6포즈에 **커피컵**, sleep에 **노트북**, sulk에 **안경**
- `ppiyak_evolved2`: 8포즈 중 6포즈에 **태블릿**

셋 다 스펙의 아이덴티티 서술(목끈 + 사원증/명찰)에 없고 포즈마다 들쭉날쭉했다.
신규 27장에서는 **영구 아이덴티티(목끈·사원증·볏·육수·꼬리깃)만 유지하고 손에 드는 소품은
전부 제외**했다. 커피컵/태블릿을 캐릭터 정체성으로 되살리려면 `char-designer` 스펙에
명시한 뒤 재제작해야 한다.

## §8 인수인계 템플릿

```text
캐릭터 ID: ppiyak / ppiyak_evolved / ppiyak_evolved2
기준 포즈 / 아이덴티티 키:
  - ppiyak: 노란 병아리, 머리 위 노란 뿔깃 1가닥, 파란 넥스트랩 + 흰 사각 사원증
  - ppiyak_evolved: 노란 닭, 빨간 하트 볏, 금/탄색 목끈 + 흰-주황 사원증
  - ppiyak_evolved2: 노란 수탉, 큰 빨간 볏 + 빨간 육수 + 빨간 꼬리깃, 빨간 목끈 + 금색 "팀장" 명찰
  (v2 Sleep에서 확정한 base-source.png 3장을 그대로 아이덴티티 앵커로 재사용 — 티어 간 표류 없음)
기본 걷기 시트 방향: **왼쪽** (3티어 전부, bichon과 동일). 오른쪽 이동은 flip_h.
원본 배경 방식: chroma → 알파 변환 완료.
  - ppiyak: green #00FF00
  - ppiyak_evolved / evolved2: **cyan #00FFFF** — 생성기가 요청한 green을 무시하고 cyan을 썼다.
    sprite-gen 추출기가 자동 감지해 정상 처리했고, 최종 알파에 잔여 키 픽셀 0개를 확인했다.
표시 목표 몸통 높이: 상태별 중앙값 정규화 결과 티어별 77~107px @128셀
  (ppiyak 87~106 / evolved 82~107 / evolved2 77~107)
발바닥 기준선: 프레임 하단에서 **12px** 위 (기존 sleep_6f.png와 동일, foot_padding=12)
  단 Happy/Dragged/Fall은 의도적으로 공중에 뜨므로 foot_padding이 프레임마다 커진다(위 표 참조).
Walk에서만 허용하는 수평 이동 범위: 시트 자체는 수평 이동 0 (모든 프레임 몸통 중심 정렬).
  보행 이동은 런타임이 담당하고, 시트는 다리 교대만 표현한다.
Walk 외 동작의 몸통 고정 기준: 알파 가중 중심을 셀 중심에 정렬. 프레임 간 편차 ±2px 이내
  (Idle 최대 1.5px, Walk 최대 1px) — 좌우 흔들림 없음.
최대 폭 자세와 좌우 안전 여백: 최대폭은 Fall (evolved f4에서 97px) → 셀 좌우 여백 각 15px 이상 확보.
  27장 전부 셀 4변 접촉 픽셀 0개로 검증.
Idle 미세 동작: 고개 갸웃(좌→중앙→우) + 미세 호흡. 4프레임 @4fps.
파일 호버(입 열기) 표현: 미제작 — ppiyak은 FileHover/FileConsume 상태를 쓰지 않는다
  (10상태 단일 기준에 포함되지 않음). 필요해지면 별도 작업.
파일 드롭(먹기) 표현: 위와 동일. 일반 급식 반응은 Eat 시트가 담당한다.
상태별 시트 목록: 위 "런타임 등록값" 9개 표 참조 (3티어 동일 격자/타이밍)
프레임별 foot_padding / horizontal_offsets: 위 9개 표 참조
렌더 필터 및 밉맵 확인: ★ 미완 — 아래 "gd-integrator 조치 필요" 참조
baby·adult 수동 QA 결과: ★ 미완 — 실기 화면 QA는 qa-verifier 담당
```

## 제작 과정에서 처리한 파이프라인 이슈 (재작업 시 참고)

sprite-gen의 기본 추출 설정만으로는 이 프로젝트의 시각 계약을 만족하지 못해, 추출 뒤
결정론적 보정을 두 가지 넣었다. 스크립트는 `assets/generated/sprites/*-v3/`의 산출물과 함께
재현 가능하며, 픽셀 소스는 항상 sprite-gen이 합성한 `sprite-sheet-alpha.png`다
(`frames/`를 직접 읽지 않는다).

1. **프레임별 크기 정규화 해제.** 추출기는 프레임마다 독립적으로
   `scale = min(max_w/w, max_h/h)`를 적용해 셀에 꽉 채운다. 그 결과 모든 포즈의 바운딩 높이가
   똑같이 고정되어 스쿼시-스트레치가 사라지고, 머리를 숙인 Eat 프레임이 서 있는 몸통의 약 1.3배로
   부풀었다. → **상태별 중앙값 몸통 높이로 정규화**해 상태 간 몸통 크기는 맞추고(가이드 §2),
   같은 행 안의 프레임 간 변화는 살렸다.
2. **공중 동작의 수직 이동 복원.** `align_y=bottom`은 모든 프레임의 최하단을 한 기준선에 붙인다.
   접지 동작에는 정확하지만 Happy의 깡충(원본 스트립 기준 91px 진폭), Dragged/Fall의 부유가
   전부 사라졌다. → 원본 스트립에서 프레임별 접지선을 재측정해 **`foot_padding`으로 되돌렸다.**
   셀 상단을 뚫을 경우 프레임을 자르지 않고 진폭 전체를 한 계수로 축소해 궤적 모양을 지켰다.

또한 **evolved/evolved2의 생성 배경이 cyan**으로 나온 것을 감지하지 못하면 측정이 전부 깨진다
(첫 시도에서 두 티어의 모든 행이 단일 덩어리로 분할됐다). 배경색은 요청값을 믿지 말고
이미지 모서리에서 실측해야 한다.

**재제작 1회 발생:** Eat와 Sulk가 3티어 모두 같은 방식으로 실패했다 — Eat는 머리가 몸통에
파묻혀 2번 프레임이 얼굴 없는 덩어리가 됐고, Sulk는 "돌아선다"를 문자 그대로 해석해 뒤통수만
보였다. 두 상태의 action 문구에 "얼굴이 모든 프레임에서 반드시 보인다 / 등을 보이지 않는다"
제약을 넣어 6개 행을 재생성해 해결했다(1회 재시도로 통과). 1차 시도본은 `raw/rejected/`에 보존.

## gd-integrator 조치 필요

1. **밉맵**: 신규 PNG **27장 전부 `.import`가 아직 없다.** Godot 최초 임포트 후 각 파일의
   `.import`에 `mipmaps/generate=true`를 넣어야 한다(제작 가이드 §2). 기존 `sleep_6f.png` 3장은
   이미 `mipmaps/generate=true`로 되어 있다.
2. **Happy는 `Play` 상태로 등록한다.** `state_machine.gd`가 정의하는 상태명에 `Happy`는 없다
   (`Idle/Walk/Sleep/Eat/Poop/Sick/Sulk/Dragged/Fall/Land/Jump/Perch/Play`).
   `happy_6f.png`를 `Play` 키에 넣는다 — mochi가 이미 쓰는 규칙과 동일하다.
3. **`Land`는 `loop=false`**, 나머지 8개는 `loop=true`.
4. **기존 `ANIMATED_POSE_OVERRIDES["ppiyak"]`의 Sleep 등록은 그대로 두고**, 그 아래에 9개 상태를
   같은 tier(base/evolved/evolved2) 3단 구조로 추가한다.
5. **레거시 정지 이미지 보존됨**: `assets/sprites/chars/ppiyak*/`의 8장 x 3티어는 삭제하지 않았다.
   등록 전환과 회귀 비교가 끝난 뒤 정리 여부를 판단한다.
6. **이전 인수인계 표의 오류 정정**: 이 문서 위쪽 Sleep 표는 시트 크기를 `1536x256`,
   `foot_padding`을 24로 적고 있으나, 이는 **생성 중간 산출물**의 값이다. 실제 런타임 자산
   `assets/sprites/ppiyak*/sleep_6f.png`는 **768x128 / 셀 128 / `foot_padding` 12**이고,
   `pet.gd`에 등록된 값도 12다. 신규 9상태는 전부 이 128셀 기준에 맞췄다.

## qa-verifier에게 미리 공유할 것

- **보류 상태 없음.** 9상태 x 3티어 = 27장 전부 완성. Sleep까지 포함해 **10/10 상태 커버리지**이므로,
  이제 ppiyak을 상태 커버리지 테스트에서 제외할 이유가 없다.
- **정적 검증은 통과 상태로 넘긴다**: 27장 전부 (a) 셀 4변 접촉 픽셀 0개, (b) 크로마 잔여 0개,
  (c) 완전 투명 픽셀 아래 비-0 RGB 0개, (d) 선언한 프레임 수 일치.
- **화면에서 반드시 눈으로 볼 것 — Eat/Sulk의 동작 폭이 작다.** 얼굴이 잘리거나 뒤통수가 보이는
  문제를 잡느라 두 상태의 포즈 변화를 의도적으로 억제했다. 수치로는 정상이지만 "거의 안 움직인다"로
  읽힐 수 있다. 그렇게 보이면 프레임 수를 늘리는 게 아니라 동작 진폭을 키워 재생성해야 한다.
- **Happy의 점프 높이**: `foot_padding`이 12→최대 27까지 오르내리며 깡충임을 만든다.
  이 값이 무시되면 제자리에서 붙어 있는 것처럼 보인다 — 등록 누락 여부를 화면에서 확인할 것.
- **Walk 방향**: 시트 기본이 왼쪽이다. 오른쪽 이동 시 `flip_h`와 `horizontal_offsets` 부호 반전이
  같이 적용되는지 양방향 모두 확인.
- **기존 Sleep 자산의 선재 결함 (이번 작업 범위 밖, 그러나 밉맵 켜면 드러남)**:
  `sleep_6f.png` 3장에는 **완전 투명(α=0) 픽셀 아래에 비-0 RGB가 각각 827 / 1140 / 1094개** 있다.
  지금은 보이지 않지만 `mipmaps/generate=true`를 켜면 밉 하위 레벨에서 그 색이 평균에 섞여
  축소 표시 시 색 테두리로 번질 수 있다. 신규 27장은 이 값을 0으로 정리해 두었다.
  Sleep도 같은 정리를 할지는 별도 판단이 필요하다.

---

# 삐약(ppiyak) 계열 — Idle 눈 깜박임(블링크) 인수인계 (v4)

> **스코프:** `Idle` 1개 상태, **3티어 전부** 신규 제작 완료. 보류 상태 없음.
> 나머지 9상태(Walk/Sleep/Eat/Sick/Sulk/Play/Dragged/Fall/Land)는 v2·v3 자산 그대로이며
> 이번 작업에서 전혀 건드리지 않았다.
>
> **전제 정정 — Idle은 이미 애니메이션이었다.** 이 작업은 "정지 이미지 → 애니메이션" 전환이
> 아니라 **이미 애니메이션이던 Idle(`idle_4f.png`, 고개 갸웃 4프레임)에 눈 깜박임을 더한 것**이다.
> 신규 `idle_blink_6f.png`는 기존 `idle_4f.png`를 **대체**한다(고개 갸웃 동작을 그대로 품고 있다).
> 등록을 바꾼 뒤 `idle_4f.png`는 미사용이 되지만 회귀 비교용으로 삭제하지 않았다.

## 제작 기록 위치 (보존)

- `assets/generated/sprites/ppiyak-idle-blink-v1/`
- `assets/generated/sprites/ppiyak_evolved-idle-blink-v1/`
- `assets/generated/sprites/ppiyak_evolved2-idle-blink-v1/`

각 폴더에 `sprite-request.json`(SSoT), `raw/idle_blink.png`, `frames/`, `sprite-sheet-alpha.png`,
`manifest.json`, `qa/`가 있다. base 폴더의 `raw/rejected/idle_blink-closed-beak.png`는
재제작으로 폐기한 1차 시도본이다(사유는 아래 "재제작 1회 발생").

QA 산출물: `qa/idle_blink-sequence.gif`(실제 재생 시퀀스 그대로 16프레임 @8fps),
`qa/sequence-contact.png`(같은 시퀀스의 정지 대조표), `qa/idle_blink-contact.png`(시트 6칸).
`ppiyak-idle-blink-v1/qa/compare-all-tiers.png`는 3티어 x (기존 idle f0 / 신규 f0 / 갸웃 / 블링크) 대조표다.

## 시트 구조 — 물리 6칸을 논리 16프레임으로 재생 (bichon Idle과 같은 방식)

물리 시트는 **6칸 1행**이고, 재생은 `sprite_frame_sequence`로 **논리 16프레임**을 만든다.
bichon의 `BICHON_ANIMATIONS["Idle"]`이 2칸 시트를 11논리 프레임으로 돌리는 것과 같은 구조이며,
`pet.gd`의 `_apply_frame_offsets_from_config()`가 `ANIMATED_POSE_OVERRIDES` 경로에서도
`sprite_frame_sequence`를 그대로 읽으므로(`pet.gd:820`) 추가 코드 없이 동작한다.

| 물리 셀 | 내용 |
|---|---|
| 0 | 중립 정면, 눈 뜸 (기준 포즈) |
| 1 | 고개 갸웃 (캐릭터 기준 왼쪽), 눈 뜸 |
| 2 | 중립 + 미세 호흡 상승, 눈 뜸 |
| 3 | 고개 갸웃 (캐릭터 기준 오른쪽), 눈 뜸 |
| 4 | **중립 포즈 그대로, 눈 반쯤 감음** (블링크 중간) |
| 5 | **중립 포즈 그대로, 눈 완전히 감음** (블링크 정점) |

셀 4·5는 셀 0과 **눈만 다르고 나머지는 동일**하다. 그래서 시퀀스에서 0 → 4 → 5 → 4 → 0으로
이어져도 몸이 튀지 않는다.

```gdscript
"sprite_frame_sequence": [0, 0, 1, 1, 2, 2, 3, 3, 0, 4, 5, 4, 0, 0, 2, 2]
```

- **8fps / 16프레임 = 2.0초 루프**, 루프당 깜박임 1회.
- 앞 8프레임(idx 0~7)이 고개 갸웃 1주기다. 각 포즈를 2틱씩 유지하므로 **기존 4fps `idle_4f`와
  체감 속도가 같다** — 갸웃 동작이 빨라지지 않는다.
- 깜박임은 idx 9~11 (반→완전→반, 총 375ms, 완전히 감긴 구간은 125ms).
- **깜박임 뒤에 눈 뜬 프레임 4개(idx 12~15)를 남겨 루프 이음새 전에 반드시 눈이 다시 떠 있다.**
  마지막에 붙이면 루프가 감긴 눈에서 뜬 눈으로 튄다. 위치를 옮길 때 이 제약을 깨지 말 것.
- idx 15(셀 2, 중립) → idx 0(셀 0, 중립)이라 이음새에 스냅이 없다.

## 런타임 등록값 (gd-integrator가 그대로 옮길 표)

세 티어 모두 **동일한 격자·타이밍·시퀀스**다. `ANIMATED_POSE_OVERRIDES["ppiyak"]["states"]["Idle"]`의
기존 3티어 항목을 아래로 **교체**한다(추가가 아니라 교체 — `idle_4f.png`를 대신한다).

| 항목 | ppiyak | ppiyak_evolved | ppiyak_evolved2 |
|---|---|---|---|
| `path` | `res://assets/sprites/ppiyak/idle_blink_6f.png` | `res://assets/sprites/ppiyak_evolved/idle_blink_6f.png` | `res://assets/sprites/ppiyak_evolved2/idle_blink_6f.png` |
| 시트 크기 | 768x128 | 768x128 | 768x128 |
| `columns` x `rows` | 6 x 1 | 6 x 1 | 6 x 1 |
| 프레임(셀) 크기 | 128x128 | 128x128 | 128x128 |
| 물리 셀 수 | 6 | 6 | 6 |
| 논리 `frames` | **16** | **16** | **16** |
| `fps` | 8.0 | 8.0 | 8.0 |
| `loop` | true | true | true |
| `airborne` | 없음 (접지 상태) | 없음 | 없음 |
| 셀 경계 접촉 픽셀 | 0 | 0 | 0 |
| α=0 픽셀 아래 비-0 RGB | 0 | 0 | 0 |

**`frames`는 16이다 (6이 아니다).** `columns`x`rows`는 물리 격자(6x1)이고, `frames`는
`sprite_frame_sequence` 길이와 같아야 한다. bichon Idle이 `"frames": 11`에 2칸 시트인 것과 같다.

### 프레임별 `foot_padding` / `horizontal_offsets` (논리 16프레임 기준)

`foot_padding`과 `horizontal_offsets`는 **물리 셀이 아니라 논리 프레임 인덱스로 참조**된다
(`pet.gd:796~801`의 `_bichon_frame` 인덱싱). 따라서 배열 길이는 16이어야 한다.

**`foot_padding` — 3티어 전부 동일, 전 프레임 12.0:**

```gdscript
"foot_padding": [12.0, 12.0, 12.0, 12.0, 12.0, 12.0, 12.0, 12.0, 12.0, 12.0, 12.0, 12.0, 12.0, 12.0, 12.0, 12.0]
```

기존 ppiyak 접지 상태(Idle/Walk/Sleep/Eat/Sick/Sulk/Land)와 같은 12.0 기준선이라 상태가 바뀌어도
발바닥이 튀지 않는다. 6칸 모두 실측 `foot_padding`이 정확히 12이므로 프레임별 편차가 없다.

**`horizontal_offsets` — 전 프레임 0.0 권장 (3티어 공통):**

```gdscript
"horizontal_offsets": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
```

굽는 단계에서 **각 셀의 알파 가중 중심을 셀 중심(63.5)에 정수 픽셀로 정렬**해 두었다. 남은 잔차는
전 셀 **|0.5px| 이하**라서 보정이 필요 없고, 오히려 프레임마다 ±0.5px를 넣으면 눈만 깜박여야 할
정지 자세에서 좌우로 미세하게 떠는 것처럼 보인다. **그래서 0으로 두는 것을 권장한다.**
실측 잔차는 참고용으로 아래에 남긴다(물리 셀 0~5 순서):

| 티어 | 셀별 잔차 (0.5px 반올림) |
|---|---|
| ppiyak | 0.0 / -0.5 / 0.0 / 0.0 / 0.0 / +0.5 |
| ppiyak_evolved | +0.5 / 0.0 / +0.5 / -0.5 / -0.5 / -0.5 |
| ppiyak_evolved2 | 0.0 / +0.5 / 0.0 / +0.5 / 0.0 / -0.5 |

### 실측 몸통 크기 (물리 셀 0~5, α>128 기준)

| 티어 | 몸통 높이 | 몸통 폭 |
|---|---|---|
| ppiyak | 98 / 96 / 98 / 96 / 97 / 97 | 76 / 74 / 76 / 74 / 76 / 75 |
| ppiyak_evolved | 94 / 91 / 93 / 92 / 93 / 93 | 63 / 64 / 60 / 61 / 60 / 60 |
| ppiyak_evolved2 | 94 / 93 / 94 / 93 / 94 / 94 | 70 / 68 / 69 / 67 / 70 / 70 |

블링크 셀(4·5)과 기준 셀(0)의 높이 차는 **전 티어 1px 이내**라 깜박이는 동안 몸이 커지거나
작아지지 않는다.

## ★ `sheet_scale`은 그대로 둔다 (1.144 / 1.150 / 1.000) — 중요

`pet.gd:159`의 `sheet_scale`은 **"그 티어 정지 idle.png 몸통 높이 / 그 티어 시트 idle 0번 프레임
몸통 높이"**로 계산된 값이고, 주석의 base 계산 `119 / 104 = 1.144`에서 **104는 기존
`idle_4f.png` 0번 프레임을 α>0으로 잰 값**이다.

신규 시트를 같은 α>0으로 재면 **98**이 나와서 6px(5.8%) 작아 보이지만, **이것은 실제 크기 차이가
아니다.** 알파 프로파일을 실측한 결과:

| 측정 임계 | `idle_4f.png` f0 | `idle_blink_6f.png` f0 |
|---|---|---|
| α>0 | 104 | 98 |
| α>32 | 99 | 98 |
| α>128 | **98** | **98** |

기존 `idle_4f.png`는 위아래로 **α가 1~8인 사실상 보이지 않는 헤일로가 약 3px** 붙어 있어서
α>0 측정만 104로 부풀었다. 화면에 실제로 보이는 실루엣(α>32 이상)은 **98~99로 동일**하고,
신규 시트는 그 헤일로 없이 깔끔한 경계를 가진다.

→ **결론: `sheet_scale`을 건드리지 말 것.** 신규 시트로 교체해도 화면상 몸통 크기는 그대로다.
α>0으로 재고 "6% 작아졌다"고 판단해 1.144를 1.21 같은 값으로 "고치면" 오히려 Idle만
6% 커진다. evolved(94)·evolved2(94)도 각 티어의 `idle_4f` f0과 α>128에서 정확히 일치시켜 구웠다.

## §8 인수인계 템플릿

```text
캐릭터 ID: ppiyak / ppiyak_evolved / ppiyak_evolved2
기준 포즈 / 아이덴티티 키: v3와 동일 (v2에서 확정한 base-source.png 3장을 그대로 재사용,
  티어 간·버전 간 표류 없음)
  - ppiyak: 노란 병아리, 머리 위 노란 뿔깃 1가닥, 파란 넥스트랩 + 흰 사각 사원증
  - ppiyak_evolved: 노란 닭, 빨간 하트 볏, 금/탄색 목끈 + 흰-주황 사원증, 노란 꼬리깃
  - ppiyak_evolved2: 노란 수탉, 큰 빨간 볏 + 빨간 육수 + 빨간 꼬리깃, 빨간 목끈 + 금색 "팀장" 명찰,
    자신감 있는 각진 눈썹
기본 걷기 시트 방향: 이번 작업 범위 아님 (Walk는 v3 자산 유지, 왼쪽 기준)
원본 배경 방식: chroma → 알파 변환 완료, 잔여 키 픽셀 0개
  - ppiyak: green #00FF00
  - ppiyak_evolved / evolved2: cyan #00FFFF (v3에서 생성기가 실제로 쓴 색을 이번엔 요청에 명시)
표시 목표 몸통 높이: base 98px / evolved 94px / evolved2 94px @128셀 (각 티어 idle_4f f0과 동일)
발바닥 기준선: 프레임 하단에서 12px 위 (전 프레임·전 티어 동일, foot_padding=12)
Walk에서만 허용하는 수평 이동 범위: 해당 없음 (Idle 수평 이동 0)
Walk 외 동작의 몸통 고정 기준: 알파 가중 중심을 셀 중심(63.5)에 정수 픽셀 정렬, 잔차 ≤0.5px
최대 폭 자세와 좌우 안전 여백: 최대폭 76px(base f0/f2/f4) → 셀 좌우 여백 각 26px 확보,
  18칸 전부 셀 4변 접촉 픽셀 0개
Idle 미세 동작: 고개 갸웃(중립→왼쪽→중립호흡→오른쪽) + 눈 깜박임 1회. 물리 6칸 → 논리 16프레임 @8fps
파일 호버(입 열기) 표현: 미제작 (ppiyak은 FileHover/FileConsume 상태를 쓰지 않음)
파일 드롭(먹기) 표현: 위와 동일, 일반 급식 반응은 Eat 시트 담당
상태별 시트 목록: idle_blink_6f.png / 6x1 물리 / 논리 16프레임 / 8fps / loop=true (3티어 동일)
프레임별 foot_padding / horizontal_offsets: 위 표 참조 (전부 12.0 / 전부 0.0 권장)
렌더 필터 및 밉맵 확인: ★ 미완 — 아래 "gd-integrator 조치 필요" 참조
baby·adult 수동 QA 결과: ★ 미완 — 실기 화면 QA는 qa-verifier 담당
```

## 재제작 1회 발생 (base 티어)

1차 시도본은 6프레임 전부 **부리를 닫은 채로** 나왔다. 기존 `idle_4f.png`와 다른 9개 상태는 전부
**작게 벌린 부리(안쪽 붉은 입)**로 그려져 있어서, 그대로 등록하면 Idle만 부리를 다문 유일한
상태가 되어 표정이 달라 보인다. 프롬프트에 "부리는 여섯 프레임 전부 참조 이미지와 같이 벌린 채로
유지하고, 깜박임 프레임에서도 **눈만** 바뀐다"는 제약을 넣어 재생성해 해결했다(1회 재시도로 통과).
폐기본은 `ppiyak-idle-blink-v1/raw/rejected/idle_blink-closed-beak.png`에 보존.

evolved / evolved2는 이 제약이 처음부터 프롬프트에 들어가 1회 생성으로 통과했다.

## 제작 과정 메모 (재작업 시 참고)

v3와 **같은 두 가지 결정론 보정**을 이번에도 적용했다. 픽셀 소스는 언제나 sprite-gen이 합성한
`sprite-sheet-alpha.png`이고 `frames/`를 직접 읽지 않는다.

1. **프레임별 크기 정규화 해제.** 추출기는 프레임마다 독립적으로 셀에 꽉 채우므로 6칸의 바운딩
   높이가 전부 같아져 호흡의 크기 변화가 사라진다. → 원본 스트립에서 프레임별 몸통 높이를 다시
   재고(base 409/400/409/399/406/406), 그 비율을 유지한 채 0번 프레임이 기존 `idle_4f` f0과
   같아지도록 한 계수로 축소했다.
2. **몸통 중심 재정렬.** 알파 가중 중심을 셀 중심에 정수 픽셀로 맞췄다.

추가로 α=0 픽셀의 RGB를 0으로 정리했다(3티어 전부 0개 확인). 기존 `sleep_6f.png`가 이 값이 0이
아니어서 밉맵을 켜면 색 번짐이 생길 수 있다는 v3의 경고와 같은 항목이며, 신규 3장은 미리 정리했다.

**Windows 환경 이슈 2건** (다음 작업자가 같은 데서 막힌다):
- `sprite-gen`의 codex 가용성 프로브가 `subprocess`에 맨 `"codex"`를 넘겨서 Windows에서
  `WinError 2`로 실패하고 grok으로 폴백한다(grok은 미설치). **`--provider codex`를 명시**하면
  프로브를 건너뛰고 정상 동작한다.
- `extract`/`preview`가 POSIX `fcntl` 기반 `publish_guard`/`read_guard`를 요구해 Windows에서
  `RWLockUnavailable`로 멈춘다. 단독 작성자일 때는 그 두 가드를 no-op으로 바꿔 같은 엔트리포인트를
  호출하면 된다(스킬 파일은 수정하지 않았다).

## gd-integrator 조치 필요

1. **`Idle` 3티어 항목을 교체**한다 — `idle_4f.png` → `idle_blink_6f.png`, `frames` 4 → **16**,
   `fps` 4.0 → **8.0**, `columns` 4 → **6**, 그리고 **`sprite_frame_sequence` 추가**.
   `foot_padding`/`horizontal_offsets` 배열 길이도 4 → **16**으로 늘려야 한다.
2. **`sheet_scale`은 절대 건드리지 않는다** (위 ★ 절 참조).
3. **밉맵 — 반드시 고쳐야 한다.** 신규 PNG 3장
   `assets/sprites/ppiyak{,_evolved,_evolved2}/idle_blink_6f.png`는 Godot이 자동 임포트하면서
   `.import`를 만드는데, **기본값이 `mipmaps/generate=false`라 제작 가이드 §2 위반 상태로 생성된다**
   (작업 종료 시점에 base의 `.import`가 실제로 `false`로 만들어져 있는 것을 확인했다. 나머지 두 장은
   아직 `.import`가 없었지만 임포트되면 같은 기본값이 붙는다). 기존 `idle_4f.png`는 `true`이므로,
   교체 후 축소 렌더링 품질이 오히려 나빠지지 않도록 **3장 모두 `mipmaps/generate=true`로 바꿀 것.**
4. **`idle_4f.png` 3장은 삭제하지 않았다.** 등록 전환과 회귀 비교가 끝난 뒤 정리 여부를 판단한다.

## qa-verifier에게 미리 공유할 것

- **보류 상태 없음.** Idle 3티어 전부 완성. 상태 커버리지는 v3와 동일하게 **10/10** 유지
  (상태가 늘어난 게 아니라 Idle의 내용이 바뀐 것).
- **정적 검증은 통과 상태로 넘긴다**: 18칸(6칸 x 3티어) 전부 (a) 셀 4변 접촉 픽셀 0개,
  (b) 크로마 잔여 0개, (c) α=0 아래 비-0 RGB 0개, (d) 선언 프레임 수 일치.
- **화면에서 반드시 눈으로 볼 것 — 깜박임이 실제로 보이는가.** 논리 16프레임 중 3프레임만
  블링크라, `sprite_frame_sequence`가 등록에서 누락되면 **에러 없이 셀 0~5를 순서대로 6프레임만
  돌린다.** 그러면 깜박임이 2초에 1번이 아니라 매 0.75초마다 나오고 고개 갸웃 리듬도 빨라진다.
  "너무 자주 깜박인다"로 보이면 시퀀스 누락을 의심할 것.
- **`frames`를 6으로 등록하면** 갸웃만 나오고 깜박임이 전혀 안 보인다(시퀀스 앞 6개가 0,0,1,1,2,2라
  눈 감는 셀에 도달하지 못한다). 이것도 에러 없이 조용히 잘못 동작한다.
- **Idle 몸통 크기 회귀**: 교체 전후로 Idle에서 펫이 커지거나 작아지지 않아야 한다. 수치상으로는
  α>128 기준 3티어 전부 기존과 동일하게 맞췄지만, `sheet_scale`이 함께 수정돼 버리면 여기서 티가
  난다 — **진화 전/후 모두 육안 확인**할 것.
- **깜박임 속도**: 완전히 감긴 구간이 125ms뿐이라 놓치기 쉽다. 느리게 보고 싶으면
  `qa/idle_blink-sequence.gif`가 실제 재생 시퀀스 그대로다.
