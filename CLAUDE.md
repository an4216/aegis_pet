## 하네스: 캐릭터 콘텐츠 파이프라인

**목표:** 새 펫 캐릭터를 기획(밸런스·진화조건·대사) → 스프라이트 제작(sprite-gen) → GDScript 등록 → 테스트 검증까지 4개 에이전트 팀으로 자동화한다.

**트리거:** 새 캐릭터 추가, 캐릭터 기획/스프라이트/코드등록/검증 관련 요청(전체 또는 부분) 시 `character-pipeline` 스킬을 사용하라. 단순 질문이나 캐릭터 데이터 조회는 직접 응답 가능.

**변경 이력:**
| 날짜 | 변경 내용 | 대상 | 사유 |
|------|----------|------|------|
| 2026-08-06 | 초기 구성 (char-designer/sprite-artist/gd-integrator/qa-verifier 4에이전트 + character-pipeline 오케스트레이터) | 전체 | 캐릭터 추가가 항상 같은 4단계(기획→스프라이트→등록→검증)를 반복하므로 사용자 요청에 따라 콘텐츠 파이프라인 중심 하네스로 구축 |
| 2026-08-06 | "포즈 8종/풀애니 14상태" 등급을 스킬 전반에 명시하고 QA에 상태 커버리지 검사 추가 | pet-character-spec, pet-sprite-production, pet-runtime-wiring, pet-qa-checklist, character-pipeline | 파이프라인 테스트로 만든 ppyojjok이 Idle 1개만 등록되고 나머지 7개 상태(walk/sleep/eat/sick/sulk/pet/play)가 전부 빈 화면·Idle 대체로 나왔는데도 매니페스트 테스트("97 passed 0 failed")가 못 잡음 — 기존 12종 캐릭터가 예외 없이 8장 포즈 세트를 갖고 있다는 사실을 스킬이 명시하지 않아서 등급 결정이 임의로(그리고 저품질로) 이뤄졌던 것이 근본 원인 |
| 2026-08-06 | 위 등급 구분(포즈8종/풀애니14상태)을 폐지하고 단일 기준(10상태: Idle/Walk/Sleep/Eat/Sick/Sulk/Happy/Dragged/Fall/Land 전부 애니메이션)으로 통합. 레거시 12종은 순차 업그레이드 대상으로 지정, character-pipeline에 업그레이드 진입 경로 추가 | pet-character-spec, pet-sprite-production, pet-runtime-wiring, pet-qa-checklist, character-pipeline | 사용자 피드백: "각 포즈의 애니메이션 스프라이트가 다 있어야 한다" + 마우스로 잡힘/떨어짐(Dragged/Fall/Land, bichon 방식 그대로) 포즈 추가 요청. 기존 12종도 순차 업그레이드하기로 확정(대규모 후속 작업, 하네스만 우선 갱신) |
| 2026-08-07 | feed/snack 먹이 소품 메커니즘 신설(`pet.gd`의 `show_food_prop()`/`hide_food_prop()` + `characters.gd`의 `FOOD_PROPS`). Eat 몸동작은 feed/snack 공용, 옆에 뜨는 정지 소품 이미지 1장(먹으며 점점 작아지고 옅어짐)으로만 구분 — 상태 수를 늘리지 않는 저비용 설계 | scenes/pet/pet.gd, scripts/data/characters.gd, scripts/states/eat_state.gd, pet-sprite-production, pet-runtime-wiring, pet-qa-checklist | 사용자 피드백: "먹기 모션과 간식 모션은 달라야 한다"는 요청에, 몸동작을 굳이 늘리지 않고 소품으로 저비용 구현하는 방식을 채택. 모찌·햄찌에도 소급 적용 결정(진행 중) |
| 2026-08-07 | 진화 티어 아트 256px 복원 반영 + **크기 사다리 신설**(`Characters.TIER_SIZE_LADDER` = base 1.0 / evolved 1.0926 / evolved2 1.1852, 화면 몸통 108/118/128). 24티어 `BODY_SCALE`/`BODY_CORE_HEIGHT`/`expected_torso`와 3종 `sheet_scale` 갱신. `pet.gd`가 위치 계산에 하드코딩하던 `STATIC_POSE_SIZE=128`을 실측 텍스처 크기(`_sprite_anchor()`)로 교체하고 상수를 폴백 전용(`STATIC_POSE_FALLBACK_SIZE`)으로 강등. 테스트는 "진화 크기 불변" 검사를 "같은 성장단계에서 base<evolved<evolved2"로 뒤집고 확대 렌더 금지(108조합)·캔버스 크기 혼재·발 접지 검사 신설 | scenes/pet/pet.gd, scripts/data/characters.gd, tests/run_tests.gd, pet-runtime-wiring, pet-character-spec | (1) 결함: kong/evolved 등 4종이 확대 렌더(최대 1.22배)라 뿌옇게 나오고 있었다. (2) 사용자 요청: "진화할수록 커져야 한다". 캔버스가 티어별로 혼재(base/egg 128px, evolved 계열 256px)하게 되면서 상수 기반 위치 계산이 256px 티어를 화면에서 크게 어긋나게 하는 것이 최우선 위험이었다. 9단계 전역 크기 순서는 성장 폭(1.406배) > 진화 폭(1.093배)이라 양립 불가능해 사용자가 "순서 규칙은 느슨하게"로 결정 |
