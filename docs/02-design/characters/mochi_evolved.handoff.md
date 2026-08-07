# 모찌 evolved (프로찌 / `mochi_evolved`) 스프라이트 인수인계 — 10상태

> 작성: sprite-artist / character-pipeline, 2026-08-07
> 스펙: `docs/02-design/characters/mochi.spec.md` (§업그레이드 순서 2단계 = evolved)
> 제작 기준: `docs/02-design/pet-sprite-production-guide.md` §8 템플릿
> 제작 기록: `assets/generated/sprites/mochi-evolved-v2/` (보존), 반려 기록 `mochi-evolved-v1/`
> **스코프**: `evolved` 티어 10상태만. `base`는 완료(별도 `mochi.handoff.md`), `evolved2`는 미착수.

## 1. 제작 가이드 §8 인수인계 템플릿

| 항목 | 값 |
|---|---|
| 캐릭터 ID | `mochi_evolved` (프로찌, evolved 티어) |
| 기준 포즈 / 아이덴티티 키 | base 모찌보다 **더 크고 위로 솟은** 파스텔 핑크 젤리 블롭. **필수 식별 요소 2개: 둥근 금/갈색 테 안경, 스틸블루 넥타이.** 그 외 다크로즈 외곽선, 광택 하이라이트, 큰 반짝이는 다크레드 눈, 작은 입, 블러시 볼, 밑면의 작은 발 2개 |
| 기본 걷기 시트 방향 | 정면 대칭 — `flip_h` 무의미 |
| 원본 배경 방식 | chroma + **그린 `#00FF00`** ⚠️ base 티어(시안)와 **다르다** — 이유는 §4 |
| 표시 목표 몸통 높이 | evolved 정지 포즈가 화면에 그려지는 높이 `232.76` (= 128캔버스 bbox 119 × 현재 `BODY_SCALE` 1.956) |
| 발바닥 기준선 | 셀 하단에서 **16px** 위 — **10상태 44프레임 전부 `foot_padding = 16.0`**. base 티어와 동일 기준선 |
| Walk에서만 허용하는 수평 이동 범위 | 신규 10상태 모두 `horizontal_offsets` −3.0 ~ +6.0 범위의 미세 보정만 |
| Walk 외 동작의 몸통 고정 기준 | 셀 중심 ±6px 이내 (sulk가 최대 +6.0 — 몸을 살짝 돌린 자세) |
| 최대 폭 자세와 좌우 안전 여백 | 최대 폭 156px (192 셀 → 좌우 18px 확보, `safe_margin_x` 18 충족) |
| Idle 미세 동작 | 미세 호흡 스쿼시 + **3번째 프레임 눈 깜빡임 1회** (안경은 감은 눈 위에 그대로 유지) |
| 파일 호버 / 파일 드롭 | **미제작** (스코프 외) |
| 상태별 시트 목록 | 아래 §2 |
| 프레임별 foot_padding / horizontal_offsets | 아래 §2 (실측) |
| 렌더 필터 및 밉맵 확인 | 10장 전부 `.import`에 `mipmaps/generate=true` + **Godot 4.4.1 헤드리스 `--import` 검증 완료** (uid·ctex 자동 배정, params 보존) |
| baby·adult 수동 QA 결과 | **미실시** — 런타임 등록 전에는 화면에 뜨지 않는다. `qa-verifier` 몫 |

## 2. 런타임 등록 실측값

전 상태 공통: **셀 192×208**, `foot_padding` 전 프레임 **16.0**.
경로 접두사: `res://assets/sprites/mochi_evolved/`
`visible_extent`는 그 상태 프레임 중 최대 몸통 높이 (포즈 오버라이드 경로는 이 키를 읽지 않는다 — §3).

