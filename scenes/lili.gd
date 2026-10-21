class_name Lili
extends Node2D
## Lili: sprite frames from art/characters (idle + 8 walk frames facing right), simple shapes if they are missing.
## Origin is at her feet; the node is flipped to face left.

signal arrived(ok: bool)

const SPEED := 460.0
const WALK_FRAMES := 8
const WALK_FPS := 10.0
const SPRITE_SCALE := 1.3

## [y_far, y_near, scale_far, scale_near]: Lili gets smaller further up the screen.
var depth: Array = [700.0, 900.0, 0.85, 1.0]
var _path := PackedVector2Array()
var _facing := 1.0
var _anim := 0.0
var _sprite: Sprite2D
var _idle: Texture2D
var _walk: Array[Texture2D] = []


func _ready() -> void:
	_idle = _load("res://art/characters/lili_idle.png")
	for i in WALK_FRAMES:
		var t := _load("res://art/characters/lili_walk_%d.png" % i)
		if t == null:
			_walk.clear()
			break
		_walk.append(t)
	if _idle and not _walk.is_empty():
		_sprite = Sprite2D.new()
		_sprite.texture = _idle
		_sprite.centered = false
		_sprite.offset = Vector2(-_idle.get_width() / 2.0, -_idle.get_height())
		_sprite.scale = Vector2.ONE * SPRITE_SCALE
		add_child(_sprite)


func _load(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null


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
		if _sprite:
			_sprite.texture = _idle
		return
	_anim += delta
	if _sprite:
		_sprite.texture = _walk[int(_anim * WALK_FPS) % WALK_FRAMES]
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
	if _sprite:
		return
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
