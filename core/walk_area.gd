class_name WalkArea
extends RefCounted
## Walkable polygon with simple pathfinding (visibility graph + A*), so Lili walks around corners.

const EPS := 1.5

var poly := PackedVector2Array()


func _init(points: PackedVector2Array) -> void:
	poly = points


func contains(p: Vector2) -> bool:
	if poly.size() < 3:
		return true
	return Geometry2D.is_point_in_polygon(p, poly) or _on_edge(p)


## Nearest walkable point.
func clamp_point(p: Vector2) -> Vector2:
	if contains(p):
		return p
	var best := p
	var best_dist := INF
	for i in poly.size():
		var c := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
		var d := c.distance_squared_to(p)
		if d < best_dist:
			best_dist = d
			best = c
	return best


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	from = clamp_point(from)
	to = clamp_point(to)
	if poly.size() < 3 or _visible(from, to):
		return PackedVector2Array([from, to])
	var points := PackedVector2Array([from, to])
	points.append_array(poly)
	var astar := AStar2D.new()
	for i in points.size():
		astar.add_point(i, points[i])
	for i in points.size():
		for j in range(i + 1, points.size()):
			if _visible(points[i], points[j]):
				astar.connect_points(i, j)
	var path := astar.get_point_path(0, 1)
	if path.is_empty():
		return PackedVector2Array([from, to])
	return path


## True when the straight segment a-b stays inside the polygon.
func _visible(a: Vector2, b: Vector2) -> bool:
	if a.distance_to(b) < EPS:
		return true
	for i in poly.size():
		var c := poly[i]
		var d := poly[(i + 1) % poly.size()]
		var hit = Geometry2D.segment_intersects_segment(a, b, c, d)
		if hit == null:
			continue
		var h: Vector2 = hit
		if h.distance_to(a) > EPS and h.distance_to(b) > EPS and h.distance_to(c) > EPS and h.distance_to(d) > EPS:
			return false
	return contains((a + b) * 0.5)


func _on_edge(p: Vector2) -> bool:
	for i in poly.size():
		if Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()]).distance_to(p) < EPS:
			return true
	return false
