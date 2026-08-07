# 모찌 잔여 4상태 인수인계 — FileHover / FileConsume / Poop / Pet × 3티어

> 작성: sprite-artist / character-pipeline, 2026-08-07
> 제작 기록: `assets/generated/sprites/mochi-extra-v1/`, `mochi_evolved-extra-v1/`, `mochi_evolved2-extra-v1/`
> **스코프**: 4상태 × 3티어 = **12 row**. 이로써 모찌 3티어가 bichon 기준 14상태를 모두 갖춘다.

## 1. 요약

기존 10상태에 더해 `FileHover` / `FileConsume` / `Poop` / `Pet` 4종을 base·evolved·evolved2
세 티어 모두에 추가했다. 셀 규격·기준선·크로마키는 각 티어의 기존 라운드와 동일하게 유지했으므로
**`sheet_scale`은 그대로 쓰면 된다** (아래 §4).

| 티어 | 자산 폴더 | 크로마키 | 추가된 4장 |
|---|---|---|---|
| base | `assets/sprites/mochi/` | 시안 `#00FFFF` | `file_hover_4f` `file_consume_4f` `poop_4f` `pet_4f` |
| evolved | `assets/sprites/mochi_evolved/` | **그린 `#00FF00`** | 〃 |
| evolved2 | `assets/sprites/mochi_evolved2/` | 시안 `#00FFFF` | 〃 |

크로마키는 각 티어의 기존 판정을 그대로 적용했다 — **이번 4상태는 새로운 소재색을 도입하지 않기
때문이다**(§2 참고: 파일·응아를 그리지 않는다). evolved만 그린인 이유는 스틸블루 넥타이가 시안과
충돌해서이며, 그 판정 근거는 `mochi_evolved.handoff.md` §4에 있다.

## 2. ⚠️ 네 상태 모두 "몸만" 그린다 — 코드를 먼저 확인하고 결정했다

bichon 값을 복사하지 않고 **런타임이 무엇을 그리는지 직접 확인**한 뒤 액션을 작성했다:

- **Poop**: `scenes/pet/poop.tscn` + `poop.gd`가 **별도 Node2D 엔티티**다. `_draw()`에서 갈색 원들을
  직접 그려 월드에 스폰되고 클릭하면 청소된다. → **시트에 응아를 그리면 이중으로 나온다.**
  Poop 시트는 힘주기→후련함 포즈만 담았다.
- **FileHover / FileConsume**: `main.gd`가 OS의 `files_dropped` 시그널을 받고, 파일 비주얼은
  드래그 중인 OS 아이콘이다. 펫 스프라이트가 파일을 그리지 않는다. → **시트는 입 벌림(기대) /
  씹기(섭취) 반응만** 담았다.
- **Pet**: 쓰다듬는 손은 그리지 않는다(마우스가 그 자리에 있다).

그래서 네 상태 전부 프롬프트에 "파일/서류/아이콘/응아/더미/손/하트/반짝임/기호를 어떤 프레임에도
그리지 말 것"을 명시했다. base 라운드 Eat에서 음식 소품이 1프레임만 나와 깜빡였던 실패를 반복하지 않으려는 것이다.

## 3. 런타임 등록 실측값

전 상태 공통: **셀 192×208**, **`foot_padding` 12 row 48프레임 전부 `[16.0]×4`**,
그리드 **4×1**, `airborne` **해당 없음(전부 접지)**, `runtime_sick_mark` 해당 없음.

| 상태 | frames / fps / loop | 비고 |
|---|---|---|
| FileHover | 4 / 12.0 / **false** | 입이 점점 벌어지는 비반복 빌드업 |
| FileConsume | 4 / 12.0 / **false** | 씹고 삼킨 뒤 마지막 프레임 만족 표정 |
| Poop | 4 / 6.0 / **true** | 힘주기→후련함 반복 |
| Pet | 4 / 10.0 / **false** | 눈 감고 만족, Play보다 확실히 잔잔함 |

### base (`res://assets/sprites/mochi/`)

| 상태 | 파일 | horizontal_offsets | 몸통 높이 |
|---|---|---|---:|
| FileHover | `file_hover_4f_alpha_smooth.png` | `[-1.0, -2.0, -2.0, -2.0]` | 116~124 |
| FileConsume | `file_consume_4f_alpha_smooth.png` | `[-1.0, -1.0, -1.0, -1.0]` | 122~123 |
| Poop | `poop_4f_alpha_smooth.png` | `[1.0, 0.0, -1.0, -1.0]` | 85~125 |
| Pet | `pet_4f_alpha_smooth.png` | `[-2.0, -2.0, -1.0, -2.0]` | 96~126 |

### evolved (`res://assets/sprites/mochi_evolved/`)

| 상태 | 파일 | horizontal_offsets | 몸통 높이 |
|---|---|---|---:|
| FileHover | `file_hover_4f_alpha_smooth.png` | `[0.0, 0.0, 0.0, 0.0]` | 159~159 |
| FileConsume | `file_consume_4f_alpha_smooth.png` | `[0.0, 0.0, 0.0, 0.0]` | 153~154 |
| Poop | `poop_4f_alpha_smooth.png` | `[0.0, 0.0, 0.0, 0.0]` | 141~173 |
| Pet | `pet_4f_alpha_smooth.png` | `[-1.0, 0.0, 0.0, -1.0]` | 97~158 |

