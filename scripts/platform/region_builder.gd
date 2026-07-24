# 클릭 통과 폴리곤 생성 (Design §2.2, §4.1).
# Windows에서 이 영역 밖은 렌더링도 잘리므로(SetWindowRgn), 보여야 할 모든 사각형을
# 2px 두께의 "기둥(stem)"으로 화면 바닥과 연결해 하나의 폴리곤으로 잇는다.
# (기존 스카이라인 방식은 공중에 뜬 펫 아래로 클릭 차단 기둥이 생기는 문제가 있었다)
extends RefCounted


static func build(rects: Array, base_y: float) -> PackedVector2Array:
	var merged := _merge_intersecting(rects)
	merged.sort_custom(func(a, b): return a.get_center().x < b.get_center().x)
	var poly := PackedVector2Array()
	for r in merged:
		var rl: float = r.position.x
		var rt: float = r.position.y
		var rr: float = r.end.x
		var rb: float = minf(r.end.y, base_y - 1.0)
		var sx: float = clampf(r.get_center().x, rl + 2.0, rr - 2.0)
		poly.append(Vector2(sx - 1.0, base_y))
		poly.append(Vector2(sx - 1.0, rb))
		poly.append(Vector2(rl, rb))
		poly.append(Vector2(rl, rt))
		poly.append(Vector2(rr, rt))
		poly.append(Vector2(rr, rb))
		poly.append(Vector2(sx + 1.0, rb))
		poly.append(Vector2(sx + 1.0, base_y))
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
