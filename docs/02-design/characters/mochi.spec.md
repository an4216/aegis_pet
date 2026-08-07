# 모찌 (mochi) 캐릭터 스펙 — 레거시 업그레이드용 최소 스펙

> 상태: 레거시 애니메이션 업그레이드 진행 중 — base 단계 10상태부터 시작, evolved/evolved2는 base 완료·검증 후 착수
> 이 스펙은 char-designer 신규 기획이 아니라 기존 `characters.gd`/`balance.gd`/`dialog.gd` 값을 그대로 옮긴 것이다. 밸런스·진화조건·대사는 변경하지 않는다.

## 애니메이션 등급

**10개 상태 애니메이션 시트** (Idle/Walk/Sleep/Eat/Sick/Sulk/Happy/Dragged/Fall/Land) — 신규 기준과 동일.
기존 `assets/sprites/chars/mochi/idle.png` 등 8장 정지 이미지는 실루엣·색·표정 참고용으로만 쓰고, 그대로 재사용하지 않는다. 삭제하지 않고 보존한다.

## 데이터 (변경 없음, 참고용)

| 필드 | 값 | 출처 |
|---|---|---|
| `character_id` | `"mochi"` | |
| `name_kr` | `"모찌"` | characters.gd:69 |
| `rarity` | `"common"` | characters.gd:69 |
| `stat_modifiers` | `{}` | characters.gd:70 |
| `care_modifiers` | `{"pet": 1.5}` | characters.gd:71 |
| `special` | `[]` | characters.gd:72 |
| `EVOLVED_NAMES["mochi"]` | `"프로찌"` | characters.gd:9 |
| `EVOLVED_2_NAMES["mochi"]` | `"회찌"` | characters.gd:19 |
| `BODY_SCALE["mochi"]` | `{"base": 1.538, "evolved": 0.978, "evolved2": 1.009}` | characters.gd:43 — **base 값은 새 애니메이션 자산의 idle 알파 바운딩박스로 재실측 필요** (기존 1.538은 구 정지 이미지 기준값) |
| `EVOLUTION["mochi"]` | `{"metric": "kb", "amount": 30000, "hint": "키보드 30,000번 두드리기"}` | balance.gd:54 |
| `EVOLUTION_2["mochi"]` | `{"metric": "kb", "amount": 100000, "hint": "키보드 100,000번 - 진짜 일잘러의 손"}` | balance.gd:71 |
| `BY_CHARACTER["mochi"]` (base/e1/e2 대사) | 기존 `dialog.gd` 그대로 유지 | dialog.gd:77~ |

## 업그레이드 순서

1. **base 단계 10상태**를 sprite-artist가 먼저 전부 제작 → gd-integrator 등록 → qa-verifier 검증 통과.
2. base가 완전히 통과한 뒤에만 `evolved`(1차 진화 "프로찌") 10상태 진행.
3. evolved 통과 후에만 `evolved2`(최종 진화 "회찌") 10상태 진행.
4. 세 단계를 동시에 벌리지 않는다 — 이 문서에서 지금 다루는 범위는 **base만**이다.

## 걷기/드래그 표현

모찌는 다리가 있는 젤리형 캐릭터(기존 8장 참고)이므로 Walk는 실제 보행으로, Dragged/Fall/Land는 bichon 방식(잡혀서 흔들림 → 낙하 → 비반복 착지)을 그대로 따른다. 별도 waddle 처리 불필요.
