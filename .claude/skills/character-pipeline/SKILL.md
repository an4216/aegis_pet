---
name: character-pipeline
description: aegis_pet에 새 펫 캐릭터를 기획부터 스프라이트 제작(sprite-gen)·GDScript 등록·테스트 검증까지 처음부터 끝까지 자동화하는 오케스트레이터. "새 캐릭터 추가해줘", "캐릭터 하나 만들어줘", "진화형 캐릭터 넣어줘" 같은 신규 요청뿐 아니라, "캐릭터 대사만 다시", "이 캐릭터 스프라이트만 보완", "코드 등록만 다시 확인", "저번에 만든 캐릭터 검증만 다시 돌려줘" 같은 부분 재실행 요청, 그리고 "이 캐릭터 애니메이션으로 업그레이드해줘"/"정지 이미지를 애니메이션으로 바꿔줘"/"레거시 캐릭터 애니메이션 작업" 같은 기존 12종 레거시 캐릭터 업그레이드 요청에도 사용한다. char-designer/sprite-artist/gd-integrator/qa-verifier 4개 에이전트로 구성된 팀을 조율한다.
---

# character-pipeline — 캐릭터 콘텐츠 파이프라인 오케스트레이터

## 실행 모드

**에이전트 팀** (기본). `char-designer` → `sprite-artist` → `gd-integrator` → `qa-verifier` 순서의 파이프라인이지만, QA 실패 시 앞 단계로 되돌아가는 피드백 루프가 있으므로 팀원 간 `SendMessage` 직접 통신이 필요하다.

## Phase 0: 컨텍스트 확인 + 품질 기본값 고지

작업 시작 전 `docs/02-design/characters/` 디렉토리를 확인한다.

- 요청한 `character_id`의 스펙/handoff 파일이 **없음** → **초기 실행**: 아래 전체 절차를 처음부터.
- 있고 사용자가 "새로 다시 기획해줘"처럼 새 입력을 준 경우 → 기존 파일을 `{character_id}.spec.md.prev`로 백업 후 **새 실행**.
- 있고 사용자가 "스프라이트만", "대사만", "검증만" 처럼 특정 단계만 요청 → **부분 재실행**: 해당 단계 담당 에이전트만 호출하고, 그 결과가 이후 단계에 영향을 주면 이후 단계도 순서대로 이어서 호출한다(예: "스프라이트만 다시" → sprite-artist 재호출 후 실측값이 바뀌었으면 gd-integrator·qa-verifier도 이어서 실행).
- 사용자가 기존 레거시 캐릭터(mochi, ppiyak, haemjji, kkubeok, nyang, kong, mundeok, geobujang, bulgeumjo, seureureuk, tokki, ddungsil 중 하나)를 "애니메이션으로 업그레이드"해달라고 요청 → **레거시 업그레이드 모드**: char-designer 단계는 건너뛴다(밸런스·대사·진화조건은 이미 있으므로 `docs/02-design/characters/{id}.spec.md`가 없으면 기존 `characters.gd`/`balance.gd`/`dialog.gd` 값을 그대로 옮겨 최소 스펙만 만든다). sprite-artist부터 시작해 `pet-sprite-production`의 "레거시 캐릭터 업그레이드" 절차로 10개 상태를 새로 제작하고, 이후 gd-integrator·qa-verifier로 이어간다. 한 번에 한 캐릭터, base 단계부터 순서대로 진행한다(사용자가 명시적으로 여러 캐릭터를 동시에 요청하지 않는 한).

**품질 기본값 (반드시 지킨다)**: 모든 캐릭터(신규·업그레이드 후 레거시 모두)의 목표 기준은 **10개 상태 전부 애니메이션 시트**(Idle/Walk/Sleep/Eat/Sick/Sulk/Happy/Dragged/Fall/Land) — bichon과 동일한 수준이다. 정지 이미지 8장짜리 "포즈 등급"은 아직 업그레이드되지 않은 12종 레거시에만 남아있는 구세대 상태이며, 신규 캐릭터에는 적용하지 않는다. 오케스트레이터가 스코프를 줄여서 실행을 지시하는 경우(예: 파이프라인 자체를 테스트하는 목적), 그 결과물은 **실제 캐릭터가 아니라 테스트 산출물**이며, 게임에 실제로 반영하기 전에 10개 상태 완성을 요구해야 한다. 스코프 축소를 명시적으로 말하지 않으면, 담당 에이전트는 항상 10개 완비 기준으로 작업한다 — "일단 하나만 만들고 나머지는 나중에" 라는 결과가 기본 흐름에서 나와서는 안 된다. (`ppyojjok` 사례: Idle 하나만 등록되어 나머지 상태가 전부 Idle로 대체되거나 빈 화면으로 나왔다 — 이는 스코프 축소를 명확히 지시하지 않고 진행한 결과다.)

