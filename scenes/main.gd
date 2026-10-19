extends Node
## Game entry point: owns the current Room and the UI, turns taps into Rules calls
## and plays the events Rules returns.

const HOLD_TIME := 0.45

var rules: Rules
var room: Room
var ui: GameUI
var voice: Mumble
var busy := false
var _hold_timer: Timer
var _highlighted := false


func _ready() -> void:
	ui = GameUI.new()
	add_child(ui)
	voice = Mumble.new()
	add_child(voice)
	_hold_timer = Timer.new()
	_hold_timer.one_shot = true
	_hold_timer.wait_time = HOLD_TIME
	_hold_timer.timeout.connect(_on_hold)
	add_child(_hold_timer)
	ui.item_tapped.connect(_on_item_tapped)
	ui.item_dropped.connect(_on_item_dropped)
	ui.items_combined.connect(_on_items_combined)
	ui.hint_pressed.connect(_on_hint)
	var smoke := "--smoke" in OS.get_cmdline_user_args()
	var choice := "new"
	if smoke:
		ui.fade(0.0, 0.0)
	else:
		choice = await ui.title_screen(Game.has_save())
	if choice != "continue" or not Game.load_game():
		Game.new_game()
	for arg in OS.get_cmdline_user_args():
		if smoke and arg.begins_with("--scene=") and Game.data.scenes.has(arg.substr(8)):
			Game.state.scene_id = arg.substr(8)
		if smoke and arg.begins_with("--flags="):
			for f in arg.substr(8).split(","):
				Game.state.set_flag(f)
	rules = Rules.new(Game.data, Game.state)
	await _enter_room(Game.state.scene_id)
	if smoke:
		_smoke_quit()


## Plays presentation events in order, waiting for each to finish.
func play(events: Array) -> void:
	for e in events:
		if e.has("say"):
			await _say(String(e.get("who", "lili")), String(e["say"]))
		elif e.has("give"):
			var item: Dictionary = Game.data.items.get(e["give"], {})
			ui.toast(tr("UI_GOT") % tr(String(item.get("name", ""))))
			_refresh()
		elif e.has("goto"):
			await _enter_room(String(e["goto"]))
		elif e.has("dialogue"):
			await _dialogue(String(e["dialogue"]))
		elif e.has("walk"):
			await room.lili.walk_to(room.walk.find_path(room.lili.position, Room.vec(e["walk"])))
		elif e.has("wait"):
			await get_tree().create_timer(float(e["wait"])).timeout
		elif e.has("fade"):
			await ui.fade(float(e["fade"]), 0.4)
		elif e.has("image"):
			ui.show_image(Color(String(e.get("color", "#000000"))), String(e["image"]), tr(String(e.get("caption", ""))))
		elif e.has("image_clear"):
			ui.clear_image()
		elif e.has("minigame"):
			await _minigame(String(e["minigame"]))
		elif e.has("cutscene_begin"):
			ui.letterbox(true)
		elif e.has("cutscene_end"):
			ui.letterbox(false)
	_refresh()


func _minigame(id: String) -> void:
	if "--smoke" in OS.get_cmdline_user_args():
		return
	match id:
		"race":
			var game := RaceGame.new()
			ui.add_child(game)
			await game.finished
			game.queue_free()
			voice.silence()


func _enter_room(id: String) -> void:
	busy = true
	await ui.fade(1.0, 0.25)
	var from := ""
	if room:
		from = String(room.data.get("id", ""))
		room.queue_free()
	var sd: Dictionary = Game.data.scenes[id]
	room = Room.new()
	add_child(room)
	move_child(room, 0)
	room.setup(sd, _texture(sd.get("background", "")), _texture(sd.get("foreground", "")), from)
	_refresh()
	await ui.fade(0.0, 0.25)
	await play(rules.enter(id))
	Game.save_game()
	_preload_neighbours(sd)
	busy = false


func _refresh() -> void:
	ui.set_inventory(Game.state.inventory, Game.data.items)
	if room:
		room.set_hotspots(rules.hotspots())
		var alt: Dictionary = room.data.get("background_alt", {})
		var path := String(room.data.get("background", ""))
		if not alt.is_empty() and Game.state.check(alt.get("if", "")):
			path = String(alt.get("path", path))
		if path != room.background_path:
			room.background_path = path
			room.set_background(_texture(path))


func _say(who: String, key: String) -> void:
	var ch: Dictionary = Game.data.characters.get(who, {})
	var text := tr(key)
	var name_key := String(ch.get("name", ""))
	voice.speak(text, float(ch.get("pitch", 0)))
	await ui.say(tr(name_key) if name_key != "" else "", Color(String(ch.get("color", "#ffffff"))), text)
	voice.silence()


