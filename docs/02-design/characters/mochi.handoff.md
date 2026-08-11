# 모찌 (mochi) base 스프라이트 인수인계 — 10상태 애니메이션

> 작성: sprite-artist / character-pipeline, 2026-08-06
> 제작 기준: `docs/02-design/pet-sprite-production-guide.md` (§8 템플릿을 이 문서가 채운다)
> 제작 기록: `assets/generated/sprites/mochi-v2/` (보존 — 삭제 금지)
> **스코프**: mochi **base 티어**의 10상태. `evolved` / `evolved2`는 미제작.

## 1. 제작 가이드 §8 인수인계 템플릿

| 항목 | 값 |
|---|---|
| 캐릭터 ID | `mochi` (base 티어) |
| 기준 포즈 / 아이덴티티 키 | 파스텔 핑크 반달형 젤리 블롭. 팔·다리 없음, 다크로즈 외곽선, 광택 하이라이트, 큰 반짝이는 다크레드 눈, 작은 입, 블러시 볼. **블롭의 납작한 밑면이 접지점** |
| 기본 걷기 시트 방향 | 정면 대칭 — 방향 개념 없음. `flip_h` 무의미 |
| 원본 배경 방식 | chroma + **시안 `#00FFFF`**. 소재가 핑크라 마젠타는 충돌(자동 선택 점수 168.75), 시안이 최고점(249.12). mochi-v1과 동일 키를 유지해 기존 walk와 일관 |
| 표시 목표 몸통 높이 | `BODY_SCALE_TARGET_HEIGHT = 223.0` × `STAGE_SCALE`. **`BODY_SCALE`은 기존 `1.538` 그대로 유효** (§4 참고) |
| 발바닥 기준선 | 셀 하단에서 **16px** 위 — **10상태 40프레임 전부 예외 없이 `foot_padding = 16.0`**. 기존 출고된 `walk_8f.png`의 등록값(16.0)과 정확히 일치 |
| Walk에서만 허용하는 수평 이동 범위 | Walk 시트는 기존 출고본을 그대로 재사용(§3). 신규 9상태는 `horizontal_offsets` −4.0 ~ +5.0 범위의 미세 보정만 |
| Walk 외 동작의 몸통 고정 기준 | 셀 중심 기준 ±4px 이내. idle/eat/happy는 4프레임 전부 −1.0으로 완전 고정 |
| 최대 폭 자세와 좌우 안전 여백 | 최대 폭 **156px** (192 셀 → 좌우 여백 18px 확보, 요청 `safe_margin_x` 18 충족). dragged만 폭 134px·높이 176px로 세로가 가장 김 |
| Idle 미세 동작 | 아주 작은 스쿼시-스트레치 호흡 + **3번째 프레임에서 눈 깜빡임 1회**. 상하 바운스·좌우 이동 없음 |
| 파일 호버(입 열기) 표현 | **미제작** (스코프 외) |
| 파일 드롭(먹기) 표현 | **미제작** (스코프 외). `Eat`은 제작됨 |
| 상태별 시트 목록 | 아래 §2 표 |
| 프레임별 foot_padding / horizontal_offsets | 아래 §2 표 (실측) |
| 렌더 필터 및 밉맵 확인 | 신규 9장 전부 `.import`에 `mipmaps/generate=true` + **Godot 4.4.1 헤드리스 `--import`로 검증 완료** (uid·ctex 해시 자동 배정, params 보존). 픽셀아트가 아닌 소프트 페인팅이라 선형+밉맵 유지 |
| baby·adult 수동 QA 결과 | **미실시** — 런타임 등록(§3) 전에는 화면에 뜨지 않는다. `qa-verifier` 몫 |

## 2. 런타임 등록 실측값 (gd-integrator가 그대로 옮길 값)

전 상태 공통: **셀 192×208**, `foot_padding` 전 프레임 **16.0**.
경로 접두사: `res://assets/sprites/mochi/`
`visible_extent`는 그 상태 프레임 중 **최대 몸통 높이**로 산출했다 (정의는 §2-b 참고).

| 상태 | 파일 | 그리드 | frames / fps / loop | horizontal_offsets | 몸통 높이(min~max) | visible_extent |
|---|---|---:|---|---|---:|---:|
| Idle | `idle_4f_alpha_smooth.png` | 4×1 | 4 / 4.0 / true | `[-1.0, -1.0, -1.0, -1.0]` | 128~142 | 142.0 |
| Walk | `walk_8f_alpha_smooth.png` | 4×2 | 8 / 10.0 / true | `[-1.0, 1.0, 1.0, 1.0, 0.0, -1.0, -2.0, -2.0]` | 141~150 | 150.0 |
| Sleep | `sleep_4f_alpha_smooth.png` | 4×1 | 4 / 5.0 / true | `[-1.0, -2.0, -2.0, -1.0]` | 67~97 | 97.0 |
| Eat | `eat_4f_alpha_smooth.png` | 4×1 | 4 / 6.0 / true | `[-1.0, -1.0, -1.0, -1.0]` | 129~130 | 130.0 |
| Sick | `sick_4f_alpha_smooth.png` | 4×1 | 4 / 6.0 / true | `[-1.0, -4.0, 0.0, -4.0]` | 88~123 | 123.0 |
| Sulk | `sulk_4f_alpha_smooth.png` | 4×1 | 4 / 6.0 / true | `[-3.0, -3.0, -2.0, -1.0]` | 111~127 | 127.0 |
| Happy | `happy_4f_alpha_smooth.png` | 4×1 | 4 / 8.0 / true | `[-1.0, -1.0, -1.0, -1.0]` | 93~144 | 144.0 |
| Dragged | `dragged_4f_alpha_smooth.png` | 4×1 | 4 / 10.0 / true | `[5.0, 0.0, 1.0, 4.5]` | 176~176 | 176.0 |
| Fall | `fall_4f_alpha_smooth.png` | 4×1 | 4 / 12.0 / true | `[0.5, 2.0, 0.5, -1.0]` | 123~176 | 176.0 |
| Land | `land_4f_alpha_smooth.png` | 4×1 | 4 / 10.0 / **false** | `[0.0, -1.0, -2.0, -1.0]` | 58~139 | 139.0 |

`foot_padding`은 4프레임 상태 전부 `[16.0, 16.0, 16.0, 16.0]`, walk는 `[16.0]×8`.

