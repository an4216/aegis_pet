# 햄찌 (haemjji) 캐릭터 스펙 — 레거시 업그레이드용 최소 스펙

> 상태: 레거시 애니메이션 업그레이드 진행 중 — base 단계 14상태부터 시작, evolved/evolved2는 base 완료·검증 후 착수
> 이 스펙은 char-designer 신규 기획이 아니라 기존 `characters.gd`/`balance.gd`/`dialog.gd` 값을 그대로 옮긴 것이다. 밸런스·진화조건·대사는 변경하지 않는다.

## 애니메이션 등급

**14개 상태 애니메이션 시트** (Idle/Walk/Sleep/Eat/Sick/Sulk/Play/Dragged/Fall/Land/FileHover/FileConsume/Poop/Pet) — 모찌와 동일 기준, bichon과 동급.
기존 `assets/sprites/chars/haemjji/idle.png` 등 8장 정지 이미지는 실루엣·색·표정 참고용으로만 쓰고, 그대로 재사용하지 않는다. 삭제하지 않고 보존.

## 데이터 (변경 없음, 참고용)

| 필드 | 값 | 출처 |
|---|---|---|
| `character_id` | `"haemjji"` | |
| `name_kr` | `"햄찌"` | characters.gd:158 |
| `rarity` | `"common"` | characters.gd:158 |
| `stat_modifiers` | `{"hunger_decay": 1.4}` | characters.gd:159 |
| `care_modifiers` | `{"snack": 2.0}` | characters.gd:160 |
| `special` | `["self_snack"]` | characters.gd:161 — **로직 특수 메커니즘 있음, 건드리지 말 것** |
| `EVOLVED_NAMES["haemjji"]` | `"함장님"` | characters.gd:9 |
| `EVOLVED_2_NAMES["haemjji"]` | `"햄왕"` | characters.gd:19 |
| `BODY_SCALE["haemjji"]` | `{"base": 1.667, "evolved": 1.72, "evolved2": 1.72}` | characters.gd:114 — 정지 포즈 128 캔버스 기준, 애니메이션 등록 시 `sheet_scale`로 별도 보정(BODY_SCALE 자체는 안 건드림, 모찌와 동일 방식) |
| `EVOLUTION["haemjji"]` | `{"metric": "feed_snack", "amount": 40, "hint": "먹이·간식 40번 챙기기"}` | balance.gd:56 |
| `EVOLUTION_2["haemjji"]` | `{"metric": "feed_snack", "amount": 150, "hint": "먹이·간식 150번 - 프랜차이즈 오너"}` | balance.gd:73 |
| `BY_CHARACTER["haemjji"]` (base/e1/e2 대사) | 기존 `dialog.gd` 그대로 유지 | |
| `HATCH_WEIGHTS["lunch_hatch"]["haemjji"]` | `2.0` | characters.gd:226 — 변경 없음 |

## 업그레이드 순서

1. **base 단계 14상태**를 sprite-artist가 먼저 전부 제작 → gd-integrator 등록 → qa-verifier 검증 통과.
2. base 통과 후에만 evolved("함장님") 14상태.
3. evolved 통과 후에만 evolved2("햄왕") 14상태.
4. 세 단계를 동시에 벌리지 않는다.

## 걷기/특수 메커니즘 주의

햄찌는 다리 있는 햄스터형 캐릭터(기존 8장 참고)라 Walk는 실제 보행으로 만든다. `special: ["self_snack"]`는 로직 코드(간식 자동 섭취 확률)라 스프라이트 작업과 무관 — 건드리지 않는다. Eat 상태는 햄찌 볼주머니(치크 파우치)가 특징이니 살려서 표현하면 좋다(선택).
