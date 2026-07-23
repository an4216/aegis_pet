# desktop-tamagotchi Planning Document

> **Summary**: 업무시간에 윈도우 데스크톱 위에서 알부터 성체까지 키우는 데스크톱 다마고치 (창 위를 돌아다니고 구석에서 잠자는 정통 케어형 펫)
>
> **Project**: desktop-tamagotchi
> **Version**: 0.1.0
> **Author**: user1
> **Date**: 2026-07-21
> **Status**: Draft

---

## Executive Summary

| Perspective | Content |
|-------------|---------|
| **Problem** | 업무시간 내내 PC 앞에 있지만 감정적 환기 요소가 없다. 기존 다마고치류는 별도 기기/앱을 열어야 해서 업무 흐름과 공존하지 못한다. |
| **Solution** | Godot 4 기반 투명 오버레이 펫. 데스크톱 화면 위를 자율적으로 돌아다니고, 열린 창 위에 올라가고, 구석에서 잠들며, 정통 다마고치 케어(배고픔/행복/청결/에너지/건강)로 알→성체까지 성장한다. 클릭 통과로 업무를 방해하지 않는다. |
| **Function/UX Effect** | 항상 화면에 존재하지만 입력을 가로채지 않는 펫. 트레이 아이콘 + 우클릭 메뉴로 케어. 방치 시 병들거나 시무룩해지지만 죽지는 않아 업무 부담이 없다. |
| **Core Value** | "일하는 동안 곁에서 자라는 반려 펫" — 낮은 인지 부하로 애착과 소소한 즐거움 제공. |

---

## Context Anchor

> Design/Do 문서로 전파되는 컨텍스트 앵커.

| Key | Value |
|-----|-------|
| **WHY** | 업무 흐름을 방해하지 않으면서 데스크톱 위에 상주하는 육성형 펫이 없다 |
| **WHO** | 업무시간 대부분 PC를 사용하는 사무직/개발자 (Windows 10/11) |
| **RISK** | Godot에서 타 프로그램 창 위치 감지(Win32 EnumWindows)는 기본 미지원 → GDExtension 또는 폴링 방식 필요 |
| **SUCCESS** | 클릭 통과 오버레이에서 펫이 창/화면 위를 자율 이동, 알→성체 성장 사이클 완주, idle CPU < 3% / RAM < 150MB |
| **SCOPE** | Phase 1: 코어 펫 + 성장 + 케어 / Phase 2: 창 인식 이동 / Phase 3: 진화 분기·미니게임 |

---

## 1. Overview

### 1.1 Purpose

Windows 데스크톱에서 상시 실행되는 육성형 데스크톱 마스코트를 만든다. 사용자는 알을 받아 부화시키고, 먹이 주기·놀아주기·청소·재우기·치료 등 정통 다마고치 케어를 통해 성체까지 키운다. 펫은 화면과 열린 창들 위를 자율적으로 돌아다니며 살아있는 존재감을 준다.

### 1.2 Background

- 업무 중 감정적 환기 도구에 대한 수요 (탕비실 잡담, 화분, 어항의 디지털 버전)
- Shimeji(데스크톱 마스코트)의 "창 위를 돌아다니는 재미"와 다마고치의 "육성 애착"을 결합한 제품은 드묾
- 업무용 PC 환경 제약: 관리자 권한 불필요, 낮은 리소스, 입력 방해 금지가 필수 조건

### 1.3 Related Documents

- 참고: Shimeji-ee (데스크톱 마스코트 행동 패턴), Tamagotchi 케어 루프
- Godot 4 문서: `DisplayServer.window_set_mouse_passthrough`, `per_pixel_transparency`

---

## 2. Scope

### 2.1 In Scope