**Walk은 v1 자산 재사용을 폐기하고 새로 생성했다** (2026-08-06 16:21 세션). 스펙 §걷기가
"Walk는 실제 보행으로"를 요구하는데 v1 액션이 `"...hops forward, no legs"`(다리 없는 홉)여서
스펙 위반이었다. 새 액션은 밑면의 작은 발 2개가 교대로 접지하는 8프레임 2보 사이클이다.
v1에서 물려온 원본은 `raw/walk.inherited-from-v1.png`로 보존.

### 2-b. `visible_extent` 정의와 사용처

`pet.gd`의 포즈 오버라이드 경로는 이 키를 **읽지 않는다**(§2-a 참고) — 그래서 실제 등록에는
불필요하다. 다만 bichon식 카탈로그로 옮길 가능성을 위해 계산해 둔다. 정의는
**그 상태의 프레임 중 최대 알파 bbox 높이**다. bichon의 등록값(Idle 716 vs 실측 622)은
손으로 튜닝된 값이라 산식이 없으므로, 그 숫자를 참고식으로 쓰지 말 것.

### ⚠️ 포즈 캐릭터 오버라이드는 `visible_extent`를 쓰지 않는다 — 코드로 확인함

`pet.gd`의 `start_animated_walk()`(:453)와 `start_animated_sleep()`(:494)이 실제로 읽는 키는
`path` / `columns` / `rows` / `foot_padding` / `horizontal_offsets` / `sprite_frame_sequence` /
`fps` / `frames` / `loop` **뿐이다**. 크기는

```gdscript
_base_scale = Vector2.ONE * STAGE_SCALE[stage] * Characters.get_body_scale(species, tier)
```

로 잡는다 — 즉 **`visible_extent`를 넣어도 무시된다.** 비숑(`BICHON_ANIMATIONS`)만
`visible_extent` 기반 `fit_scale`을 쓴다. 위 표에 `visible_extent`를 넣지 않은 이유가 이것이다.
비숑 항목에서 값을 복사해 오지 말 것.

### 등록 형태 예시

Sleep은 기존 `ANIMATED_SLEEP_OVERRIDES`(species → tier 2단) 모양에 그대로 들어간다:

```gdscript
"mochi": {
    "base": {"path": "res://assets/sprites/mochi/sleep_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 5.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [-1.0, -2.0, -2.0, -1.0]},
},
```

나머지 8개 신규 상태(Idle/Eat/Sick/Sulk/Happy/Dragged/Fall/Land)는 **현재 코드에 등록할 자리가 없다** — §3 참고.

### 🔴 `BODY_SCALE` 재실측 — **`3.076` → `1.860`으로 반드시 바꿔야 한다**

```gdscript
"mochi": {"base": 1.860, "evolved": 1.956, "evolved2": 2.018},
```

**현재 등록된 `3.076`을 그대로 두면 모찌가 정상 크기의 165%로 렌더된다.** 실측 근거:

- 2026-08-06에 정지 포즈 원본 캔버스가 256→128로 축소되면서 `BODY_SCALE` 값이 전부 2배가 됐다
  (`characters.gd` 주석 참고). 즉 `3.076`은 **128 캔버스 정지 아트 기준** 배수다.
- 정지 경로 실측: `chars/mochi/idle.png` = 128 캔버스, 알파 bbox 높이 **78px**
  → 화면 몸통 높이 `78 × 3.076 = 239.9` (이게 모찌가 지금 화면에 그려지는 크기다)
- 애니메이션 경로는 셀이 **208px**이고 idle 휴지 프레임 bbox 높이가 **129px**이다.
  같은 `3.076`을 쓰면 `129 × 3.076 = 396.8` → 정상의 **165%**.
- 같은 화면 크기를 유지하는 값: `239.93 ÷ 129 = 1.8599` → **`1.860`**

| 기준 프레임 | 몸통 높이 | 산출 BODY_SCALE |
|---|---:|---:|
| **idle 휴지 프레임(0) — 권장** | 129 | **1.860** |
| idle 4프레임 평균 | 132.25 | 1.814 |
| idle 호흡 최고점(1) | 142 | 1.690 |

휴지 프레임을 기준으로 잡았다 — 구 정지 `idle.png` 한 장과 대응하는 자세이고, 호흡 스쿼시는
그 위에 얹히는 것이 의도된 모션이다. `1.860`이면 휴지 자세가 현재 화면 크기와 정확히 일치하고
호흡 최고점만 10% 늘어난다. **이 재실측이 이전 라운드에 내가 플래그한 "정지↔애니메이션 7% 축소"
문제까지 함께 해소한다.**

`evolved`(1.956) / `evolved2`(2.018)는 **손대지 않는다** — 해당 티어 애니메이션 미제작이라
정지 포즈 기준값이 그대로 맞다.

⚠️ `BODY_SCALE`은 정지 경로와 공유되므로 `base`를 1.860으로 내리면, 혹시 정지 PNG로 폴백될 때
`78 × 1.860 = 145` (정상의 60%)로 작게 그려진다. base는 10상태 전부 애니메이션이므로 실사용
경로는 없지만, 시트 로드 실패 시 폴백이 작아진다는 점은 알고 있어야 한다.

### 발견: `BODY_SCALE_TARGET_HEIGHT` 상수와 실제 테이블이 어긋나 있다 (모찌 범위 밖)

`BODY_SCALE_TARGET_HEIGHT = 111.5`인데, 테이블 값을 그 상수로 역산하면 맞지 않는다:

| 캐릭터 | 128캔버스 bbox h | 테이블 값 | `111.5 ÷ h` | `h × 테이블값`(실제 화면 높이) |
|---|---:|---:|---:|---:|
| mochi | 78 | 3.076 | 1.429 | 239.9 |
| ddungsil | 108 | 2.144 | 1.032 | 231.6 |
| tokki | 91 | 2.578 | 1.225 | 234.6 |
| geobujang | 119 | 1.956 | 0.937 | 232.8 |

256→128 축소가 bbox를 정확히 절반으로 만들지 않았기 때문이다 (모찌 145 → 78, 정확한 절반은 72.5 —
다운스케일이 알파 프린지를 더 남겼다). 그래서 값을 기계적으로 2배 한 결과가 캐릭터마다 4~8%씩
어긋났고, 상수 `111.5`로는 어떤 값도 재현되지 않는다. 화면 높이가 232~240으로 흩어진 상태다.

**이건 12캐릭터 전체에 걸친 문제라 내 스코프(모찌 base)를 넘는다.** 모찌 값은 위와 같이
"모찌가 지금 그려지는 크기(239.9)를 유지"하는 기준으로 냈다. 전체 정규화를 다시 맞출지는
gd-integrator/qa-verifier 판단이다.

