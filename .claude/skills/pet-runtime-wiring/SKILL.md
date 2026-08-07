---
name: pet-runtime-wiring
description: aegis_pet 캐릭터 스펙과 스프라이트를 characters.gd/balance.gd/dialog.gd/pet.gd 4개 GDScript SSoT 파일에 등록하는 방법. "코드에 등록해줘", "애니메이션 카탈로그 추가", "캐릭터 딕셔너리에 넣어줘" 요청 시 사용. gd-integrator 에이전트가 character-pipeline 팀에서 사용한다.
---

# 펫 런타임 등록

## 이제 모든 캐릭터가 같은 경로: 애니메이션 카탈로그 등록

**(2026-08-06 갱신) "정지 이미지 포즈는 `pet.gd`를 안 건드려도 된다"는 예전 규칙은 폐지됐다.** 모든 캐릭터(신규든 레거시 업그레이드든)는 `pet-sprite-production`이 정한 10개 상태(Idle/Walk/Sleep/Eat/Sick/Sulk/Happy/Dragged/Fall/Land)를 `pet.gd`의 애니메이션 카탈로그에 등록한다. `assets/sprites/chars/<id>/`의 정지 이미지 8장 + `POSES` 배열 경로는 **레거시 12종이 아직 업그레이드되기 전까지만 유효한 구경로**이며, 신규 캐릭터에는 쓰지 않는다.

**절대 하지 말 것**: 10개 중 일부만 애니메이션 시트로 등록하고 나머지를 비워두는 것(정지 이미지로도 안 채우는 것). 실제로 `ppyojjok`이 이렇게 됐다 — Idle 하나만 등록했는데 나머지 9개가 화면에 아무것도 없거나 Idle이 대신 재생돼 기존 캐릭터보다 뚜렷이 낮은 퀄리티였다. 스펙에 스코프 축소가 명시돼 있지 않다면 10개 전부를 등록한다.

**`pet.gd`가 캐릭터마다 거의 동일한 `<CHARACTER>_ANIMATIONS` 상수를 반복해서 쌓아가는 구조라, 캐릭터가 늘어날수록(13종 목표) 유지보수가 부담스러워진다.** 두 번째 캐릭터를 이 방식으로 등록하게 되면(레거시 업그레이드 첫 건 포함), 개별 상수 대신 `CHARACTER_ANIMATIONS := {species: {state: {...}}}` 형태의 종족별 단일 딕셔너리로 통합할지 검토하고, 이건 기존 코드 스타일을 벗어나는 아키텍처 변경이므로 진행 전 사용자에게 확인을 구한다.

## 크기 규칙 (2026-08-07 개정): 성장하면 커지고, 진화해도 커진다

**크기를 바꾸는 축이 둘이다: `STAGE_SCALE`(성장) × `Characters.TIER_SIZE_LADDER`(진화).**
예전 규칙("진화는 크기가 아닌 모양만 바꾼다")은 사용자가 명시적으로 철회했다.

- 성장: 단계마다 약 +19% (egg → baby → child → adult, 단조증가).
- 진화: 같은 성장단계 기준 **base 108 / evolved 118 / evolved2 128** (약 +9%/단계) = `TIER_SIZE_LADDER {1.0, 1.0926, 1.1852}`.
- ⚠️ **"진화 아기 > 이전 성체"는 성립하지 않는다 — 의도된 것이다.** 성장 폭(1.406배)이 진화 폭(1.0926배)보다 커서 9단계 전역 순서는 수학적으로 불가능하고, 사용자가 "순서 규칙은 느슨하게"로 결정했다. 테스트도 같은 성장단계 안의 진화 순서만 검사한다.

`BODY_SCALE`/`sheet_scale`은 여전히 "원본 아트마다 캔버스를 차지하는 비율이 다른 것"을 상쇄하는 정규화 보정값이다. 다만 정규화 **목표가 티어별로 달라졌다**: 비예외 종족의 목표 몸통 = `2 × BODY_SCALE_TARGET_TORSO × TIER_SIZE_LADDER[tier]` = 160 / 174.8 / 189.6. 이 계산은 `Characters.get_expected_torso()` 한 곳에만 있다 — 티어 목표를 손으로 곱해 쓰지 마라.

