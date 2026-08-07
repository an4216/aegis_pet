---
name: pet-character-spec
description: aegis_pet 신규 캐릭터의 밸런스·진화조건·대사 스펙을 작성하는 방법. "캐릭터 기획", "진화 조건 정해줘", "대사 써줘", "새 캐릭터 스펙" 요청 시 사용. char-designer 에이전트가 character-pipeline 팀에서 이 스킬을 사용한다.
---

# 펫 캐릭터 스펙 작성

## 크기 규칙 (2026-08-07 개정): 성장하면 커지고, 진화해도 커진다

크기를 바꾸는 축이 **둘**이다. 예전 규칙("진화하면 크기가 아닌 모양만 바뀐다")은 사용자가 명시적으로 철회했다.

| 축 | 값 | 크기에 미치는 영향 |
|---|---|---|
| 성장 stage | egg → baby → child → adult | **단조증가**. 단계마다 약 +19% 커진다 |
| 진화 tier | base → evolved → evolved2 | **커진다**. 화면상 몸통 기준 108 / 118 / 128 (약 +9%/단계) |

- 진화 배율은 `Characters.TIER_SIZE_LADDER = {base 1.0, evolved 1.0926, evolved2 1.1852}` 하나가 SSoT다. 스펙에 크기 숫자를 따로 쓰지 마라.
- **"진화 아기 > 이전 성체"는 성립하지 않는다 — 의도된 것이다.** 성장 폭(baby→adult 1.406배)이 진화 폭(1.0926배)보다 커서 9단계 전역 순서는 수학적으로 불가능하고, 사용자가 "순서 규칙은 느슨하게"로 결정했다. 보장되는 것은 **같은 성장단계 안에서의 진화 순서**뿐이다.
- 스펙에 "덩치가 두 배가 된다" 같은 표현은 여전히 쓰지 마라 — 커지는 폭은 9%로 고정이며 종족이 정할 수 없다. 그 이상의 진화 연출은 모양(뿔·날개·색)으로 표현한다.
- 진화 티어별 아트를 그릴 때 **몸통 높이를 세 티어 모두 같게 그린다.** 크기 차이는 아트가 아니라 위 사다리(런타임 배율)가 만든다.
- egg는 전 종족 공통 아트(`assets/sprites/chars/egg/`)라 **모든 종족의 알이 화면에서 정확히 같은 크기**여야 한다. 종족별 알 크기 차이는 버그다.

### 캔버스 해상도 규칙 (확대 렌더 금지)

- **아트 캔버스 크기는 티어마다 다를 수 있다.** 현재: base/egg = 128px, evolved/evolved2 = 256px (2026-08-07 해상도 복원). 캔버스가 같다고 가정하는 코드·실측은 전부 틀린다.
- 새 아트를 만들 땐 **확대 렌더가 되지 않도록 원본 해상도를 확보한다**: `BODY_SCALE × STAGE_SCALE ≤ 1.0`. 넘으면 원본에 없는 픽셀을 보간으로 만들어내 화면이 뿌옇게 보이고(실제로 kong/evolved가 1.22배로 그랬다), 헤드리스 테스트가 108개 조합 전부를 검사해 실패시킨다.
- 캔버스 여백이 남아도 **원본을 확대해 채우지 마라.** 허용 연산은 평행이동과 축소뿐이다.

이 규칙은 `tests/run_tests.gd`의 크기 규칙 테스트(성장 단조증가 / egg 종족 무관 동일 / 같은 성장단계 진화 사다리 / 확대 렌더 금지 108조합 / 캔버스 크기·발 접지)로 잠겨 있다.

## 애니메이션 등급 — 이제 단 하나의 기준: 모든 포즈가 애니메이션 시트

