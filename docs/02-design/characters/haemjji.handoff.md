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


---

# 햄찌 계열 — 프레임별 크기 정규화 해제 (recompose, 2026-08-10)

> **재생성 0회.** 기존 raw 스트립을 재측정해 **재합성만** 했다. 그림 내용은 그대로이고
> 프레임별 크기 비율만 원본으로 되돌렸다. 대상: 이 계열 15장 (전체 A분류 27장 중).

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

- **`foot_padding`은 15장 전부 불변** — 발 접지·공중 궤적이 바뀌지 않는다.
- **`horizontal_offsets`는 최대 0.5px만 이동** — 아래 표대로 갱신하면 된다.

## 등록 갱신값 (`horizontal_offsets`만)

| 티어 | 시트 (경로) | 갱신값 |
|---|---|---|
| `base` | `res://assets/sprites/haemjji/fall_4f_alpha_smooth.png` | `[0.0, 0.5, 0.5, -0.5]` |
| `base` | `res://assets/sprites/haemjji/idle_6f_alpha_smooth.png` | `[1.0, 0.5, -1.0, 0.5, -0.5, 0.5]` |
| `base` | `res://assets/sprites/haemjji/pet_6f_alpha_smooth.png` | `[0.0, 0.5, 0.5, -0.5, -0.5, -0.5]` |
| `base` | `res://assets/sprites/haemjji/play_6f_alpha_smooth.png` | `[0.0, 0.0, 0.0, 0.5, 0.0, 0.5]` |
| `base` | `res://assets/sprites/haemjji/poop_6f_alpha_smooth.png` | `[-0.5, 0.0, 0.0, -0.5, -0.5, -0.5]` |
| `evolved` | `res://assets/sprites/haemjji_evolved/fall_4f_alpha_smooth.png` | `[0.5, 1.0, -3.5, 1.5]` |
| `evolved` | `res://assets/sprites/haemjji_evolved/idle_6f_alpha_smooth.png` | `[1.5, 1.5, 2.0, 1.5, 1.5, 1.5]` |
| `evolved` | `res://assets/sprites/haemjji_evolved/pet_6f_alpha_smooth.png` | `[2.0, 0.0, 2.0, -1.0, 1.0, 1.5]` |
| `evolved` | `res://assets/sprites/haemjji_evolved/play_6f_alpha_smooth.png` | `[-0.5, -0.5, 1.0, 1.0, 1.0, 0.0]` |
| `evolved` | `res://assets/sprites/haemjji_evolved/poop_6f_alpha_smooth.png` | `[1.5, 1.5, 0.0, 1.5, 1.5, 1.5]` |
| `evolved` | `res://assets/sprites/haemjji_evolved/sick_6f_alpha_smooth.png` | `[1.0, 1.0, -1.5, -1.5, -1.5, 1.5]` |
| `evolved2` | `res://assets/sprites/haemjji_evolved2/fall_4f_alpha_smooth.png` | `[1.5, 1.0, 1.5, -2.0]` |
| `evolved2` | `res://assets/sprites/haemjji_evolved2/play_6f_alpha_smooth.png` | `[1.0, 1.5, 1.0, 1.0, 1.0, 0.0]` |
| `evolved2` | `res://assets/sprites/haemjji_evolved2/sick_6f_alpha_smooth.png` | `[1.5, 1.5, -1.5, -1.5, -1.5, 1.0]` |

변경 없음: `pet_6f_alpha_smooth.png`

## 전체 크기가 줄어든 시트

아래 시트는 **가장 극단적인 프레임이 셀에 안 들어가서** 행 전체를 조금 축소했다.
비율을 지키려면 피할 수 없다 — 한 프레임만 따로 눌러 맞추면 지금 고치려는 왜곡을
다시 넣는 셈이라 그렇게 하지 않았다.

| 시트 | 이전 대비 크기 |
|---|---:|
| `fall_4f_alpha_smooth.png` | **95.2%** |
| `sick_6f_alpha_smooth.png` | **98.1%** |
| `fall_4f_alpha_smooth.png` | **97.1%** |

**화면 QA에서 이 시트들만 크기 튐을 확인해야 한다.**

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


---

# 햄찌 계열 — Eat / FileConsume 재생성 (2단계, Task #35, 2026-08-10)

> 이 계열 **4장**. 1단계(재합성)와 달리 **이미지를 새로 생성**했다 —
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
| `base` | FileConsume | 0.8% → **15.9%** | **15.4%** |
| `evolved` | FileConsume | 0.7% → **34.1%** | **34.2%** |
| `evolved2` | FileConsume | 2.8% → **25.3%** | **25.3%** |
| `evolved` | Eat | 2.1% → **31.7%** | **31.4%** |

최대 폭 프레임도 전부 의도한 위치에 왔다 (FileConsume·모찌 Eat = f2, 햄찌 evolved Eat = f6).

## 등록 갱신값

`foot_padding`은 **4장 전부 불변**이다. `horizontal_offsets`만 갱신하면 된다.

