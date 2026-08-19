# ddungsil (뚱실이) — 레거시 업그레이드 최소 스펙

char-designer 단계 생략(레거시 업그레이드 모드). 기존 `characters.gd`/`balance.gd`/`dialog.gd` 값을 그대로 옮긴 최소 스펙이며, 밸런스·진화조건·대사는 변경하지 않는다.

## 기본 정보
- name_kr: 뚱실이
- rarity: uncommon
- 진화 이름: base 뚱실이 → evolved 뚱과장 → evolved2 뚱대박

## 스탯/케어 보정 (characters.gd)
- stat_modifiers: hunger_decay 0.7, energy_decay 1.3, move_speed 0.6
- care_modifiers: feed 1.5, snack 1.5
- special: []

## 진화 조건 (balance.gd)
- base→evolved: feed 10회 ("밥 10번 먹이기 - 회식 야근 승진")
- evolved→evolved2: feed 30회 ("밥 30번 - 그러다 로또 대박")

## 부화 가중치
- wednesday_hatch: 3.0

## 크기 (BODY_SCALE / expected_torso 등)
- base 85.0, evolved 165.17, evolved2 142.00 (기존 24티어 표 값 유지, sheet_scale은 실측 후 gd-integrator가 재계산)

## 레거시 아트 특이사항 (참고용, 신규 시트 제작 시 유의)
- walk_static: true — 기존 walk2가 walk1과 동일해 waddle 모션으로 보완했던 이력. 신규 Walk 애니메이션 시트에서는 실제 다리/몸통 움직임으로 대체한다.
- walk_face_inverted: true — 기존 걷기 시트가 뒤돌아본 상태라 좌우 반전 처리했던 이력. 신규 시트에서 방향이 정면/측면으로 통일되면 이 플래그는 gd-integrator가 재검토.
- 기존 정지 이미지 8장(`assets/sprites/chars/ddungsil/*.png` 등, 위치는 sprite-artist가 확인)은 아이덴티티(실루엣·색·표정) 참고용으로만 사용, 삭제하지 않음.

## 목표 (이번 업그레이드)
- 14상태(Idle/Walk/Sleep/Eat/Sick/Sulk/Play/Dragged/Fall/Land/FileHover/FileConsume/Poop/Pet) × 3티어(base/evolved/evolved2) 애니메이션 시트.
- base 티어 먼저 전부 완성 + 검증 통과 후 evolved/evolved2 진행.
- 이번 라운드(mochi/haemjji/ppiyak)에서 확립된 지표 적용: 활기=면적 변화, 전환 팝=max(|폭변화|,|높이변화|) 기준(FileHover/FileConsume/Eat류 ≤ 15%, 부양류는 공중 여부 명시 목록으로 관리), 종횡비 불일치 시 재합성 대신 재생성.
