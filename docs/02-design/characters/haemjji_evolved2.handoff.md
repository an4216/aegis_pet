# 햄찌 evolved2 (햄왕 / `haemjji_evolved2`) 스프라이트 인수인계 — 14상태

> 작성: sprite-artist / character-pipeline, 2026-08-07
> 제작 기록: `assets/generated/sprites/haemjji_evolved2-v1/` (보존)
> **스코프**: `evolved2` 티어 14상태. 이로써 **햄찌 3티어가 모두 애니메이션화됐다**
> (base `haemjji.handoff.md`, evolved `haemjji_evolved.handoff.md`).

## 1. 요약

| 항목 | 값 |
|---|---|
| 캐릭터 ID | `haemjji_evolved2` (햄왕, 최종 진화) |
| 아이덴티티 | base 햄찌의 크림색 몸통·주황 머리무늬·둥근 귀·볼터치 + **금관(crown)** + 흰 셰프 토크(주황 깅엄 밴드) + 크림 앞치마(깅엄 끈 + 주황 쿠키 포켓) |
| 셀 | **128×128**, `safe_margin` 12 (base·evolved와 동일) |
| 크로마키 | **시안 `#00FFFF`** — 실측 재판정(§3) |
| 기준선 | **14상태 76프레임 전부 `foot_padding = 12.0`** (base·evolved와 동일) |
| 렌더 | `.import` 14장 전부 `mipmaps/generate=true` + Godot 임포트 검증 **14/14** |
| 실제 화면 QA | **미실시** — `qa-verifier` 담당 |

## 2. 런타임 등록 실측값

경로 접두사: `res://assets/sprites/haemjji_evolved2/`
`foot_padding`은 전 상태 프레임 수만큼 `12.0` 반복.

| 상태 | 파일 | 그리드 | frames / fps / loop | horizontal_offsets |
|---|---|---:|---|---|
| Idle | `idle_6f_alpha_smooth.png` | 6×1 | 6 / 4.0 / true | `[0.5, 1.0, 0.5, 1.5, 1.5, 1.5]` |
| Walk | `walk_8f_alpha_smooth.png` | 4×2 | 8 / 10.0 / true | `[1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.0, 1.0]` |
| Sleep | `sleep_6f_alpha_smooth.png` | 6×1 | 6 / 5.0 / true | `[-3.0, -3.0, -3.0, -3.0, -3.0, -3.0]` |
| Eat | `eat_6f_alpha_smooth.png` | 6×1 | 6 / 6.0 / true | `[0.0, 0.5, 0.5, 0.5, 1.5, 1.0]` |
| Sick | `sick_6f_alpha_smooth.png` | 6×1 | 6 / 6.0 / true | `[1.5, 1.0, -1.0, -1.5, -1.5, 0.5]` |
| Sulk | `sulk_6f_alpha_smooth.png` | 6×1 | 6 / 6.0 / true | `[2.0, 2.0, 2.0, 1.5, 0.5, 1.5]` |
| Play | `play_6f_alpha_smooth.png` | 6×1 | 6 / 8.0 / true | `[1.0, 1.5, 1.0, 1.0, 1.5, 0.5]` |
| Dragged | `dragged_4f_alpha_smooth.png` | 4×1 | 4 / 10.0 / true | `[0.5, -0.5, -1.0, 1.0]` |
| Fall | `fall_4f_alpha_smooth.png` | 4×1 | 4 / 12.0 / true | `[2.0, 1.0, 1.5, -2.0]` |
| Land | `land_4f_alpha_smooth.png` | 4×1 | 4 / 10.0 / **false** | `[2.0, 0.0, 1.0, 1.0]` |
| FileHover | `file_hover_4f_alpha_smooth.png` | 4×1 | 4 / 12.0 / **false** | `[1.0, 1.0, 2.0, 1.5]` |
| FileConsume | `file_consume_4f_alpha_smooth.png` | 4×1 | 4 / 12.0 / **false** | `[0.5, 0.5, 0.5, 1.0]` |
| Poop | `poop_6f_alpha_smooth.png` | 6×1 | 6 / 6.0 / true | `[0.5, 0.5, 0.0, 0.5, 1.0, 0.5]` |
| Pet | `pet_6f_alpha_smooth.png` | 6×1 | 6 / 10.0 / **false** | `[1.0, 1.5, 1.0, 1.0, 1.0, 0.5]` |