| 티어 | 시트 (경로) | `horizontal_offsets` |
|---|---|---|
| `base` | `res://assets/sprites/haemjji/file_consume_4f_alpha_smooth.png` | `[0.0, -1.0, 1.0, 1.0]` |
| `evolved` | `res://assets/sprites/haemjji_evolved/file_consume_4f_alpha_smooth.png` | `[1.5, 2.0, 2.5, 1.5]` |
| `evolved2` | `res://assets/sprites/haemjji_evolved2/file_consume_4f_alpha_smooth.png` | `[0.0, 1.0, 0.0, 0.5]` |
| `evolved` | `res://assets/sprites/haemjji_evolved/eat_6f_alpha_smooth.png` | `[2.0, 2.5, 1.5, 2.5, 2.0, 2.0]` |

## 전체 크기가 줄어든 시트

없다 — 이 계열은 4장 전부 크기가 그대로다.

## 자체 검수

- [x] 추출 `ok: true`, errors 0
- [x] 셀 경계 접촉 0, 부유 파편 0
- [x] `foot_padding` 불변
- [x] 아이덴티티 유지 (안경·넥타이·정장/요리사 모자·왕관 전 프레임)
- [x] 회귀 테스트 3595 passed / 0 failed
- [ ] 실제 화면 QA — qa-verifier

반려본은 각 런의 `raw/rejected/<state>.flat-silhouette.png`로 보존했다.
Before/After 대조표: `docs/02-design/characters/stage2-eat-fileconsume.png`


## 2026-08-10 후속 — `haemjji/eat` base·evolved2 재생성 (Task #36)