| 상태 | 파일 | 그리드 | frames / fps / loop | horizontal_offsets | 몸통 높이 | 특수 키 |
|---|---|---:|---|---|---:|---|
| Idle | `idle_4f_alpha_smooth.png` | 4×1 | 4 / 4.0 / true | `[0.0, -1.0, -1.0, -1.0]` | 120~168 | — |
| Walk | `walk_8f_alpha_smooth.png` | 4×2 | 8 / 10.0 / true | `[0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 1.0]` | 162~169 | — |
| Sleep | `sleep_4f_alpha_smooth.png` | 4×1 | 4 / 5.0 / true | `[0.0, 0.0, 1.0, 0.0]` | 98~136 | — |
| Eat | `eat_4f_alpha_smooth.png` | 4×1 | 4 / 6.0 / true | `[0.0, 0.0, 0.0, 0.0]` | 160~161 | — |
| Sick | `sick_4f_alpha_smooth.png` | 4×1 | 4 / 6.0 / true | `[0.0, 4.0, -1.0, -1.0]` | 88~171 | **`runtime_sick_mark: true`** |
| Sulk | `sulk_4f_alpha_smooth.png` | 4×1 | 4 / 6.0 / true | `[0.0, 6.0, 4.0, 4.0]` | 148~157 | — |
| Play | `play_4f_alpha_smooth.png` | 4×1 | 4 / 8.0 / true | `[0.0, 2.0, 0.0, -3.0]` | 107~176 | **`airborne: true`** |
| Dragged | `dragged_4f_alpha_smooth.png` | 4×1 | 4 / 10.0 / true | `[0.5, -1.5, -1.0, 1.5]` | 176~176 | **`airborne: true`** |
| Fall | `fall_4f_alpha_smooth.png` | 4×1 | 4 / 12.0 / true | `[0.5, -0.5, 0.0, -1.0]` | 148~176 | **`airborne: true`** |
| Land | `land_4f_alpha_smooth.png` | 4×1 | 4 / 10.0 / **false** | `[1.0, 0.0, 0.0, 0.5]` | 63~176 | — |

`foot_padding`: 4프레임 상태는 `[16.0]×4`, Walk는 `[16.0]×8` (44프레임 전부 16.0).
`ground_padding`은 생략해도 된다 — airborne 3상태의 `foot_padding` 최솟값이 16.0이라 자동 기본값과 같다.

### 등록 형태 (기존 `ANIMATED_POSE_OVERRIDES["mochi"]`에 evolved 티어 추가)

`sheet_scale`이 티어별로 달라지고 시트가 티어마다 따로 있으므로, `pet.gd` 헤더 주석이 규정한
**tier 한 단 추가** 구조가 필요하다 (ppiyak이 이미 쓰는 형태):

```gdscript
"sheet_scale": {"base": 0.605, "evolved": 0.753},
"tiers": ["base", "evolved"],
"states": {
    "Idle": {
        "base":    { ... 기존 base 설정 ... },
        "evolved": {"path": "res://assets/sprites/mochi_evolved/idle_4f_alpha_smooth.png", "columns": 4, "rows": 1, "frames": 4, "fps": 4.0, "loop": true, "foot_padding": [16.0, 16.0, 16.0, 16.0], "horizontal_offsets": [0.0, -1.0, -1.0, -1.0]},
    },
    ...
}
```

현재 등록은 `"sheet_scale": 0.605`(스칼라) + `"tiers": ["base"]` + 상태별 tier 없는 flat 설정이다.
**evolved 시트가 생겼으니 `tiers`에 `"evolved"`를 추가하고 `sheet_scale`을 tier 맵으로 바꿔야 한다** —
안 그러면 진화 후에도 base 시트가 재생되거나(경로가 base 고정) 몸통 크기가 틀어진다(0.605 적용).
주석의 "진화 단계 시트 미제작" 문구도 이제 사실과 다르다.

### `sheet_scale` (evolved) = **0.753** — `BODY_SCALE`은 건드리지 않는다

```gdscript
"sheet_scale": {"base": 0.605, "evolved": 0.753},
```

`BODY_SCALE["mochi"]["evolved"] = 1.956`은 **그대로 둔다.** 그 값은 정지 포즈 캔버스
(`STATIC_POSE_SIZE = 128`) 기준으로 정규화돼 있고, 미등록 상태(Poop/Pet 등)가 폴백하는
정지 포즈 8종이 같은 값을 쓰기 때문이다. 시트 셀이 208px이라 생기는 차이는 `sheet_scale`이 흡수한다.

산출 (base와 동일한 방식):

```text
evolved 정지 아트 몸통 119px ÷ 시트 idle 휴지프레임 몸통 158px = 0.7532 → 0.753
검산: 1.956 × 0.753 = 1.4729 ;  158 × 1.4729 = 232.7 ≈ 119 × 1.956 = 232.8 ✅
```

- 기준 프레임: idle 프레임0(휴지 자세), 알파 bbox `(18, 34, 174, 192)` → 높이 **158**
- 보정 없이 그대로 쓰면 `158 × 1.956 = 309.0` = **정상의 133%** 과대
- 이 값은 `pet.gd`의 기존 주석(§ANIMATED_POSE_OVERRIDES 헤더)에 이미 실측 근거로 기재된 값과 일치한다

`base`는 `0.605`(별도 handoff), `evolved2`는 아트 미제작이라 `sheet_scale` 미등록(=1.0) 유지.