## 3. gd-integrator 결정 필요 — 등록 지점이 부족하다

현재 포즈 캐릭터용 오버라이드는 **상태별로 하드코딩된 딕셔너리 2개**뿐이다:

- `ANIMATED_WALK_OVERRIDES` (species → config) — Walk 전용, mochi 이미 등록됨
- `ANIMATED_SLEEP_OVERRIDES` (species → tier → config) — Sleep 전용, 현재 ppiyak만

`Idle/Eat/Sick/Sulk/Happy/Dragged/Fall/Land` **8종은 들어갈 자리가 없다.** 상태마다
`ANIMATED_<STATE>_OVERRIDES`를 8개 더 만드는 것은 확장성이 없으니, 아래를 제안한다:

> **species → state → (tier →) config** 형태의 단일 카탈로그(예: `ANIMATED_POSE_OVERRIDES`)로
> 통합하고, 기존 `ANIMATED_WALK_OVERRIDES` / `ANIMATED_SLEEP_OVERRIDES`를 그 위의 얇은 조회로
> 바꾼다. Sleep이 이미 tier 2단인 이유(진화 티어마다 몸통 폭·중심이 달라 시트가 따로)는 그대로
> 유지해야 하므로, tier 레벨은 선택적으로 허용하는 형태가 안전하다.

이건 런타임 구조 결정이라 내 판단 범위를 넘는다 — 설계는 gd-integrator가 정한다.
어떤 구조를 택하든 위 §2 표의 값은 그대로 쓰인다.

또한 `_is_animated_pet()` → `_is_bichon()`이라 **비숑만** 상태머신 전체가 시트 기반으로 돈다.
mochi는 상태별 오버라이드를 호출부(`walk_state.gd` / `sleep_state.gd`처럼)에서 켜 주는 방식이므로,
신규 8상태도 각 상태 스크립트에서 `start_animated_*()` 호출을 넣어야 실제로 재생된다.

## 4. Walk 처리 경위 (1차 판단을 스펙에 맞춰 뒤집었다)

1차에는 이미 출고·등록·QA된 `walk_8f.png`를 흔들지 않으려고 v1 원본(`raw/walk.png`, 8/5 생성)을
그대로 재사용하고 런타임 자산도 유지했다. **이 판단은 틀렸다** — 스펙 §걷기가 "Walk는 실제 보행으로"를
요구하는데 v1의 액션이 `"bouncing/wobbling ... hops forward, no legs"`(다리 없는 홉)였다.

그래서 walk만 액션을 다시 쓰고 **새로 생성**했다(2026-08-06 16:21 세션, 오늘 원본).
런타임 자산도 `walk_8f_alpha_smooth.png` (4×2, 768×416)로 새로 설치했다.

- 구 원본 보존: `raw/walk.inherited-from-v1.png`
- 구 런타임 자산 `walk_8f.png`는 **삭제하지 않고 남겨 두었다** (768×104 — 2026-08-06 자산 축소 때
  다른 작업자가 절반으로 줄인 파일). 현재 등록은 새 시트를 가리키므로 미사용 상태다.
- 그리드는 **4×2**로 맞췄다 — gd-integrator가 이미 그 형태로 등록해 둔 것과 일치시켰다.

⚠️ **새 walk의 `horizontal_offsets`가 1차 보고 때와 다르다.** 등록된 값은 1차 walk 기준이므로
아래 값으로 갱신해야 한다:

```text
등록된 값(구): [-1.0, 0.0, 0.0, -1.0, -1.0, 0.0, 0.0, -1.0]
새 실측값:     [-1.0, 1.0, 1.0, 1.0, 0.0, -1.0, -2.0, -2.0]
```

`foot_padding`은 `[16.0]×8`로 동일하다.

## 5. 자체 검수 결과 (제작 가이드 §6 정적 점검)

- [x] 런타임 PNG 10종 전부 투명 배경 — `frames-manifest.json.ok = true`, errors/warnings 없음
- [x] **`edge_pixels` 전 상태 0** (프레임이 셀 경계에 잘리지 않음)
- [x] `chroma_adjacent_pixels` 최대 5 (walk 5, land 4, 나머지 0~1 — 기존 출고 walk가 3이었으므로 동급). 시안 잔여 색 없음, 핑크·다크로즈 보존
- [x] 열×행 × 논리 프레임 수 일치 (아틀라스 리포트 `states 10 / cells 44`)
- [x] 논리 프레임마다 `foot_padding` 존재, 길이 == frames
- [x] `horizontal_offsets` 길이 == frames (10상태 전부)
- [x] 발바닥(블롭 밑면) **40프레임 전부 동일 기준선 16.0** — 프레임 간 상하 튐 0
- [x] 몸통 중심 좌우 흔들림 ±4px 이내
- [x] 밉맵 생성 + 선형 필터 (Godot 임포트로 검증)
- [x] 최대 폭 156px < 셀 192px — 안전 여백 확보
- [ ] **실제 화면 QA 미실시** — 런타임 등록 후 `qa-verifier` 담당

### 상태별 모션 판정 (제작자 1차 검수)

| 상태 | 판정 | 근거 |
|---|---|---|
| Idle | 통과 | 미세 호흡 + 3프레임 깜빡임, 몸통 고정 |
| Walk | 통과(**재생성**) | 1차는 v1의 "다리 없는 홉" 원본 재사용 → 스펙 위반으로 폐기. 새 시트는 밑면 발이 교대로 접지하는 8프레임 2보 사이클, 몸통 상하 보브 + 미세 리드 |
| Sleep | 통과 | 납작 누움, 눈 감김, 상단만 호흡 |
| Eat | 통과(**재생성**) | 1차본은 2프레임에만 음식 소품이 그려져 깜빡임 → 소품 금지 제약 추가해 재생성. 현재본은 입 모양·볼 움직임만으로 씹기 표현 |
| Sick | 통과 | 처짐·탁한 느낌·찡그린 눈 |
| Sulk | 통과 | 아래로 내린 눈·삐진 입 — Sick과 표정이 명확히 구분됨 |
| Happy | 통과 | 감은 호선 눈·활짝 웃음·쾌활한 스쿼시 |
| Dragged | 통과 | 매달려 늘어짐·좌우 흔들림, **손 안 그려짐** |
| Fall | 통과 | 세로로 길게 늘어남, 어느 프레임도 바닥에 닿지 않음 |
| Land | 통과 | 납작 스쿼시 → 원형 복귀, 비반복 |

**보류 상태 없음.** 1차 반려 1건(Eat)은 재생성으로 해소했고 반려본은
`raw/eat.rejected-food-prop.png`로 보존했다.

