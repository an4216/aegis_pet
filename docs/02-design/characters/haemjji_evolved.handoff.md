# 햄찌 evolved (함장님 / `haemjji_evolved`) 스프라이트 인수인계 — 14상태

> 작성: sprite-artist / character-pipeline, 2026-08-07
> 제작 기록: `assets/generated/sprites/haemjji_evolved-v1/` (보존)
> **스코프**: `evolved` 티어 14상태. `base`는 완료(`haemjji.handoff.md`), `evolved2`(햄왕)는 미착수.

## 1. 요약

| 항목 | 값 |
|---|---|
| 캐릭터 ID | `haemjji_evolved` (함장님, 1차 진화) |
| 아이덴티티 | base 햄찌와 같은 크림색 햄스터(주황 머리무늬·둥근 귀·볼터치·큰 눈) + **제빵사 복장**: 흰 셰프 토크(주황·흰 깅엄 체크 밴드), 크림색 앞치마(주황 쿠키 포켓 + 뒤 리본) |
| 셀 | **128×128**, `safe_margin` 12 (base 티어와 동일) |
| 크로마키 | **시안 `#00FFFF`** — 실측 재판정(§3) |
| 기준선 | **14상태 76프레임 전부 `foot_padding = 12.0`** (base 티어와 동일) |
| 렌더 | `.import` 14장 전부 `mipmaps/generate=true` + Godot 임포트 검증 **14/14** |
| 실제 화면 QA | **미실시** — `qa-verifier` 담당 |

## 2. 런타임 등록 실측값

경로 접두사: `res://assets/sprites/haemjji_evolved/`
`foot_padding`은 전 상태 프레임 수만큼 `12.0` 반복.

| 상태 | 파일 | 그리드 | frames / fps / loop | horizontal_offsets |
|---|---|---:|---|---|
| Idle | `idle_6f_alpha_smooth.png` | 6×1 | 6 / 4.0 / true | `[1.0, 1.5, 1.5, 1.5, 1.5, 1.5]` |
| Walk | `walk_8f_alpha_smooth.png` | 4×2 | 8 / 10.0 / true | `[1.5, 1.5, 1.0, 1.0, 1.5, 1.5, 1.5, 1.5]` |
| Sleep | `sleep_6f_alpha_smooth.png` | 6×1 | 6 / 5.0 / true | `[-3.0, -2.0, -2.0, -2.0, -3.0, -3.0]` |
| Eat | `eat_6f_alpha_smooth.png` | 6×1 | 6 / 6.0 / true | `[2.0, 2.0, 2.0, 2.0, 2.0, 1.5]` |
| Sick | `sick_6f_alpha_smooth.png` | 6×1 | 6 / 6.0 / true | `[1.5, 0.5, -2.0, -1.5, -1.5, 1.0]` |
| Sulk | `sulk_6f_alpha_smooth.png` | 6×1 | 6 / 6.0 / true | `[-1.0, -2.0, -3.5, -1.5, -1.5, -1.0]` |
| Play | `play_6f_alpha_smooth.png` | 6×1 | 6 / 8.0 / true | `[-1.0, -1.0, 1.0, 1.0, 1.0, 0.5]` |
| Dragged | `dragged_4f_alpha_smooth.png` | 4×1 | 4 / 10.0 / true | `[0.0, 0.5, -1.5, 0.5]` |
| Fall | `fall_4f_alpha_smooth.png` | 4×1 | 4 / 12.0 / true | `[1.0, 0.5, -3.5, 1.0]` |
| Land | `land_4f_alpha_smooth.png` | 4×1 | 4 / 10.0 / **false** | `[0.0, 0.0, 2.0, 2.0]` |
| FileHover | `file_hover_4f_alpha_smooth.png` | 4×1 | 4 / 12.0 / **false** | `[2.0, 1.5, 2.0, 2.0]` |
| FileConsume | `file_consume_4f_alpha_smooth.png` | 4×1 | 4 / 12.0 / **false** | `[2.0, 2.0, 2.5, 2.0]` |
| Poop | `poop_6f_alpha_smooth.png` | 6×1 | 6 / 6.0 / true | `[1.5, 1.5, 0.5, 1.5, 1.5, 1.5]` |
| Pet | `pet_6f_alpha_smooth.png` | 6×1 | 6 / 10.0 / **false** | `[1.5, 0.5, 1.5, -1.0, 1.0, 1.0]` |

### `sheet_scale` (evolved) = **1.125**

`BODY_SCALE["haemjji"]["evolved"] = 1.72`는 **그대로 둔다**(정지 포즈 폴백용).

```text
정지 아트 torso 99 ÷ 시트 idle 휴지프레임 torso 88 = 1.1250 → 1.125
```