**(2026-08-06 기준 갱신) "정지 이미지 포즈"는 더 이상 유효한 신규 캐릭터 등급이 아니다.** 예전에는 포즈 캐릭터(정지 이미지 8장)와 풀 애니메이션 펫(bichon류)을 별개 등급으로 뒀지만, 사용자가 "포즈 각각이 다 애니메이션 스프라이트여야 한다"고 확정했다 — 이제부터 만드는 모든 신규 캐릭터는 예외 없이 **아래 10개 상태 전부를 애니메이션 시트(여러 프레임)로** 만든다. 기존 12종(mochi, ppiyak 등, 정지 이미지 8장짜리)은 이 기준에 못 미치는 **레거시**이며, 순차적으로 애니메이션으로 업그레이드 대상이다 — `character-pipeline`의 "레거시 캐릭터 업그레이드" 절차를 쓴다.

| 상태 | 의미 | 비고 |
|---|---|---|
| `Idle` | 정지·휴식 | |
| `Walk` | 이동 | 예전 walk1/walk2 정지 이미지 2장이 이제 하나의 애니메이션 시트로 합쳐진다 |
| `Sleep` | 잠 | |
| `Eat` | 먹이/간식 반응 | |
| `Sick` | 아픔 | |
| `Sulk` | 시무룩 | |
| `Happy`(=Pet) | 쓰다듬기 반응 | 기존 `happy` 포즈에 대응 |
| `Dragged` | 마우스로 잡혀서 끌려다니는 동안 | 신규 — bichon `Dragged` 그대로 |
| `Fall` | 마우스를 놓아서 떨어지는 동안 | 신규 — bichon `Fall` 그대로 |
| `Land` | 떨어진 뒤 착지 | 신규 — bichon `Land` 그대로, `loop: false` |

`Play`/`FileHover`/`FileConsume`/`Poop` 등 bichon에만 있던 나머지 상태는 이번 기준 통일에는 포함하지 않는다 — 컨셉상 자연스러우면 추가해도 되지만 필수는 아니다. 위 10개는 예외 없이 필수다.

**컨셉은 10개 상태(특히 Walk, Dragged, Fall)가 자연스럽게 나올 수 있는 것으로 고른다.** 다리가 없거나 스스로 이동하지 않는 컨셉(화분, 사물 등)이라면 Walk를 어떻게 표현할지(예: 제자리에서 흔들리는 waddle 애니메이션) 스펙에 명시한다. 걷기 프레임을 아예 안 만드는 선택지는 없다.

**파이프라인 테스트·프로토타입처럼 의도적으로 스코프를 줄이는 경우**, 스펙 최상단에 `> 상태: 스코프 축소 — 테스트용, N/10 상태 미완성` 처럼 눈에 띄게 표시하고, 어떤 상태가 비어있는지 나열한다. 이 표시가 없으면 `gd-integrator`와 `qa-verifier`는 10개 상태 완비를 기본 가정으로 검증한다.

## 왜 이 형식을 지켜야 하는가

aegis_pet은 "로직은 데이터 테이블만 조회한다"는 원칙(`scripts/data/characters.gd` 1행)으로 짜여 있다. 즉 캐릭터 하나를 추가하는 일은 새 로직을 쓰는 게 아니라, 4개의 GDScript 딕셔너리(`CHARACTERS`, `EVOLUTION`/`EVOLUTION_2`, `BY_CHARACTER`)에 정확한 형태로 항목을 추가하는 일이다. 스펙을 미리 이 딕셔너리 모양대로 확정해두면, 통합 단계에서 재작업이 없다.

## 스펙에 반드시 담을 항목

`scripts/data/characters.gd`, `scripts/data/balance.gd`를 직접 읽고 아래 표를 캐릭터 값으로 채운다 (기존 캐릭터 값과 겹치지 않게).