### evolved2 (`res://assets/sprites/mochi_evolved2/`)

| 상태 | 파일 | horizontal_offsets | 몸통 높이 |
|---|---|---|---:|
| FileHover | `file_hover_4f_alpha_smooth.png` | `[0.0, 0.0, 0.0, -0.5]` | 174~176 |
| FileConsume | `file_consume_4f_alpha_smooth.png` | `[0.0, 0.0, 0.0, 0.0]` | 168~170 |
| Poop | `poop_4f_alpha_smooth.png` | `[0.0, 0.0, 0.0, 0.0]` | 144~175 |
| Pet | `pet_4f_alpha_smooth.png` | `[0.0, 0.0, 0.0, 0.0]` | 123~176 |

## 4. `sheet_scale` — 변경 없음

```gdscript
"sheet_scale": {"base": 0.605, "evolved": 0.753, "evolved2": 0.653},   // 그대로
```

`sheet_scale`은 **티어당 하나**이고 셀 규격(192×208)과 아트의 셀 내 비율이 기존 10상태와 같으므로
재계산이 필요 없다. 실측 몸통 높이가 각 티어 기존 상태의 범위 안에 들어오는 것으로 확인했다:

| 티어 | 기존 idle 휴지프레임 | 신규 4상태 범위 |
|---|---:|---|
| base | 129 | 85~126 |
| evolved | 158 | 97~173 |
| evolved2 | 176 | 123~176 |

`BODY_SCALE`도 손대지 않는다.

## 5. 반려 1건 — base/FileHover (레이아웃 가이드가 그려짐)

1차 생성본의 **3번 프레임에 캐릭터 대신 레이아웃 가이드 상자가 그려졌다** — 흰 배경에 격자선이 있고
그 안에 아주 작은 모찌가 들어간 그림이었다. 프롬프트 계약이 금지하는 "guide boxes / visible grids"
그대로다.

**추출 QA는 이걸 못 잡는다** — 가이드 상자도 유효한 불투명 컴포넌트라 `ok: true`, `edge_pixels 0`,
`chroma_adjacent 0`으로 통과했다. 컨택트 시트 육안 검수에서만 드러났다. 프레임 1장만 고칠 수 없으므로
계약대로 **행 전체를 재생성**했고, 재생성본은 입이 단계적으로 벌어지는 정상 시퀀스다.
반려본은 `mochi-extra-v1/raw/file_hover.rejected-guide-box.png`로 보존했다.

나머지 11 row는 1차에 통과했다.

## 6. 자체 검수

- [x] 12 row 전부 `frames-manifest.ok = true`, errors/warnings 없음
- [x] **`edge_pixels` 전 row 0**
- [x] `chroma_adjacent_pixels` 0~10 (evolved/file_consume 10이 최대 — 기존 티어 land 수준)
- [x] `foot_padding`/`horizontal_offsets` 길이 == frames (전 row 4)
- [x] **48프레임 전부 기준선 16.0** — 기존 10상태와 동일
- [x] 티어별 아이덴티티 유지 — evolved 안경+넥타이, evolved2 안경+턱시도+나비넥타이+금배지 2개
- [x] **파일·응아·손·기호 등 소품이 어느 프레임에도 없음** (컨택트 시트 확인)
- [x] Pet이 Play보다 잔잔함 — Pet은 눈 감은 만족+가벼운 눌림, Play는 입 벌린 바운스
- [x] 밉맵 + Godot 4.4.1 헤드리스 임포트 검증 (12장 전부 uid·mipmaps 확인)
- [ ] 실제 화면 QA 미실시 — `qa-verifier` 담당

## 7. 등록 시 참고

- 런타임 키는 bichon과 같은 `FileHover` / `FileConsume` / `Poop` / `Pet`을 쓰면 된다.
- **`Pet`과 `Play`는 별개 상태다.** base는 `happy_4f_...`가 `Play`에 등록돼 있고, 이번에 추가된
  `pet_4f_...`가 `Pet`이다. evolved/evolved2는 `play_4f_...` + `pet_4f_...`로 파일명이 갈린다.
- 이 4상태는 `airborne`을 **달지 않는다**(전부 접지).
- bichon의 `visible_extent`/`foot_padding` 값을 가져오지 않았다 — 위 값은 전부 모찌 자체 실측이다.
  (bichon Poop은 6프레임 3×2, FileConsume은 8프레임 4×2지만, 모찌는 기존 10상태와 같은 4프레임
  4×1 규격으로 통일했다.)

## 8. 제작 기록

3개 런 디렉토리 모두 보존한다. 구조는 기존 라운드와 동일(요청 SSoT / raw 4 / frames 16 /
curated 16 / 아틀라스 / qa 프리뷰). 상태별 시트는 `curated/`의 최종 셀을 1:1 무손실 paste.

실행: row 1장 12~15분, 티어별 4병렬 1배치 × 3 + 반려 재생성 1회 = 총 13 row 생성.