### 캔버스 크기는 티어마다 다르다 + 확대 렌더 금지

- **현재 캔버스: base/egg = 128px, evolved/evolved2 = 256px** (2026-08-07 해상도 복원). 앞으로도 티어별로 달라질 수 있다.
- 그래서 `pet.gd`의 **위치 계산은 절대 상수를 쓰면 안 된다.** 반드시 `_frame_size`(= `_sprite.texture.get_size()` 실측)를 쓰는 `_sprite_anchor()`를 거쳐라. `STATIC_POSE_FALLBACK_SIZE`(128.0)는 텍스처 로드 실패 시 폴백 전용이며, 이 상수를 위치 계산에 곱하던 코드가 256px 티어를 화면에서 크게 어긋나게 했다.
- **새 아트는 확대 렌더가 되지 않게 원본 해상도를 확보한다: `BODY_SCALE × STAGE_SCALE ≤ 1.0`.** 넘으면 원본에 없는 픽셀을 보간으로 만들어 뿌옇게 보인다(kong/evolved가 1.22배로 그랬다). 테스트가 12종 × 3티어 × 3성장단계 = 108조합을 전부 검사한다.
- **`BODY_CORE_HEIGHT`는 그 티어 캔버스 기준 픽셀값이다.** 256px 티어의 값이 128px 티어의 약 2배인 것은 정상이다 — 두 티어의 값을 직접 비교하지 마라(비교는 `BODY_CORE_HEIGHT × BODY_SCALE`인 `expected_torso`로 한다).
- 아트를 다른 해상도로 다시 뽑으면 **`BODY_SCALE`은 art_ratio로 나누고 `BODY_CORE_HEIGHT`는 곱한다**(곱인 `expected_torso`는 불변). 정지 아트만 바뀌고 애니메이션 시트가 그대로면 **`sheet_scale`에 같은 art_ratio를 곱해야 한다** — sheet_scale은 "그 티어 정지 아트 몸통 / 시트 몸통" 비율이라 분자만 커지기 때문이다.

**(2026-08-07 기준 변경) 정규화 기준은 전체 실루엣이 아니라 몸통(코어 덩어리)이다.** 예전 기준(`BODY_SCALE_TARGET_HEIGHT = 111.5`, 알파 바운딩박스 높이)은 실루엣을 223px로 균일하게 맞췄지만, 그 박스에 귀·꼬리·불꽃·김·촉수·소품이 캐릭터마다 다르게 섞여 실제 몸 덩어리는 2배까지 차이 났다. 지금은 `Characters.BODY_CORE_HEIGHT`(36장 전수 실측, `docs/02-design/characters/body-size-audit.md`)를 `BODY_SCALE_TARGET_TORSO = 80.0`으로 정규화한다: `BODY_SCALE = 2 × 80.0 ÷ 코어높이`. **실루엣은 이제 균일하지 않다(adult 기준 72~131px)** — 부속물이 많은 종족일수록 실루엣이 크며, 이는 의도된 결과다.

화면상 몸통 높이 = `코어 몸통 높이 × _base_scale.y` (아래 표는 **base 티어** 기준 — evolved는 ×1.0926, evolved2는 ×1.1852):

| stage | STAGE_SCALE | 몸통 높이 |
|---|---|---|
| egg | 0.58 | 43.5px (전 종족 공통, BODY_SCALE 미적용) |
| baby | 0.32 | 51.2px |
| child | 0.38 | 60.8px |
| adult | 0.45 | 72.0px |

새 캐릭터를 등록할 때 `BODY_SCALE`은 **idle 알파 바운딩박스가 아니라 코어 몸통 실측값**으로 잡고, `BODY_CORE_HEIGHT`에 그 실측값을 같이 등록한다(테스트가 두 표의 일관성을 잠근다).

지켜야 할 세 가지:

1. **egg는 `BODY_SCALE`을 곱하지 않는다.** egg 아트는 전 종족 공통 단일 이미지라 정규화 보정을 곱할 이유가 없다. 곱하면 종족마다 알 크기가 3.1배까지 벌어지고 adult보다 커진다(2026-08-07 수정). `_base_scale` 계산은 반드시 `_stage_scale()` × `_static_body_scale()` 헬퍼를 거친다 — 새 계산 지점을 추가할 때 이 분기를 빠뜨리는 것이 바로 그 버그의 원인이었다.
2. **`STAGE_SCALE`은 단조증가여야 한다.** 한때 baby와 child가 둘 다 0.378이라 4단계 중 실질 3단계뿐이었다. egg는 BODY_SCALE을 안 곱하므로 몸통 정규화 목표를 바꿀 때마다 egg가 baby를 추월하지 않는지 다시 확인해야 한다(2026-08-07 몸통 기준 전환 시 egg 0.72 → 0.58).
3. **진화 사다리는 `TIER_SIZE_LADDER` 한 곳에만 둔다.** `BODY_SCALE` 표의 evolved/evolved2 값에는 이미 곱해져 들어가 있으므로 런타임에서 또 곱하지 마라(이중 적용). 예외 3종(mochi/mundeok/tokki)은 `TORSO_NORMALIZATION_EXEMPT`의 `expected_torso`에 사다리가 반영돼 있다.
4. **애니메이션 시트를 등록하면 `sheet_scale`을 반드시 검토한다.** 셀 크기가 정지 포즈 캔버스와 같아도(128×128) 그 안에 그려진 몸통 높이가 다르면 `BODY_SCALE`이 그대로 어긋난다 — 삐약이 이 이유로 진화 시 몸통이 12.7% 커졌다. 셀 크기가 같으니 보정이 필요 없다고 **넘겨짚지 말고 실측한다.**

### `sheet_scale` 계산법

`ANIMATED_POSE_OVERRIDES[species]["sheet_scale"]`는 **티어별 딕셔너리**다(단일 숫자도 하위호환으로 허용 — 모든 티어에 같은 값).

```
sheet_scale[tier] = (그 티어 정지 idle.png 몸통 높이) / (그 티어 시트 idle 0번 프레임 몸통 높이)
```

0번 프레임(정지 프레임) 기준인 것이 규약이다 — 최댓값이나 평균을 쓰면 기존 등록값(mochi)과 어긋난다. 종족당 하나가 아니라 **티어마다 따로 재야 한다**: 티어별로 정지 아트 크기와 시트 몸통 높이가 각각 다르다.

Sleep처럼 웅크리는 상태는 이 보정 후에도 Idle보다 낮게 나오는데, 그건 아트 의도(스쿼시)이지 배선 오류가 아니다. **보정은 Idle 기준으로만 잡고, 나머지 상태는 원본 아트의 형태 차이를 그대로 남긴다** — 상태마다 배율을 따로 맞추면 몸통이 늘었다 줄었다 하는 것처럼 보인다.

이 규칙은 `tests/run_tests.gd`의 크기 규칙 테스트로 잠겨 있다: 성장 단조증가 / egg 종족 무관 동일 / **같은 성장단계에서 base < evolved < evolved2 진화 사다리** / **확대 렌더 금지 108조합** / **티어별 캔버스 크기(128 vs 256)와 발 접지** / 삐약 애니메이션 진화 ±5%.

## 4개 SSoT와 각각의 역할

| 파일 | 확장 대상 | 참고할 기존 캐릭터 예시 |
|---|---|---|
| `scripts/data/characters.gd` | `CHARACTERS`, `BODY_SCALE`, `EVOLVED_NAMES`, `EVOLVED_2_NAMES`, (선택) `HATCH_WEIGHTS` | `bichon` 항목 |
| `scripts/data/balance.gd` | `EVOLUTION`, `EVOLUTION_2` | `bichon: {"metric": "files_dropped", ...}` |
| `scripts/data/dialog.gd` | `BY_CHARACTER` | `bichon` 항목 (base/e1/e2 구조) |
| `scenes/pet/pet.gd` | `<CHARACTER>_ANIMATIONS` 상수(또는 통합 딕셔너리) + `_animation_catalog()`/`_is_animated_pet()` 분기, 10개 상태 전부 | `BICHON_ANIMATIONS`, `_is_bichon()` |
| `assets/sprites/chars/<id>/` (+`_evolved`/`_evolved2`) | **레거시 전용, 업그레이드 전까지만**: 정지 이미지 8장 | `ddungsil`, `mochi` 등 업그레이드 대기 중인 캐릭터 |