### `airborne` 판단 — Play / Dragged / Fall = **true**, 나머지 7종 = false

`pet.gd` 계약상 `airborne`은 "프레임 간 `foot_padding` 차이가 바운딩박스 모양 차이가 아니라
지면에서 떠오른 높이를 뜻한다"는 선언이다. 시트 그림을 실제로 보고 판정했다:

| 상태 | airborne | 근거 (시트 육안 + 실측) |
|---|---|---|
| Play | **true** | 바운스 동작 — 2·4프레임에서 몸이 들리고 밑면 발이 지면에서 떨어져 매달린다 |
| Dragged | **true** | 4프레임 전부 공중에 매달려 늘어난 자세, 접지 없음 |
| Fall | **true** | 4프레임 전부 낙하 중, 어느 프레임도 바닥에 닿지 않는다 |
| Idle / Walk / Sleep / Eat / Sick / Sulk | false | 상시 접지 (Walk는 발이 교대로 접지하지만 항상 한쪽이 닿아 있다) |
| Land | false | 1프레임이 지면 충격 스쿼시 — 전 프레임 접지 |

base 티어와 동일한 3종이다.

⚠️ **다만 이 시트에서 airborne은 "의미 선언"일 뿐 화면에 상승분이 나오지 않는다.**
추출이 `fit.align_y: bottom`으로 모든 프레임을 셀 하단에 정렬하기 때문에 `foot_padding`이
**44프레임 전부 16.0 고정**이고, 프레임 간 padding 차이가 0이라 상승분으로 환산될 값이 없다.
base 티어가 이미 같은 상태이고 `pet.gd` 주석도 그렇게 기록돼 있다.

→ 지금 `airborne: true`를 달아도 **화면 결과는 픽셀 단위로 기존과 동일**하다(회귀 없음).
공중 진폭을 실제로 보이게 하려면 그 3상태를 `align_y: bottom` 없이(또는 `center`로) 다시 추출해
프레임별 `foot_padding`이 실제 부양 높이를 담게 만들어야 한다 — **이번 스코프 밖**이며,
그날을 위해 플래그는 미리 달아 두는 것이 맞다(그래야 그 진폭이 즉시 화면에 나온다).

### `runtime_sick_mark` (Sick) = **true** — 시트에 어지럼 표시가 없다

Sick 시트 4프레임을 확대해 확인한 결과:

- **소용돌이 눈(@_@) 없음** — 눈은 안경 뒤에서 아래로 처진 반쯤 감긴 실눈이다
- **부유 기호 없음** — 별·나선·땀방울 등 분리된 기호가 그려지지 않았다 (프롬프트가 분리 이펙트를 금지하므로 의도된 결과)
- 아픔은 **몸이 점점 주저앉아 납작해지는 실루엣 변화**로만 표현된다 (1프레임 171px → 4프레임 88px)

따라서 정지 포즈 `sick.png`가 갖고 있던 어지럼 표시 역할을 **런타임 `@_@` 라벨이 대신해야 한다**
→ `"runtime_sick_mark": true`. 이게 없으면 Sulk(삐짐)와 화면상 구분이 어렵다 — 둘 다 "표정이
안 좋은 핑크 블롭"이고, 구분 요소가 몸통 납작함 정도뿐이다.

나머지 9상태는 `runtime_sick_mark`를 **달지 않는다**(기본값 false).

## 3. 등록 시 주의 (base 티어와 동일)

- 포즈 오버라이드 경로는 **`visible_extent`를 읽지 않는다.** 크기는
  `STAGE_SCALE × Characters.get_body_scale(species, tier) × sheet_scale`로 잡는다
  (`pet.gd:653`). 그래서 위 표에는 `visible_extent`를 빼고 `sheet_scale`을 따로 냈다.
- **티어 크기 보정은 `sheet_scale`이 담당한다** — `BODY_SCALE`은 정지 포즈용이라 손대지 않는다.
  `_body_tier == "evolved"`일 때 `1.956 × 0.753 = 1.473`이 실효 배율이 되어야 한다.
- 시트 경로가 티어마다 다르므로(`assets/sprites/mochi/` vs `assets/sprites/mochi_evolved/`)
  상태 밑에 tier 한 단이 필요하다 — 위 §2 등록 형태 참고.
- Play 상태 이름: 이번 티어는 파일명을 `play_4f_...`로 제작했다(요청 상태 목록 그대로).
  base 티어는 `happy_4f_...` 파일을 `"Play"` 키에 등록해 두었다. **런타임 키는 양쪽 다 `Play`**이고
  파일명만 티어별로 다르다 — 키를 `Happy`로 바꾸지 말 것(상태머신이 `Play`를 쓴다).