**Phase 1 — 코어 펫 (MVP)**
- [ ] 투명·테두리 없음·항상 위·클릭 통과 오버레이 창 (펫 영역만 클릭 가능)
- [ ] 성장 시스템: 알 → 유아기 → 소년기 → 성체 (4단계)
- [ ] 정통 케어 스탯 5종: 배고픔 / 행복 / 청결 / 에너지 / 건강
- [ ] 자율 행동 FSM: 대기, 걷기(화면 하단·작업표시줄 위), 잠자기(화면 구석), 먹기, 응아, 아픔, 시무룩
- [ ] 상호작용: 마우스로 집어 옮기기(드래그), 쓰다듬기, 우클릭 케어 메뉴(먹이/간식/청소/놀기/약/재우기)
- [ ] 시스템 트레이 아이콘: 상태 요약, 집중 모드 토글, 종료
- [ ] 로컬 저장(JSON) + 오프라인 경과 시간 반영(감소율 캡 적용)
- [ ] 집중 모드: 펫이 구석에서 조용히 잠들고 알림·이동 정지

**Phase 2 — 창 인식**
- [ ] 열린 창 감지(Win32 EnumWindows/GetWindowRect) → 창 타이틀바 위 걷기/앉기
- [ ] 창이 움직이거나 닫히면 떨어지기(낙하 + 착지 애니메이션)
- [ ] 멀티모니터 지원

**Phase 3 — 깊이 추가**
- [ ] 성체 진화 분기 3종 (케어 품질: 우수/보통/불량)
- [ ] 훈육·미니게임(행복 회복 수단)
- [ ] 통계 화면(나이, 케어 이력), 펫 도감

### 2.2 Out of Scope

- 온라인 기능 (계정, 클라우드 저장, 펫 교류/통신)
- macOS / Linux 지원 (Windows 10/11 전용)
- 인앱 결제·수익화, 자동 업데이트
- 다중 펫 동시 육성 (v1은 1마리)

---

## 3. Requirements

### 3.1 Functional Requirements

| ID | Requirement | Priority | Status |
|----|-------------|----------|--------|
| FR-01 | 투명/무테두리/항상 위 오버레이 창, 펫 스프라이트 영역 외 클릭 통과 | High | Pending |
| FR-02 | 성장 단계: 알(부화 게이지) → 유아기 → 소년기 → 성체, 실시간 시간 기반 진행 | High | Pending |
| FR-03 | 케어 스탯 5종(배고픔/행복/청결/에너지/건강)이 시간에 따라 자동 변화 | High | Pending |
| FR-04 | 케어 행동: 먹이, 간식, 청소, 놀아주기, 약 주기, 재우기 (우클릭 메뉴) | High | Pending |
| FR-05 | 방치 페널티: 배고픔·청결 악화 → 병듦(아픈 스프라이트), 행복 저하 → 시무룩. 죽음은 없음 | High | Pending |
| FR-06 | 자율 행동 FSM: 대기/걷기/달리기/잠자기(구석 이동 후 취침)/먹기/응아 생성 | High | Pending |
| FR-07 | 마우스 드래그로 집어 옮기기(버둥거림), 놓으면 낙하 후 착지 | High | Pending |
| FR-08 | 쓰다듬기(펫 위에서 클릭/문지르기) → 행복 소폭 상승 + 하트 이펙트 | Medium | Pending |
| FR-09 | 시스템 트레이: 스탯 요약 툴팁, 집중 모드 토글, 항상 위 토글, 종료 | High | Pending |
| FR-10 | 저장/복원: 종료 시 상태 저장, 재시작 시 오프라인 경과 반영(감소량 50% + 최대 8시간 캡) | High | Pending |
| FR-11 | 집중 모드: 펫이 구석에서 수면 고정, 사운드/이동 정지 (스탯 감소는 지속) | High | Pending |
| FR-12 | 밤 시간(기본 22:00~07:00, 설정 가능)에는 자동 취침 | Medium | Pending |
| FR-13 | 창 감지: 최상위 창들의 타이틀바 위를 플랫폼처럼 걷기/앉기 (Phase 2) | Medium | Pending |
| FR-14 | 창 이동/닫힘 시 펫 낙하 처리 (Phase 2) | Medium | Pending |
| FR-15 | 성체 진화 분기 3종: 평균 케어 품질 기반 (Phase 3) | Low | Pending |
| FR-16 | Windows 시작 시 자동 실행 옵션 (레지스트리 Run 키, 관리자 권한 불필요) | Medium | Pending |
| FR-17 | 부화 캐릭터 10종: 부화 시 확률 + 히든 가중치로 종족 결정, 종족별 스탯 보정·시그니처 행동 (상세: `docs/02-design/characters.md`) | High | Pending |
| FR-18 | 말풍선 시스템: 요일·시간대 트리거 기반 직장인 공감 대사 출력, 집중 모드 시 비활성 | Medium | Pending |
| FR-19 | 파일 먹이기: 파일을 펫에 드래그하면 휴지통 이동(복구 가능) + 먹이 효과 (1MB 이상=먹이, 미만=간식. 폴더 제외, 최대 5개) | Medium | Pending |
| FR-20 | 소화 시스템: 먹이/간식 섭취 후 15~30분 내 응아 생성 | Medium | Pending |
| FR-21 | 펫 리마인더: 시간·반복(한번/매일/평일) 등록 → 시간 되면 펫이 흥분 점프 + 강조 말풍선 | High | Pending |
| FR-22 | 뽀모도로 집중 친구: 25분 집중(펫 조용·말풍선 정지) → 완료 축하 + 행복 보상 → 5분 휴식 알림 | High | Pending |
| FR-23 | 오늘 할 일 3개: 펫에게 맡기고 완료 체크 시 펫 축하 + 행복 보상, 전부 완료 시 파티 | High | Pending |
| FR-24 | 펫 도감: 키워본 캐릭터 수집 기록 + 부화 히든 조건 힌트 | Medium | Pending |
| FR-25 | 마우스 쫓기 모드: 토글 시 펫이 커서를 따라다님 (장난감) | Low | Pending |
| FR-26 | 기념일 코스튬: 날짜 기반 액세서리 (크리스마스·월급날·부화 기념일) | Low | Pending |
| FR-27 | 건강 루틴: 물 마시기·스트레칭 주기 알림 (설정 가능) | Low | Pending |
| FR-28 | 처음부터 다시 키우기: 트레이 메뉴에서 확인 절차 후 새 알로 리셋 | Medium | Pending |
| FR-29 | 반자동 업데이트: GitHub Releases 버전 확인 → 알림 → 트레이 원클릭 다운로드·교체·재시작 (저장 데이터 유지) | High | Pending |

