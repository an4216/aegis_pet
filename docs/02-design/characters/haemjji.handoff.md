# 햄찌 (haemjji) base 스프라이트 인수인계 — 14상태

> 작성: sprite-artist / character-pipeline, 2026-08-07
> 제작 기록: `assets/generated/sprites/haemjji-v1/` (보존)
> **스코프**: `base` 티어 14상태. `evolved`(함장님) / `evolved2`(햄왕)는 미착수.

## 1. 요약

| 항목 | 값 |
|---|---|
| 캐릭터 ID | `haemjji` (햄찌, base) |
| 아이덴티티 | 통통한 크림색 햄스터. 머리·등 위 주황빛 탠 무늬, 갈색 겉/분홍 속 둥근 귀 2개, 큰 반짝이는 진갈색 눈, 분홍 코 + 작은 웃는 입, 분홍 볼터치, 가슴 앞 크림색 앞발 2개, 밑면 분홍 발 2개(접지점), 진갈색 외곽선 |
| 셀 | **128×128**, `safe_margin` 12 (ppiyak과 동일 규격) |
| 크로마키 | **시안 `#00FFFF`** — 실측 판정(§3) |
| 기준선 | **14상태 76프레임 전부 `foot_padding = 12.0`** (ppiyak과 동일) |
| 렌더 | `.import` 14장 전부 `mipmaps/generate=true` + Godot 4.4.1 헤드리스 임포트 검증(14/14 uid·mipmaps 확인) |
| 실제 화면 QA | **미실시** — `qa-verifier` 담당 |

## 2. 런타임 등록 실측값

경로 접두사: `res://assets/sprites/haemjji/`
전 상태 `foot_padding` = 프레임 수만큼 `12.0` 반복. `runtime_sick_mark`는 §5, `airborne`은 §6.

| 상태 | 파일 | 그리드 | frames / fps / loop | horizontal_offsets | 몸통(전체 실루엣) |
|---|---|---:|---|---|---:|
| Idle | `idle_6f_alpha_smooth.png` | 6×1 | 6 / 4.0 / true | `[0.5, 0.0, -0.5, 0.5, -0.5, 0.5]` | 104 |
| Walk | `walk_8f_alpha_smooth.png` | 4×2 | 8 / 10.0 / true | `[-0.5, 0.0, 0.0, 0.0, -0.5, 0.0, 0.0, 0.0]` | 104 |
| Sleep | `sleep_6f_alpha_smooth.png` | 6×1 | 6 / 5.0 / true | `[-1.0, -1.0, -1.0, -1.0, -1.0, -1.0]` | 80 |
| Eat | `eat_6f_alpha_smooth.png` | 6×1 | 6 / 6.0 / true | `[0.5, 0.0, 0.0, 0.0, -0.5, 0.0]` ⚠️v2 | 104 |
| Sick | `sick_6f_alpha_smooth.png` | 6×1 | 6 / 6.0 / true | `[-0.5, 0.0, 0.0, 1.5, -0.5, 1.0]` | 98~104 |
| Sulk | `sulk_6f_alpha_smooth.png` | 6×1 | 6 / 6.0 / true | `[0.5, -0.5, -0.5, 0.5, 1.0, -1.5]` | 104 |
| Play | `play_6f_alpha_smooth.png` | 6×1 | 6 / 8.0 / true | `[0.0, -0.5, 0.0, 0.5, 0.0, 0.5]` | 104 |
| Dragged | `dragged_4f_alpha_smooth.png` | 4×1 | 4 / 10.0 / true | `[-0.5, -0.5, 0.5, 0.0]` | 104 |
| Fall | `fall_4f_alpha_smooth.png` | 4×1 | 4 / 12.0 / true | `[0.0, 0.5, 0.5, -1.0]` | 104 |
| Land | `land_4f_alpha_smooth.png` | 4×1 | 4 / 10.0 / **false** | `[0.0, 0.0, 0.0, 0.5]` | 67~104 |
| FileHover | `file_hover_4f_alpha_smooth.png` | 4×1 | 4 / 12.0 / **false** | `[-0.5, 0.0, -0.5, 0.0]` | 104 |
| FileConsume | `file_consume_4f_alpha_smooth.png` | 4×1 | 4 / 12.0 / **false** | `[0.0, -0.5, 0.5, 0.5]` | 104 |
| Poop | `poop_6f_alpha_smooth.png` | 6×1 | 6 / 6.0 / true | `[-0.5, 0.0, 0.5, -0.5, -0.5, -0.5]` | 104 |
| Pet | `pet_6f_alpha_smooth.png` | 6×1 | 6 / 10.0 / **false** | `[0.5, 0.5, 0.5, -0.5, -0.5, -0.5]` | 104 |

6프레임 상태는 **6×1**로 배치했다 — ppiyak 출고 시트(768×128)와 같은 형태다.

## 3. 크로마키 = **시안 `#00FFFF`** (실측 판정)

신규 캐릭터라 관성 없이 새로 쟀다. 정지 아트 3장의 불투명 피사체 픽셀 대 후보 키 거리(1퍼센타일):