## 절차

1. `TeamCreate`로 `char-designer`, `sprite-artist`, `gd-integrator`, `qa-verifier` 4명을 구성한다.
2. `TaskCreate`로 4개 작업을 의존 관계와 함께 등록한다: 기획(선행 없음) → 스프라이트(기획 완료 후) → 코드 등록(스프라이트 완료 후) → 검증(코드 등록 완료 후).
3. `char-designer`에게 사용자의 캐릭터 컨셉(또는 "자유 기획" 요청)을 전달한다. 완료 시 `docs/02-design/characters/{id}.spec.md` 경로를 받는다.
4. `sprite-artist`에게 스펙 경로를 전달한다. `pet-sprite-production` 스킬과 `sprite-gen` 스킬을 사용해 완료 후 실측값 표를 받는다.
5. `gd-integrator`에게 스펙 + 실측값을 전달한다. `pet-runtime-wiring` 스킬을 사용해 4개 GDScript 파일(characters/balance/dialog/pet.gd)에 등록 후 변경 목록을 받는다 — `pet.gd`에 10개 상태 전부를 채운 애니메이션 카탈로그를 신설/추가한다. 오케스트레이터가 "Idle만 있어도 된다" 같은 스코프 축소를 지시하지 않았다면, gd-integrator가 일부 상태만 커버하는 구조를 제안해오는 경우 즉시 반려하고 10개 완비로 되돌린다.
6. `qa-verifier`에게 변경 목록을 전달한다. `pet-qa-checklist` 스킬로 테스트 작성 + 헤드리스 실행 + 화면 QA까지 수행한다.
7. QA 실패가 있으면, `qa-verifier`가 실패 유형에 따라 해당 에이전트에게 직접 `SendMessage`로 재작업을 요청한다 (라우팅 기준은 `pet-qa-checklist` 스킬 하단 표). 재작업 완료 후 `qa-verifier`가 재검증한다.
8. 모든 검증이 통과하면 결과를 종합해 사용자에게 보고하고, 팀을 정리한다(`TeamDelete`).

## 데이터 전달

- **파일 기반** (주 채널): `docs/02-design/characters/{character_id}.spec.md` (기획 산출물), `{character_id}.handoff.md` (스프라이트 실측값), GDScript 4파일 diff, `tests/run_tests.gd` 추가분. 모두 감사 추적을 위해 보존한다.
- **태스크 기반**: 4단계 의존관계를 `TaskCreate`/`TaskUpdate`로 추적.
- **메시지 기반**: QA 실패 피드백 루프, 단계 간 완료 통보.

## 에러 핸들링

- 각 단계는 1회 재시도까지 자체 해결을 시도한다. 재실패 시 해당 산출물을 "보류"로 표시하고 나머지 단계는 계속 진행하며, 최종 보고서에 누락을 명시한다.
- 서로 다른 단계의 산출물이 상충하면(예: 스펙의 `body_scale` 초안과 sprite-artist 실측값) 삭제하지 않고 둘 다 남긴 채 어느 쪽이 최종본인지 표시한다(항상 실측값 우선).
- `gd-integrator`가 기존 로직 코드 변경이 필요하다고 판단하면(새 `special` 메커니즘 등) 자동으로 진행하지 않고 사용자에게 스코프 확대를 먼저 확인한다.

## 테스트 시나리오

**정상 흐름**: "귀여운 사무실 고양이 캐릭터 하나 기획해서 추가해줘" → 4단계가 순서대로 실행되어 새 캐릭터가 `characters.gd`/`balance.gd`/`dialog.gd`/`pet.gd`에 등록되고, `run_tests.gd`가 실패 0건으로 통과.

**에러 흐름**: QA 단계에서 `foot_padding` 배열 길이가 `frames`와 안 맞아 매니페스트 테스트가 실패 → `qa-verifier`가 `gd-integrator`에게 SendMessage로 구체적 불일치(어느 상태, 기대 길이 vs 실제 길이)를 전달 → `gd-integrator`가 sprite-artist의 실측값 표를 재확인해 수정 → `qa-verifier`가 해당 테스트만 재실행해 통과 확인 → 전체 스위트 최종 1회 재실행.