이 파일들 외(특히 `autoload/pet_state.gd`의 진화 판정 로직, `scenes/pet/pet.gd`의 상태 전이 함수 본문)은 **원칙적으로 건드리지 않는다.** 새 `special` 메커니즘이나 새 진화 `metric`처럼 로직 확장이 필요한 경우만 예외이며, 이때는 스코프가 커지므로 먼저 사용자 확인을 구한다.

## `pet.gd`는 매번 다시 읽는다

`pet.gd`는 이 프로젝트에서 가장 자주 바뀌는 파일이다(여러 캐릭터 애니메이션 작업이 동시에 진행되곤 한다). 작업 시작 시점의 `_is_animated_pet()`/`_animation_catalog()` 구현을 반드시 다시 읽고, 그 시점의 분기 스타일을 그대로 따라간다. 예를 들어 이미 여러 캐릭터가 각자의 `_is_<species>()` 헬퍼와 `_animation_catalog()` 내부 `match`/`if` 분기로 등록되어 있다면 같은 패턴으로 추가하고, 새로운 스타일(예: 딕셔너리 매핑)을 임의로 도입하지 않는다.

## 애니메이션 카탈로그 키 계약

각 상태(`Idle`, `Walk`, ... )는 다음 키를 상황에 맞게 채운 `Dictionary`다. 원본 계약: `docs/02-design/pet-sprite-production-guide.md` §4.3.

| 키 | 필수 여부 | 검증 규칙 |
|---|---|---|
| `path` | 항상 | 파일과 `.import`가 실제로 존재 |
| `columns`, `rows` | 항상 | 실제 시트 분할과 일치 |
| `frames`, `fps`, `loop` | 항상 | `frames`는 논리 프레임 수(시트 칸 수와 다를 수 있음) |
| `visible_extent` | 항상 | 양수, 상태 간 눈에 보이는 몸통 크기가 일관되도록 캘리브레이션 |
| `foot_padding` | 항상 | 배열 길이 == `frames` |
| `horizontal_offsets` | Walk 제외 모든 상태 | 배열 길이 == `frames`. 좌우 반전 시 부호도 반전 |
| `sprite_frame_sequence` | 셀 재사용이 필요할 때만(예: Idle의 깜박임 루프) | 각 값이 `0 <= v < columns*rows` |
| `airborne` | 공중 동작(Play/Dragged/Fall 등)에 **필수** | `true`일 때만 프레임 간 `foot_padding` 차이가 화면상 상승분이 된다 |
| `ground_padding` | `airborne`일 때 선택 | 접지 기준 `foot_padding` 값. 생략하면 배열 최솟값 |
| `runtime_sick_mark` | `Sick` 상태에 **필수 판단** | 시트에 어지럼 표시가 없으면 `true`, 그림에 있으면 생략(이중 표시 방지) |

### `airborne` — 공중 동작은 반드시 선언한다

기본(접지) 처리는 **매 프레임 발을 지면 y=0에 재고정**한다. 걷기처럼 프레임마다 바운딩 박스가 달라져도 발이 지면에 붙어 있게 하는 올바른 동작이지만, 점프·매달림·낙하처럼 `foot_padding`의 프레임 간 변화가 "지면에서 뜬 높이"를 뜻하는 상태에 그대로 적용하면 **의도한 상승분을 정확히 상쇄**해 화면에서 전혀 움직이지 않는다(2026-08-06 삐약 Play/Dragged/Fall 블로커, 화면상 span 0px).

- `"airborne": true`를 붙이면 런타임이 `ground_padding` 하나로만 고정 보정하고, 나머지 차이를 화면상 상승분으로 남긴다.
- 값 규약: `foot_padding` 최솟값 = 접지 프레임. 애니메이션에 접지 프레임이 하나도 없으면 `ground_padding`을 명시한다.
- 판정 기준: 그 상태에서 캐릭터의 **발이 지면을 떠나는가**. 뜨면 `airborne`, 아니면 붙이지 않는다. `bichon`의 Play/Dragged/Fall/Land는 붙이지 않는다 — 그 시트의 `foot_padding` 변동은 상승분이 아니라 프레임별 바운딩 박스 차이이고, 출시 후 정상 동작 중이다.
- 검증: `_sprite.position.y`가 변하는지 보는 것으로는 부족하다(공중 상태는 오히려 고정된다). `pet.current_frame_foot_offset()`(0 = 지면, 음수 = 공중)으로 프레임 간 span > 0을 확인한다.

