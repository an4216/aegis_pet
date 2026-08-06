# 클릭 통과 폴리곤 생성 (Design §2.2, §4.1).
# Windows에서 이 영역 밖은 렌더링도 잘린다(SetWindowRgn) — 이전에는 각 사각형을 2px 두께의
# "기둥(stem)"으로 화면 바닥과 연결해 하나의 오목한(concave) 폴리곤으로 이었으나 (공중에
# 뜬 펫 아래로 클릭 차단 기둥이 생기는 걸 막기 위해), 실측 결과 이 오목 폴리곤 자체가 이
# 환경의 DisplayServer.window_set_mouse_passthrough()에서 정상 렌더링되지 않는다 — 사각형
# 부분이 통째로 사라지고 얇은 기둥만 보이거나 아예 아무것도 안 보인다(폭 2px/20px, 와인딩
# 정방향/역방향 모두 재현됨; 반대로 기둥 없는 단순 볼록 사각형은 항상 정상 렌더링됨).
# 그래서 기둥 없이 각 사각형을 그대로 반환한다 — 공중에 뜬 펫 아래로 클릭이 살짝 막히는
# 정도는, 펫이 아예 안 보이는 것보다 훨씬 가벼운 트레이드오프다.
extends RefCounted


static func build(rects: Array, _base_y: float) -> PackedVector2Array:
	var merged := _merge_intersecting(rects)
	merged.sort_custom(func(a, b): return a.get_center().x < b.get_center().x)
	var poly := PackedVector2Array()
	for r in merged:
		var rl: float = r.position.x
		var rt: float = r.position.y
		var rr: float = r.end.x
		var rb: float = r.end.y
		poly.append(Vector2(rl, rt))
		poly.append(Vector2(rr, rt))
		poly.append(Vector2(rr, rb))
		poly.append(Vector2(rl, rb))
	return poly


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