| 필드 | 위치 | 예시 (bichon) |
|---|---|---|
| `character_id` | 전체 SSoT의 키 | `"bichon"` |
| `name_kr` | `CHARACTERS[id]["name_kr"]` | `"해솔"` |
| `rarity` | `CHARACTERS[id]["rarity"]` (`common`/`uncommon`/`rare`) | `"uncommon"` |
| `stat_modifiers` | 배율. 키는 `hunger_decay`/`happiness_decay`/`energy_decay`/`sleep_recovery`/`move_speed`/`poop_penalty`/`all_decay` 중 선택 | `{"happiness_decay": 0.8}` |
| `care_modifiers` | 배율. 키는 `feed`/`snack`/`play`/`pet` | `{"pet": 1.3}` |
| `special` | 특수 메커니즘 태그. 기존 태그(`morning_speed`, `self_snack`, `healing_sleep`, `tsundere_pet`, `caffeine_rush`, `late_sleep`, `burnout_link`, `weekend_boost`, `after_work_boost`) 재사용 또는 신규 제안 — 신규면 로직 구현이 필요하므로 `gd-integrator`에게 스코프 확대를 미리 알린다 | `[]` |
| `evolved_name` / `evolved_2_name` | `EVOLVED_NAMES`/`EVOLVED_2_NAMES` | `"달솔"` / `"별솔"` |
| `EVOLUTION.metric/amount/hint` | 1차 진화 조건 | `{"metric": "files_dropped", "amount": 15, "hint": "파일 15개 정리해주기"}` |
| `EVOLUTION_2.metric/amount/hint` | 최종 진화 조건 (같은 metric, 상향된 amount) | `{"metric": "files_dropped", "amount": 60, ...}` |
| `body_scale` (초안) | `BODY_SCALE[id]` | `{"base": 1.0, "evolved": 1.0, "evolved2": 1.0}` — sprite-artist 실측 후 갱신 |
| `hatch_weight` (선택) | `HATCH_WEIGHTS` | 없으면 "해당 없음" |

## 진화 지표(metric) 고르는 법

기존 지표는 모두 "업무 중 자연스럽게 쌓이는 활동 로그"다 — 새 지표를 만들 때도 이 원칙을 지킨다:
- 입력 기반: `kb`(키보드 입력 수), `mouse`(클릭 수)
- 시간 기반: `active_sec`, `friday_active_sec`
- 케어 기반: `feed`, `feed_snack`, `pet_care`
- 이벤트 카운트 기반: `todos_done`, `pomodoro_done`, `files_dropped`, `late_shutdowns`
- 날짜 기반: `distinct_days`(누적, 중복 날 제외), `consecutive_days`(연속 출근)

새 지표를 제안하려면 `autoload/pet_state.gd`의 `add_input_delta`/`note_activity_day`/`note_todo_complete` 계열 함수에 새 카운터를 추가해야 하므로, 이 경우 `gd-integrator`에게 로직 코드 변경이 필요함을 미리 알린다.

## 대사 스펙 — 테스트가 강제하는 최소 기준

`tests/run_tests.gd`의 `_test_dialog_evolution_pools`가 자동으로 모든 캐릭터를 검사한다. 통과 기준:
- 캐릭터가 등장하는 모든 단계(`base` 항상, `EVOLUTION`에 있으면 `+e1`, `EVOLUTION_2`에 있으면 `+e2`)마다:
  - `random` 배열 3줄 이상
  - `random` 외 트리거 override 3개 이상 (`monday_morning`/`tuesday`/`wednesday`/`thursday`/`friday_afternoon`/`before_lunch`/`three_pm`/`quitting_time`/`overtime`/`payday`/`long_no_break` 중에서 고른다 — `scripts/data/dialog.gd`의 `COMMON`에 전체 목록과 톤이 있다)
- 대사 톤: 캐릭터 관점의 1인칭 반려동물 말투, 업무 소재를 가볍게 놀리되 비난하지 않음. 진화 단계가 올라갈수록(`base`→`e1`→`e2`) 캐릭터의 성장/자신감이 서사적으로 드러나야 한다 (예: mochi는 `흘러내리는데 잘 살잖아` → 진화하며 톤이 여유로워짐).

## 산출물

`docs/02-design/characters/{character_id}.spec.md`에 위 표 전체 + 대사 초안(단계별 random 3줄+ / 트리거 3개+)을 마크다운으로 작성한다. 이 파일이 `sprite-artist`와 `gd-integrator`의 유일한 입력이 되므로, 여기 없는 값은 존재하지 않는 것으로 간주된다.