### 3.2 Non-Functional Requirements

| Category | Criteria | Measurement Method |
|----------|----------|-------------------|
| Performance | idle 시 CPU < 3%, RAM < 150MB, 대기 시 저FPS 모드(10fps) | 작업 관리자 / Godot profiler |
| 업무 비방해 | 펫 영역 외 100% 클릭 통과, 포커스 탈취 0회 | 수동 시나리오 테스트 |
| 안정성 | 8시간 연속 실행 시 크래시·메모리 누수 없음 | 장시간 실행 테스트 |
| 호환성 | Windows 10 (19045+) / Windows 11, 100~200% DPI 스케일 | 실기 테스트 |
| 배포 | 단일 포터블 exe (관리자 권한/설치 불필요) | Godot export 검증 |
| 저장 안전성 | 강제 종료에도 저장 파일 손상 없음 (주기 저장 + 원자적 쓰기) | 강제 종료 테스트 |

---

## 4. Success Criteria

### 4.1 Definition of Done

- [ ] Phase 1 기능 요구사항(FR-01~12, 16) 전체 구현
- [ ] 알 → 성체까지 실제 성장 사이클 1회 완주 확인 (시간 가속 디버그 모드로 검증)
- [ ] 업무 시나리오 테스트 통과: 문서 작업/브라우징 중 입력 방해 0회
- [ ] 8시간 연속 실행 안정성 테스트 통과
- [ ] 포터블 exe 익스포트 및 타 PC 실행 확인

### 4.2 Quality Criteria

- [ ] idle CPU < 3%, RAM < 150MB 충족
- [ ] 강제 종료 후 재시작 시 상태 복원 정상 동작
- [ ] gdlint/gdformat 통과 (GDScript 스타일 준수)

