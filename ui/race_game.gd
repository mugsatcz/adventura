class_name RaceGame
extends Control
## Race minigame: Hrom gallops, fences come from the right, a tap makes him jump.
## Each stumble costs a little time. Beating Cylindr's horse to the finish wins.
## Lost races restart; from the third attempt on Hrom never stumbles, so nobody gets stuck.

signal finished

const W := 1920.0
const GROUND_Y := 820.0
const HROM_X := 420.0
const HROM_HALF := 70.0
const FENCE_W := 80.0
const FENCE_H := 120.0
const SPEED := 500.0
const TRACK := 15500.0
const JUMP_V := 1700.0
const GRAVITY := 4200.0
const STUMBLE_TIME := 1.0
const STUMBLE_SPEED := 0.4
const RIVAL_SECONDS := 32.5
const FENCE_FROM := 1500.0

var _fences: Array = []
var _dist := 0.0
var _time := 0.0
var _y := 0.0
var _vy := 0.0
var _stumble := 0.0
var _stumbles := 0
var _attempt := 0
var _state := "ready"  # ready, count, run, over
var _count := 0.0
var _message := ""
var _font: Font


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font


func _ready() -> void:
	_start_attempt()


func _start_attempt() -> void:
	_attempt += 1
	_fences.clear()
	var x := FENCE_FROM
	var seed_i := 0
	while x < TRACK - 1200.0:
		_fences.append({"x": x, "hit": false})
		seed_i += 1
		x += 1000.0 + float((seed_i * 7) % 5) * 90.0
	_dist = 0.0
	_time = 0.0
	_y = 0.0
	_vy = 0.0
	_stumble = 0.0
	_stumbles = 0
	_state = "count"
	_count = 3.0
	_message = ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed or event is InputEventScreenTouch and event.pressed:
		_jump()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_jump()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_jump()


func _jump() -> void:
	if _state == "run" and _y <= 0.0:
		_y = 0.001
		_vy = JUMP_V


func _process(delta: float) -> void:
	match _state:
		"count":
			_count -= delta
			if _count <= 0.0:
				_state = "run"
		"run":
			_step(delta)
		"over":
			_count -= delta
			if _count <= 0.0:
				if _message == "win":
					finished.emit()
					set_process(false)
				else:
					_start_attempt()
	queue_redraw()


func _step(delta: float) -> void:
	_time += delta
	var speed := SPEED * (STUMBLE_SPEED if _stumble > 0.0 else 1.0)
	_stumble = maxf(_stumble - delta, 0.0)
	_dist += speed * delta
	if _y > 0.0:
		_vy -= GRAVITY * delta
		_y += _vy * delta
		if _y <= 0.0:
			_y = 0.0
			_vy = 0.0
	for f in _fences:
		if f["hit"]:
			continue
		var fx: float = HROM_X + float(f["x"]) - _dist
		if absf(fx - HROM_X) < HROM_HALF + FENCE_W * 0.5 and _y < FENCE_H:
			f["hit"] = true
			if _attempt < 3:
				_stumble = STUMBLE_TIME
				_stumbles += 1
	if _dist >= TRACK:
		_state = "over"
		_count = 2.2
		_message = "win" if _time < RIVAL_SECONDS or _attempt >= 3 else "lose"


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, 1080), Color("#9fd4f0"))
	draw_rect(Rect2(0, GROUND_Y, W, 1080.0 - GROUND_Y), Color("#8fb360"))
	draw_rect(Rect2(0, GROUND_Y, W, 14), Color("#6e8f45"))
	var scroll := fmod(_dist, 400.0)
	for i in range(6):
		draw_rect(Rect2(i * 400.0 - scroll, GROUND_Y + 80.0, 160, 10), Color("#7aa04e"))
	for f in _fences:
		var fx: float = HROM_X + float(f["x"]) - _dist
		if fx > -200.0 and fx < W + 200.0:
			draw_rect(Rect2(fx - FENCE_W * 0.5, GROUND_Y - FENCE_H, FENCE_W, FENCE_H), Color("#7a4a2a"))
			draw_rect(Rect2(fx - FENCE_W * 0.5 - 10, GROUND_Y - FENCE_H * 0.8, FENCE_W + 20, 18), Color("#a06a3a"))
	var fin := HROM_X + TRACK - _dist
	if fin < W + 100.0:
		draw_rect(Rect2(fin, GROUND_Y - 260.0, 18, 260), Color.WHITE)
	_draw_hrom(Vector2(HROM_X, GROUND_Y - _y))
	_draw_progress()
	var tip := tr("UI_RACE_TAP")
	if _state == "count":
		_text(str(ceili(_count)), Vector2(960, 400), 200, Color.WHITE)
		_text(tip, Vector2(960, 520), 56, Color("#3b2a1a"))
	elif _state == "run" and _time < 2.0:
		_text(tr("UI_RACE_GO"), Vector2(960, 400), 160, Color.WHITE)
	elif _state == "over":
		_text(tr("UI_RACE_WIN") if _message == "win" else tr("UI_RACE_LOSE"), Vector2(960, 440), 90, Color.WHITE)


func _draw_hrom(p: Vector2) -> void:
	var gallop := sin(_time * 18.0) * 14.0 if _state == "run" and _y <= 0.0 else 0.0
	var tint := Color("#a05a3a") if _stumble <= 0.0 else Color("#c07a5a")
	for i in range(4):
		var lx := p.x - 60.0 + i * 40.0
		var off := gallop * (1.0 if i % 2 == 0 else -1.0)
		draw_rect(Rect2(lx + off, p.y - 70.0, 16, 70), tint.darkened(0.2))
	draw_rect(Rect2(p.x - 80, p.y - 150, 170, 90), tint)
	draw_rect(Rect2(p.x + 70, p.y - 220, 60, 100), tint)
	draw_rect(Rect2(p.x + 100, p.y - 200, 60, 40), tint)
	draw_rect(Rect2(p.x - 20, p.y - 215, 50, 70), Color("#e0b070"))
	draw_circle(Vector2(p.x + 5, p.y - 235), 24, Color("#f0c8a0"))


func _draw_progress() -> void:
	var x0 := 360.0
	var w := 1200.0
	draw_rect(Rect2(x0, 70, w, 16), Color(0, 0, 0, 0.25))
	var me := clampf(_dist / TRACK, 0.0, 1.0)
	var rival := clampf(_time / RIVAL_SECONDS, 0.0, 1.0)
	draw_circle(Vector2(x0 + w * rival, 78), 18, Color("#6a5a8a"))
	draw_circle(Vector2(x0 + w * me, 78), 22, Color("#e0a030"))
	draw_circle(Vector2(x0 + w, 78), 6, Color.WHITE)


func _text(s: String, center: Vector2, size: int, color: Color) -> void:
	var width := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(_font, Vector2(center.x - width * 0.5, center.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