func _dialogue(id: String) -> void:
	var node_id := rules.dialogue_start(id)
	while node_id != "":
		var step := rules.dialogue_enter(id, node_id)
		var node: Dictionary = step["node"]
		if node.is_empty():
			return
		await _say(String(node.get("who", "lili")), String(node.get("text", "")))
		await play(step["events"])
		var options: Array = node["options"]
		if options.is_empty():
			node_id = String(node.get("next", ""))
			continue
		var labels := []
		for o in options:
			labels.append(tr(String(o["text"])))
		var chosen := rules.dialogue_choose(id, node_id, await ui.choose(labels))
		await play(chosen["events"])
		node_id = chosen["next"]


# --- Input -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if room == null or not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_hold_timer.start()
		return
	_hold_timer.stop()
	if _highlighted:
		_highlighted = false
		room.set_highlight(false)
	else:
		_tap(event.position)


## Holding a finger on the scene highlights everything interactive.
func _on_hold() -> void:
	if busy or room == null:
		return
	_highlighted = true
	room.set_highlight(true)


func _tap(pos: Vector2) -> void:
	if busy:
		return
	var hs := room.hotspot_at(pos)
	var item := ui.selected_item()
	if item != "":
		ui.select_item("")
		if not hs.is_empty():
			await _use_on(item, hs)
		return
	if hs.is_empty():
		room.lili.walk_to(room.walk.find_path(room.lili.position, pos))
		return
	busy = true
	if await _walk_to_hotspot(hs):
		await play(rules.interact(hs["id"])["events"])
	busy = false


func _on_item_dropped(item: String, pos: Vector2) -> void:
	if busy or room == null:
		return
	ui.select_item("")
	var hs := room.hotspot_at(pos)
	if hs.is_empty():
		return
	await _use_on(item, hs)


func _use_on(item: String, hs: Dictionary) -> void:
	busy = true
	if await _walk_to_hotspot(hs):
		await play(rules.use_item(item, hs["id"])["events"])
	busy = false


func _on_items_combined(a: String, b: String) -> void:
	if busy:
		return
	ui.select_item("")
	busy = true
	await play(rules.combine(a, b)["events"])
	busy = false


## First tap picks the item, then a tap on the scene uses it and a tap on another item combines
## them. Tapping the picked item again makes Lili describe it.
func _on_item_tapped(item: String) -> void:
	if busy:
		return
	var picked := ui.selected_item()
	if picked == "":
		ui.select_item(item)
		var def: Dictionary = Game.data.items.get(item, {})
		ui.toast(tr("UI_SELECTED") % tr(String(def.get("name", item))))
		return
	ui.select_item("")
	busy = true
	if picked == item:
		await play(rules.look_item(item))
	else:
		await play(rules.combine(picked, item)["events"])
	busy = false


func _on_hint() -> void:
	if busy:
		return
	busy = true
	await _say("sheriff", rules.hint())
	busy = false


func _walk_to_hotspot(hs: Dictionary) -> bool:
	var ok := await room.lili.walk_to(room.walk.find_path(room.lili.position, room.target_for(hs)))
	room.lili.face(Room.centroid(hs).x)
	return ok


# --- Loading ---------------------------------------------------------------

func _texture(path) -> Texture2D:
	var p := String(path)
	if p == "" or not ResourceLoader.exists(p):
		return null
	if ResourceLoader.load_threaded_get_status(p) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		return ResourceLoader.load_threaded_get(p)
	return load(p)


## Starts loading backgrounds of neighbouring scenes in the background, so the next transition is instant.
func _preload_neighbours(sd: Dictionary) -> void:
	for hs in sd.get("hotspots", []):
		if not hs.has("exit"):
			continue
		var next: Dictionary = Game.data.scenes.get(hs["exit"], {})
		for key in ["background", "foreground"]:
			var p := String(next.get(key, ""))
			if p != "" and ResourceLoader.exists(p) and ResourceLoader.load_threaded_get_status(p) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				ResourceLoader.load_threaded_request(p)


## Used by `--smoke`: plays the start of the game for a moment, then quits.
## With `--shots=<dir>` it also saves screenshots (needs a real display, not --headless).
func _smoke_quit() -> void:
	var shots := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.substr(8)
	if shots != "":
		await _save_shot(shots.path_join("1_room.png"))
		room.set_highlight(true)
		await _save_shot(shots.path_join("2_highlight.png"))
		room.set_highlight(false)
		_tap(Vector2(1300, 600))
		await get_tree().create_timer(2.5).timeout
		await _save_shot(shots.path_join("3_say.png"))
	await get_tree().create_timer(1.0).timeout
	print("SMOKE OK scene=%s items=%s" % [Game.state.scene_id, Game.state.inventory])
	get_tree().quit()


func _save_shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