---

## 5. Risks and Mitigation

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Godot에서 타 앱 창 감지 불가(기본 API 없음) | High | High | Phase 2로 분리. 1안: C++ GDExtension으로 EnumWindows 호출. 2안: PowerShell/보조 프로세스 폴링(0.5s). Phase 1은 화면 가장자리+작업표시줄만 사용 |
| 클릭 통과(mouse passthrough) 폴리곤 갱신 성능·동작 이슈 | High | Medium | 프로젝트 최초 스파이크로 `window_set_mouse_passthrough` 검증. 실패 시 "작은 이동 창" 방식(펫 크기 창이 직접 이동)으로 전환 |
| 상시 실행 리소스 부담 (게임 엔진 특성) | Medium | Medium | low_processor_mode 활성화, 대기 시 10fps 제한, 파티클·물리 최소화 |
| 스프라이트 애니메이션 에셋 제작 부담 (성장 4단계 × 행동 8종+) | Medium | High | 32~64px 도트 스타일로 단순화, 단계별 팔레트 스왑 재활용, 우선순위 애니메이션부터 제작(대기/걷기/잠) |
| DPI 스케일·멀티모니터 좌표 오차 | Medium | Medium | DisplayServer 스크린 API 기준 좌표계 통일, 200% 스케일 실기 테스트 |
| 백신/보안 소프트웨어 오탐 (무서명 exe + 창 열거) | Medium | Low | 창 열거는 위치 정보만 사용(내용 접근 없음) 명시, 필요시 코드 서명 검토 |
| 정통 케어의 방치 페널티가 업무 스트레스로 전이 | Medium | Medium | 죽음 없음 + 오프라인 감소 캡 + 집중 모드로 부담 완화. 회복 비용을 낮게 설계 |

---

## 6. Impact Analysis

### 6.1 Changed Resources

| Resource | Type | Change Description |
|----------|------|--------------------|
| C:\projects\desktop-tamagotchi | 신규 프로젝트 | 전체 신규 생성. 기존 시스템/코드에 대한 변경 없음 |
| 레지스트리 `HKCU\...\Run` | Config | 자동 시작 옵션 활성화 시에만 항목 추가 (opt-in, 제거 기능 포함) |
| `%APPDATA%\Godot\app_userdata\desktop-tamagotchi\` | 저장 파일 | 세이브 JSON 생성 (user:// 경로) |

### 6.2 Current Consumers

신규 프로젝트로 기존 소비자 없음. 외부에 영향을 주는 지점은 6.1의 레지스트리(opt-in)와 세이브 파일뿐이다.

### 6.3 Verification

- [x] 기존 코드 영향 없음 확인 (신규 프로젝트)
- [ ] 자동 시작 등록/해제가 다른 Run 항목에 영향 없음 확인
- [ ] 관리자 권한 요구 없음 확인

---

## 7. Architecture Considerations

### 7.1 Project Level Selection

| Level | Characteristics | Recommended For | Selected |
|-------|-----------------|-----------------|:--------:|
| **Starter** | 단일 클라이언트 앱, 백엔드 없음 | 로컬 데스크톱 앱 | ☑ |
| **Dynamic** | 기능 모듈 + BaaS 연동 | 백엔드 있는 웹앱 | ☐ |
| **Enterprise** | 레이어 분리, MSA | 대규모 시스템 | ☐ |

> 백엔드·네트워크가 없는 단일 데스크톱 앱이므로 **Starter** 레벨. 단, 게임 로직은 씬/스크립트 모듈로 분리한다.

### 7.2 Key Architectural Decisions

| Decision | Options | Selected | Rationale |
|----------|---------|----------|-----------|
| 엔진 | Godot 4.x / WPF / Electron / Tauri | **Godot 4.x (4.3+)** | 사용자 선택. 스프라이트 애니메이션·FSM에 최적, 투명창·클릭통과 내장 지원 |
| 언어 | GDScript / C# / C++ | **GDScript (+ Phase 2에서 GDExtension C++)** | 반복 개발 속도 우선. Win32 창 감지만 네이티브 확장 |
| 오버레이 방식 | 전체화면 투명 오버레이 / 작은 이동 창 | **전체화면 투명 오버레이 + passthrough 폴리곤** | 펫 이동이 자유롭고 창 전환 비용 없음. 스파이크로 검증 후 확정 |
| 상태 관리 | 씬 내 변수 / Autoload 싱글톤 | **Autoload 싱글톤 (PetState, SaveManager, TimeManager)** | 씬 전환과 무관한 전역 상태(스탯, 시간) 관리 |
| 행동 로직 | if-else / FSM 노드 / Behavior Tree | **경량 FSM (State 패턴)** | 행동 수가 ~10개 수준, FSM으로 충분. BT는 과설계 |
| 저장 | JSON / SQLite / ConfigFile | **JSON (user://save.json, 원자적 쓰기 + 백업본)** | 단순 구조, 디버깅 용이 |
| 트레이 아이콘 | Godot StatusIndicator / 네이티브 | **Godot 4.3 StatusIndicator** | 엔진 내장 기능으로 충분 |
| 창 감지 (Phase 2) | GDExtension / 보조 프로세스 폴링 | **GDExtension C++ (EnumWindows)** | 지연 최소·프로세스 1개 유지. 폴링은 폴백 |
| 테스트 | GUT / 수동 | **GUT(단위: 스탯·성장 로직) + 수동(오버레이 동작)** | 시뮬레이션 로직은 자동화 가치 높음 |

### 7.3 Clean Architecture Approach

```
Selected Level: Starter (Godot 구조로 적용)

