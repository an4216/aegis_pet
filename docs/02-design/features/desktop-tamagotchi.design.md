# desktop-tamagotchi Design Document

> **Summary**: Godot 4 기반 투명 오버레이 데스크톱 다마고치의 상세 설계 (Autoload 싱글톤 + FSM, C안: 실용 밸런스)
>
> **Project**: desktop-tamagotchi
> **Version**: 0.1.0
> **Author**: user1
> **Date**: 2026-07-21
> **Status**: Draft
> **Planning Doc**: [desktop-tamagotchi.plan.md](../../01-plan/features/desktop-tamagotchi.plan.md)
> **Character Doc**: [characters.md](../characters.md)

---

## Context Anchor

| Key | Value |
|-----|-------|
| **WHY** | 업무 흐름을 방해하지 않으면서 데스크톱 위에 상주하는 육성형 펫이 없다 |
| **WHO** | 업무시간 대부분 PC를 사용하는 사무직/개발자 (Windows 10/11) |
| **RISK** | Godot에서 타 프로그램 창 위치 감지(Win32 EnumWindows)는 기본 미지원 → GDExtension 또는 폴링 방식 필요 |
| **SUCCESS** | 클릭 통과 오버레이에서 펫이 창/화면 위를 자율 이동, 알→성체 성장 사이클 완주, idle CPU < 3% / RAM < 150MB |
| **SCOPE** | Phase 1: 코어 펫 + 성장 + 케어 / Phase 2: 창 인식 이동 / Phase 3: 진화 분기·미니게임 |

---

## 1. Overview

### 1.1 Design Goals

1. **비침습 오버레이**: 펫 몸체 외 전 영역 클릭 통과, 포커스 탈취 0회
2. **확장 가능한 시뮬레이션**: 캐릭터 10종 × 행동 12종을 데이터 주도로 관리 (코드 수정 없이 캐릭터/대사 추가 가능)
3. **저리소스 상주**: low_processor_mode + 대기 시 저FPS, idle CPU < 3%
4. **저장 안전성**: 원자적 쓰기 + 백업으로 강제 종료에도 데이터 보존

### 1.2 Design Principles

- **밸런스 수치 단일 출처**: 모든 감소율/회복량은 `balance.gd` 한 파일에만 존재
- **데이터 주도 캐릭터**: 캐릭터 정의(보정치·팔레트·대사)는 `characters.gd` 데이터로 분리, 로직은 종족을 모름
- **시뮬레이션과 표현 분리**: 스탯 변화(autoload)는 화면 표현(씬)과 시그널로만 통신
- **YAGNI**: Phase 2(창 감지) 인터페이스만 자리 확보, 구현은 하지 않음

---

## 2. Architecture

### 2.0 Architecture Comparison

| Criteria | Option A: Minimal | Option B: Clean | Option C: Pragmatic |
|----------|:-:|:-:|:-:|
| Approach | main.gd 집중 | 도메인 완전 분리 + 이벤트 버스 | Autoload 싱글톤 + FSM 모듈 |
| New Files | ~8 | ~35 | ~20 |
| Complexity | Low | High | Medium |
| Maintainability | Low | High | High |
| Effort | Low | High | Medium |

**Selected**: **Option C** — **Rationale**: 캐릭터 10종·행동 12종 확장이 확정된 규모에서 Godot 관용구(Autoload + State 패턴)가 개발 속도와 유지보수의 최적 균형. 사용자 승인 완료 (2026-07-21).

### 2.1 Component Diagram

