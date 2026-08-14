# 클릭 통과 폴리곤 생성 (Design §2.2, §4.1).
# Windows에서 이 영역 밖은 렌더링도 잘린다(SetWindowRgn) — 이전에는 각 사각형을 2px 두께의
# "기둥(stem)"으로 화면 바닥과 연결해 하나의 오목한(concave) 폴리곤으로 이었으나 (공중에
# 뜬 펫 아래로 클릭 차단 기둥이 생기는 걸 막기 위해), 실측 결과 이 오목 폴리곤 자체가 이
# 환경의 DisplayServer.window_set_mouse_passthrough()에서 정상 렌더링되지 않는다 — 사각형
# 부분이 통째로 사라지고 얇은 기둥만 보이거나 아예 아무것도 안 보인다(폭 2px/20px, 와인딩
# 정방향/역방향 모두 재현됨; 반대로 기둥 없는 단순 볼록 사각형은 항상 정상 렌더링됨).
# 그래서 기둥을 두지 않는다 — 공중에 뜬 펫 아래로 클릭이 살짝 막히는 정도는, 펫이 아예
# 안 보이는 것보다 훨씬 가벼운 트레이드오프다.
# 2026-08-14: 기둥을 뺀 뒤에도 "각 사각형을 그대로 이어붙여" 반환하고 있었는데, 폴리곤은
# 하나뿐이라 이것 역시 떨어진 사각형 사이에 의도치 않은 변을 만든다(아래 build() 주석).
# 반환값은 항상 **볼록 사각형 하나**다.
extends RefCounted


## 떨어져 있는 사각형이 둘 이상이면 **전체를 감싸는 사각형 하나**를 돌려준다.
##
## 이전에는 각 사각형의 정점 4개를 한 폴리곤에 그냥 이어붙였다. 폴리곤은 하나뿐이라
## A의 왼아래에서 B의 왼위로 가는 대각선 변이 생기고, 결과는 자기교차(bowtie) 도형이 된다.
## 와인딩 규칙에 따라 영역이 서로 상쇄되면서 **사각형이 통째로 사라진다** — 응아를 한 뒤
## 펫이 걸어서 멀어지면(그 순간 두 사각형이 분리된다) 치울 때까지 펫이 화면에서 사라지던
## 버그가 이것이었다. 사각형이 하나일 때만 우연히 정상이었다.
##
## 얇은 통로로 이어 하나의 오목 폴리곤을 만드는 방법은 이 환경에서 이미 기각됐다(위 주석:
## 폭 2px/20px, 와인딩 양방향 모두 렌더링 실패). DisplayServer는 폴리곤 하나만 받으므로
## 떨어진 영역 여러 개를 정확히 표현할 방법이 없다 — 그래서 볼록 상위집합으로 덮는다.
## 대가는 펫과 응아 사이 띠에서 클릭이 통과되지 않는 것인데, 응아는 펫에서 60px 거리에
## 생기고 둘 다 바닥에 있어서 대개 펫 영역이 조금 넓어지는 정도다. 무엇이든 안 보이게
## 되는 것보다 가벼운 트레이드오프다(파일 헤더의 판단 기준과 같다).
static func build(rects: Array, _base_y: float) -> PackedVector2Array:
	var merged := _merge_intersecting(rects)
	if merged.is_empty():
		return PackedVector2Array()
	var region: Rect2 = merged[0]
	for index in range(1, merged.size()):
		region = region.merge(merged[index])
	return PackedVector2Array([
		region.position,
		Vector2(region.end.x, region.position.y),
		region.end,
		Vector2(region.position.x, region.end.y),
	])


static func _merge_intersecting(rects: Array) -> Array:
	var result: Array = []
	for r in rects:
		result.append(r)
	var changed := true
	while changed:
		changed = false
		for i in result.size():
			for j in range(i + 1, result.size()):
				if (result[i] as Rect2).grow(4.0).intersects(result[j]):
					result[i] = (result[i] as Rect2).merge(result[j])
					result.remove_at(j)
					changed = true
					break
			if changed:
				break
	return result