### `sheet_scale` (evolved2) = **1.056**

`BODY_SCALE["haemjji"]["evolved2"] = 1.72`는 **그대로 둔다**(정지 포즈 폴백용).

| 방법 (양쪽 자산 동일 적용) | 정지 | 시트 | 비율 |
|---|---:|---:|---:|
| **코어 몸통 (관·모자 제외, α>0.125)** | 94 | 89 | **1.0562** |
| 전체 실루엣 bbox (α>0.125) | 113 | 104 | 1.0865 |
| 전체 실루엣 bbox (α>0) | 118 | 104 | 1.1346 |

**α>0.125 두 방법의 차이는 2.79%로 목표 1.5%를 넘는다** (evolved는 1.74%였다). 원인은 evolved와
같지만 더 커졌다 — **금관이 추가되면서 머리 위 장식이 더 높아졌고**, 그 장식/몸통 비율이 정지 아트와
시트에서 다르다. 측정 정밀도 문제가 아니라 두 자산의 실제 형태 차이라 좁혀지지 않는다.

**`1.056`(코어 몸통 기준)을 채택**한다 — 프로젝트 정규화 축이 코어 몸통이므로 기준이 일치한다.
전체 실루엣 기준을 원하면 `1.087`이 대응값이다(약 2.8% 크게 렌더된다).
`BODY_CORE_HEIGHT`의 evolved2 감사값(93)을 분자로 쓰면 `93 ÷ 89 = 1.045`가 된다 — 이 세 값
(1.045 / 1.056 / 1.087) 중 어느 것을 쓸지는 `qa-verifier` 확인 후 확정하는 것이 안전하다.

α>0 행이 1.1346으로 부푼 이유도 동일하다 — 정지 아트에 5px 프린지(118 vs 113), 시트엔 없음(104=104).
삐약 오경보와 같은 메커니즘이므로 α>0은 배제한다.

### `airborne` = **Play / Dragged / Fall** · `runtime_sick_mark` = **true**

- Play(제자리 바운스로 발이 뜸) / Dragged(4프레임 공중 매달림) / Fall(4프레임 낙하, 접지 없음) → `airborne: true`
- 나머지 11상태 접지(Land 1프레임은 지면 충격 스쿼시)
- Sick 시트에 **소용돌이 눈·땀방울 등 어지럼 표시가 없다**(프롬프트에서 부유 기호를 처음부터 금지했다)
  → 런타임 `@_@` 라벨 필요: `runtime_sick_mark: true`. 나머지 13상태는 미등록.
- ⚠️ 3티어 공통 한계: `align_y: bottom`이라 `foot_padding`이 전 프레임 12.0 고정 → 화면상 상승분은
  나오지 않는다. 선언은 의미상 정확하고 지금 켜도 회귀 없다.

## 3. 크로마키 = **시안 `#00FFFF`** (재판정)

금관이 추가돼 노란 계열이 늘었으므로 다시 쟀다:

| 키 | idle | eat | happy |
|---|---:|---:|---:|
| **cyan** | **217.3** | **217.7** | **218.7** ✅ |
| green | 210.2 | 210.8 | 211.1 |
| blue | 199.0 | 199.4 | 199.1 |
| magenta | 195.0 | 189.5 | 192.1 |

시안이 여전히 최고지만 **여유가 base(231)보다 줄었다**(217) — 금관·스크롤의 노란빛이 초록/시안 쪽으로
조금 다가온 결과다. 그래도 안전 범위이고, 실제 추출 결과 `chroma_adjacent_pixels` **0~1**로 깨끗하다.

## 4. ⚠️ 설계 판단 — 레퍼런스의 **머핀과 두루마리(계약서)를 모두 제외**했다

정지 아트의 햄왕은 **왼손에 머핀, 오른손에 두루마리**를 들고 있고, **두루마리에는 한글 "계약서"가
쓰여 있다.** 그대로 두면 세 가지가 걸린다:

1. **텍스트는 프롬프트 계약이 명시적으로 금지**한다("no text, labels"). 128px에서는 어차피 뭉개진 얼룩이 된다.
2. **Eat의 음식 소품 금지**와 충돌(머핀).
3. Dragged/Fall의 공중 자세, Poop/FileHover/FileConsume/Pet의 소품 금지와 충돌.