```
[Autoload 싱글톤 - 씬과 무관한 전역 상태]
┌─────────────────────────────────────────────────────┐
│ PetState        TimeManager        SaveManager      │
│ (스탯·성장·종족)  (틱·밤낮·오프라인)   (JSON 저장/복원)   │
└──────┬────────────────┬─────────────────┬───────────┘
       │ signals        │ minute_tick     │ autosave(60s)
       ▼                ▼                 ▼
[Main Scene - 투명 풀스크린 오버레이 창]
Main (Node2D)
├─ Pet (Node2D)
│   ├─ AnimatedSprite2D          # 종족별 SpriteFrames 교체
│   ├─ StateMachine (Node)       # scripts/states/*.gd 자식 노드
│   └─ ClickArea (Area2D)        # 클릭·드래그·쓰다듬기 입력
├─ PoopContainer (Node2D)        # 응아 인스턴스들
├─ UI (CanvasLayer)
│   ├─ CareMenu (PopupPanel)     # 우클릭 케어 메뉴
│   ├─ SpeechBubble (Control)    # 말풍선 (펫 머리 위 추적)
│   └─ StatsPopup (Control)      # 스탯 요약
├─ SpeechController (Node)       # 대사 트리거·쿨다운 관리
└─ PassthroughController (Node)  # 클릭 통과 폴리곤 갱신
[OS 통합] StatusIndicator(트레이) · DisplayServer(창 플래그) · 레지스트리(자동시작)
```

### 2.2 Data Flow

```
[시뮬레이션 틱]
TimeManager(1분 틱) → PetState.apply_decay(분당 감소 × 종족 보정)
  → stat_changed 시그널 → Pet 표정/상태 갱신, StatsPopup 갱신
  → 임계값 도달 시 → PetState.update_condition() → 병듦/시무룩/응아 이벤트

[케어 입력]
우클릭 → CareMenu → PetState.care(action)  (balance.gd 수치 적용)
  → stat_changed → Pet 반응 애니메이션(eat 등) + SpeechBubble 리액션

[클릭 통과]
매 프레임: PassthroughController가 펫 Rect + 열린 UI Rect 수집
  → DisplayServer.window_set_mouse_passthrough(폴리곤)

[저장]
SaveManager: 60초마다 + 종료 시 → save.json 원자적 쓰기(.tmp → rename) + .bak 유지
시작 시: load → TimeManager.compute_offline() → PetState.apply_offline_decay(50%, 최대 8h)
```

### 2.3 Dependencies