base 티어와 **같은 자동 검출기·같은 임계값(α>0.125)** 으로 양쪽을 쟀다.

### 측정 방법 간 비율 교차검증 (실측)

"절대값을 감사표에 맞추지 말고 비율이 방법 간 일치하는지로 판단한다"는 기준으로 3가지 방법을 비교했다:

| 방법 | 정지 | 시트 | 비율 |
|---|---:|---:|---:|
| **코어 몸통 검출기 (귀 제외, α>0.125)** | 99 | 88 | **1.1250** |
| 전체 실루엣 bbox (α>0.125) | 115 | 104 | 1.1058 |
| 전체 실루엣 bbox (α>0) | 119 | 104 | 1.1442 |

**α>0.125인 두 방법의 차이는 1.74%로, 목표치 1.5%를 약간 벗어난다.** 원인은 귀 비율이다 —
정지 아트는 귀가 몸 대비 더 높이 솟아 있고(전체 115 vs 코어 99 = 16px), 시트는 그 차이가 작다
(104 vs 88 = 16px이지만 몸통이 작아 상대 비중이 다르다). 즉 두 자산의 **귀/몸통 비율 자체가
조금 다르다.**

**`1.125`(코어 몸통 기준)를 채택한다** — 프로젝트의 정규화 축이 2026-08-07부터 전체 실루엣이
아니라 **코어 몸통**(`BODY_CORE_HEIGHT` / `BODY_SCALE_TARGET_TORSO`)이므로 기준이 일치한다.
전체 실루엣 기준을 쓰고 싶다면 `1.106`이 대응값이다(1.7% 작게 렌더된다).

세 번째 행(α>0)이 왜 배제되는지도 실측으로 드러난다 — 정지 아트에는 4px 프린지가 있고(119 vs 115)
시트에는 없어서(104 = 104) 비율이 1.1442로 부풀려진다. 삐약 "Idle만 -6%" 오경보와 같은 메커니즘이다.

### `airborne` = **Play / Dragged / Fall** · `runtime_sick_mark` = **true**

- Play: 제자리 바운스로 발이 뜨는 프레임 있음 / Dragged: 4프레임 전부 공중 매달림 /
  Fall: 4프레임 전부 낙하, 접지 없음 → 3종 `airborne: true`
- 나머지 11상태는 상시 접지(Land 1프레임은 지면 충격 스쿼시)
- Sick 시트에 **소용돌이 눈·땀방울 등 어지럼 표시가 없다**(자세·처진 귀·찡그린 눈으로만 표현) →
  런타임 `@_@` 라벨이 필요하다: `runtime_sick_mark: true`. 나머지 13상태는 미등록.
- ⚠️ base·모찌와 동일한 한계: `align_y: bottom`이라 `foot_padding`이 전 프레임 12.0 고정이고
  프레임 간 차이가 0이라 **화면상 상승분은 나오지 않는다**. 선언은 의미상 정확, 지금 켜도 회귀 없음.

## 3. 크로마키 = **시안 `#00FFFF`** (재판정)

진화로 복장이 바뀌었으므로 관성 복사하지 않고 다시 쟀다. 정지 아트 3장 기준 1퍼센타일 거리:

| 키 | idle | eat | happy |
|---|---:|---:|---:|
| **cyan** | **227.1** | **228.3** | **227.9** ✅ |
| green | 219.3 | 218.7 | 218.9 |
| blue | 211.2 | 210.2 | 212.1 |
| magenta | 198.8 | 194.6 | 197.2 |

제빵사 복장이 흰색·주황 계열이라 파랑/시안 계열 색이 없어 시안이 그대로 안전하다
(mochi_evolved의 스틸블루 넥타이 같은 충돌 요인이 없다). 결과: `chroma_adjacent_pixels` **0~1**.

## 4. ⚠️ 설계 판단 — 레퍼런스의 **머핀은 제외**했다

정지 아트의 함장님은 **머핀을 두 손에 들고 있다.** 이걸 그대로 두면 문제가 생긴다:

- **Eat**: "음식 소품을 그리지 말라"는 규칙과 정면 충돌한다(모찌 Eat 반려 사유와 동일)
- **Dragged / Fall**: 공중에 매달리고 낙하하는데 머핀을 든 자세는 부자연스럽다
- **Poop / FileHover / FileConsume / Pet**: 소품 금지 상태다

그래서 **셰프 토크와 앞치마는 "착용 아이덴티티"로 전 프레임 유지하고, 머핀은 전 상태에서 제외**했다.
14상태 전부 빈손이라 상태 전환 시 머핀이 나타났다 사라지는 깜빡임이 없다.

