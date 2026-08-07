---
name: pet-sprite-production
description: aegis_pet 신규 펫 캐릭터의 상태별 스프라이트 시트를 sprite-gen으로 제작하고 이 프로젝트의 런타임 시각 계약(발바닥 기준선, 몸통 고정, 밉맵)에 맞게 정리하는 방법. "스프라이트 만들어줘", "캐릭터 시트 제작", "이 동작 애니메이션 다시" 요청 시 사용. sprite-artist 에이전트가 character-pipeline 팀에서 사용한다.
---

# 펫 스프라이트 제작

## 먹이/간식 소품 — Eat 애니메이션과는 별개로 제작한다 (2026-08-07 추가)

`feed`(밥)와 `snack`(간식)은 같은 Eat 몸동작 애니메이션을 공유한다 — 몸동작으로 구분하지 않는다. 대신 캐릭터 옆에 잠깐 나타났다 먹으면서 점점 작아지는 **정지 이미지 소품 2장**(밥그릇/사료 1장, 간식 1장)으로 구분한다. 코드(`pet.gd`의 `show_food_prop()`)가 이 정지 이미지를 스케일·투명도 트윈으로 줄어들게 처리하므로, **프레임별 애니메이션 시트가 아니라 상태 하나당 정지 PNG 1장만** 만들면 된다.

- 파일명 관례: `assets/sprites/<character_id>/food_feed.png`, `food_snack.png` (진화 티어 구분 불필요 — 음식은 캐릭터 외형과 무관하므로 티어당 하나씩 만들 필요 없다. 티어 공용 1쌍으로 충분).
- 캐릭터의 케어 효과(`scripts/data/balance.gd`의 `CARE_EFFECTS`)와 어울리는 음식으로 디자인한다 — 예: 일반 사료/밥 vs 캐릭터 취향에 맞는 간식(과자, 과일 등).
- 배경 투명, 크로마키 없이 알파로 바로 제작 가능(작은 소품이라 sprite-gen의 component-row 파이프라인을 안 써도 되고, 단일 이미지 생성으로 충분하다).
- 이 소품은 선택 사항이다 — 없으면 `Characters.get_food_prop()`이 빈 문자열을 반환해 기존처럼 소품 없이 Eat만 재생된다. 신규 캐릭터든 레거시 업그레이드든, 다른 13상태와 별개로 언제든 추가/보완 가능하다.

## 이 스킬이 하는 일

`sprite-gen` 스킬(이미지 생성·크로마키 정리·프레임 추출 엔진, 로컬 설치: `~/.claude/skills/sprite-gen`)을 이 프로젝트의 시각 규칙에 맞춰 운전하는 절차를 담는다. sprite-gen 자체는 범용 스프라이트 도구이고, 이 스킬은 "aegis_pet에서는 어떻게 써야 하는가"를 담는다.

## 필독 원문 문서

**작업 시작 전 반드시 `docs/02-design/pet-sprite-production-guide.md` 전체를 읽는다.** 이 문서가 이 프로젝트 스프라이트 제작의 원본 규칙이며, 여기서는 sprite-gen 실행 절차와의 연결점만 요약한다. 특히 다음 섹션은 매 작업마다 다시 확인한다:
- §2 "시각적 원칙" (캐릭터 아이덴티티 유지 범위, 발바닥 기준선, 몸통 중심 고정, 밉맵)
- §3 표 (비숑 기준 상태별 프레임/FPS/loop — 새 캐릭터도 같은 상태 세트를 기본으로 삼음)
- §4.3 "런타임 등록 계약" (다음 단계인 `gd-integrator`에게 넘길 실측값 형식)
- §8 "인수인계 템플릿"

## 절차 — 모든 캐릭터가 동일: 10개 상태 전부를 애니메이션 시트로

**(2026-08-06 갱신) "정지 이미지만 만드는 포즈 등급"은 폐지됐다.** `char-designer`가 스펙 최상단에 스코프 축소를 명시하지 않았다면, 항상 아래 10개 상태 전부를 여러 프레임짜리 애니메이션 시트로 만든다 — 정지 이미지 1장짜리 "포즈"는 더 이상 허용되지 않는다.

`Idle` / `Walk`(구 walk1+walk2 통합) / `Sleep` / `Eat` / `Sick` / `Sulk` / `Happy`(=Pet 반응) / `Dragged`(잡힘) / `Fall`(떨어짐) / `Land`(착지)

