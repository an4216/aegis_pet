# 뾰족이 (ppyojjok) 캐릭터 스펙

> 상태: 확정 (파이프라인 실행 테스트용 스코프 축소판)
> 작성: char-designer / character-pipeline
> 이 문서가 `sprite-artist`, `gd-integrator`, `qa-verifier`의 단일 입력이다. 여기 없는 값은 존재하지 않는 것으로 간주한다.

## 0. 컨셉 한 줄

책상 구석 화분에 사는 작은 선인장. 물을 안 줘도 안 죽는 대신, 관심을 안 주면 삐진다.
"덜 먹고 오래 버티는" 사무실 생존형 — 밥은 거의 필요 없지만 놀아주지 않으면 금방 시들해진다.

**애니메이션 등급: 포즈 캐릭터 (Idle 중심, 풀 애니메이션 아님).**
이번 릴리스에서는 `idle` 상태 시트 하나만 제작한다. 다른 상태(walk/eat/sleep 등)는 idle 포즈를 재사용하며,
`walk_static: true`를 켜서 걷기 모션 부재를 런타임 waddle로 보완한다 (ddungsil과 동일한 처리).

## 1. 데이터 테이블 (`scripts/data/characters.gd`)

| 필드 | 값 |
|---|---|
| `character_id` | `"ppyojjok"` |
| `name_kr` | `"뾰족이"` |
| `rarity` | `"rare"` |
| `stat_modifiers` | `{"hunger_decay": 0.5, "energy_decay": 0.8, "happiness_decay": 1.25, "move_speed": 0.6}` |
| `care_modifiers` | `{"feed": 0.6, "snack": 0.6, "play": 1.4, "pet": 0.7}` |
| `special` | `[]` |
| `walk_static` | `true` |
| `walk_face_inverted` | (설정하지 않음) |

GDScript 등록 형태:

```gdscript
"ppyojjok": {
    "name_kr": "뾰족이", "rarity": "rare",
    "stat_modifiers": {"hunger_decay": 0.5, "energy_decay": 0.8, "happiness_decay": 1.25, "move_speed": 0.6},
    "care_modifiers": {"feed": 0.6, "snack": 0.6, "play": 1.4, "pet": 0.7},
    "special": [],
    "walk_static": true,   # 포즈 캐릭터 — idle 단일 시트, waddle로 걷기 보완
},
```

### 기존 캐릭터와의 차별점 (중복 검증)

- `rarity: rare` + `special: []` 조합은 기존에 없다 (rare 2종 `bulgeumjo`=weekend_boost, `seureureuk`=after_work_boost).
- 유일하게 **happiness_decay를 올리고(1.25) hunger_decay를 크게 내린(0.5)** 캐릭터다.
  ddungsil(hunger 0.7 / energy 1.3)은 "많이 먹고 안 움직이는" 방향, 뾰족이는 "안 먹고 버티지만 외로움에 약한" 방향.
- `pet`을 깎고(0.7) `play`를 올린(1.4) 조합도 신규다 (geobujang은 play/pet을 둘 다 0.7로 깎음).
- **신규 `special` 태그 없음 → gd-integrator 로직 코드 변경 불필요.** 데이터 테이블 등록만으로 완결된다.

## 2. 진화 이름

| 위치 | 값 |
|---|---|
| `EVOLVED_NAMES["ppyojjok"]` | `"꽃대리"` |
| `EVOLVED_2_NAMES["ppyojjok"]` | `"가시본부장"` |

서사: 말 없이 구석에 있던 선인장(뾰족이) → 꽃 한 송이가 피면서 말을 걸기 시작(꽃대리) → 사무실 전체의
"버티는 법"을 알려주는 존재(가시본부장). 진화할수록 뾰족함은 남되 태도가 여유로워진다.

## 3. 진화 조건 (`scripts/data/balance.gd`)

기존 지표 `distinct_days`를 재사용한다 (`autoload/pet_state.gd` 카운터 추가 불필요).
선인장은 "물 준 횟수"가 아니라 "함께 지낸 날 수"로 자란다는 컨셉과 맞는다.
ppiyak(5 / 20)과 같은 지표지만 임계값이 달라 체감 페이스가 겹치지 않는다.

| 단계 | metric | amount | hint |
|---|---|---|---|
| `EVOLUTION` | `distinct_days` | `8` | `"서로 다른 날 8번 출근 - 조용히 꽃봉오리가 올라온다"` |
| `EVOLUTION_2` | `distinct_days` | `30` | `"출근 30일 - 사막에서도 버티는 가시본부장"` |

```gdscript
# EVOLUTION
"ppyojjok":   {"metric": "distinct_days",     "amount": 8,        "hint": "서로 다른 날 8번 출근 - 조용히 꽃봉오리가 올라온다"},
# EVOLUTION_2
"ppyojjok":   {"metric": "distinct_days",     "amount": 30,       "hint": "출근 30일 - 사막에서도 버티는 가시본부장"},
```

## 4. 몸통 크기 보정 (`BODY_SCALE`)

```gdscript
"ppyojjok": {"base": 1.0, "evolved": 1.0, "evolved2": 1.0},
```

