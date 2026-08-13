# 삐약이 14상태 모션 리메이크 핸드오프

## 완료 범위

- 대상: `ppiyak`, `ppiyak_evolved`, `ppiyak_evolved2`
- 상태: Idle, Walk, Sleep, Eat, Sick, Sulk, Play, Dragged, Fall, Land, FileHover, FileConsume, Poop, Pet
- 산출물: 3티어 × 14상태 = 런타임 시트 42장
- 공통 셀: 192×208 RGBA
- 시트 규격: 6프레임 1152×208, 4프레임 768×208, Walk 8프레임 768×416

## 시각 규칙

- base는 연노랑 병아리와 파란 사원증, evolved는 붉은 볏과 금색 사원증, evolved2는 큰 붉은 볏·꼬리와 `팀장` 배지를 모든 상태에서 유지한다.
- 얼굴을 첫 번째 인지 요소로 두고, 눈·부리·볼·날개·발의 선 굵기와 노란색 팔레트를 세 티어 전체에 통일했다.
- 런타임이 별도로 그리는 음식, 파일 아이콘, 손 커서, 응아 엔티티는 시트에 중복 삽입하지 않았다.
- grounded 상태는 16px 투명 바닥선을 공유한다. Play, Dragged, Fall만 `airborne` 프레임 패딩으로 상승 폭을 보존한다.

## 런타임 등록

- [pet.gd](../../../scenes/pet/pet.gd)의 `ANIMATED_POSE_OVERRIDES.ppiyak`이 42개 `_remake.png`를 직접 참조한다.
- 티어별 시트 배율: base `0.7570`, evolved `1.4416`, evolved2 `1.2505`.
- 실측 수평 앵커는 전 프레임 `|offset| ≤ 0.5px`로 제한했다.
- 42개 임포트 모두 mipmap 생성을 켜 축소 표시 시 윤곽과 얼굴 디테일을 보존한다.

## 검증 증거

- [실제 Godot 런타임 보드](ppiyak-remake-14state-runtime.png): OpenGL Compatibility 렌더러에서 실제 `Pet` 노드가 적용한 텍스처, 프레임 격자, 배율, 앵커, 필터를 복제해 3티어 14상태를 확인했다.
- [전체 프레임 보드](ppiyak-remake-14state-contact.png): 42개 시트의 모든 물리 프레임을 원본 해상도로 비교한다.
- 기계 검증: 42/42 8-bit RGBA, 정확한 시트 규격, 빈 셀 0, 셀 경계 알파 점유 0, mipmap 42/42.
- Godot 구문 검사: `PARSE RESULT: OK`.
- 전체 테스트: `5111 passed, 0 failed`.

정적 보드는 프레임 순서와 루프 이음새를 직접 비교할 수 있지만 실제 시간 간격 자체를 영상처럼 증명하지는 않는다. 재생 속도와 loop/one-shot 계약은 런타임 설정 및 테스트로 검증한다.