그래서 evolved와 같은 원칙을 적용했다 — **금관·토크·앞치마는 "착용 아이덴티티"로 전 프레임 유지,
머핀과 두루마리는 14상태 전부에서 제외.** 이번엔 이 규칙(`HANDS-EMPTY RULE`)을 **캐릭터 설명에 처음부터
넣어** 14개 프롬프트 전부에 자동 반영되게 했다 — evolved에서 배치 1 이후에 넣느라 2행을 재생성했던
실수를 반복하지 않았고, 결과적으로 **소품 관련 재생성 0회**다.

## 5. 반려 1건 — Pet 포즈가 서로 붙음

Pet 1차본은 6개 포즈가 너무 가까이 붙어 **이웃 포즈끼리 윤곽이 닿아서** 추출이 실패했다:

```text
"ok": false
"pet: could not extract 6 sprite components"
```

그림 자체는 정상이었지만(왕관·앞치마·빈손·만족 표정 모두 정확) 연결 컴포넌트 분리가 안 됐다.
프롬프트 계약의 "overlaps another pose / crosses into a neighboring slot" 위반이다.
액션에 `CRITICAL SPACING`(포즈 사이에 배경이 보이는 넓은 간격, 필요하면 포즈를 조금 작게)을 추가해
**Pet 행만 재생성** → 추출 `ok: true`. 반려본은 `raw/pet.rejected-poses-touching.png`로 보존.

**이 결함은 추출이 스스로 걸러준 유일한 종류다** — 지금까지 겪은 시각 결함(레이아웃 가이드 박스,
부유 기호, 소품 깜빡임)은 전부 추출을 통과했지만, 포즈 붙음은 컴포넌트 수가 안 맞아 하드 실패한다.

## 6. 자체 검수

- [x] 14행 `frames-manifest.ok = true`, errors/warnings 없음
- [x] `edge_pixels` 전 행 **0**
- [x] `chroma_adjacent_pixels` **0~1**
- [x] `foot_padding`/`horizontal_offsets` 길이 == frames, **76프레임 전부 기준선 12.0**
- [x] 금관·셰프 토크·깅엄 밴드·앞치마·쿠키 포켓이 **76프레임 전부 유지**
- [x] **머핀·두루마리·텍스트가 어느 프레임에도 없음** (컨택트 시트 전수 확인)
- [x] Eat 볼주머니 — 프레임 진행에 따라 볼이 부풀어 실루엣이 넓어짐
- [x] 소품 없음 — 파일·응아·손·하트·부유 기호 없음
- [x] Pet(눈 감은 잔잔한 만족) ≠ Play(입 벌린 바운스)
- [x] Walk 실제 보행 — 다리 교대 접지 + 몸통 보브
- [x] 밉맵 + Godot 임포트 14/14
- [~] **1px 파편 2건** — `fall/f3`, `sick/f5`. evolved와 같은 판단으로 통과시킨다(1픽셀 AA 잔여물,
  표시 배율에서 1픽셀 미만). `qa-verifier`가 화면에서 점이 보인다고 하면 해당 행만 재생성하면 된다.
- [ ] 실제 화면 QA 미실시

## 7. 등록 참고

- 상태 키는 base·evolved와 동일.
- **`tiers`에 `"evolved2"`를 추가**하고 `sheet_scale`을 3티어 맵으로 완성한다.
  시트 경로가 `assets/sprites/haemjji_evolved2/`로 다르므로 상태 밑에 tier 한 단이 필요하다.
- 이로써 **햄찌는 3티어 전부 애니메이션 시트를 갖는다** — 정지 포즈 폴백이 더 이상 필요 없다
  (단, 미등록 상태가 생기면 폴백하므로 정지 8장은 3티어 모두 보존해 두었다).

## 8. 제작 기록

`assets/generated/sprites/haemjji_evolved2-v1/` — 삭제 금지.
raw 14(+반려 1) / frames 76 / curated 76 / 아틀라스 / state-sheets 14 / qa 프리뷰.
상태별 시트는 `curated/`의 최종 셀을 1:1 무손실 paste(6f→6×1, 8f→4×2, 4f→4×1).

실행: row 1장 12~15분, 4병렬 4배치(4+4+4+2) + 재생성 1회 = 총 15 row 생성. **OOM 없음**
(배치 사이에 잔류 프로세스를 정리했고, 정리 명령과 배치 실행을 분리했다 — 묶으면 정리가 자기 셸을 죽인다).
추출·compose는 Linux 컨테이너(`runio.py` fcntl 가드 무수정).
