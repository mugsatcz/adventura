class_name Lili
extends Node2D
## Lili, drawn with simple shapes until the real sprite sheet exists. Origin is at her feet.

signal arrived(ok: bool)

const SPEED := 460.0

## [y_far, y_near, scale_far, scale_near]: Lili gets smaller further up the screen.
var depth: Array = [700.0, 900.0, 0.85, 1.0]
var _path := PackedVector2Array()
var _facing := 1.0
var _anim := 0.0


func place(p: Vector2) -> void:
	_path = PackedVector2Array()
	position = p
	_apply_scale()


func is_walking() -> bool:
	return not _path.is_empty()


## Walks along the path. Returns false if another walk interrupted this one.
func walk_to(path: PackedVector2Array) -> bool:
	if is_walking():
		arrived.emit(false)
	_path = path.duplicate()
	while not _path.is_empty() and _path[0].distance_to(position) < 2.0:
		_path.remove_at(0)
	if _path.is_empty():
		return true
	var ok: bool = await arrived
	return ok


func face(x: float) -> void:
	if absf(x - position.x) > 2.0:
		_facing = signf(x - position.x)
		_apply_scale()


func _process(delta: float) -> void:
	if _path.is_empty():
		return
	_anim += delta
	var target := _path[0]
	var step := SPEED * absf(scale.y) * delta
	var to := target - position
	if to.length() <= step:
		position = target
		_path.remove_at(0)
	else:
		position += to.normalized() * step
		face(target.x)
	_apply_scale()
	queue_redraw()
	if _path.is_empty():
		arrived.emit(true)


func _apply_scale() -> void:
	var t := clampf(inverse_lerp(float(depth[0]), float(depth[1]), position.y), 0.0, 1.0)
	var s := lerpf(float(depth[2]), float(depth[3]), t)
	scale = Vector2(s * _facing, s)


func _draw() -> void:
	var bob := sin(_anim * 16.0) * 5.0 if is_walking() else 0.0
	var step := sin(_anim * 16.0) * 8.0 if is_walking() else 0.0
	var boots := Color("#5b3a1e")
	draw_rect(Rect2(-24 + step, -62, 18, 62), boots)
	draw_rect(Rect2(6 - step, -62, 18, 62), boots)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-42, -56 + bob), Vector2(42, -56 + bob), Vector2(28, -168 + bob), Vector2(-28, -168 + bob)
	]), Color("#3f7fbf"))
	draw_line(Vector2(-26, -160 + bob), Vector2(-44, -100 + bob), Color("#f2c79a"), 10.0)
	draw_line(Vector2(26, -160 + bob), Vector2(44, -100 + bob), Color("#f2c79a"), 10.0)
	draw_circle(Vector2(-30, -196 + bob), 14.0, Color("#c0612b"))
	draw_circle(Vector2(0, -204 + bob), 36.0, Color("#f2c79a"))
	draw_circle(Vector2(14, -208 + bob), 4.0, Color.BLACK)
	draw_rect(Rect2(-56, -238 + bob, 112, 12), Color("#8b5a2b"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-30, -236 + bob), Vector2(30, -236 + bob), Vector2(22, -276 + bob), Vector2(-22, -276 + bob)
	]), Color("#8b5a2b"))