2단계(#35)에서 **내 범위 산정이 틀려서** 이 상태의 3티어가 벌어졌다. 그 불일치를 되돌린 작업이다.

### 무엇을 잘못했나

#35 대상을 고를 때 **폭 변화만 보고** 판단했다. `haemjji/eat`의 base·evolved2는 폭이 7~8%
살아 있어 "정상"으로 분류해 제외했는데, **높이가 정확히 0.0%**였다 — 반쪽만 움직이는 시트였다.
그 결과 evolved 한 장만 재생성되어 같은 상태의 3티어가 이렇게 벌어졌다:

| 티어 | 면적 변화 (#35 직후) |
|---|---:|
| base | 7.9% |
| evolved (재생성됨) | 37.9% |
| evolved2 | 7.0% |

**재생성이 오히려 티어 불일치를 만들었다.** `qa-verifier`가 찾아서 2장 추가를 제안했고 수용했다.

### 지표를 면적으로 바꿨다

캐릭터·상태마다 표현 축이 다르다 — 모찌 Eat은 세로 스쿼시, 모찌 FileConsume은 가로,
햄찌는 가로다. **폭만 보면 멀쩡한 걸 재작업시키고 진짜 약한 걸 놓친다** (#35에서 실제로 둘 다
일어났다: `mochi_evolved/eat`을 "가장 약하다"고 잘못 지목했고, 이 2장은 놓쳤다).
앞으로 이 축의 판정은 **면적(폭×높이)** 으로 한다.

### 결과

| 티어 | 폭 | 높이 | **면적** |
|---|---:|---:|---:|
| base (이전) | 7.8% | **0.0%** | 7.9% |
| **base (신규)** | **41.5%** | 15.6% | **22.4%** |
| evolved (#35) | 31.4% | 4.9% | 37.9% |
| evolved2 (이전) | 7.6% | **0.3%** | 7.0% |
| **evolved2 (신규)** | **53.4%** | 9.5% | **40.1%** |

최대 폭 프레임은 둘 다 **f6**(의도한 위치)이고, 볼주머니가 프레임마다 점진적으로 부푼다.

### 면적 지표의 한계도 같이 확인됐다

**base가 22.4%로 다른 둘(37.9 / 40.1%)보다 낮게 나오는데, 이건 base가 약해서가 아니다.**
base는 폭이 41.5% 늘면서 **높이가 15.6% 줄어든다**(볼이 차면서 머리가 어깨 사이로 가라앉는
연출을 프롬프트에 넣었다). 면적은 곱이라 **한 축이 늘고 다른 축이 줄면 서로 상쇄된다** —
즉 스쿼시-스트레치가 강할수록 면적 지표가 과소평가한다.

폭만 보면 base 41.5% / evolved 31.4% / evolved2 53.4%로 오히려 base가 evolved보다 크다.
**면적은 "한 축이 죽었는지" 걸러내는 데는 정확하지만(0.0% 축을 놓치지 않는다),
연출 강도의 절대 비교에는 폭·높이를 같이 봐야 한다.**

### 등록 갱신값

`foot_padding` 불변. `horizontal_offsets`만:

| 티어 | 시트 (경로) | `horizontal_offsets` |
|---|---|---|
| `base` | `res://assets/sprites/haemjji/eat_6f_alpha_smooth.png` | `[1.0, -0.5, 0.5, 0.0, -0.5, 0.0]` |
| `evolved2` | `res://assets/sprites/haemjji_evolved2/eat_6f_alpha_smooth.png` | `[-0.5, 0.5, 1.0, 0.5, 1.0, 1.0]` |

### 검수

- [x] 추출 `ok: true`, errors 0
- [x] 셀 경계 접촉 0, `foot_padding` 불변, 크기 유지 100%
- [x] 최대 폭 프레임 f6 (의도한 위치)
- [x] 회귀 테스트 3597 passed / 0 failed
- [ ] 화면 QA — qa-verifier

반려본: 각 런의 `raw/rejected/eat.height-pinned.png`

---

# 햄찌 계열 — 공중 진폭 복원 (Task #37, 2026-08-10)

> 이 계열 **3장**. 재합성 2장 / 재생성 1행.

## 배경

추출 `fit`의 `align_y: bottom`이 모든 프레임 밑면을 셀 바닥선에 재고정하므로, 공중 상태
(Play/Dragged/Fall)의 "떠오른 높이"가 시트에서 지워진다. `pet.gd:107-112`의 `airborne` 계약은
프레임 간 `foot_padding` 차이를 화면 상승분으로 읽으므로 차이가 0이면 매달림·낙하가 안 보인다.
`raw` 스트립의 프레임별 상승분을 복원해 되살렸다. 자세한 원리와 우선순위 규칙은
`mochi.handoff.md`의 "공중 진폭 복원" 절에 있다 (여기서 반복하지 않는다).

## 등록 갱신값

| 티어 | 상태 | 방식 | 진폭 | `foot_padding` | `horizontal_offsets` |
|---|---|---|---:|---|---|
| `base` | Dragged | **재생성** | 10px | `[21.0, 22.0, 12.0, 19.0]` | `[-2.5, 0.5, -2.0, 0.5]` |
| `evolved` | Fall | 재합성 | 7.0px | `[9.0, 11.0, 7.0, 4.0]` | `[0.5, 1.0, -3.5, 1.5]` (불변) |
| `evolved2` | Fall | 재합성 | 7.0px | `[14.0, 12.0, 13.0, 7.0]` | `[1.5, 1.0, 1.5, -2.0]` (불변) |

`ground_padding`은 **명시하지 않는다** (생략 시 `foot_padding` 최솟값 = 위 값들의 계산 전제).

## 셀 축소 없이 진폭 전량을 살린 방법 (Fall 2장)

이 2장은 raw에 좋은 궤적이 있었는데도(상승분 raw 29~39px) 자동 보정이 진폭을 **0으로** 깎고
있었다. 원인은 f1의 머리 위 여유가 2px뿐이라 상승분을 얹을 자리가 없었던 것이다.
처음 계획은 스프라이트를 축소해 여유를 만드는 것(낙하 중 크기가 작아지는 트레이드오프)이었으나,
**행 전체를 셀 안에서 아래로 내리는 것으로 축소 없이 해결했다.**

근거는 `airborne` 계약 자체다 — `ground_padding` 하나로만 고정 보정하므로 **행 전체의 균일한
수직 이동은 화면에서 완전히 상쇄되고 프레임 간 상대 차이만 보인다.** 접지 기준값을 12 → 4
(`evolved`) / 12 → 7 (`evolved2`)로 낮춰 머리 위 여유를 벌었다. 결과 **진폭 감쇠 0 · 축소 0 ·
이미지 재생성 0**으로 7.0px 확보. base(`haemjji/fall`)의 9px과 같은 급이다.

## base Dragged는 재생성이 필요했다

raw 자체에 궤적이 거의 없어(표시배율 적용 후 2.4px) 재합성으로 복원할 것이 없었다. 프롬프트에
"목덜미를 잡혀 늘어져 매달림 / 두 발이 바닥에서 완전히 떨어져 아래로 늘어짐 / 앞발도 가슴에서
떨어져 늘어짐 / 프레임마다 몸 아래 빈 여백 크기가 달라야 함"을 명시해 10px을 확보했다.

> ⚠️ 다만 **매달린 느낌은 아직 약하다** — 그림이 "똑바로 선 채 떠 있는" 쪽으로 읽히는 면이 있다.
> 화면 QA에서 부족하다고 나오면 이 행만 다시 뽑아야 한다. 진폭 자체는 기준을 넘겼다.

## 남은 낮은 값 (후속 후보)

같은 상태에서 이제 `evolved/Dragged` 5px, `evolved2/Dragged` 4px가 가장 약한 티어로 남았다.
둘 다 raw가 약해서(편차 1~3%) 재합성으로는 못 올리고 재생성이 필요하다. 전수 재감사에서
`haemjji/sleep`도 raw 정지(높이 변화 0.0%)로 잡혔는데, 수면 상태라 우선순위를 낮게 뒀다.

## 검수

- [x] 추출 `ok: true`, errors 0, warnings 0
- [x] 셀 경계 접촉 0, 부유 파편 0, 크로마 잔여 0
- [x] 표시 크기 유지 100%
- [x] `mipmaps/generate=true`
- [ ] 화면 QA — qa-verifier

제작 기록: `haemjji-air-v1` (base Dragged). 재합성본은 각 런의 `recomposed/`.
