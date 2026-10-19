class_name GameData
extends RefCounted
## All static game content: items, characters, scenes and texts, loaded from res://data and res://locale.

const GAME_FILE := "res://data/game.json"
const ITEMS_FILE := "res://data/items.json"
const CHARACTERS_FILE := "res://data/characters.json"
const SCENES_DIR := "res://data/scenes"
const TEXTS_FILE := "res://locale/texts.csv"

var start_scene := ""
var start_items: Array = []
var items: Dictionary = {}
var combos: Array = []
var characters: Dictionary = {}
var scenes: Dictionary = {}
## locale -> {text key: text}
var texts: Dictionary = {}
var locales: Array[String] = []
## Problems found while loading (missing or broken files).
var errors: Array[String] = []


func load_all() -> void:
	var game := _read_json(GAME_FILE)
	start_scene = String(game.get("start_scene", ""))
	start_items = game.get("start_items", [])
	for id in game.get("scenes", []):
		var scene := _read_json(SCENES_DIR.path_join(String(id) + ".json"))
		if scene.is_empty():
			continue
		scene["id"] = String(id)
		scenes[String(id)] = scene
	var item_file := _read_json(ITEMS_FILE)
	items = item_file.get("items", {})
	combos = item_file.get("combos", [])
	characters = _read_json(CHARACTERS_FILE)
	_load_texts(TEXTS_FILE)


func install_translations() -> void:
	for locale in locales:
		var t := Translation.new()
		t.locale = locale
		var table: Dictionary = texts[locale]
		for key in table:
			t.add_message(key, table[key])
		TranslationServer.add_translation(t)
	if not locales.is_empty():
		TranslationServer.set_locale(locales[0])


## Text keys of the first (reference) language.
func text_keys() -> Dictionary:
	if locales.is_empty():
		return {}
	return texts[locales[0]]


func _load_texts(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		errors.append("Missing file: " + path)
		return
	var header := f.get_csv_line()
	for i in range(1, header.size()):
		locales.append(header[i])
		texts[header[i]] = {}
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < 2 or row[0].strip_edges() == "":
			continue
		for i in range(1, header.size()):
			if i < row.size() and row[i] != "":
				texts[header[i]][row[0]] = row[i].replace("\\n", "\n")


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("Missing file: " + path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	errors.append("Invalid JSON: " + path)
	return {}