## 4. ⚠️ 크로마키를 시안 → 그린으로 바꿨다 (재생성 1회)

**base 티어는 시안 `#00FFFF`인데 evolved는 그린 `#00FF00`이다.** 이유:

프로찌에는 **스틸블루 넥타이**가 있고, 파랑은 시안과 가깝다. 시안 키로 먼저 10상태를 전부
생성했더니(`mochi-evolved-v1`) 추출이 **설계대로 거부**했다:

```
"ok": false
"idle: frame 00 has 145 chroma-adjacent pixels"
"eat:  frame 00 has 239 chroma-adjacent pixels"   (총 14건, 136~239px)
```

추측하지 않고 실측으로 확인했다 — raw의 실제 피사체 픽셀과 각 후보 키의 거리(1퍼센타일):

| 키 | evolved(넥타이 있음) | base(넥타이 없음) |
|---|---:|---:|
| cyan | **147.3** ❌ | 214.7 ✅ |
| **green** | **218.3** ✅ | 215.4 |
| magenta | 166.2 | 170.9 |

넥타이가 시안 기준 근접 거리를 214.7 → 147.3으로 끌어내린 것이 원인이다. 그린이 최고점이고,
sprite-gen의 크로마 분기표("핑크/보라/자주 소재 → 그린 `#00FF00`")와도 일치한다.

스킬의 BLOCKING 게이트가 "키 선택이 소재와 충돌하면 로컬 보정이 아니라 **키를 바꿔 재생성**"을
요구하므로, `mochi-evolved-v2`를 그린으로 새로 만들어 10상태를 전부 재생성했다. 결과:

| | 시안(v1) | 그린(v2) |
|---|---:|---:|
| `chroma_adjacent_pixels` | 136~239 | **0~2** (land만 10) |
| `edge_pixels` | — | **전 상태 0** |
| 추출 | `ok: false` | **`ok: true`, errors/warnings 없음** |

넥타이 파랑과 몸통 핑크 모두 탈색 없이 보존됐다. **v1(시안)은 반려 기록으로 보존**한다 —
`assets/generated/sprites/mochi-evolved-v1/` (raw 10장 포함).

**다음 티어(`evolved2` = 회찌) 작업자 주의**: 회찌도 액세서리 색에 따라 키를 다시 판정해야 한다.
base의 시안을 관성으로 복사하지 말 것. 판정 스크립트는 이 세션의 `keycheck.py` 방식(피사체 픽셀 대
후보 키 1퍼센타일 거리)이 근거로 충분하다.

## 5. 자체 검수 결과 (제작 가이드 §6 정적 점검)

- [x] 10상태 전부 투명 배경 — `frames-manifest.json.ok = true`, errors/warnings 없음
- [x] **`edge_pixels` 전 상태 0**
- [x] `chroma_adjacent_pixels` 0~2 (land 10). 그린 잔여 없음, 핑크·다크로즈·넥타이 블루 보존
- [x] 열×행 × 논리 프레임 일치 (아틀라스 10 rows / 44 cells)
- [x] `foot_padding`·`horizontal_offsets` 길이 == frames (10상태 전부)
- [x] **44프레임 전부 동일 기준선 16.0** — 상하 튐 0
- [x] 몸통 중심 좌우 ±6px 이내
- [x] 밉맵 + 선형 필터 (Godot 임포트 검증)
- [x] **안경·넥타이가 44프레임 전부에 유지됨** (컨택트 시트 육안 확인)
- [ ] **실제 화면 QA 미실시** — `qa-verifier` 담당

### 상태별 모션 판정

| 상태 | 판정 | 근거 |
|---|---|---|
| Idle | 통과 | 미세 호흡 + f3 깜빡임(안경 유지), 몸통 고정 |
| Walk | 통과 | 밑면 발 교대 접지 8프레임 2보 사이클, 넥타이 흔들림 |
| Sleep | 통과 | 납작 누움, 눈 감김, 상단만 호흡 |
| Eat | 통과 | 입 모양·볼만으로 씹기 — **음식 소품 없음** (base 티어 반려 교훈을 프롬프트에 선반영) |
| Sick | 통과 | 처짐·탁함·찡그린 눈. f3~4가 sleep과 실루엣이 가까우나 눈·입으로 구분됨 |
| Sulk | 통과 | 삐진 입·아래로 내린 눈·몸 살짝 돌림 |
| Play | 통과 | 스쿼시-스트레치 바운스, 감은 호선 눈·활짝 웃음. 접지 프레임이 기준선 복귀 |
| Dragged | 통과 | 매달려 늘어짐·좌우 흔들림, 손 안 그려짐 |
| Fall | 통과 | 세로 신장, 어느 프레임도 바닥 안 닿음 |
| Land | 통과 | 납작 스쿼시 → 원형 복귀, 비반복 |

