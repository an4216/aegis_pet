---
name: pet-qa-checklist
description: aegis_pet 신규/변경된 캐릭터를 헤드리스 Godot 테스트와 실제 화면 확인으로 검증하는 방법. "테스트 돌려줘", "검증해줘", "헤드리스 테스트", "화면에서 확인" 요청 시 사용. qa-verifier 에이전트가 character-pipeline 팀에서 사용한다.
---

# 펫 캐릭터 QA 체크리스트

## Godot 바이너리 위치

이 환경은 Godot이 PATH에 없고, 프로젝트 캐시 경로에 있다:

```powershell
$godot = "$env:LOCALAPPDATA\Temp\aegis_pet_godot_4_4_1\Godot_v4.4.1-stable_win64_console.exe"      # 헤드리스(콘솔)
$godotGui = "$env:LOCALAPPDATA\Temp\aegis_pet_godot_4_4_1\Godot_v4.4.1-stable_win64.exe"            # GUI(화면 확인용)
```

없으면 `Get-ChildItem`으로 다른 위치를 탐색하거나 사용자에게 물어본다. `$godot` 변수는 PowerShell 세션 안에서만 유지되므로, 새 커맨드 블록마다 다시 정의해야 한다 — 정의와 사용을 같은 명령 문자열에 줄바꿈으로 묶는다.

## 실행 명령

```powershell
# 전체 회귀 테스트
& $godot --headless --path . --script tests/run_tests.gd

# 비숑류 애니메이션 통합 테스트 (해당 캐릭터가 있다면 같은 패턴으로 확장)
& $godot --headless --path . --script tests/bichon_animation_integration.gd

# 실제 화면 확인
& $godotGui --path . --rendering-method gl_compatibility
```

종료 코드로 1차 판정한다 (`$LASTEXITCODE`, `run_tests.gd`는 실패 1건 이상이면 exit 1). 출력 마지막 줄 `RESULT: N passed, M failed`도 함께 확인한다.

## `.ctex` 로딩 에러는 먼저 임포트 캐시를 갱신해서 무해 여부를 구분한다

`ERROR: Unable to open file: res://.godot/imported/....ctex` / `Make sure resources have been imported by opening the project in the editor at least once.`는 새로 추가된 PNG가 아직 `.godot/imported/`에 캐시되지 않아서 나는 것으로, 실제 코드 결함이 아닐 수 있다. 진짜 실패와 구분하려면 먼저 아래로 임포트를 강제 완료시킨다:

```powershell
& $godot --headless --editor --path . --quit-after 600
```

`--quit-after`가 없으면(단순 `--quit`) 백그라운드 스캔 스레드가 끝나기 전에 프로세스가 죽어(`WARNING: Scan thread aborted...`) 임포트가 누락된다. 600프레임 정도면 이 프로젝트 규모에서 충분하다. 이후 다시 테스트를 돌려서 같은 에러가 사라지면 무해했던 것이고, 남아있으면 실제 자산 경로/이름 문제다.

## 커버리지 검증이 매니페스트 검증보다 먼저다 — "등록된 것"이 아니라 "빠진 것"을 찾는다

여기서 가장 중요한 실수는 **등록된 항목의 내부 정합성만 확인하고, 등록되지 않은 항목의 존재를 놓치는 것**이다. 실제로 이 프로젝트에서 한 번 발생했다: `ppyojjok`이 Idle 하나만 등록됐는데, 매니페스트 테스트는 그 Idle 항목의 배열 길이·리소스 존재를 전부 통과시켰고("97 passed, 0 failed"), 정작 걷기/자기/먹기/아픔/시무룩/펫/플레이가 전부 빈 화면이거나 Idle로 대체되는 문제는 아무 테스트도 잡지 못했다. "존재 확인"이 아니라 **"경계면 교차 비교"** — 이 캐릭터의 애니메이션 등급이 요구하는 상태 전체 목록과, 실제로 등록된 상태 목록을 나란히 놓고 빠진 게 있는지 비교한다.