| 키 | idle | eat | happy |
|---|---:|---:|---:|
| **cyan** | **231.5** | **232.7** | **235.4** ✅ |
| blue | 216.8 | 213.8 | 223.2 |
| green | 215.2 | 213.6 | 216.8 |
| magenta | 203.0 | 206.6 | 187.4 |

크림·주황탠·갈색·분홍 팔레트라 시안이 가장 멀다. 결과적으로 추출 후
`chroma_adjacent_pixels`가 **0~1**로, 지금까지 만든 어떤 캐릭터보다 깨끗하다.

(방법 검증: 같은 스크립트를 mochi_evolved에 돌리면 green을, mochi base에는 cyan을 고른다 —
실제로 겪은 결론을 재현한다.)

## 4. ⚠️ `sheet_scale` — **1.083 제안**, 다만 측정 기준 확인이 필요하다

2026-08-07에 정규화 기준이 **전체 실루엣 → 코어 몸통**으로 바뀌었고
(`BODY_SCALE = 2 × BODY_SCALE_TARGET_TORSO ÷ 코어높이`), `BODY_CORE_HEIGHT["haemjji"]["base"] = 96.0`이
`body-size-audit.md`의 **수작업 시각 실측** SSoT다.

`sheet_scale`은 "같은 티어의 두 자산(정지 아트 / 시트) 비율"이므로 **두 값을 같은 방법으로 재야 한다.**
자동 검출기(귀를 제외하려고 '단일 연속 런' 휴리스틱 사용, α>0.125)로 양쪽을 재면:

```text
정지 아트 idle.png   torso = 104
시트 idle 프레임0     torso =  96
sheet_scale = 104 / 96 = 1.0833 → 1.083
```

**투명하게 밝힌다: 내 검출기는 감사 표를 완전히 재현하지 못한다.**
ppiyak은 93으로 정확히 일치하지만 haemjji는 104(감사 96), mochi 67(72), tokki 60(53),
geobujang 100(93)으로 어긋난다. 감사는 36장 수작업 시각 판정이라 알고리즘화되어 있지 않다.

그래서 위 `1.083`은 **"두 자산을 같은 자동 기준으로 잰 비율"**이며, 계통 오차가 비율에서 상당 부분
상쇄된다는 근거로 제안한다. **감사 값(96)과 검출기 시트 값(96)을 섞어 1.000을 쓰면 안 된다** —
서로 다른 측정 방법을 섞는 것이 바로 qa-verifier가 진단한 삐약 "Idle만 -6%" 오경보의 원인이었다.

→ **`qa-verifier`가 감사와 같은 방법으로 시트 idle 프레임0의 코어 몸통을 한 번 재서 확정**해 주면
가장 안전하다. 그 값을 `X`라 하면 `sheet_scale = 96 / X`다.
(참고: 셀이 128이어도 `sheet_scale = 1.0`이 아니다 — ppiyak도 1.168/1.187/1.027이었고,
`pet.gd:199` 주석이 "128이라 필요 없다고 봤지만 틀렸다"고 기록하고 있다.)

## 5. `runtime_sick_mark` = **true** (재생성 후 시트에 표시 없음)

1차 Sick 시트에는 **땀방울·콧물방울 같은 부유 기호가 있었고 반려했다**(§7).
재생성본은 **어떤 부유 기호도 없다** — 아픔이 자세(주저앉음)·처진 귀·찡그린 눈으로만 표현된다.
소용돌이 눈도 없다.

→ 정지 `sick.png`가 갖던 어지럼 표시 역할을 런타임 `@_@` 라벨이 해야 한다: **`runtime_sick_mark: true`**.
나머지 13상태는 달지 않는다.

## 6. `airborne` = **Play / Dragged / Fall**

| 상태 | airborne | 근거 |
|---|---|---|
| Play | **true** | 제자리 바운스 — 발이 뜨는 프레임이 있다 |
| Dragged | **true** | 4프레임 전부 공중에 매달려 다리·발이 늘어진다 |
| Fall | **true** | 4프레임 전부 낙하, 접지 없음 |
| 나머지 11상태 | false | 상시 접지 (Land 1프레임은 지면 충격 스쿼시) |

⚠️ 다른 캐릭터와 같은 한계: 추출이 `align_y: bottom`이라 `foot_padding`이 76프레임 전부 12.0 고정이고,
프레임 간 차이가 0이라 **화면상 상승분은 나오지 않는다**. 선언은 의미상 정확하고 지금 켜도 회귀 없다.

## 7. 반려 1건 — Sick에 **분리된 부유 기호**

1차 Sick 시트 6프레임 중 **4프레임에 몸에서 떨어진 작은 blob**(25~42px)이 있었다 — 땀방울/콧물방울이다.
제작 가이드 §2("분리된 이펙트 금지")와 프롬프트 계약("separate disconnected component" 금지) 위반이다.

**추출 QA는 이걸 못 잡는다** — `ok: true`, `edge_pixels 0`, `chroma_adjacent 0`으로 전부 통과했다.
그래서 **전 프레임 연결성 스캔**(`scan_detached.py`)을 따로 돌려서 찾아냈다:

```text
DETACHED  sick/frame-0: 3 blobs [7474, 37, 37]
DETACHED  sick/frame-2: 2 blobs [7883, 31]
DETACHED  sick/frame-4: 2 blobs [7708, 42]
DETACHED  sick/frame-5: 2 blobs [7552, 25]
```

부유 기호 금지 문구를 액션에 추가해 Sick 행만 재생성했고, 재스캔 결과
**76프레임 전부 단일 컴포넌트**로 통과했다. 반려본은 `raw/sick.rejected-detached-symbols.png`로 보존.
나머지 13행은 1차 통과.

> 이번 라운드의 교훈: 모찌 라운드의 "레이아웃 가이드가 그려진 프레임"과 마찬가지로,
> **자동 추출 QA가 통과시키는 시각 결함이 존재한다.** 컨택트 시트 육안 검수 + 연결성 스캔을
> 둘 다 돌려야 한다.

## 8. 자체 검수

- [x] 14행 `frames-manifest.ok = true`, errors/warnings 없음
- [x] `edge_pixels` 전 행 **0**
- [x] `chroma_adjacent_pixels` **0~1** (idle만 1)
- [x] **76프레임 전부 단일 연결 컴포넌트** — 부유 기호·파편 없음
- [x] `foot_padding`/`horizontal_offsets` 길이 == frames
- [x] **76프레임 전부 기준선 12.0**, 몸통 중심 ±1.5px
- [x] 아이덴티티(주황 머리무늬·귀·볼터치·앞발·분홍 발) 전 프레임 유지
- [x] 소품 없음 — Eat에 먹이 없음, Poop에 응아 없음, FileHover/Consume에 파일 없음, Pet에 손 없음
- [x] Walk이 실제 보행 — 8프레임에 걸쳐 발이 교대로 앞뒤로 놓이고 몸이 상하로 보브한다(홉 아님)
- [x] **볼주머니(치크 파우치) 달성 (Eat v2, 2026-08-07 재생성)** — 1차본은 볼터치만 있고 부푼
  실루엣이 없어 미달이었다. 액션에 "양 볼이 눈에 띄게 둥글고 통통하게 부풀어 머리 실루엣이 좌우로
  넓어진다 — 이건 이 캐릭터의 시그니처이며 볼터치 자국으로 끝나면 안 된다"를 명시해 Eat 행만
  재생성했다. 결과: 프레임별 실루엣 폭이 **77 → 76 → 80 → 80 → 81 → 82px로 단조 증가**해
  볼주머니가 차오르는 것이 수치로도 확인된다(마지막 프레임이 가장 통통). 먹이 소품은 여전히 없다.
  1차본은 `raw/eat.v1-no-cheek-pouch.png`로 보존.
- [x] Pet과 Play가 구분됨 (Pet=눈 감은 만족·잔잔, Play=입 벌린 바운스)
- [x] 밉맵 + Godot 임포트 검증 14/14
- [ ] 실제 화면 QA 미실시

## 9. 등록 참고

- 상태 키는 bichon과 동일: `Idle/Walk/Sleep/Eat/Sick/Sulk/Play/Dragged/Fall/Land/FileHover/FileConsume/Poop/Pet`
- 이 캐릭터는 **base 티어만** 제작됐다. `tiers`에 `"base"`만 넣고, evolved/evolved2는 기존 정지 포즈로 폴백해야 한다.
- Poop/FileHover/FileConsume은 몸만 그렸다 — 응아는 `scenes/pet/poop.tscn`가, 파일은 OS 드래그 아이콘이 그린다.

## 10. 제작 기록

`assets/generated/sprites/haemjji-v1/` — 삭제 금지.
raw 14 / frames 76 / curated 76 / 아틀라스 / state-sheets 14 / qa 프리뷰. 상태별 시트는
`curated/`의 최종 셀을 1:1 무손실 paste.

실행: row 1장 12~15분, 4병렬 4배치(4+4+4+2) + 재생성 2회(Sick 반려, Eat 볼주머니 보강) = 총 16 row 생성.

### ⚠️ Eat 재생성으로 `horizontal_offsets`가 바뀌었다 (등록 갱신 필요)

gd-integrator가 이미 등록을 마친 뒤(task #18) Eat을 재생성했으므로 **그 한 줄만 갱신**해야 한다.
파일명·그리드(6×1)·frames(6)·fps(6.0)·loop(true)·`foot_padding`(`[12.0]×6`)은 전부 그대로다.

```text
등록된 값(v1): [0.0, 0.0, 0.0, 0.5, 0.0, 0.5]
새 값(v2):     [0.5, 0.0, 0.0, 0.0, -0.5, 0.0]
```
추출·compose는 Linux 컨테이너(`runio.py` fcntl 가드 무수정).

**함정 기록**: PowerShell `Set-Content -Encoding utf8`은 **BOM을 붙인다.** 이걸로
`sprite-request.json`을 고쳤더니 추출이 `JSONDecodeError: Unexpected UTF-8 BOM`으로 죽었다.
JSON/프롬프트를 스크립트로 고칠 땐 `UTF8Encoding($false)`로 써야 한다.