**보류 상태 없음.** Play의 공중 프레임은 추출의 `align_y: bottom`으로 기준선에 정렬되므로
수직 이동 대신 스쿼시-스트레치로 읽힌다 — 제작 가이드 §5("Pet/Play는 몸통 크기와 접지 위치를
Idle과 맞춘다")가 요구하는 동작이다.

## 6. 미제작 (qa-verifier 기대값에서 제외)

- **FileHover / FileConsume / Poop / Pet 4종 미제작** (이번 스코프는 10상태).
- **`evolved2`(회찌) 티어 전체 미제작** — 스펙 §업그레이드 순서에 따라 evolved 검증 통과 후 착수.
- 정지 포즈 8장(`assets/sprites/chars/mochi_evolved/*.png`)은 **보존**했다 — 참고용·폴백용.

## 7. 제작 기록

`assets/generated/sprites/mochi-evolved-v2/` (채택) — 삭제 금지.
`assets/generated/sprites/mochi-evolved-v1/` (시안 반려본) — 삭제 금지.

| 경로 | 내용 |
|---|---|
| `sprite-request.json` | 수치 SSoT. cell rect 192×208, safe_margin 18/16, **그린 키**, fit lanczos/alpha-centroid/bottom |
| `base-source.png` | lock된 base = `chars/mochi_evolved/idle.png`를 ×4 LANCZOS 업스케일(512²). 원본 128px은 생성 레퍼런스로 디테일이 부족해서다 — 최종 자산이 아니라 아이덴티티 참조용이므로 sprite-gen의 앵커 ×8 업스케일 관행과 같은 취급이다 |
| `prompts/*.txt` | 10상태 row 프롬프트 (안경·넥타이 유지 제약 포함) |
| `raw/*.png` | 생성된 row 원본 10장 |
| `frames/<state>/frame-N.png` | 결정론 추출 44프레임 (각 192×208 투명) |
| `curated/<state>-frame-N.png` | 큐레이션 반영 내보내기 44장 — **런타임 시트의 실제 소스** |
| `sprite-sheet-alpha.png` + `manifest.json` | 전체 아틀라스, `frame_layout` 10 rows / 44 cells |
| `state-sheets/*.png` | 상태별 시트 10장 (런타임 설치본과 동일) |
| `qa/*.gif`, `qa/*-contact.png` | 상태별 모션 프리뷰 |

상태별 시트를 만든 방법은 base 티어와 동일하다 — `curated/`의 최종 셀을 격자로 **1:1 무손실
paste**만 한다(리샘플·색·알파 처리 없음). 근거는 `mochi.handoff.md` §7 참고.

## 8. 실행 메모

- row 1장 생성 **12~15분**, 4병렬 3배치. 시안 10장 + 그린 10장 = 총 20 row 생성.
- **동시 실행 누적으로 OOM 1회**: 이전 배치의 잔류 python/codex 프로세스가 19개까지 쌓여
  `sick` 생성이 `0xC0000409` + `memory allocation failed`로 죽었다. 잔류 프로세스를 정리한 뒤
  (가용 RAM 12GB 회복) 단독 재실행해 성공했다. **배치 사이에 잔류 프로세스를 정리할 것.**
- `codex_provider.py` Windows 수정 4건은 `mochi.handoff.md` §8 참고 (이번에도 그대로 필요했다).
- 추출·compose·preview·curated export는 **Linux 컨테이너**에서 실행 (`runio.py`의 fcntl
  publish guard는 손대지 않았다). WSL은 이 호스트에서 여전히 응답 불가.
- **세션↔상태 매칭 함정**: base와 evolved의 action 문구 앞부분이 동일해서, 세션 매칭을 action
  텍스트만으로 하면 **evolved 런에 base 티어 이미지가 섞여 들어간다**(실제로 dry-run에서 9상태가
  오매칭됐다). 캐릭터 설명(`"Prochi (mochi evolved)"`)과 키 색(`"green #00FF00"`)을 필수 마커로
  함께 요구해서 격리했다. v1(시안)/v2(그린) 구분에도 키 색 마커가 필요하다.
