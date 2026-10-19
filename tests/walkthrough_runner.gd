class_name WalkthroughRunner
extends RefCounted
## Plays a walkthrough (list of player actions) through Rules, without any UI.
## Fails when a step is not possible, which catches dead ends and missing items.
##
## Steps: {"interact": id}, {"use": item, "on": id}, {"combine": [a, b]},
## {"expect_item": id}, {"expect_no_item": id}, {"expect_flag": f}, {"expect_scene": id}.
## A step that opens a dialogue takes "choose": [option indexes in order].


static func run(data: GameData, steps: Array) -> Array[String]:
	var errs: Array[String] = []
	var state := GameStateData.new()
	for item in data.start_items:
		state.give(item)
	var rules := Rules.new(data, state)
	_play(rules, rules.enter(data.start_scene), [], errs, "start")
	var n := 0
	for step in steps:
		n += 1
		var ctx := "step %d %s" % [n, JSON.stringify(step)]
		var choices: Array = step.get("choose", []).duplicate()
		var result := {}
		if step.has("interact"):
			result = rules.interact(step["interact"])
		elif step.has("use"):
			result = rules.use_item(step["use"], step["on"])
		elif step.has("combine"):
			result = rules.combine(step["combine"][0], step["combine"][1])
		elif step.has("expect_item"):
			if not state.has_item(step["expect_item"]):
				errs.append(ctx + ": item not in inventory, have " + str(state.inventory))
		elif step.has("expect_no_item"):
			if state.has_item(step["expect_no_item"]):
				errs.append(ctx + ": item should be gone")
		elif step.has("expect_flag"):
			if not state.is_set(step["expect_flag"]):
				errs.append(ctx + ": flag not set")
		elif step.has("expect_scene"):
			if state.scene_id != step["expect_scene"]:
				errs.append(ctx + ": in scene " + state.scene_id)
		else:
			errs.append(ctx + ": unknown step")
		if result.has("ok"):
			if not result["ok"]:
				errs.append(ctx + ": not possible in scene " + state.scene_id)
			else:
				_play(rules, result["events"], choices, errs, ctx)
				if not choices.is_empty():
					errs.append(ctx + ": unused dialogue choices " + str(choices))
		if not errs.is_empty():
			break
	return errs


static func _play(rules: Rules, events: Array, choices: Array, errs: Array[String], ctx: String) -> void:
	for e in events:
		if e.has("goto"):
			_play(rules, rules.enter(e["goto"]), choices, errs, ctx)
		elif e.has("dialogue"):
			_dialogue(rules, String(e["dialogue"]), choices, errs, ctx)


static func _dialogue(rules: Rules, id: String, choices: Array, errs: Array[String], ctx: String) -> void:
	var node_id := rules.dialogue_start(id)
	var guard := 0
	while node_id != "" and guard < 500:
		guard += 1
		var step := rules.dialogue_enter(id, node_id)
		var node: Dictionary = step["node"]
		_play(rules, step["events"], choices, errs, ctx)
		var options: Array = node.get("options", [])
		if options.is_empty():
			node_id = String(node.get("next", ""))
			continue
		if choices.is_empty():
			errs.append("%s: dialogue %s needs a choice at node %s" % [ctx, id, node_id])
			return
		var index := int(choices.pop_front())
		if index >= options.size():
			errs.append("%s: dialogue %s node %s has only %d options" % [ctx, id, node_id, options.size()])
			return
		var chosen := rules.dialogue_choose(id, node_id, index)
		_play(rules, chosen["events"], choices, errs, ctx)
		node_id = chosen["next"]
	if guard >= 500:
		errs.append("%s: dialogue %s loops forever" % [ctx, id])