## 6. 미제작 항목 (qa-verifier 기대값에서 제외할 것)

- **FileHover / FileConsume / Poop / Pet / Play 5종 미제작** (이번 스코프는 10상태).
  비숑 기준 14상태 중 이 5개가 빠진다.
- **`evolved` / `evolved2` 티어 미제작** — base 티어 전용. Sleep 오버라이드가 tier 2단 구조라
  mochi는 `base` 키만 채울 수 있다. 나머지 티어는 정지 포즈로 폴백되어야 한다.
- 포즈 시스템 정지 PNG 8종(`assets/sprites/chars/mochi/*.png`)은 **그대로 남겨 두었다** — 폴백용.

## 7. 제작 기록 (보존)

`assets/generated/sprites/mochi-v2/` — 삭제 금지.

| 경로 | 내용 |
|---|---|
| `sprite-request.json` | 수치 SSoT. cell rect 192×208, safe_margin 18/16, 시안 키, fit lanczos/alpha-centroid/bottom |
| `base-source.png` | lock된 base = `chars/mochi/idle.png` (mochi-v1과 동일 base 유지) |
| `prompts/*.txt` | 10상태 row 프롬프트 |
| `references/layout-guides/*.png` | 10상태 레이아웃 가이드 |
| `raw/*.png` | 생성된 row 원본 10장 (+ `eat.rejected-food-prop.png` 반려본) |
| `frames/<state>/frame-N.png` | 결정론 추출 결과 44프레임 (각 192×208 투명) |
| `frames/frames-manifest.json` | `ok: true`, errors/warnings 없음 |
| `curated/<state>-frame-N.png` | 큐레이션 반영 내보내기 44장 — **런타임 시트의 실제 소스** |
| `sprite-sheet-alpha.png` + `manifest.json` | 전체 아틀라스와 `frame_layout` (10 rows / 44 cells) |
| `state-sheets/*.png` | 상태별 시트 10장 (런타임에 설치한 것과 동일 + walk 대안본) |
| `qa/*.gif`, `qa/*-contact.png` | 상태별 모션 프리뷰 21개 |

### 상태별 시트를 만든 방법 (계약상 근거)

이 프로젝트 런타임은 **상태당 PNG 1장**을 읽는데(`pet.gd`), sprite-gen의 `compose_sprite_atlas.py`는
런 전체를 **하나의 다중 행 아틀라스**로 낸다. 그래서:

1. `export_curated_pngs.py`로 `curated/`를 만든다 (Output Contract: "Install from `curated/`,
   never from `frames/`" — 큐레이션 편집이 반영된 유일한 소스).
2. `curated/`의 **최종 셀들을 격자로 붙이기만** 해서 상태별 시트를 만든다. 리샘플·색·알파 처리
   일절 없는 **1:1 무손실 paste**이며, 격자 모양은 비숑 시트가 이미 쓰는 값(4프레임→4×1,
   8프레임→4×2)을 따랐다.

즉 결정론 파이프라인(크로마 제거 → 컴포넌트 분리 → fit → 셀 배치)은 전부 sprite-gen이 수행했고,
마지막 재그룹만 런타임 계약에 맞췄다. 다운스케일 쇼트컷이 아니다.

## 8. 파이프라인 실행 환경 메모 (다음 작업자 필수)

이 호스트(Windows)에서 sprite-gen을 돌리려면 아래를 알아야 한다.

**`codex_provider.py`에 적용한 수정 4건** (`~/.claude/skills/sprite-gen/sprite_gen/gen/`):

1. 맨 `"codex"` 스폰 → `shutil.which("codex")`. Windows codex는 `codex.cmd` 셸 심이라
   `CreateProcess`가 못 찾는다(`WinError 2`). 같은 파일 가용성 체크는 이미 `shutil.which`를 써서 내부 불일치였다.
2. stdin UTF-8 고정. provider 프롬프트 템플릿이 한글인데 로케일(cp949)로 인코딩돼 codex가
   `input is not valid UTF-8`로 거부했다.
3. `CODEX_HOME` 존중. 이 환경은 `CODEX_HOME`이 Orca 런타임 홈으로 재지정돼 있는데 rollout jsonl과
   `--add-dir generated_images`가 `~/.codex`로 하드코딩돼 있었다.
4. **파이프 → 파일 리다이렉트 + `ignore_cleanup_errors=True`.** codex가 띄우는 플러그인 데몬
   (codegraph / lsp-daemon / git-bash-mcp)이 codex보다 오래 살며 상속한 핸들을 붙잡는다.
   파이프를 쓰면 codex가 끝나도 `communicate()`가 영원히 안 돌아오고(성공한 생성이 멈춘 것처럼 보인다),
   임시 prompt.txt 삭제도 `WinError 32`로 실패해 완성된 생성을 날린다.

**`runio.py`(fcntl publish guard)는 손대지 않았다.** 추출·compose·preview·curated export는
**Linux 컨테이너 안에서** 실행했다(WSL은 이 호스트에서 `true`조차 응답하지 않는 wedged 상태).
바인드 마운트의 `flock` 위험 때문에 런 디렉토리를 컨테이너 파일시스템으로 복사해 돌린 뒤 되가져왔다.
결정론 코드 경로가 동일하므로 산출물 계약은 그대로다.

**소요 시간**: row 1장 생성에 **12~15분**. 스킬 권고대로 **4병렬**로 돌렸다(idle/sleep/eat/sick →
sulk/happy/dragged/fall → eat재생성/land). 총 3배치 + 재생성 1건.

**생성이 멈춘 것처럼 보일 때**: `CODEX_HOME/generated_images/<session>/`에 PNG가 이미 있는지 확인.
세션↔상태 매칭은 rollout jsonl에 `sprite-request.json`의 `action` 문구가 그대로 들어가므로
타임스탬프 추측 없이 정확히 짝지을 수 있다.

## 9. 재작업 요청 시

`qa-verifier`가 특정 상태를 반려하면 `mochi-v2`를 보존한 채 해당 상태만 재생성한다
(`prompts/<state>.txt`에 제약을 추가 → 그 한 상태만 `generate_sprite_image.py` → 컨테이너에서 재추출).
반려본은 `raw/<state>.rejected-<이유>.png`로 남긴다 — Eat 1건이 그 예다.
base는 `base-source.png`를 재사용하면 아이덴티티가 유지된다.


---

# 모찌 계열 — 프레임별 크기 정규화 해제 (recompose, 2026-08-10)

> **재생성 0회.** 기존 raw 스트립을 재측정해 **재합성만** 했다. 그림 내용은 그대로이고
> 프레임별 크기 비율만 원본으로 되돌렸다. 대상: 이 계열 12장 (전체 A분류 27장 중).

## 무엇이 문제였나

추출기가 프레임마다 셀 안전영역에 꽉 채우는 탓에 **한 축이 전 프레임 동일한 값으로 고정**돼
있었다 (모찌 = 폭 156px = 셀 192 − 2×18, 햄찌 = 높이 104px = 셀 128 − 2×12).
그래서 스쿼시-스트레치가 사라졌다. 가장 뚜렷한 예가 모찌 Land로, 높이가 58→139px로 눌리는데
폭은 156px에서 1px도 변하지 않았다 — 납작해진 프레임과 서 있는 프레임의 폭이 같은,
물리적으로 불가능한 그림이었다.

## 어떻게 고쳤나

원본 스트립에서 프레임별 실제 bbox를 다시 재고, **행 전체에 단일 배율**을 적용해 되돌렸다
(배율 = 현재 행 중앙값 높이 / 원본 중앙값 높이). 프레임마다 다른 배율을 쓰던 것을
한 배율로 바꾼 것이 핵심이다.

배치는 **각 프레임의 기존 bbox 바닥선과 가로 중심을 그대로 유지**하도록 잡았다. 덕분에:

- **`foot_padding`은 12장 전부 불변** — 발 접지·공중 궤적이 바뀌지 않는다.
- **`horizontal_offsets`는 최대 0.5px만 이동** — 아래 표대로 갱신하면 된다.

## 등록 갱신값 (`horizontal_offsets`만)

| 티어 | 시트 (경로) | 갱신값 |
|---|---|---|
| `base` | `res://assets/sprites/mochi/dragged_4f_alpha_smooth.png` | `[5.0, 0.5, 1.0, 4.0]` |
| `base` | `res://assets/sprites/mochi/happy_4f_alpha_smooth.png` | `[-1.0, -0.5, -1.0, -1.5]` |
| `base` | `res://assets/sprites/mochi/land_4f_alpha_smooth.png` | `[0.0, -1.0, -2.0, -1.5]` |
| `base` | `res://assets/sprites/mochi/poop_4f_alpha_smooth.png` | `[0.5, 0.0, -1.0, -1.0]` |
| `base` | `res://assets/sprites/mochi/sick_4f_alpha_smooth.png` | `[-0.5, -4.0, 0.0, -4.0]` |
| `base` | `res://assets/sprites/mochi/sleep_4f_alpha_smooth.png` | `[-0.5, -2.0, -1.5, -0.5]` |
| `evolved` | `res://assets/sprites/mochi_evolved/idle_4f_alpha_smooth.png` | `[0.0, -1.0, -0.5, -1.5]` |
| `evolved` | `res://assets/sprites/mochi_evolved/sick_4f_alpha_smooth.png` | `[0.0, 4.0, -0.5, -1.5]` |
| `evolved` | `res://assets/sprites/mochi_evolved/sleep_4f_alpha_smooth.png` | `[-0.5, 0.0, 1.5, -0.5]` |
| `evolved2` | `res://assets/sprites/mochi_evolved2/poop_4f_alpha_smooth.png` | `[0.0, 0.0, 0.5, -0.5]` |
| `evolved2` | `res://assets/sprites/mochi_evolved2/sick_4f_alpha_smooth.png` | `[0.0, 1.0, 1.5, 2.0]` |

변경 없음: `sulk_4f_alpha_smooth.png`

## 전체 크기가 줄어든 시트

아래 시트는 **가장 극단적인 프레임이 셀에 안 들어가서** 행 전체를 조금 축소했다.
비율을 지키려면 피할 수 없다 — 한 프레임만 따로 눌러 맞추면 지금 고치려는 왜곡을
다시 넣는 셈이라 그렇게 하지 않았다.

| 시트 | 이전 대비 크기 |
|---|---:|
| `dragged_4f_alpha_smooth.png` | **96.6%** |
| `land_4f_alpha_smooth.png` | **91.3%** |

**화면 QA에서 이 시트들만 크기 튐을 확인해야 한다.**
특히 Land는 91.3%로, 착지 마지막(서 있는) 프레임이 Idle보다 작아 보이면
Land→Idle 전환에서 팝이 생길 수 있다.

## 자체 검수

- [x] 셀 경계 접촉 0 (전 프레임)
- [x] 부유 파편 0 (연결성분 스캔)
- [x] `foot_padding` 불변
- [x] Godot 재임포트 + 회귀 테스트 3595 passed / 0 failed
- [ ] 실제 화면 QA — qa-verifier 담당

제작 기록: 각 런 디렉토리의 `recomposed/` 하위에 동일 파일을 보존했다.
원본은 git에 그대로 있으므로 해당 경로를 git checkout 하면 언제든 되돌릴 수 있다.


### 전환 팝 재측정 (2026-08-10 추가) — 실제 전이 경로 기준

크기가 줄어든 시트가 상태 전환에서 튀는지 다시 쟀다. 처음엔 "최종 프레임 대 Idle"로 봤는데,
**Fall은 Idle로 가지 않는다 — Fall -> Land -> Idle 순서다.** Land의 첫 프레임은 착지 스쿼시라
원래 크게 낮은 게 맞으므로, Fall을 Idle과 비교하면 정상 동작이 결함으로 보인다.

등록된 전이 경로대로 다시 재면:

| 전이 | 이전 프레임 -> 다음 프레임 | 변화 |
|---|---|---:|
| mochi Land -> Idle | 120 -> 129 | **+7%** |
| haemjji_evolved Land -> Idle | 104 -> 105 | **+1%** |
| haemjji_evolved2 Land -> Idle | 104 -> 104 | **0%** |
| mochi Fall -> Land | 123 -> 70 | -43% (의도된 스쿼시) |
| haemjji_evolved Fall -> Land | 85 -> 77 | -9% (의도된 스쿼시) |
| haemjji_evolved2 Fall -> Land | 95 -> 61 | -36% (의도된 스쿼시) |

**Land -> Idle 세 경우 모두 0~7%로, 전환 팝은 없다.** 축소된 5장 중 실제로 전환에서 문제를
일으키는 것은 현재 없는 것으로 보인다. Fall -> Land의 큰 감소는 착지 스쿼시 그 자체다.

남는 것은 전환 팝이 아니라 **연출 중 크기**다 — 예를 들어 mochi Land는 애니메이션 도중
이전보다 8.7% 작게 보인다. 이건 원본 비율을 지킨 결과이고 튐이 아니라서, 화면에서
"작아 보인다"는 인상이 있는지만 확인하면 된다.


## 2026-08-10 후속 — `mochi_evolved/land` 전환 팝 수정 (Task #34)

`qa-verifier`가 Land 6조합을 전수로 재서 **`mochi_evolved`만 Land -> Idle 전환에서 약 10% 크기 팝**이
있는 것을 찾아냈다. 그 1장만 재합성했다. **이미지 재생성 없음.**

### 선재 결함이었다 (이번 재합성이 만든 게 아니다)

git HEAD와 대조했다. `mochi_evolved/land`는 A분류가 아니라 손대지 않았고, Idle도 첫 프레임
높이가 158로 그대로였다 — **팝 크기가 변경 전후 모두 -10.2%로 동일**했다. 1단계 작업이 만든
회귀가 아니라, 원래 있던 것이 이번 검증으로 드러난 것이다.

### 원인은 포즈가 아니라 행별 배율 기준

처음엔 "evolved의 마지막 프레임만 리바운드 오버슛 포즈"로 보였는데, 원본을 재보니
**3티어 전부 Land 마지막 프레임이 그 행에서 가장 큰 포즈**다:

```
raw Land 높이:  base [162,207,264,277]  evolved [176,255,333,372]  evolved2 [235,332,402,426]
```

`evolved2`가 0%인 것은 포즈 설계가 달라서가 아니라 **Idle raw(432)와 Land 끝(426)이 우연히
거의 같아서**다. 진짜 원인은 각 행을 **자기 행 중앙값**에 맞춰 정규화하기 때문에, Land 끝과
Idle 첫 프레임의 관계가 행마다 제각각이 된다는 것이다.

### 조치 — 배율 기준만 바꿔 재합성

Land 행의 기준을 "행 중앙값" 대신 **"마지막 프레임 = Idle 첫 프레임"**으로 바꿨다(배율 0.4247).

| 항목 | 이전 | 이후 |
|---|---|---|
| 프레임 높이 | [63, 102, 153, 176] | [75, 108, 141, **158**] |
| 프레임 폭 | [156, 156, 156, 155] | [183, 166, 144, 139] |
| Land 끝 -> Idle f0 | **-10.2%** | **0.0%** |
| `horizontal_offsets` | [1.0, 0.0, 0.0, 0.5] | **[0.5, 0.0, 0.0, 0.5]** (f0만 0.5px) |
| `foot_padding` | 불변 | 불변 |

**덤으로 폭 고정도 풀렸다.** 이 시트는 폭이 [156,156,156,155]로 마지막만 1px 달라
자동 분류에서 "고정 아님"(C분류)으로 빠져 있었는데, 사실상 폭 고정 상태였다.
재합성으로 착지 스쿼시가 같이 살아났다.

> **분류 기준의 허점**: "전 프레임 완전 동일"로 고정을 판정하면 1px 차이로 빠져나간다.
> 다음에 같은 감사를 할 때는 **변화폭 임계값**(예: 2% 미만이면 고정으로 간주)을 써야 한다.

### Land -> Idle 전수 재측정 (6조합)

| 티어 | Land 끝 | Idle f0 | 팝 |
|---|---:|---:|---:|
| mochi base | 120 | 129 | 7.5% |
| **mochi_evolved** | 158 | 158 | **0.0%** (수정됨) |
| mochi_evolved2 | 176 | 176 | 0.0% |
| haemjji base | 104 | 106 | 1.9% |
| haemjji_evolved | 104 | 105 | 1.0% |
| haemjji_evolved2 | 104 | 104 | 0.0% |

**mochi base 7.5%는 고치지 않았다** — 개선하려면 행을 확대해야 하는데 납작한 스쿼시 프레임이
셀(192px)을 넘어간다(202px 필요). `qa-verifier`도 허용 범위로 판정했다.

### 검수

- [x] 셀 경계 접촉 0, 바닥선 보존, `foot_padding` 불변
- [x] 회귀 테스트 3595 passed / 0 failed
- [ ] 화면 재확인 — qa-verifier


---

# 모찌 계열 — Eat / FileConsume 재생성 (2단계, Task #35, 2026-08-10)

> 이 계열 **6장**. 1단계(재합성)와 달리 **이미지를 새로 생성**했다 —
> 원본 그림 자체가 정지 상태여서 재합성으로는 복구가 불가능했기 때문이다.

## 왜 재생성이 필요했나

1단계에서 84장을 분류할 때, 이 시트들은 **원본 스트립부터 실루엣이 평평**했다
(폭 변화 0.5~3.1%). 추출기가 죽인 게 아니라 애초에 같은 그림 4~6장이 그려져 있었다.
`qa-verifier`가 삐약에서 4.2%를 "거의 정지"로 반려한 기준을 적용하면, 이 시트들은
그보다 더 밋밋했다 — Eat과 FileConsume은 **실루엣 변화가 곧 내용**인 상태라 치명적이다.

## 어떻게 고쳤나 — 프롬프트에 프레임 번호와 비율을 못박았다

삐약에서 얻은 교훈을 그대로 적용했다. "부풀려라" 같은 정성적 지시는 두 번 실패했고,
**몇 번 프레임이 가장 넓어야 하는지와 최소 몇 배인지**를 숫자로 지정하니 한 번에 됐다.

- **FileConsume**: "프레임 2가 프레임 1보다 최소 1/5 넓고, 넷 중 단독 최대여야 한다"
- **Eat (모찌)**: "프레임 2가 가장 넓고 낮은 스쿼시, 프레임 4가 가장 높고 좁은 스트레치"
- **Eat (햄찌 evolved)**: "볼주머니가 프레임마다 넓어져 5·6번이 1번보다 최소 1/5 넓다"

생성 후 **재합성 보정을 한 번 더 걸었다** — 추출기가 프레임을 다시 셀에 꽉 채워
모처럼 만든 실루엣 변화를 그대로 없애버리기 때문이다. 이 두 단계는 세트로 가야 한다.

## 결과

| 티어 | 상태 | 원본 폭 변화 (이전 → 이후) | 최종 시트 폭 변화 |
|---|---|---|---:|
| `base` | FileConsume | 0.8% → **24.7%** | **25.2%** |
| `evolved` | FileConsume | 0.8% → **41.1%** | **41.4%** |
| `evolved2` | FileConsume | 0.5% → **27.1%** | **26.9%** |
| `base` | Eat | 1.7% → **32.0%** | **32.4%** |
| `evolved` | Eat | 3.1% → **11.1%** | **10.9%** |
| `evolved2` | Eat | 0.5% → **27.7%** | **27.3%** |

최대 폭 프레임도 전부 의도한 위치에 왔다 (FileConsume·모찌 Eat = f2, 햄찌 evolved Eat = f6).

## 등록 갱신값

`foot_padding`은 **6장 전부 불변**이다. `horizontal_offsets`만 갱신하면 된다.

| 티어 | 시트 (경로) | `horizontal_offsets` |
|---|---|---|
| `base` | `res://assets/sprites/mochi/file_consume_4f_alpha_smooth.png` | `[-1.0, -1.5, -1.0, -1.5]` |
| `evolved` | `res://assets/sprites/mochi_evolved/file_consume_4f_alpha_smooth.png` | `[-0.5, 0.0, -0.5, -0.5]` |
| `evolved2` | `res://assets/sprites/mochi_evolved2/file_consume_4f_alpha_smooth.png` | `[0.0, 0.0, -0.5, 0.0]` |
| `base` | `res://assets/sprites/mochi/eat_4f_alpha_smooth.png` | `[-1.0, 0.0, -0.5, -1.0]` |
| `evolved` | `res://assets/sprites/mochi_evolved/eat_4f_alpha_smooth.png` | `[0.0, -0.5, 0.0, 0.0]` |
| `evolved2` | `res://assets/sprites/mochi_evolved2/eat_4f_alpha_smooth.png` | `[-0.5, -0.5, 0.5, 0.5]` |

## 전체 크기가 줄어든 시트

가장 넓은 프레임이 셀에 안 들어가 행 전체를 조금 축소했다(1단계와 같은 이유).

| 시트 | 이전 대비 |
|---|---:|
| `file_consume_4f_alpha_smooth.png` | **93.5%** |
| `eat_4f_alpha_smooth.png` | **99.2%** |
| `eat_4f_alpha_smooth.png` | **94.4%** |
| `eat_4f_alpha_smooth.png` | **99.4%** |

## 자체 검수

- [x] 추출 `ok: true`, errors 0
- [x] 셀 경계 접촉 0, 부유 파편 0
- [x] `foot_padding` 불변
- [x] 아이덴티티 유지 (안경·넥타이·정장/요리사 모자·왕관 전 프레임)
- [x] 회귀 테스트 3595 passed / 0 failed
- [ ] 실제 화면 QA — qa-verifier

반려본은 각 런의 `raw/rejected/<state>.flat-silhouette.png`로 보존했다.
Before/After 대조표: `docs/02-design/characters/stage2-eat-fileconsume.png`

---

# 모찌 계열 — 공중 진폭 복원 · Idle 호흡 정상화 (3단계, Task #37/#4, 2026-08-10)

> 이 계열 **6장**. 공중 상태(Play/Dragged/Fall)의 "떠오른 높이"가 시트에서 사라져 있던 것과,
> `evolved` Idle의 과대 스쿼시를 잡았다. 재합성 0장 / **재생성 6행**(이 중 2행은 1차 반려 후 v2).

## 무엇이 문제였나 — 추출기의 바닥 정렬이 공중 궤적을 없앤다

추출 `fit`이 `align_y: bottom`이라 **모든 프레임의 밑면이 셀 바닥선에 재고정된다.** 접지 상태에는
정확한 동작이지만(발바닥 기준선 유지) 공중 상태에서는 "지면에서 얼마나 떠 있는가"가 통째로
지워진다. `pet.gd:107-112`의 `airborne` 계약은 **프레임 간 `foot_padding` 차이**를 화면 상승분으로
읽으므로, 차이가 0이면 매달림·낙하·점프가 화면에서 전혀 안 보인다.

`raw` 스트립을 재측정해 프레임별 상승분을 복원했다. 다만 이번 6행은 **raw 자체에 궤적이 없어서**
(표시배율 적용 후 0.4~2.6px) 재합성으로는 복구가 불가능했다 — 그래서 재생성했다.

## 재생성 6행

| 티어 | 상태 | 진폭 | `foot_padding` | `horizontal_offsets` |
|---|---|---:|---|---|
| `base` | Play (`happy_4f`) | 17px | `[16.0, 33.0, 21.0, 16.0]` | `[-1.0, -1.5, -1.5, -1.0]` |
| `evolved` | Dragged | 38px | `[42.0, 42.0, 4.0, 30.0]` | `[-0.5, 4.0, 0.5, -2.5]` |
| `evolved2` | Dragged | 38px | `[40.0, 32.0, 2.0, 25.0]` | `[1.5, -6.0, 3.0, 4.0]` |
| `evolved` | Fall | 17px | `[28.0, 20.0, 13.0, 11.0]` | `[0.0, -0.5, -0.5, 0.0]` |
| `evolved2` | Fall | 17px | `[33.0, 27.0, 20.0, 16.0]` | `[0.0, 3.0, 2.5, 2.5]` |
| `evolved` | Idle | — (접지) | `[16.0, 16.0, 16.0, 16.0]` 불변 | `[-1.0, -1.0, -1.0, -0.5]` |

`ground_padding`은 **명시하지 않는다** — 생략 시 `foot_padding` 최솟값이 쓰이고, 위 값들이 정확히
그 전제로 계산돼 있다.

> ⚠️ **접지값 최솟값이 4나 2로 내려간 시트가 있다(evolved/evolved2 Dragged, Fall).** 결함이 아니라
> 의도다. 공중 상태는 행 전체를 셀 안에서 아래로 내려 머리 위 여유를 벌 수 있고, 균일 이동분은
> `ground_padding`이 상쇄하므로 **화면 위치는 그대로이고 프레임 간 차이만 상승분으로 보인다.**
> "접지값이 왜 4냐"로 반려하지 말 것.

## 우선순위 규칙 — 표시 크기 > 진폭

셀에 다 안 들어갈 때 무엇을 먼저 포기하는가가 이 작업의 핵심 결정이다. **크기를 깎는 것이 가장
비싼 수단이다** — 이 문서가 반복해서 기록한 반려 원인이 "프레임 간·상태 간 크기 팝"이기 때문이다.
그래서 ① 접지 기준값을 낮춰 여유 확보 → ② 진폭 감쇠 → ③ 그래도 안 되면 전역 축소 순으로 간다.

실측 사례: `evolved/Dragged` v1은 raw의 프레임 간 몸 길이 편차가 31%(545~714px)라 표시 크기를
유지하면 가장 긴 프레임이 셀 높이 208 중 204를 먹어 **진폭이 0px로 붕괴**했다. 5% 축소를 허용하면
38px이 들어갔지만, 위 우선순위에 따라 축소 대신 **재생성**을 택했다. v2 프롬프트에 "가장 긴 프레임이
가장 짧은 프레임보다 1/7 이상 길면 안 된다 / 머리 위 여백도 남겨라"를 넣어 편차를 7.4%로 잡았고,
결과 **크기 100% 유지 + 38px 진폭**을 둘 다 얻었다. 같은 로직에서 `evolved2`가 처음부터 통과한
이유는 그쪽 raw 편차가 20%였기 때문이다 — 즉 로직 문제가 아니라 원본 자세의 길이 편차 문제다.

## 진폭 상한을 어떻게 정했나

QA는 **같은 상태를 티어끼리** 비교하므로 상태 단위 일관성을 기준으로 삼았다: 각 상태에서 이미
출고돼 QA를 통과한 최대 진폭(모찌 Dragged 38px, Fall 13px)을 상한으로 걸고, 셀 높이의 8%를
하한으로 뒀다. 자연 진폭(44~141px)은 전부 상한보다 훨씬 컸으므로 **깎기만 했고 키운 곳은 없다.**

## 종료칸은 산술로 단정하지 않는다

`Play`는 `loop: true`, fps 8, `play_state.gd`의 `_timer = 2.6`이라 산술상 종료칸이 **f0**이다
(ceil(2.6×8)=21, (21-1)%4=0). f3이 아니다. v1은 f0을 "이륙 전 웅크림"으로 뽑아 Idle f0과
18.6% 어긋나 반려됐다.

**대응은 인덱스를 맞히는 게 아니라 인덱스에 의존하지 않는 것이다** — v2는 f1과 f4를 **둘 다**
중립 휴식 실루엣으로 만들고 극단 자세를 가운데 두 프레임에만 뒀다. 어느 쪽이 종료칸이 되든 안전하다.
결과 f0 팝 6.4% / f3 팝 6.2%(이전 8.5~9.3%). 이 설계를 Eat에도 적용했다.

`base/Play`는 배율 기준을 행 중앙값에서 **Idle 첫 프레임**으로 옮겼다(`fix41`이 file_hover에 쓴
방식과 동일). 그 결과 시트 표시 배율이 3% 커졌다 — `sheet_scale`은 종족-티어 단위 값이므로
**건드리지 말 것**, 시트 자체에 반영돼 있다.

## `evolved` Idle — 과대 스쿼시 (Task #4)

f2가 높이 -20%로 눌려 있어 fps 4.0 루프마다 250ms씩 압박 펄스로 보였고, FileHover 진입 체인 팝
26%의 실제 원인이었다. **원인은 재합성이 아니라 raw다** — raw f2가 행 중앙값 높이의 0.805배였고
이전 세대 raw(v1)도 0.857배로 같은 경향이었다. 재합성 클램프로 고치려면 그림을 세로로 1.2배
늘려야 해서 안경·눈이 왜곡된다 → 재생성했다.

| 항목 | 이전 | 이후 |
|---|---|---|
| 프레임 높이 | `[158, 165, 127, 157]` | `[158, 161, 156, 158]` |
| 프레임 폭 | `[156, 154, 165, 155]` | `[156, 156, 156, 155]` |
| 높이 진폭 | 29.9% | **3.2%** |
| Idle f0 | 156×158 | **156×158 (정확히 보존)** |

**Idle은 배율 기준을 행 중앙값이 아니라 f0으로 잡는다.** `BODY_SCALE`·`sheet_scale`·`expected_torso`와
다른 상태들의 전환 비교 기준이 전부 Idle f0이고, 기존 행 중앙값은 스쿼시 프레임에 오염돼 있었다.
f0을 고정하면 **다른 상태 등록값을 하나도 안 건드려도 된다.**

> **Idle은 활기를 키우는 대상이 아니라 줄이는 대상이다.** FileHover·Eat의 "활기 확보" 기준과
> 혼동하지 말 것. 프롬프트도 반대로 써야 한다 — "네 실루엣이 거의 같아 보이면 그게 맞는 것,
> 눌리거나 납작한 자세를 어느 프레임에도 그리지 말 것". 이 문구로 raw 편차 30.0% → 3.0%.

## 셀 폭 제약 — 활기를 폭으로 요구하면 전환 팝과 충돌한다 (Task #43에서 실측)

**192폭 셀에서 중립 프레임이 156px이면 어떤 프레임도 중립보다 20% 이상 넓어질 수 없다**
(한계 188px = 192 − 안전여백 2×2). Eat 1차는 "씹기 peak를 최소 1/5 더 넓게"를 요구했고, 그
결과 peak가 188px에 붙어 **종료칸을 Idle에 맞추기 위한 확대(7.9%)가 막혔다** — 팝이 10.1%에서
더 안 내려갔다. 활기는 **높이 쪽으로** 요구해야 한다("옆으로 퍼뜨리지 말고 아래로 눌러라").

## 자체 검수

- [x] 추출 `ok: true`, errors 0, warnings 0
- [x] 셀 경계 접촉 0 (전 프레임), 부유 파편 0 (연결성분 스캔)
- [x] 크로마 잔여 0
- [x] 표시 크기 유지 99~103% (`base/Play`만 의도적으로 +3%)
- [x] `mipmaps/generate=true`
- [x] 아이덴티티 유지 (안경·넥타이·정장·배지 전 프레임)
- [ ] 실제 화면 QA — qa-verifier
- [ ] FileHover 진입 체인 팝 26% 해소 확인 → 해소 시 `REACTION_CHAIN_POP_KNOWN`에서
      `mochi/evolved/진입` 제거 (테스트가 실패로 알려준다)

제작 기록: `mochi-air-v2`, `mochi-evolved-air-v2`, `mochi-evolved2-air-v1`, `mochi-evolved-idle-v1`.
반려된 1차본은 `mochi-air-v1`, `mochi-evolved-air-v1`로 보존.

## 환경 블로커 (다음 작업자 필독)

`sprite-gen`의 `extract_sprite_row_frames.py`는 **Windows에서 돌지 않는다.**
`runio.publish_guard`가 `fcntl` 부재 시 no-op으로 degrade하지 않고 요란하게 실패하도록 설계돼
있고(의도된 격리 계약) Windows에는 `fcntl`이 없다. 가드를 끄지 말고 `msvcrt.locking` 기반
`fcntl.flock` 셰임을 심어 **공식 추출 경로를 그대로** 태울 것 — 픽셀 변환 코드를 건드리면 안 된다.
