# 삐약(ppiyak) — 최소 스펙 (레거시 업그레이드용)

> 이 문서는 신규 기획이 아니라, 기존 `characters.gd`/`balance.gd`/`dialog.gd`에 이미 있는 값을
> 애니메이션 업그레이드 작업(sprite-artist/gd-integrator/qa-verifier)이 참조할 수 있게 옮겨온
> 최소 스펙이다. char-designer 단계는 이번 업그레이드에서 건너뛰었다.

## 아이덴티티

| 티어 | character id | 이름 | 비주얼 |
|---|---|---|---|
| base | `ppiyak` | 삐약 | 노란 병아리, 머리 위 노란 뿔깃 1가닥, 파란 넥스트랩 + 흰 사각 사원증 |
| evolved | `ppiyak_evolved` | 꼬꼬 | 노란 닭, 빨간 하트 볏, 목끈 + 사원증 |
| evolved2 | `ppiyak_evolved2` | 꼬끼오 | 노란 수탉, 큰 빨간 볏 + 빨간 육수 + 빨간 꼬리깃, 빨간 목끈 + "팀장" 금색 명찰 |

(비주얼 디스크립션은 `docs/02-design/characters/ppiyak.handoff.md`의 Sleep 인수인계에서 그대로 가져옴 — 실제 확인된 값)

## 밸런스 (characters.gd/balance.gd, 변경 없음)

- `rarity`: common
- `stat_modifiers`: `happiness_decay: 0.75`, `energy_decay: 1.25`
- `BODY_SCALE`: base 1.956 / evolved 2.028 / evolved2 2.322
- 1차 진화 조건 (`EVOLUTION.ppiyak`): `distinct_days` 5회 ("서로 다른 날 5번 출근")
- 2차 진화 조건 (`EVOLUTION_2.ppiyak`): `distinct_days` 20회 ("출근 20일 - 한 달의 성실")
- 진화형 이름: `EVOLVED_NAMES.ppiyak` = "꼬꼬", `EVOLVED_2_NAMES.ppiyak` = "꼬끼오"
- 특수 트리거: `high_care` 이벤트에서 ppiyak 가중치 2.0

## 대사 (dialog.gd, 변경 없음)

`dialog.gd:121`의 `"ppiyak": {...}` 블록 그대로 유지 — 이번 업그레이드에서 손대지 않음.

## 이번 업그레이드 범위

Sleep은 완료(`sleep_6f.png`, 6프레임/4fps, `ANIMATED_SLEEP_OVERRIDES` 등록, QA 통과).
나머지 9상태(Idle/Walk/Eat/Sick/Sulk/Happy/Dragged/Fall/Land)를 bichon과 동일한 10상태
완비 기준으로 애니메이션화하는 것이 이번 스펙의 목적. 밸런스/진화조건/대사는 변경하지 않는다.
