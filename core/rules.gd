class_name Rules
extends RefCounted
## Game logic: interprets scene data against the game state.
## Changes the state and returns presentation events (say, goto, dialogue, wait, ...).
## Never touches nodes, so tests can play the whole game headless.

const FAIL_KEYS := ["FAIL_1", "FAIL_2", "FAIL_3", "FAIL_4"]

var data: GameData
var state: GameStateData
var _fail_index := 0


func _init(p_data: GameData, p_state: GameStateData) -> void:
	data = p_data
	state = p_state


func scene() -> Dictionary:
	return data.scenes.get(state.scene_id, {})


## Hotspots whose "if" condition currently holds.
func hotspots() -> Array:
	var out := []
	for hs in scene().get("hotspots", []):
		if state.check(hs.get("if", "")):
			out.append(hs)
	return out


func hotspot(id: String) -> Dictionary:
	for hs in hotspots():
		if hs["id"] == id:
			return hs
	return {}


func enter(scene_id: String) -> Array:
	state.scene_id = scene_id
	return run(scene().get("on_enter", []))


func look(hotspot_id: String) -> Dictionary:
	var hs := hotspot(hotspot_id)
	if hs.is_empty():
		return _fail()
	return _ok(run(hs.get("look", [])))


func interact(hotspot_id: String) -> Dictionary:
	var hs := hotspot(hotspot_id)
	if hs.is_empty():
		return _fail()
	if hs.has("exit"):
		if not state.check(hs.get("exit_if", "")):
			return _ok(run(hs.get("blocked", "SAY_CANT_GO")))
		return _ok([{"goto": hs["exit"]}])
	if hs.has("interact"):
		return _ok(run(hs["interact"]))
	return look(hotspot_id)


func use_item(item: String, hotspot_id: String) -> Dictionary:
	var hs := hotspot(hotspot_id)
	if hs.is_empty() or not state.has_item(item):
		return _fail()
	var uses: Dictionary = hs.get("use", {})
	if uses.has(item):
		return _ok(run(uses[item]))
	if uses.has("*"):
		return {"ok": false, "events": run(uses["*"])}
	return _fail()


func combine(a: String, b: String) -> Dictionary:
	if a == b or not (state.has_item(a) and state.has_item(b)):
		return _fail()
	for c in data.combos:
		if (c["a"] == a and c["b"] == b) or (c["a"] == b and c["b"] == a):
			return _ok(run(c.get("do", [])))
	return _fail()


func look_item(item: String) -> Array:
	return run(data.items.get(item, {}).get("look", []))


## Next hint for the first hint group in this scene whose condition holds.
## Each press goes one level deeper, up to the last (most explicit) hint.
func hint() -> String:
	for h in scene().get("hints", []):
		if not state.check(h.get("if", "")):
			continue
		var keys: Array = h["keys"]
		var level: int = state.hint_levels.get(h["id"], 0)
		state.hint_levels[h["id"]] = mini(level + 1, keys.size() - 1)
		return keys[mini(level, keys.size() - 1)]
	return "HINT_NONE"


func dialogue_start(dialogue_id: String) -> String:
	return String(_dialogue(dialogue_id).get("start", ""))


## Enters a dialogue node: runs its "do" actions, then returns the node with only the options available now.
func dialogue_enter(dialogue_id: String, node_id: String) -> Dictionary:
	var node: Dictionary = _dialogue(dialogue_id).get("nodes", {}).get(node_id, {})
	if node.is_empty():
		return {"node": {}, "events": []}
	var events := run(node.get("do", []))
	var shown := node.duplicate()
	shown["options"] = _options(node)
	return {"node": shown, "events": events}


func dialogue_choose(dialogue_id: String, node_id: String, index: int) -> Dictionary:
	var node: Dictionary = _dialogue(dialogue_id).get("nodes", {}).get(node_id, {})
	var options := _options(node)
	if index < 0 or index >= options.size():
		return {"events": [], "next": ""}
	var option: Dictionary = options[index]
	var events := [{"say": option["text"], "who": "lili"}]
	events.append_array(run(option.get("do", [])))
	return {"events": events, "next": String(option.get("next", ""))}


## Runs a list of actions. A plain string is shorthand for Lili saying that text key.
func run(actions) -> Array:
	var events := []
	if actions is String:
		actions = [{"say": actions}]
	for a in actions:
		if a.has("if"):
			events.append_array(run(a.get("then", []) if state.check(a["if"]) else a.get("else", [])))
		elif a.has("once"):
			if state.is_set(a["once"]):
				events.append_array(run(a.get("else", [])))
			else:
				state.set_flag(a["once"])
				events.append_array(run(a.get("do", [])))
		elif a.has("give"):
			state.give(a["give"])
			events.append(a)
		elif a.has("take"):
			state.take(a["take"])
		elif a.has("set"):
			state.set_flag(a["set"])
		elif a.has("clear"):
			state.set_flag(a["clear"], false)
		elif a.has("cutscene"):
			events.append({"cutscene_begin": a["cutscene"]})
			events.append_array(run(scene().get("cutscenes", {}).get(a["cutscene"], [])))
			events.append({"cutscene_end": a["cutscene"]})
		else:
			events.append(a)
	return events


func _dialogue(dialogue_id: String) -> Dictionary:
	return scene().get("dialogues", {}).get(dialogue_id, {})


func _options(node: Dictionary) -> Array:
	var out := []
	for o in node.get("options", []):
		if state.check(o.get("if", "")):
			out.append(o)
	return out


func _ok(events: Array) -> Dictionary:
	return {"ok": true, "events": events}


func _fail() -> Dictionary:
	_fail_index = (_fail_index + 1) % FAIL_KEYS.size()
	return {"ok": false, "events": [{"say": FAIL_KEYS[_fail_index], "who": "lili"}]}
