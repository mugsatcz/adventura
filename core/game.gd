extends Node
## Autoload "Game": holds the loaded data and current state, and handles saving.

const SAVE_PATH := "user://save.json"

var data := GameData.new()
var state := GameStateData.new()


func _ready() -> void:
	data.load_all()
	data.install_translations()
	if OS.is_debug_build():
		for err in DataValidator.validate(data):
			push_warning(err)


func new_game() -> void:
	state = GameStateData.new()
	for item in data.start_items:
		state.give(item)
	state.scene_id = data.start_scene


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(state.to_dict()))


func load_game() -> bool:
	if not has_save():
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not parsed is Dictionary or not data.scenes.has(String(parsed.get("scene_id", ""))):
		return false
	state = GameStateData.new()
	state.from_dict(parsed)
	return true