1. **(2026-08-06 갱신) 기대 상태 목록은 이제 신규 캐릭터 전부 동일하다**: Idle/Walk/Sleep/Eat/Sick/Sulk/Happy/Dragged/Fall/Land 10종 × 진화 단계 수. "포즈 8종"은 업그레이드 대기 중인 12종 레거시에만 적용되는 구경로다 — 레거시 캐릭터를 검증할 때만 8종(`idle`/`walk1`/`walk2`/`sleep`/`happy`/`sulk`/`sick`/`eat`) 기준을 쓰고, 그 외에는 10종 기준을 쓴다.
2. **커버리지 테스트를 매니페스트 테스트보다 먼저 추가한다**: `<CHARACTER>_ANIMATIONS`(또는 통합 딕셔너리 안의 해당 종족 항목)에 10개 키가 전부 있는지 `has()`로 확인. 레거시(아직 업그레이드 안 된) 캐릭터라면 대신 `assets/sprites/chars/{id}/`(+`_evolved`/`_evolved2`)에 8개 파일이 전부 있는지 `FileAccess.file_exists`로 확인. **하나라도 빠지면 여기서 FAIL** — 스펙에 스코프 축소 표시(`> 상태: 스코프 축소`)가 있는 경우만 예외로 허용하고, 그 경우엔 통과 처리하되 결과 보고에 "N/10(레거시는 N/8) 상태만 존재, 미완성 캐릭터" 를 명시한다.
3. 이 커버리지 테스트가 통과한 뒤에만 아래 매니페스트 세부 검증으로 넘어간다.

## 새 캐릭터에 추가할 테스트 (기존 비숑/핑냥이 패턴)

`tests/run_tests.gd`의 기존 패턴을 참고해 새 캐릭터용 테스트 함수를 추가하고 `_init()`의 호출 목록에 등록한다:

1. **등록 테스트**: `Characters.CHARACTERS.has(id)`와 `name_kr` 확인 (`_test_bichon_registration` 참고)
2. **상태 커버리지 테스트**: 위 섹션대로 기대 상태 전체 목록과 실제 등록 목록을 비교 — 이게 없으면 리뷰가 불완전하다.
3. **애니메이션 매니페스트 테스트**: 10개 상태 각각의 `frames` 값, `sprite_frame_sequence`/`foot_padding`/`horizontal_offsets` 배열 길이 == `frames`, `ResourceLoader.exists(path)`, 시퀀스 값이 `columns*rows` 범위 안인지 (`_test_pink_cat_baby_animation_manifest` 참고 — 더 엄격한 버전). 레거시(정지 이미지 8장, 업그레이드 전) 캐릭터만 이 항목이 해당 없음 — 대신 8개 PNG 파일 존재 여부만 확인한다.
4. **대사 풀**: 새로 만들지 않아도 됨 — `_test_dialog_evolution_pools`가 전체 캐릭터를 자동으로 순회하므로, 이 테스트가 통과하는지만 확인하면 된다.

## 실제 화면 QA (코드로 대신할 수 없는 부분)

모든 캐릭터가 이제 애니메이션 등급이므로, `docs/02-design/pet-sprite-production-guide.md` §6 "실제 화면 QA" 체크리스트를 실제로 앱을 띄워 확인한다:
- baby/adult 모두에서 발바닥이 작업표시줄 기준선에 맞는가
- Walk 제외 상태에서 몸통 중심이 흔들리지 않는가
- Walk 좌우 반전이 올바른가
- Idle 깜박임 외 불필요한 바운스가 없는가
- 성체 크기에서 화면 양쪽 끝에 잘리지 않는가
- **Dragged**: 마우스로 잡는 순간 자연스럽게 전환되고, 끌려다니는 동안 반복되는가
- **Fall→Land**: 마우스를 놓는 순간 낙하 애니메이션이 시작되고, 바닥(작업표시줄)에 닿는 순간 착지 애니메이션(비반복)으로 전환된 뒤 Idle로 복귀하는가
- **먹이/간식 소품(`FOOD_PROPS` 등록 캐릭터만)**: `care("feed")`와 `care("snack")`을 각각 태워서 서로 다른 소품(밥/사료 vs 간식)이 옆에 나타나는지, Eat 동작이 끝나기 전 소품이 점점 작아지며 사라지는지, Eat 종료 시 소품이 완전히 사라지고 잔상이 안 남는지 확인한다. 소품이 등록 안 된 캐릭터는 이 항목 자체가 해당 없음(FAIL 아님).

이 항목들은 스크린샷으로 판단하거나, 판단이 애매하면 사용자에게 확인을 요청한다 — 코드 리뷰만으로 통과 처리하지 않는다.

## 실패 시 담당 라우팅

| 실패 유형 | 담당 |
|---|---|
| 캐릭터/이름 미등록 | gd-integrator |
| 매니페스트 배열 길이 불일치, 리소스 누락 | gd-integrator (값이 스펙과 다르면 sprite-artist) |
| 화면상 발바닥/몸통 불일치 | sprite-artist |
| 대사 풀 3줄/3트리거 미달 | char-designer |
