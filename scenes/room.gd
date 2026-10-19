class_name Room
extends Node2D
## Visual side of one scene: background (or placeholder), hotspot hit-testing, walk area and Lili.

const SIZE := Vector2(1920, 1080)

var data: Dictionary = {}
var walk: WalkArea
var lili: Lili
var _hotspots: Array = []
var _placeholder := true
var _highlight := false
var _font: Font


static func vec(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


static func poly(a) -> PackedVector2Array:
	var p := PackedVector2Array()
	for v in a:
		p.append(vec(v))
	return p


static func centroid(hs: Dictionary) -> Vector2:
	var p := poly(hs.get("polygon", []))
	var sum := Vector2.ZERO
	for v in p:
		sum += v
	return sum / maxi(p.size(), 1)


func setup(scene_data: Dictionary, background: Texture2D, foreground: Texture2D, from_scene: String) -> void:
	data = scene_data
	_font = ThemeDB.fallback_font
	if background:
		_placeholder = false
		_add_layer(background, -1)
	if foreground:
		_add_layer(foreground, 1)
	walk = WalkArea.new(poly(data.get("walk_area", [])))
	lili = Lili.new()
	lili.depth = data.get("depth_scale", lili.depth)
	add_child(lili)
	var entries: Dictionary = data.get("entries", {})
	lili.place(vec(entries.get(from_scene, data.get("lili_start", [960, 800]))))
	queue_redraw()


func set_hotspots(list: Array) -> void:
	_hotspots = list
	queue_redraw()


func set_highlight(on: bool) -> void:
	_highlight = on
	queue_redraw()


## Topmost visible hotspot at a point, or {} if none.
func hotspot_at(p: Vector2) -> Dictionary:
	for i in range(_hotspots.size() - 1, -1, -1):
		if Geometry2D.is_point_in_polygon(p, poly(_hotspots[i]["polygon"])):
			return _hotspots[i]
	return {}


func target_for(hs: Dictionary) -> Vector2:
	if hs.has("walk_to"):
		return vec(hs["walk_to"])
	return walk.clamp_point(centroid(hs))


func _add_layer(texture: Texture2D, z: int) -> void:
	var s := Sprite2D.new()
	s.texture = texture
	s.centered = false
	s.z_index = z
	add_child(s)


func _draw() -> void:
	if _placeholder:
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color(String(data.get("placeholder_color", "#555555"))))
		if walk.poly.size() >= 3:
			draw_colored_polygon(walk.poly, Color(1, 1, 1, 0.08))
		draw_string(_font, Vector2(40, 80), tr(String(data.get("title", ""))), HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(1, 1, 1, 0.6))
	if not (_placeholder or _highlight):
		return
	for hs in _hotspots:
		var p := poly(hs["polygon"])
		draw_colored_polygon(p, Color(1, 0.85, 0.3, 0.25) if _highlight else Color(1, 1, 1, 0.12))
		var outline := p.duplicate()
		outline.append(p[0])
		draw_polyline(outline, Color(1, 0.9, 0.5, 0.9 if _highlight else 0.35), 3.0)
		var c := centroid(hs)
		var x := clampf(c.x - 200.0, 8.0, SIZE.x - 408.0)
		draw_string(_font, Vector2(x, c.y + 10.0), tr(String(hs.get("name", ""))), HORIZONTAL_ALIGNMENT_CENTER, 400, 30, Color.WHITE)
