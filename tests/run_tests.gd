extends SceneTree
## Headless checks: data validation, walkthroughs and walk-area pathfinding.
## Run: godot --headless --path . --script res://tests/run_tests.gd

const WALKTHROUGHS_DIR := "res://tests/walkthroughs"


func _init() -> void:
	var failures := 0
	var data := GameData.new()
	data.load_all()

	var errs := DataValidator.validate(data)
	failures += _report("data validation", errs)

	for file in DirAccess.get_files_at(WALKTHROUGHS_DIR):
		if not file.ends_with(".json"):
			continue
		var steps = JSON.parse_string(FileAccess.get_file_as_string(WALKTHROUGHS_DIR.path_join(file)))
		if not steps is Array:
			failures += _report("walkthrough " + file, ["invalid JSON"])
			continue
		failures += _report("walkthrough " + file, WalkthroughRunner.run(data, steps))

	failures += _report("walk area", _walk_area_errors())

	print("\n%s" % ("ALL TESTS PASSED" if failures == 0 else "%d TEST GROUP(S) FAILED" % failures))
	quit(1 if failures > 0 else 0)


func _report(name: String, errs: Array) -> int:
	if errs.is_empty():
		print("PASS  " + name)
		return 0
	print("FAIL  " + name)
	for e in errs:
		print("      " + str(e))
	return 1


## An L-shaped area: the path from one arm to the other must bend at the inner corner.
func _walk_area_errors() -> Array:
	var errs := []
	var area := WalkArea.new(PackedVector2Array([
		Vector2(0, 0), Vector2(100, 0), Vector2(100, 300), Vector2(400, 300), Vector2(400, 400), Vector2(0, 400)
	]))
	var path := area.find_path(Vector2(50, 20), Vector2(380, 350))
	if path.size() < 3:
		errs.append("expected a path around the corner, got " + str(path))
	for i in range(path.size() - 1):
		if not area.contains((path[i] + path[i + 1]) * 0.5):
			errs.append("path leaves the area between %s and %s" % [path[i], path[i + 1]])
	if area.clamp_point(Vector2(300, 220)).distance_to(Vector2(300, 300)) > 1.0:
		errs.append("clamp_point should snap to the nearest edge")
	return errs