desktop-tamagotchi/
├── project.godot
├── autoload/            # 전역 싱글톤
│   ├── pet_state.gd     #   스탯·성장 단계·케어 이력
│   ├── time_manager.gd  #   실시간/오프라인 경과 처리
│   └── save_manager.gd  #   JSON 저장/복원
├── scenes/
│   ├── main.tscn        #   투명 오버레이 루트
│   ├── pet/             #   펫 씬 + FSM 상태들
│   └── ui/              #   케어 메뉴, 스탯 팝업, 이펙트
├── scripts/
│   ├── states/          #   idle, walk, sleep, eat, sick ...
│   └── platform/        #   창 감지 어댑터 (Phase 2)
├── assets/
│   ├── sprites/         #   단계별 스프라이트 시트
│   └── sfx/
├── addons/              #   GDExtension (Phase 2)
└── tests/               #   GUT 단위 테스트
```

---

## 8. Convention Prerequisites

### 8.1 Existing Project Conventions

- [ ] `CLAUDE.md` — 프로젝트 생성 시 함께 작성 예정
- [ ] `.editorconfig` / gdformat 설정
- [ ] `.gitignore` (Godot용: `.godot/`, export 산출물)

### 8.2 Conventions to Define/Verify

| Category | Current State | To Define | Priority |
|----------|---------------|-----------|:--------:|
| **Naming** | 없음 | 파일·함수: snake_case, 노드·클래스: PascalCase, 시그널: 과거형(snake_case) | High |
| **Folder structure** | 없음 | 7.3 구조 준수, 씬과 스크립트 1:1 매칭 | High |
| **상수/밸런스 값** | 없음 | 스탯 감소율 등 밸런스 수치는 `balance.gd` 단일 파일로 집중 | High |
| **저장 스키마** | 없음 | save.json에 `schema_version` 필드 필수 (마이그레이션 대비) | Medium |
| **디버그 모드** | 없음 | 시간 가속(x60/x600) 치트를 디버그 빌드에만 포함 | Medium |

### 8.3 Environment Variables Needed

| Variable | Purpose | Scope | To Be Created |
|----------|---------|-------|:-------------:|
| (없음) | 로컬 단독 앱으로 환경 변수 불필요 | - | - |

### 8.4 Pipeline Integration

| Phase | Status | Document Location | Command |
|-------|:------:|-------------------|---------|
| Phase 1 (Schema — 스탯/저장 스키마 정의) | ☐ | `docs/01-plan/schema.md` | 설계 문서에서 함께 다룸 |
| Phase 2 (Convention) | ☐ | `docs/01-plan/conventions.md` | 필요시 분리 |

---

## 9. Game Design Detail (기획 부록)

### 9.1 성장 단계

| 단계 | 도달 조건 | 특징 |
|------|-----------|------|
| 🥚 알 | 시작 | 화면 하단에 정지. 가끔 흔들림. 클릭·쓰다듬기로 부화 게이지 상승 (기본 1~4시간) |
| 🐣 유아기 | 부화 후 | 작고 느림. 스탯 감소 빠름(손이 많이 감). 이동 범위 좁음 |
| 🐤 소년기 | 부화 후 3일 + 건강 상태 | 이동 속도·범위 증가, 장난 행동 추가 |
| 🐔 성체 | 부화 후 7일 | 케어 품질 평균으로 진화 분기(Phase 3). 모든 행동 개방 |

### 9.2 케어 스탯 (정통 다마고치)

| 스탯 | 범위 | 자연 변화 | 회복 수단 | 방치 결과 |
|------|------|-----------|-----------|-----------|
| 배고픔 | 0~100 | -4/시간 | 먹이(+30), 간식(+10, 행복+5) | 0 지속 시 건강 감소 |
| 행복 | 0~100 | -3/시간 | 놀아주기(+20), 쓰다듬기(+3) | 시무룩 상태(구석에 웅크림) |
| 청결 | 0~100 | 응아 1개당 -15 | 청소(응아 제거 + 회복) | 낮으면 건강 감소 가속 |
| 에너지 | 0~100 | 활동 시 감소 | 수면(자동/재우기) | 0이면 아무 데서나 곯아떨어짐 |
| 건강 | 0~100 | 타 스탯 악화 시 감소 | 약 주기, 양호 상태 유지 시 자연 회복 | 30 미만 병듦(치료 필요), 죽음 없음 |

### 9.3 행동 목록 (FSM 상태)

`Idle`(대기·두리번) / `Walk`(화면 하단·작업표시줄 걷기) / `Run` / `Sleep`(구석으로 이동 후 Zzz) / `Eat` / `Poop` / `Sick`(병듦) / `Sulk`(시무룩) / `Dragged`(집힘·버둥) / `Fall→Land`(낙하·착지) / `WindowWalk`(창 타이틀바 걷기, Phase 2) / `WindowSit`(창 위에 앉기, Phase 2)

### 9.4 업무 배려 원칙 (제품 헌법)

1. **입력을 절대 가로채지 않는다** — 펫 몸체 외 전 영역 클릭 통과, 포커스 탈취 금지
2. **소리는 기본 꺼짐** — 모든 사운드 opt-in
3. **죽지 않는다** — 최악의 방치도 "병듦"까지. 복귀 시 회복 가능
4. **집중 모드 1클릭** — 트레이에서 즉시 펫 정지·수면
5. **리소스는 백그라운드 앱 수준** — 게임이 아니라 상주 위젯처럼 동작

---

## 10. Next Steps

1. [ ] 설계 문서 작성 (`/pdca design desktop-tamagotchi`) — 오버레이/FSM/저장 스키마 상세 설계
2. [ ] 기술 스파이크: Godot 4 투명창 + `window_set_mouse_passthrough` 동작 검증 (설계 확정 전 필수)
3. [ ] 스프라이트 스타일 결정 및 우선 애니메이션 3종(대기/걷기/잠) 제작
4. [ ] Phase 1 구현 시작 (`/pdca do desktop-tamagotchi`)

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 0.1 | 2026-07-21 | Initial draft — 요구사항 확정(Godot 4, 정통 케어), Phase 1~3 범위 정의 | user1 |
| 0.2 | 2026-07-21 | FR-17(부화 캐릭터 10종), FR-18(말풍선 시스템) 추가 — 캐릭터 디자인 문서 연동 | user1 |
| 0.3 | 2026-07-22 | Phase 3 확장: FR-21~27 (리마인더·뽀모도로·할일·도감·마우스쫓기·코스튬·건강루틴) | user1 |
