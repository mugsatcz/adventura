class_name DataValidator
extends RefCounted
## Checks game data for broken references, so mistakes show up in tests and not on players' phones.


static func validate(data: GameData) -> Array[String]:
	var errs: Array[String] = []
	errs.append_array(data.errors)
	var keys := data.text_keys()
	if not data.scenes.has(data.start_scene):
		errs.append("game.json: start_scene '%s' does not exist" % data.start_scene)
	for item in data.start_items:
		_item(item, data, "game.json start_items", errs)
	for id in data.items:
		var it: Dictionary = data.items[id]
		_key(it.get("name", ""), keys, "item " + id, errs)
		_actions(it.get("look", []), data, {}, "item %s look" % id, errs)
	for c in data.combos:
		var ctx := "combo %s + %s" % [c.get("a", "?"), c.get("b", "?")]
		_item(c.get("a", ""), data, ctx, errs)
		_item(c.get("b", ""), data, ctx, errs)
		_actions(c.get("do", []), data, {}, ctx, errs)
	for id in data.characters:
		if data.characters[id].has("name"):
			_key(data.characters[id]["name"], keys, "character " + id, errs)
	for sid in data.scenes:
		_scene(data.scenes[sid], data, keys, errs)
	return errs


static func _scene(s: Dictionary, data: GameData, keys: Dictionary, errs: Array[String]) -> void:
	var ctx := "scene " + String(s["id"])
	_key(s.get("title", ""), keys, ctx + " title", errs)
	var walk := WalkArea.new(Room.poly(s.get("walk_area", [])))
	if walk.poly.size() < 3:
		errs.append(ctx + ": walk_area needs at least 3 points")
	if not walk.contains(Room.vec(s.get("lili_start", [0, 0]))):
		errs.append(ctx + ": lili_start is outside walk_area")
	var entries: Dictionary = s.get("entries", {})
	for from in entries:
		if not data.scenes.has(from):
			errs.append(ctx + ": entries refers to unknown scene " + from)
		if not walk.contains(Room.vec(entries[from])):
			errs.append(ctx + ": entry from %s is outside walk_area" % from)
	var seen := {}
	for hs in s.get("hotspots", []):
		var hctx := "%s hotspot %s" % [ctx, hs.get("id", "?")]
		if not hs.has("id"):
			errs.append(ctx + ": hotspot without id")
			continue
		if seen.has(hs["id"]):
			errs.append(hctx + ": duplicate id")
		seen[hs["id"]] = true
		if hs.get("polygon", []).size() < 3:
			errs.append(hctx + ": polygon needs at least 3 points")
		_key(hs.get("name", ""), keys, hctx + " name", errs)
		if hs.has("walk_to") and not walk.contains(Room.vec(hs["walk_to"])):
			errs.append(hctx + ": walk_to is outside walk_area")
		if hs.has("exit") and not data.scenes.has(hs["exit"]):
			errs.append(hctx + ": exit to unknown scene " + String(hs["exit"]))
		_actions(hs.get("look", []), data, s, hctx + " look", errs)
		_actions(hs.get("interact", []), data, s, hctx + " interact", errs)
		_actions(hs.get("blocked", []), data, s, hctx + " blocked", errs)
		var uses: Dictionary = hs.get("use", {})
		for item in uses:
			if item != "*":
				_item(item, data, hctx + " use", errs)
			_actions(uses[item], data, s, "%s use %s" % [hctx, item], errs)
	_actions(s.get("on_enter", []), data, s, ctx + " on_enter", errs)
	var cutscenes: Dictionary = s.get("cutscenes", {})
	for id in cutscenes:
		_actions(cutscenes[id], data, s, "%s cutscene %s" % [ctx, id], errs)
	var dialogues: Dictionary = s.get("dialogues", {})
	for id in dialogues:
		var dctx := "%s dialogue %s" % [ctx, id]
		var nodes: Dictionary = dialogues[id].get("nodes", {})
		if not nodes.has(dialogues[id].get("start", "")):
			errs.append(dctx + ": start node does not exist")
		for nid in nodes:
			var node: Dictionary = nodes[nid]
			var nctx := "%s node %s" % [dctx, nid]
			_key(node.get("text", ""), keys, nctx, errs)
			if not data.characters.has(node.get("who", "lili")):
				errs.append(nctx + ": unknown character " + String(node.get("who")))
			_next(node.get("next", ""), nodes, nctx, errs)
			_actions(node.get("do", []), data, s, nctx, errs)
			for o in node.get("options", []):
				_key(o.get("text", ""), keys, nctx + " option", errs)
				_next(o.get("next", ""), nodes, nctx + " option", errs)
				_actions(o.get("do", []), data, s, nctx + " option", errs)
	for h in s.get("hints", []):
		if not h.has("id") or h.get("keys", []).is_empty():
			errs.append(ctx + ": hint needs id and keys")
		for k in h.get("keys", []):
			_key(k, keys, ctx + " hint", errs)


static func _actions(actions, data: GameData, s: Dictionary, ctx: String, errs: Array[String]) -> void:
	if actions is String:
		_key(actions, data.text_keys(), ctx, errs)
		return
	var keys := data.text_keys()
	for a in actions:
		if a.has("if"):
			_actions(a.get("then", []), data, s, ctx, errs)
			_actions(a.get("else", []), data, s, ctx, errs)
		elif a.has("once"):
			_actions(a.get("do", []), data, s, ctx, errs)
			_actions(a.get("else", []), data, s, ctx, errs)
		elif a.has("give"):
			_item(a["give"], data, ctx, errs)
		elif a.has("take"):
			_item(a["take"], data, ctx, errs)
		elif a.has("say"):
			_key(a["say"], keys, ctx, errs)
			if not data.characters.has(a.get("who", "lili")):
				errs.append(ctx + ": unknown character " + String(a.get("who")))
		elif a.has("goto"):
			if not data.scenes.has(a["goto"]):
				errs.append(ctx + ": goto unknown scene " + String(a["goto"]))
		elif a.has("dialogue"):
			if not s.get("dialogues", {}).has(a["dialogue"]):
				errs.append(ctx + ": unknown dialogue " + String(a["dialogue"]))
		elif a.has("cutscene"):
			if not s.get("cutscenes", {}).has(a["cutscene"]):
				errs.append(ctx + ": unknown cutscene " + String(a["cutscene"]))
		elif a.has("image"):
			if a.has("caption"):
				_key(a["caption"], keys, ctx, errs)


static func _item(id, data: GameData, ctx: String, errs: Array[String]) -> void:
	if not data.items.has(id):
		errs.append(ctx + ": unknown item " + String(id))


static func _key(key, keys: Dictionary, ctx: String, errs: Array[String]) -> void:
	if String(key) != "" and not keys.has(key):
		errs.append(ctx + ": missing text " + String(key))


static func _next(next, nodes: Dictionary, ctx: String, errs: Array[String]) -> void:
	if String(next) != "" and not nodes.has(next):
		errs.append(ctx + ": next node %s does not exist" % next)