초안값이다. `BODY_SCALE_TARGET_HEIGHT = 223.0` 기준으로,
**sprite-artist가 idle 시트의 알파 바운딩박스 높이를 실측한 뒤 이 스펙 파일의 값을 갱신 요청**해야 한다.
포즈 캐릭터라 idle 한 장만 실측하면 되고, 세 단계 모두 같은 방식으로 각각 산출한다.

## 5. 부화 히든 가중치 (`HATCH_WEIGHTS`) — 선택

기존 `neglect` 플래그에 항목 추가를 제안한다 (방치해도 안 죽는 선인장 컨셉과 직결).

```gdscript
"neglect": {"nyang": 2.0, "geobujang": 2.0, "ppyojjok": 2.5},
```

이번 파이프라인 테스트에서는 **선택 사항**이다. 반영하지 않아도 `RARITY_WEIGHT["rare"] = 4.0`으로 정상 부화한다.
gd-integrator 판단으로 생략 가능하며, 생략 시 스펙 위반이 아니다.

## 6. 대사 풀 (`scripts/data/dialog.gd` → `BY_CHARACTER["ppyojjok"]`)

어깨너머 안전 원칙 준수: 실제 업무 내용·수치·고유명사 없음. 전부 펫 1인칭 잡담 톤.
각 단계 `random` 6줄 + 트리거 override 4개 (테스트 최소 기준 3/3 초과).

### base — 뾰족이

```gdscript
"ppyojjok": {
    "base": {
        "random": [
            "나 물 안 줘도 돼. 대신 가끔 쳐다봐 줘",
            "가시는 무기 아니야. 그냥 내 성격이야",
            "화분 밖은 위험해. 여기가 딱 좋아",
            "심심하면 화분 톡 쳐봐. 흔들리는 거 재밌어",
            "쓰다듬을 땐 조심해. 나도 아프고 너도 아파",
            "…(조용히 자라는 중)",
        ],
        "monday_morning": "월요일. 나는 어차피 안 움직이니까 여유롭네",
        "three_pm": "햇빛 들어온다. 나 지금 제일 기분 좋은 시간이야",
        "quitting_time": "가? 나는 여기서 밤새 잘 있을게. 걱정 마",
        "overtime": "불 켜져 있으면 나도 안 자. 같이 버티는 거야",
    },
```

### e1 — 꽃대리

```gdscript
    "e1": {
        "random": [
            "봤어? 나 꽃 폈어. 딱 하나지만 진짜야",
            "가시 있어도 꽃은 피더라. 너도 그럴걸",
            "이제 말도 좀 늘었어. 구석에만 있던 거 졸업했어",
            "물은 여전히 조금만. 욕심내면 오히려 탈 나",
            "화분 옆자리 비어 있으면 누구든 앉아도 돼",
            "천천히 자라는 게 안 자라는 건 아니야",
        ],
        "monday_morning": "월요일에도 꽃은 그대로 있어. 그거면 충분하지 않아?",
        "three_pm": "3시 햇빛에 꽃잎 색이 제일 예뻐. 잠깐 봐줘",
        "quitting_time": "오늘도 안 시들었어. 서로 잘한 거야",
        "overtime": "늦게까지 있네. 나 꽃 켜둘 테니까 너무 어둡게 두지 마",
    },
```

### e2 — 가시본부장

```gdscript
    "e2": {
        "random": [
            "오래 버틴 비결? 무리해서 자라지 않은 거야",
            "여기 화분들 전부 내가 자리 잡아줬어",
            "가시는 지키려고 있는 거지, 찌르려고 있는 게 아니야",
            "메마른 날에도 사는 법, 필요하면 알려줄게",
            "새로 들어온 화분한테는 내가 먼저 인사해",
            "급하게 크는 애들이 제일 먼저 시들더라",
        ],
        "monday_morning": "월요일은 원래 사막이야. 그래도 다들 살아 있잖아",
        "three_pm": "3시. 다 같이 햇빛 쬐는 시간으로 정했어",
        "quitting_time": "마감했으면 가. 남은 건 내가 지키고 있을게",
        "overtime": "무리하지 마. 오래 남는 쪽이 결국 이기는 거야",
    },
},
```

## 7. 통합 체크리스트 (gd-integrator용)

- [ ] `scripts/data/characters.gd`: `CHARACTERS`, `EVOLVED_NAMES`, `EVOLVED_2_NAMES`, `BODY_SCALE` 4곳 추가
- [ ] `scripts/data/balance.gd`: `EVOLUTION`, `EVOLUTION_2` 2곳 추가
- [ ] `scripts/data/dialog.gd`: `BY_CHARACTER["ppyojjok"]` 추가 (base/e1/e2 전부)
- [ ] `scenes/pet/pet.gd`: 애니메이션 카탈로그에 idle 시트만 등록 (포즈 캐릭터)
- [ ] `HATCH_WEIGHTS["neglect"]`에 `ppyojjok: 2.5` (선택)
- [ ] 신규 `special` 태그 없음 → 로직 코드 변경 없음

## 8. TODO

- **TODO: `BODY_SCALE` 실측 필요** — sprite-artist가 idle 알파 바운딩박스 높이 측정 후 갱신. 현재 1.0은 임시값.