1. **필독**: `docs/02-design/pet-sprite-production-guide.md` 전체, 특히 §2(시각 원칙)·§3(상태별 프레임 계약 — 지금은 bichon 전용 문서지만 프레임/FPS/loop 계약 자체는 모든 캐릭터에 동일 적용)·§4.3(런타임 등록 계약)·§8(인수인계 템플릿). Dragged/Fall/Land는 bichon의 기존 값(`scenes/pet/pet.gd`의 `BICHON_ANIMATIONS["Dragged"/"Fall"/"Land"]`)을 참고해 같은 논리(잡혀서 흔들림 4프레임 / 낙하 4프레임 / 비반복 착지 4프레임)로 만든다.
2. **sprite-gen 실행**: `Skill(sprite-gen)`을 로드하고 `component-row` 엔진으로 캐릭터 기준 포즈부터 시작한다. 기존 산출물(`assets/generated/sprites/bichon-idle-blink-v2/`의 `sprite-request.json`)을 템플릿으로 참고해 `cell`, `chroma_key`, `states` 스펙을 구성한다.
3. **10개 상태 전부**: 위 10개를 sprite-gen의 생성→큐레이션→크로마키 정리→프레임 추출 파이프라인으로 전부 만든다. **하나라도 빠뜨리고 다음 단계로 넘기지 않는다.** 시간이 부족하면 10개 전부를 프레임 수를 줄여서라도(예: Walk를 4프레임으로) 채우는 게 몇 개만 정교하게 만들고 나머지를 비우는 것보다 낫다.
4. **시각 QA (제작자 자신의 1차 검수)**: 매 상태 완성 시 제작 가이드 §6 "정적 점검" 체크리스트를 스스로 확인한다.
5. **런타임 자산 배치**: 최종 PNG를 `assets/sprites/{character_id}/`에 상태별로 놓는다. 파일명은 `<state>_<frames>f_alpha_smooth.png` 또는 `<state>_<frames>f_chromakey_smooth.png`. sprite-gen 작업 기록(`assets/generated/sprites/{id}-v1/`)은 보존한다.
6. **실측값 정리**: 각 상태의 `columns`, `rows`, 논리 `frames` 수, `fps`/`loop`, idle 알파 바운딩박스 실측 높이, 프레임별 `foot_padding`/`horizontal_offsets`.
7. **인수인계 템플릿 작성**: 제작 가이드 §8 템플릿을 채워 `docs/02-design/characters/{character_id}.handoff.md`로 저장한다.

## 레거시 캐릭터 업그레이드 (정지 이미지 → 애니메이션)

기존 12종(mochi, ppiyak, haemjji, kkubeok, nyang, kong, mundeok, geobujang, bulgeumjo, seureureuk, tokki, ddungsil)은 `assets/sprites/chars/<id>/`에 정지 이미지 8장(idle/walk1/walk2/sleep/happy/sulk/sick/eat)만 있는 구세대 자산이다. 업그레이드 요청을 받으면:
1. 기존 8장을 아이덴티티 참고용으로만 쓴다(실루엣·색·표정) — 그대로 재사용하지 않는다, 정지 이미지 그 자체가 애니메이션이 아니므로.
2. 위 10개 상태 절차를 처음부터 그대로 수행해 애니메이션 시트를 새로 만든다. `walk1`/`walk2`가 통합된 `Walk`가 되고, `Dragged`/`Fall`/`Land`가 신규로 추가된다.
3. 기존 정지 이미지 8장은 삭제하지 않고 보존한다(`gd-integrator`가 등록 전환할 때까지의 폴백, 또는 회귀 비교용).
4. 진화 단계가 있는 캐릭터는 `_evolved`/`_evolved2`도 순서대로(base 먼저, 완료 확인 후 진화 단계) 같은 방식으로 진행한다 — 한 캐릭터를 세 단계 동시에 벌리지 않는다.

## 스코프를 의도적으로 줄여야 할 때 (테스트/프로토타입)

파이프라인 자체를 검증하는 목적 등으로 위 절차를 다 못 채우는 게 맞는 상황이라면, 결과물을 실제 캐릭터처럼 취급하지 않는다. 스펙 파일 최상단에 스코프 축소가 이미 표시돼 있어야 하고(없으면 되돌아가서 `char-designer`에게 표시를 요청한다), 완료 보고에도 "N/10 상태만 제작, 나머지는 미완성 — 실제 배포 전 완성 필요"를 명시한다. 이 표시가 없는 산출물은 `gd-integrator`가 10개 상태 완비로 간주하고 등록하므로, 표시를 빠뜨리면 미완성 캐릭터가 완성작으로 게임에 들어간다.

## 흔한 실수 (제작 가이드에서 반복 강조되는 것들)

- 포즈마다 캔버스 안에서 캐릭터 위치가 달라 몸통이 흔들리는 것 — sprite-gen 생성 시 기준 앵커를 프롬프트에 명시해도 어긋날 수 있으니 프레임 추출 후 반드시 비교한다.
- 부화 전/후 두 성장 단계(baby/adult)에서 같은 스케일 배수를 그냥 복사하는 것 — 캐릭터마다 원본 아트가 캔버스를 차지하는 비율이 다르므로 실측이 필요하다.
- 큰 원본을 축소 표시하면서 밉맵을 안 켜는 것 — `.import` 파일에 `mipmaps/generate=true`가 있는지 반드시 확인한다 (없으면 `gd-integrator`에게 `.import` 설정 보완을 요청한다).

## 산출물

- `assets/sprites/{character_id}/*.png`
- `assets/generated/sprites/{character_id}-v1/` (제작 기록, 보존)
- `docs/02-design/characters/{character_id}.handoff.md` (실측값 + 인수인계 템플릿)