| Component | Depends On | Purpose |
|-----------|-----------|---------|
| PetState | balance.gd, characters.gd | 감소율·보정치 조회 |
| StateMachine(states/*) | PetState (읽기), TimeManager | 상태 전이 조건 판단 |
| SpeechController | dialog.gd, PetState, TimeManager | 대사 풀·트리거 조건 |
| SaveManager | PetState, TimeManager | 직렬화 대상 수집 |
| PassthroughController | DisplayServer | 클릭 통과 폴리곤 |
| Pet | PetState (시그널 구독) | 표현 갱신 |

> 의존 방향: 씬(표현) → Autoload(상태) → 데이터(balance/characters/dialog). 역방향 참조 금지 (Autoload는 씬 노드를 직접 참조하지 않고 시그널만 발신).

### 2.4 기술 스파이크 (구현 착수 전 필수 검증)

| # | 검증 항목 | 성공 기준 | 실패 시 대안 |
|---|-----------|----------|--------------|
| S1 | 투명 풀스크린 + `window_set_mouse_passthrough` | 펫 영역만 클릭, 나머지 통과. 브라우저/에디터 조작 정상 | "작은 이동 창" 모드로 전환 (창 자체가 펫 크기로 이동) |
| S2 | always_on_top + 포커스 비탈취 | 타이핑 중 포커스 유지 | popup 플래그/no_focus 창 플래그 조합 변경 |
| S3 | low_processor_mode 상태 CPU 측정 | idle CPU < 3% | max_fps 10 제한 + 파티클 제거 |

---

## 3. Data Model

### 3.1 저장 스키마 (user://save.json, v1)

```jsonc
{
  "schema_version": 1,
  "created_at": "2026-07-21T09:00:00+09:00",
  "last_saved_at": "2026-07-21T18:00:00+09:00",
  "pet": {
    "species": "mochi",            // null이면 알 상태 (부화 전)
    "stage": "child",              // egg | baby | child | adult
    "hatch_progress": 100,         // 알 단계에서만 사용 (0~100)
    "birth_at": "2026-07-14T10:00:00+09:00",
    "stage_started_at": "2026-07-17T10:00:00+09:00",
    "stats": { "hunger": 72, "happiness": 60, "cleanliness": 88, "energy": 45, "health": 90 },
    "is_sick": false,
    "poops": [ { "x": 300, "y": 980 } ],
    "care_quality_samples": [78, 82, 65],  // 일 1회 기록, 성체 진화 분기용 (Phase 3)
    "position": { "x": 800, "y": 980 }
  },
  "settings": {
    "focus_mode": false,
    "sound_enabled": false,        // 기본 꺼짐 (업무 배려 원칙)
    "night_start": "22:00",
    "night_end": "07:00",
    "bubble_frequency": "normal",  // often | normal | rare | off
    "always_on_top": true,
    "autostart": false
  }
}
```

- **원자적 쓰기**: `save.json.tmp`에 쓰기 → 성공 시 `save.json`으로 rename, 직전본은 `save.bak`으로 보존
- **마이그레이션**: `schema_version` 비교 후 순차 마이그레이션 함수 적용

### 3.2 캐릭터 정의 (scripts/data/characters.gd)

```gdscript
# 로직은 이 테이블만 조회한다. 캐릭터 추가 = 항목 추가 + 스프라이트 등록.
const CHARACTERS := {
  "mochi": {
    "name_kr": "모찌",
    "rarity": "common",            # common 15% / uncommon 8% / rare 4%
    "stat_modifiers": {},           # 배율. 예: {"hunger_decay": 1.3}
    "care_modifiers": { "pet_happiness": 1.5 },  # 쓰다듬기 +50%
    "special": [],                  # 특수 규칙 태그 (아래 3.3)
    "sprite_frames": "res://assets/sprites/mochi_frames.tres",
    "dialog_key": "mochi"
  },
  # ... 10종 (상세 수치: docs/02-design/characters.md §3)
}

const HATCH_WEIGHTS := {           # 히든 가중치 (characters.md §2.2)
  "night_hatch":   { "seureureuk": 3.0 },
  "friday_hatch":  { "bulgeumjo": 3.0 },
  "lunch_hatch":   { "haemjji": 2.0 },
  "morning_hatch": { "kong": 2.0 },
  "high_care":     { "ppiyak": 2.0 },
  "neglect":       { "nyang": 2.0, "geobujang": 2.0 }
}
```

### 3.3 특수 규칙 태그 (special)

| 태그 | 대상 | 처리 위치 |
|------|------|----------|
| `weekend_boost` | 불금조 | PetState 틱에서 요일 검사 → 행복 자동 회복/감소 보정 |
| `after_work_boost` | 스르륵 | 18시 이후 행복 회복, 낮 투명도 상승 (Pet 표현) |
| `caffeine_rush` | 콩이 | care(feed) 후 10분 이동속도 버프 (StateMachine 참조) |
| `self_snack` | 햄찌 | 낮은 확률 배고픔 자동 회복 |
| `burnout_link` | 문덕 | 행복 < 30이면 에너지 감소 가속 |
| `steady` | 거부장 | 전 스탯 감소 ×0.7, 이동속도 ×0.5 |

### 3.4 밸런스 상수 (scripts/data/balance.gd) — 발췌

```gdscript
const DECAY_PER_HOUR := { "hunger": 4.0, "happiness": 3.0, "energy_active": 5.0 }
const CARE_EFFECTS := { "feed": {"hunger": 30}, "snack": {"hunger": 10, "happiness": 5},
                        "play": {"happiness": 20, "energy": -10}, "pet": {"happiness": 3},
                        "medicine": {"health": 40}, "clean": {"cleanliness": 15} }
const POOP_INTERVAL_MIN := [90, 180]      # 분, 랜덤 범위
const POOP_CLEAN_PENALTY := 15.0          # 응아 1개당 청결 감소
const SICK_THRESHOLD := 30.0              # 건강 < 30 → 병듦
const OFFLINE_DECAY_RATE := 0.5           # 오프라인 감소 50%
const OFFLINE_CAP_HOURS := 8.0
const STAGE_DURATION_DAYS := { "baby": 3, "child": 4 }   # 합계 7일 후 성체
const HATCH_HOURS_RANGE := [1.0, 4.0]
```

### 3.5 상태(FSM) 정의

```
[상태 전이 다이어그램 - Phase 1]

          ┌──────── 부화 완료 ────────┐
 (Egg) ───┘                          ▼
        Idle ⇄ Walk        (확률·타이머 기반 랜덤 전이)
          │  ↘ Eat          (케어 입력 시)
          │  ↘ Poop         (POOP_INTERVAL 타이머)
          │  ↘ Sulk         (행복 < 20)
          │  ↘ Sick         (건강 < 30, 최우선)
          ├─→ Sleep         (에너지 < 15 / 밤 시간 / 집중 모드 / 재우기)
          └─→ Dragged       (마우스 집기, 어디서든 진입)
                └─→ Fall → Land → Idle
우선순위: Dragged > Sick > Sleep(강제) > Sulk > 일반 행동
```

| 상태 | 진입 조건 | 행동 | 이탈 |
|------|----------|------|------|
| EggState | species == null | 화면 하단 고정, 흔들림, 클릭 시 hatch_progress 증가 | 부화 → Idle |
| IdleState | 기본 | 두리번, 3~8초 후 랜덤 전이 | Walk 등 |
| WalkState | Idle에서 확률 | 화면 하단(작업표시줄 상단 y) 좌우 이동 | 목적지 도달 |
| SleepState | 에너지/밤/집중모드 | 화면 구석으로 이동 후 Zzz, 에너지 회복 | 회복 완료/아침 |
| EatState | care(feed/snack) | 먹기 애니메이션 2초 | 완료 → Idle |
| PoopState | 타이머 | 응아 생성 → PoopContainer | 즉시 → Idle |
| SickState | health < 30 | 이동 정지, 아픈 표정 | medicine → Idle |
| SulkState | happiness < 20 | 구석에 웅크림 | happiness ≥ 40 |
| DraggedState | ClickArea 드래그 | 버둥 애니메이션, 마우스 추적 | 놓으면 Fall |
| FallState | Dragged 해제 | 중력 낙하 | 바닥 → Land → Idle |

---

## 4. 플랫폼 통합 인터페이스 (API 대체 섹션)

> 웹 API 없음. OS 통합 지점을 인터페이스로 정의한다.

### 4.1 창 설정 (main.gd `_ready()`)

| 설정 | 값 | 목적 |
|------|-----|------|
| `transparent_bg`, per_pixel_transparency | on | 투명 오버레이 |
| borderless, always_on_top | on | 테두리 없음·최상위 |
| `window_set_mouse_passthrough(polygon)` | 펫+UI+말풍선 영역 (64px 격자 스냅) | 클릭 통과. 주의 2가지: ① 이 영역 밖은 렌더링도 잘림(SetWindowRgn) — 보여야 할 요소는 폴리곤에 포함 ② region을 매 프레임 갱신하면 경계에 흰 줄 번쩍임 — **반드시 격자 스냅으로 갱신 빈도 최소화**. `Window.mouse_passthrough` 전체 플래그는 OS에 적용되지 않아 사용 불가(2026-07 검증) |
| unfocusable(no_focus) | on | 포커스 탈취 방지 |
| low_processor_mode | on | 상주 리소스 절약 |
| max_fps | 활동 30 / 대기 10 | CPU 절약 |

### 4.2 트레이 (StatusIndicator)

| 메뉴 항목 | 동작 |
|-----------|------|
| 상태 보기 | StatsPopup 토글 |
| 집중 모드 | settings.focus_mode 토글 → Sleep 강제 + 말풍선 off |
| 항상 위 | always_on_top 토글 |
| 시작 시 자동 실행 | 레지스트리 `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` 등록/해제 (OS.execute reg add/delete) |
| 종료 | SaveManager.save() → quit |

### 4.3 창 감지 어댑터 (Phase 2 — 구현 완료)

- **방식**: Windows 내장 C# 컴파일러(csc, .NET Framework 4.x)로 첫 실행 시 `window_probe.exe`를 빌드 → 헬퍼가 0.5초마다 EnumWindows 결과를 `user://windows.json`에 기록 → Godot이 폴링
- **개인정보**: 창 제목은 읽지 않음 (핸들·클래스 판별·좌표만)
- **수명 관리**: 게임 pid를 헬퍼에 전달 → 게임 종료 시 헬퍼 자동 종료 (+ Godot 쪽 OS.kill 이중 안전장치)
- **토스트 감지**: CoreWindow 계열 소형 창 휴리스틱 → `toast_appeared` 시그널 → 펫이 달려가 올라탐
- **폴백**: csc 부재/빌드 실패 시 platforms 빈 배열 = Phase 1 동작 (우아한 성능 저하)
- **관련 상태**: `JumpState`(포물선 점프) / `PerchState`(창 위 앉기·산책, 창 이동 추적, 소실 시 낙하)
- **클릭영역**: 스카이라인 방식 → **스템(stem) 방식**(`region_builder.gd`)으로 교체 — 공중에 뜬 펫 아래로 클릭 차단 기둥이 생기지 않도록 2px 기둥으로만 바닥과 연결

---

## 5. UI/UX Design

### 5.1 화면 레이아웃

```
┌─ 전체 화면 (투명, 클릭 통과) ──────────────────────────┐
│                                        [말풍선]        │
│                                       ┌────────┐      │
│   (업무 창들 - 통과 영역)               │ 6시다.  │      │
│                                       │ 난이미없어│     │
│                                       └───▽────┘      │
│                                         🐥 ← 펫(클릭 가능) │
│ ┌스탯팝업(트레이에서)┐      ┌케어메뉴(우클릭)┐             │
│ │ 🍚72 😊60 🧼88   │      │ 먹이/간식/청소  │             │
│ │ ⚡45 ❤90        │      │ 놀기/약/재우기  │             │
│ └─────────────────┘      └───────────────┘             │
└─────────────── 작업표시줄 위 y = ground_y ──────────────┘
```

### 5.2 인터랙션 플로우

```
좌클릭(짧게): 쓰다듬기 → 하트 이펙트 + happiness +3 (쿨다운 30초, 나른냥은 3회째 2배)
좌클릭(길게) + 이동: 드래그 → Dragged 상태 → 놓으면 낙하
우클릭: CareMenu 팝업 (펫 옆에 표시, 화면 밖 클램프)
알 단계 클릭: hatch_progress 증가 + 흔들림 강화
응아 클릭: 즉시 청소 (CareMenu 없이도 가능)
```

### 5.3 컴포넌트 목록

| Component | Scene | 책임 |
|-----------|-------|------|
| CareMenu | scenes/ui/care_menu.tscn | 케어 버튼 6종, PetState.care() 호출 |
| SpeechBubble | scenes/ui/speech_bubble.tscn | 대사 표시 5초, 페이드, 펫 추적, 화면 클램프 |
| StatsPopup | scenes/ui/stats_popup.tscn | 스탯 5종 게이지 + 나이/단계 |
| HeartEffect | scenes/ui/heart_effect.tscn | 쓰다듬기 이펙트 (CPUParticles2D 최소) |
| Poop | scenes/pet/poop.tscn | 응아. 클릭 시 제거 + 청결 회복 |

### 5.4 말풍선 트리거 (SpeechController)

- 우선순위: 특수일(월급날 25일) > 요일·시간대 > 캐릭터 랜덤 (characters.md §4.2 대사 풀)
- 빈도: `bubble_frequency` 설정 — often 15±5분 / normal 30±10분 / rare 60±20분 / off
- 억제 조건: focus_mode, Sleep 상태, 최근 5개 대사 중복 금지
- 데이터: `scripts/data/dialog.gd` — `COMMON`(트리거별)과 `BY_CHARACTER`(종족별) 딕셔너리

---

## 6. Error Handling

| 상황 | 감지 | 처리 |
|------|------|------|
| save.json 손상 | JSON parse 실패 | save.bak 로드 시도 → 실패 시 새 게임 + 알림 말풍선 |
| 마우스 통과 미지원/실패 | S1 스파이크 결과 | `small_window_mode = true` 폴백: 펫 크기 창이 직접 이동 |
| 시스템 시계 역행 (오프라인 계산 음수) | elapsed < 0 | 경과 0으로 처리, 페널티 없음 |
| 모니터 해상도 변경/절전 복귀 | window resize 알림 | ground_y 재계산, 펫 위치 화면 내 클램프 |
| 레지스트리 등록 실패 (권한) | reg 명령 exit code | 자동 시작 토글 해제 + 안내 |
| 스프라이트 리소스 누락 | load null | 기본 모찌 스프라이트 폴백 + 로그 |

---

## 7. Security & Privacy

- [ ] 네트워크 통신 전무 (완전 로컬 앱) — 방화벽 예외 불필요
- [ ] Phase 2 창 감지는 위치(Rect)만 사용, 창 제목·내용 저장/전송 금지
- [ ] 레지스트리 쓰기는 HKCU Run 키 1개만, opt-in + 해제 기능 제공
- [ ] 저장 파일에 개인정보 없음 (펫 상태 + 설정만)

---

## 8. Test Plan

### 8.1 Test Scope

| Type | Target | Tool |
|------|--------|------|
| Unit | PetState 감소/케어/성장 판정, 오프라인 계산, 부화 가중치 | GUT |
| Unit | SaveManager 직렬화/마이그레이션/손상 복구 | GUT |
| Manual | 클릭 통과, 드래그, 트레이, 멀티모니터, DPI 200% | 체크리스트 |
| Soak | 8시간 연속 실행 CPU/RAM | 작업 관리자 기록 |

### 8.2 Key Test Cases

- [ ] 1시간 경과 시 hunger 4.0 감소 (거부장은 2.8)
- [ ] 오프라인 12시간 → 8시간 캡 × 50% 만 적용
- [ ] health 29 → SickState 진입, medicine → 회복
- [ ] 부화 1000회 시뮬레이션: 기본 확률 분포 ±2%p, 금요일 가중치 시 불금조 ~11%
- [ ] save 강제 종료(프로세스 킬) 후 재시작 → 최근 60초 이내 상태 복원
- [ ] schema_version 0 파일 → v1 마이그레이션 정상
- [ ] 집중 모드 중 말풍선/이동 없음, 스탯 감소는 지속

---

## 9. Architecture Layers (Godot 적용)

### 9.1 Layer Structure

| Layer | 책임 | 위치 |
|-------|------|------|
| Presentation | 씬, 애니메이션, UI, 이펙트 | `scenes/`, Pet·UI 스크립트 |
| Application | 전역 상태·시뮬레이션·저장 | `autoload/` |
| Domain(Data) | 밸런스·캐릭터·대사 상수 | `scripts/data/` |
| Infrastructure | OS 통합 (창·트레이·레지스트리·창감지) | main.gd 창 설정부, `scripts/platform/` |

### 9.2 Dependency Rules

```
scenes(표현) ──→ autoload(상태) ──→ scripts/data(상수)
     │                                    ▲
     └──────── scripts/platform ──────────┘
규칙: autoload는 씬 노드를 직접 참조하지 않는다 (시그널 발신만).
     scripts/data는 아무것도 import하지 않는다 (순수 상수).
```

---

## 10. Coding Conventions

| Target | Rule | Example |
|--------|------|---------|
| 파일/폴더 | snake_case | `pet_state.gd`, `care_menu.tscn` |
| 클래스(class_name) | PascalCase | `PetStateMachine`, `WindowProbe` |
| 함수/변수 | snake_case | `apply_decay()`, `hatch_progress` |
| 상수 | UPPER_SNAKE | `DECAY_PER_HOUR` |
| 시그널 | 과거형 snake_case | `stat_changed`, `stage_changed` |
| 노드명 | PascalCase | `SpeechBubble`, `ClickArea` |
| 씬:스크립트 | 1:1 동일 이름 | `pet.tscn` + `pet.gd` |

- 포매터: gdformat, 린터: gdlint (pre-commit)
- 디버그 치트(시간 가속 ×60/×600, 부화 강제)는 `OS.is_debug_build()` 가드 필수

---

## 11. Implementation Guide

### 11.1 File Structure

```
desktop-tamagotchi/
├── project.godot
├── autoload/
│   ├── pet_state.gd          # 스탯·성장·종족·케어 로직
│   ├── time_manager.gd       # 분 틱·밤낮·요일·오프라인 경과
│   └── save_manager.gd       # 직렬화·원자적 쓰기·마이그레이션
├── scenes/
│   ├── main.tscn / main.gd   # 창 설정·트레이·PassthroughController
│   ├── pet/
│   │   ├── pet.tscn / pet.gd
│   │   ├── state_machine.gd
│   │   └── poop.tscn / poop.gd
│   └── ui/
│       ├── care_menu.tscn / .gd
│       ├── speech_bubble.tscn / .gd
│       ├── stats_popup.tscn / .gd
│       └── heart_effect.tscn
├── scripts/
│   ├── states/               # egg, idle, walk, sleep, eat, poop,
│   │                         # sick, sulk, dragged, fall (base: state.gd)
│   ├── data/
│   │   ├── balance.gd
│   │   ├── characters.gd
│   │   └── dialog.gd
│   ├── platform/
│   │   └── window_probe.gd   # Phase 2 스텁
│   └── speech_controller.gd
├── assets/sprites/           # 캐릭터별 SpriteFrames(.tres) + concept/
└── tests/                    # GUT: test_pet_state.gd, test_save.gd, test_hatch.gd
```

### 11.2 Implementation Order

1. [ ] **S1~S3 기술 스파이크** — 투명창+클릭통과 검증 (실패 시 §6 폴백 설계로 전환)
2. [ ] 데이터 계층: balance.gd, characters.gd, dialog.gd
3. [ ] Autoload: TimeManager → PetState → SaveManager (+GUT 테스트)
4. [ ] 메인 오버레이: main.tscn 창 설정, PassthroughController
5. [ ] Pet FSM: state.gd 베이스 → Egg/Idle/Walk/Sleep → Dragged/Fall → Eat/Poop/Sick/Sulk
6. [ ] UI: CareMenu → StatsPopup → SpeechBubble/SpeechController → HeartEffect
7. [ ] 트레이·집중 모드·자동 시작
8. [ ] 성장 통합: 부화 가중치 → 단계 전환 → 종족 보정 적용
9. [ ] 밸런스 검증 (시간 가속 치트) + 8h soak 테스트 + export

### 11.3 Session Guide

#### Module Map

| Module | Scope Key | Description | Estimated Turns |
|--------|-----------|-------------|:---------------:|
| 스파이크+데이터+코어 시뮬레이션 | `module-1` | S1~S3 검증, data 3종, autoload 3종 + GUT 테스트 | 40 |
| 오버레이+펫 FSM | `module-2` | main 창 설정, 클릭통과, 상태 10종, 이동/드래그 | 50 |
| UI+케어+말풍선 | `module-3` | CareMenu, StatsPopup, SpeechBubble, 트레이, 집중모드 | 40 |
| 성장+캐릭터 통합 | `module-4` | 부화 시스템, 단계 전환, 종족 보정, 자동시작, export | 40 |

#### Recommended Session Plan

| Session | Phase | Scope | Turns |
|---------|-------|-------|:-----:|
| Session 1 | Plan + Design | 전체 | 완료 |
| Session 2 | Do | `--scope module-1` | 40-50 |
| Session 3 | Do | `--scope module-2` | 40-50 |
| Session 4 | Do | `--scope module-3` | 40-50 |
| Session 5 | Do | `--scope module-4` | 40-50 |
| Session 6 | Check + Report | 전체 | 30-40 |

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 0.1 | 2026-07-21 | Initial draft — C안(실용 밸런스) 선택, FSM/데이터모델/플랫폼 통합 설계 | user1 |