### `runtime_sick_mark` — Sick의 아픔 신호는 시트나 라벨 중 정확히 하나

`sick_state.gd`는 `pet.animated_pose_option("Sick", "runtime_sick_mark", false)` 값으로 `@_@` 라벨 표시를 결정한다. 정지 포즈 `sick.png`에는 보통 소용돌이 눈·부유 기호가 그려져 있는데, 애니메이션 시트로 교체하면서 그 표시가 빠지는 경우가 많다. 이때 키를 안 넣으면 아픔 신호가 아무 데도 남지 않아 **Sick이 Sulk와 화면상 구분되지 않는다**(2026-08-06 모찌 회귀). 시트를 실제로 열어 보고 판단한다: 표시 없음 → `"runtime_sick_mark": true`, 표시 있음 → 키 생략(넣으면 이중 표시).

## 절차

1. `sprite-artist`가 넘긴 실측값 표를 그대로 각 상태 딕셔너리로 옮긴다 — 값을 추정하거나 반올림하지 않는다. 옮기면서 상태마다 (a) 공중 동작인가(`airborne`), (b) Sick 시트에 어지럼 표시가 있는가(`runtime_sick_mark`)를 판단해 같이 채운다.
2. `characters.gd`에 `CHARACTERS[id]`, `BODY_SCALE[id]`, `EVOLVED_NAMES[id]`, `EVOLVED_2_NAMES[id]`를 추가한다. `BODY_SCALE`은 sprite-artist가 실측한 idle 알파 바운딩박스 기준값으로 채운다(스펙의 `1.0` 초안을 그대로 두지 않는다).
3. `balance.gd`에 `EVOLUTION[id]`, `EVOLUTION_2[id]`를 스펙 그대로 추가한다.
4. `dialog.gd`에 `BY_CHARACTER[id]`를 스펙의 base/e1/e2 대사로 추가한다. `EVOLUTION`/`EVOLUTION_2`에 등록된 단계와 정확히 일치하는 단계만 만든다(1차 진화 조건이 없는데 `e1`을 만들면 사용되지 않는 죽은 데이터가 된다).
5. `pet.gd`에 `<CHARACTER>_ANIMATIONS` 상수(또는 이미 통합 딕셔너리로 전환했다면 그 안에 새 종족 항목)를 추가하고, 10개 상태(Idle/Walk/Sleep/Eat/Sick/Sulk/Happy/Dragged/Fall/Land)를 전부 채운다. 일부 상태만 넣고 나머지를 비워두지 않는다 — 스펙에 스코프 축소 표시가 없다면 10개 완비가 기본 가정이다. `_animation_catalog()`/`_is_animated_pet()` 분기에 새 종족을 연결한다.
6. `.import` 파일에 밉맵 축소 자산이면 `mipmaps/generate=true`가 있는지 확인한다 (없으면 Godot 에디터로 해당 텍스처를 재임포트하거나 `.import` 파일을 직접 보정).
7. **(선택)** sprite-artist가 먹이/간식 소품(`food_feed.png`/`food_snack.png`)을 만들었으면 `characters.gd`의 `FOOD_PROPS[id] = {"feed": "res://assets/sprites/<id>/food_feed.png", "snack": "res://assets/sprites/<id>/food_snack.png"}`에 등록한다. 이건 `pet.gd`를 건드리지 않는다 — `show_food_prop()`이 이 테이블만 조회한다. 소품이 없는 캐릭터는 이 항목 자체를 생략해도 되며(하위 호환), FAIL 사유가 아니다.

## 산출물

4개 파일에 대한 diff + 변경한 상수/키 목록(파일:라인). `qa-verifier`가 이 목록을 기준으로 매니페스트 테스트를 작성한다.