**이 판단은 되돌릴 수 있다** — 머핀을 살리고 싶다면 Idle/Walk/Sleep/Sulk/Play 정도의 접지·비섭식
상태에만 넣는 방식이 가능하지만, 그러면 Eat·Poop 등과 오가며 소품이 깜빡인다. 전 상태 통일을 권한다.

## 5. 반려 2건

1. **Idle·Walk에 머핀이 그려짐** — 1차 배치는 프롬프트에 머핀 금지 문구가 없어, 모델이 첨부된
   레퍼런스 이미지를 따라 머핀을 그렸다(레퍼런스가 아이덴티티 진실이므로 모델 동작 자체는 정상).
   나머지 12상태는 액션에 소품 금지가 있거나 자세상 자연히 생략돼 머핀이 없었다 →
   **상태 간 머핀이 들락날락하는 불일치**가 생겼다.
   → 14개 프롬프트 전부에 `HANDS-EMPTY RULE`(머핀·컵케이크·쟁반 등 들고 있는 물체 금지, 단
   토크와 앞치마는 유지)을 삽입하고 **Idle·Walk 2행만 재생성**했다. 1차본은
   `raw/idle.v1-held-muffin.png`, `raw/walk.v1-held-muffin.png`로 보존.
   **컨택트 시트 전수 육안 검수가 아니면 못 잡았을 결함이다** — 자동 QA는 전부 통과시켰다.
2. **FileHover·FileConsume OOM 실패** — 4병렬 + 이전 배치 잔류 프로세스 누적으로
   `0xC0000409`(memory allocation failed)로 죽었다. 프로세스 정리 후 2병렬로 재실행해 성공.

## 6. 자체 검수

- [x] 14행 `frames-manifest.ok = true`, errors/warnings 없음
- [x] `edge_pixels` 전 행 **0**
- [x] `chroma_adjacent_pixels` **0~1**
- [x] `foot_padding`/`horizontal_offsets` 길이 == frames, **76프레임 전부 기준선 12.0**
- [x] 셰프 토크·깅엄 밴드·앞치마·쿠키 포켓이 **76프레임 전부 유지**
- [x] 머핀이 **전 상태에서 제외**되어 상태 전환 시 소품 깜빡임 없음
- [x] Eat 볼주머니 — 프레임이 갈수록 볼이 부풀어 실루엣이 넓어진다(base 티어와 동일 처리)
- [x] 소품 없음 — 파일·응아·손·하트·부유 기호 어느 프레임에도 없음
- [x] Pet(눈 감은 잔잔한 만족)과 Play(입 벌린 바운스)가 명확히 구분됨
- [x] Walk이 실제 보행 — 다리가 교대로 접지, 앞치마가 함께 흔들림
- [x] 밉맵 + Godot 임포트 검증 14/14
- [~] **1px 파편 4건** — `dragged/f1`, `file_consume/f0`, `file_consume/f2`, `sleep/f4`에
  **1픽셀짜리** 분리 조각이 남아 있다. base 티어에서 반려했던 25~42px 땀방울과 달리 그려진 기호가
  아니라 AA 잔여물이고, 128셀의 1px는 실제 표시 배율에서 **1픽셀 미만**이라 육안 확인이 불가능하다.
  4행을 재생성할 만한 사안이 아니라고 판단해 통과시키되 기록해 둔다 — `qa-verifier`가 화면에서
  점이 보인다고 판단하면 그때 해당 행만 재생성하면 된다.
- [ ] 실제 화면 QA 미실시

## 7. 등록 참고

- 상태 키는 base 티어와 동일(`Idle/Walk/Sleep/Eat/Sick/Sulk/Play/Dragged/Fall/Land/FileHover/FileConsume/Poop/Pet`).
- **`tiers`에 `"evolved"`를 추가**하고 `sheet_scale`을 `{"base": <base값>, "evolved": 1.125}` 형태의
  티어 맵으로 둔다. 시트 경로가 `assets/sprites/haemjji_evolved/`로 다르므로 상태 밑에 tier 한 단이 필요하다.
- `evolved2`(햄왕)는 미제작 — 해당 티어는 정지 포즈 8종으로 폴백해야 한다.

## 8. 제작 기록

`assets/generated/sprites/haemjji_evolved-v1/` — 삭제 금지.
raw 14(+반려 2) / frames 76 / curated 76 / 아틀라스 / state-sheets 14 / qa 프리뷰.
상태별 시트는 `curated/`의 최종 셀을 1:1 무손실 paste(6프레임 → 6×1, 8프레임 → 4×2, 4프레임 → 4×1).

실행: row 1장 12~15분, 4병렬 배치 + 재생성 2회 + OOM 재시도 2회 = 총 18 row 생성.
추출·compose는 Linux 컨테이너(`runio.py` fcntl 가드 무수정).
