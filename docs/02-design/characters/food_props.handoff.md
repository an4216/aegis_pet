# 먹이/간식 소품 인수인계 — 모찌 · 햄찌

> 작성: sprite-artist / character-pipeline, 2026-08-07
> 제작 기록: `assets/generated/sprites/mochi-food-v1/`, `haemjji-food-v1/`, `haemjji-food-snack-v2/`
> **스코프**: 모찌·햄찌 각 2장(feed/snack) = **총 4장**. **티어 공용**(`FOOD_PROPS`가 species 단위).

## 1. 런타임 계약 (코드에서 확인함)

`pet.gd`의 `show_food_prop()`(:1316)이 이렇게 쓴다:

```gdscript
var path := Characters.get_food_prop(ps.species, _last_food_action)   # "feed" | "snack"
_food_prop.texture = load(path)
_food_prop.position = Vector2(_frame_size.x * _base_scale.x * 0.55 * side,
                              -_frame_size.y * _base_scale.y * 0.3)
_food_prop.scale = _base_scale        # ← 펫과 같은 배율
# 이후 scale을 0.1로 줄이고 alpha를 0으로 tween (먹는 연출)
```

- **species 단위**다(`FOOD_PROPS[species][action]`) → base/evolved/evolved2 **3티어가 같은 파일을 공유**한다. 태스크 요구와 일치.
- **`scale`이 펫의 `_base_scale`과 동일**하다. 즉 화면에 보이는 소품 크기는 **PNG 안 오브젝트의 픽셀 높이**가 그대로 결정한다. 소품별 배율 키는 없다.
- `Sprite2D`는 기본 `centered = true`이므로 128×128 캔버스 정중앙에 오브젝트를 두면 위 offset 계산이 의도대로 맞는다.
- `FOOD_PROPS`가 비어 있으면 소품 없이 Eat 동작만 재생된다(하위 호환) — 등록 전에도 회귀 없음.

## 2. 등록값 (gd-integrator)

```gdscript
const FOOD_PROPS := {
    "mochi": {
        "feed":  "res://assets/sprites/mochi/food_feed.png",
        "snack": "res://assets/sprites/mochi/food_snack.png",
    },
    "haemjji": {
        "feed":  "res://assets/sprites/haemjji/food_feed.png",
        "snack": "res://assets/sprites/haemjji/food_snack.png",
    },
}
```

| 자산 | 내용 | 캔버스 | 오브젝트 폭×높이 | `safe_margin` | 몸통 폭 대비 |
|---|---|---|---:|---:|---:|
| `mochi/food_feed.png` | 파스텔 핑크 그릇에 담긴 흰쌀밥 | 128×128 | 96×86 | 16 | **62%** |
| `mochi/food_snack.png` | 크림색 접시 위 분홍 모찌 경단 3개 | 128×128 | 96×65 | 16 | **62%** |
| `haemjji/food_feed.png` | 주황 테두리 그릇에 담긴 해바라기씨·곡물 믹스 | 128×128 | 48×37 | 40 | **59%** |
| `haemjji/food_snack.png` | 도토리 1개 | 128×128 | 45×48 | 40 | **56%** |

기준 몸통 폭(idle 프레임 알파 바운딩박스): 모찌 156px, 햄찌 81px.

> **2026-08-07 수정** — 햄찌 feed가 몸통 폭의 118~125%로 펫보다 컸다. `safe_margin` 16 -> 40으로
> **재생성 없이 재추출만** 해서 96×74 -> 48×37로 줄였다(런 `haemjji-food-feed-v2/`).
> 원인은 §4의 연장선이다: 추출이 컴포넌트를 안전영역에 꽉 맞추므로 `safe_margin 16`은 형태와
> 무관하게 **항상 폭 96px**을 낳는데, 셀 폭이 종족마다 다르다(모찌 192 / 햄찌 128).
> 그래서 **높이 비율은 정상 대역(67~71%)으로 보였는데도 폭이 과대**였다 —
> 소품 크기 검수는 반드시 **폭** 기준으로 한다.

`.import` 4장 전부 `mipmaps/generate=true` + Godot 4.4.1 헤드리스 임포트 검증 완료.

## 3. 디자인 근거

`care_menu.gd`의 아이콘이 **feed = 🍚, snack = 🍪**다. 플레이어가 그 버튼을 누르고 보는 물건이므로
**"그릇에 담긴 한 끼" vs "손에 집는 간식"** 이라는 카테고리 실루엣을 양쪽 캐릭터 모두 지켰다.
그 위에 캐릭터별 소재를 입혔다:

- **모찌**(분홍 젤리 떡 캐릭터): 밥그릇은 파스텔 핑크 도자기, 간식은 **자기 이름값인 분홍 모찌 경단**
- **햄찌**(햄스터, `care_modifiers.snack = 2.0`으로 간식이 시그니처): 밥그릇은 **해바라기씨·곡물 믹스**,
  간식은 **도토리**

4장 모두 소품만 그렸다 — 테이블·젓가락·김·반짝임·그림자·텍스트·캐릭터 없음. 전 프레임 단일 연결 컴포넌트.

## 4. ⚠️ 소품 크기는 프롬프트가 아니라 `safe_margin`이 정한다 (실측으로 확인)

처음 4장을 뽑았을 때 **햄찌 도토리가 펫 몸통의 92%**로 나왔다 — 햄스터만 한 도토리다.
프롬프트에 "작게 그려라"를 넣어 재생성해도 **그대로 96px이 나왔다.**

원인: **추출이 각 컴포넌트를 셀의 안전영역에 꽉 맞춘다.** 4장 모두 정확히
`96px = 128 − 2×16(safe_margin)`이었다 — 원본에서 크게 그렸든 작게 그렸든 결과는 같다.

→ 따라서 **소품의 상대 크기를 정하는 손잡이는 `safe_margin` 하나뿐**이다.
도토리를 47px로 만들려고 `safe_margin = (128−47)/2 ≈ 40`으로 잡아 **같은 raw를 재추출**했다
(재생성 없음, 12~15분 절약). 결과 48px.

**다음에 소품을 만들 사람에게**: 원하는 오브젝트 높이 `H`가 있으면
`safe_margin = (cell − H) / 2`로 요청하면 된다. 프롬프트로 크기를 조절하려 하지 마라.

## 5. 자체 검수

- [x] 4장 모두 추출 `ok: true`, errors/warnings 없음
- [x] `edge_pixels` 0, `chroma_adjacent` 0 (시안 키, 음식 색과 충돌 없음)
- [x] **4장 전부 단일 연결 컴포넌트** — 부유 파편 없음
- [x] 소품 외 요소 없음(테이블·텍스트·캐릭터·그림자 없음)
- [x] 128×128 캔버스 중앙 정렬 (`Sprite2D.centered = true` 전제와 일치)
- [x] 밉맵 + Godot 임포트 4/4
- [x] 크기 밸런스 — **몸통 폭 대비 56~62%**로 4장이 같은 대역에 든다 (높이가 아니라 폭 기준)
- [ ] **실제 화면 QA 미실시** — `qa-verifier` 담당. 특히 **소품이 펫 옆에서 잘리지 않는지**
      (offset이 `_frame_size.x × 0.55`라 화면 가장자리에서 펫이 벽에 붙어 있으면 소품이 화면 밖으로
      나갈 수 있다) 확인이 필요하다. 이건 자산이 아니라 배치 로직 쪽 이슈다.

## 6. 미제작

- 나머지 11종(ppiyak·bichon·nyang 등)의 food 소품. `FOOD_PROPS`에 없으면 소품 없이 Eat만 재생되므로
  **등록하지 않아도 회귀는 없다**(하위 호환 설계).
- 모찌·햄찌 모두 **티어 공용 1쌍**이다. 티어별로 다른 음식을 원하면 `FOOD_PROPS` 구조를
  species→tier→action으로 확장해야 하는데, 현재 `get_food_prop(species, action)` 시그니처가
  티어를 받지 않으므로 **코드 변경이 필요**하다.

## 7. 제작 기록

| 런 | 내용 |
|---|---|
| `mochi-food-v1/` | 밥그릇·모찌경단 raw 2 + frames 2 + curated 2 |
| `haemjji-food-v1/` | 씨앗그릇·도토리(1차, 92% 과대) raw 2 + frames 2. 반려본 `raw/food_snack.v1-too-large.png` 보존 |
| `haemjji-food-snack-v2/` | 같은 도토리 raw를 `safe_margin 40`으로 **재추출만** 한 런 (생성 없음) |
| `haemjji-food-feed-v2/` | 같은 씨앗그릇 raw를 `safe_margin 40`으로 **재추출만** 한 런 (생성 없음, 2026-08-07 폭 과대 수정) |

생성은 4 row(1프레임짜리 row) + 도토리 재생성 1회 = 5회, 마지막 크기 수정은 재추출로 해결.
추출·compose는 Linux 컨테이너(`runio.py` fcntl 가드 무수정).
