class_name GameStateData
extends RefCounted
## Everything that changes while playing. Serialised to the save file.

const VERSION := 1

var scene_id := ""
var flags: Dictionary = {}
var inventory: Array[String] = []
var hint_levels: Dictionary = {}


func has_item(id: String) -> bool:
	return inventory.has(id)


func give(id: String) -> void:
	if not inventory.has(id):
		inventory.append(id)


func take(id: String) -> void:
	inventory.erase(id)


func is_set(flag: String) -> bool:
	return flags.get(flag, false)


func set_flag(flag: String, value := true) -> void:
	if value:
		flags[flag] = true
	else:
		flags.erase(flag)


## Evaluates a condition string such as "has:bucket & !fire_out".
## Terms: flag name, "has:<item>", "true", "false"; "!" negates; "&" joins.
func check(cond) -> bool:
	if cond == null:
		return true
	if cond is bool:
		return cond
	var text := String(cond).strip_edges()
	if text == "":
		return true
	for term in text.split("&"):
		if not _check_term(term.strip_edges()):
			return false
	return true


func _check_term(term: String) -> bool:
	var negate := term.begins_with("!")
	if negate:
		term = term.substr(1).strip_edges()
	var value: bool
	if term.begins_with("has:"):
		value = has_item(term.substr(4))
	elif term == "true":
		value = true
	elif term == "false":
		value = false
	else:
		value = is_set(term)
	return value != negate


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"scene_id": scene_id,
		"flags": flags,
		"inventory": inventory,
		"hint_levels": hint_levels,
	}


func from_dict(d: Dictionary) -> void:
	scene_id = String(d.get("scene_id", ""))
	flags = d.get("flags", {})
	inventory.assign(d.get("inventory", []))
	hint_levels.clear()
	var levels: Dictionary = d.get("hint_levels", {})
	for key in levels:
		hint_levels[key] = int(levels[key])
