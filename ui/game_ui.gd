class_name GameUI
extends CanvasLayer
## All on-screen UI, built in code: inventory, subtitles, dialogue choices, hint button,
## fades and cutscene frames.

signal item_tapped(item: String)
signal item_dropped(item: String, pos: Vector2)
signal items_combined(a: String, b: String)
signal hint_pressed
signal _advance
signal _chosen(index: int)
signal _title_choice(choice: String)

const SLOT := 124
const BAR_H := 150
const DRAG_START := 24.0

var _root: Control
var _bar: PanelContainer
var _slots_box: HBoxContainer
var _slots: Dictionary = {}
var _hint_button: Button
var _image_layer: Control
var _image_color: ColorRect
var _image_tex: TextureRect
var _image_caption: Label
var _bars: Array[ColorRect] = []
var _choices: VBoxContainer
var _catcher: Control
var _subtitle: PanelContainer
var _subtitle_name: Label
var _subtitle_text: Label
var _toast: Label
var _ghost: Panel
var _fade: ColorRect
var _say_token := 0
var _press_item := ""
var _press_pos := Vector2.ZERO
var _dragging := false


func _ready() -> void:
	layer = 10
	_root = _full_rect(Control.new())
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _make_theme()
	add_child(_root)
	_build_image_layer()
	_build_inventory_bar()
	_build_hint_button()
	_build_letterbox()
	_build_choices()
	_build_subtitle()
	_build_toast()
	_ghost = Panel.new()
	_ghost.size = Vector2(SLOT, SLOT)
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.hide()
	_root.add_child(_ghost)
	_fade = _full_rect(ColorRect.new())
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)


# --- Inventory -------------------------------------------------------------

func set_inventory(items: Array[String], defs: Dictionary) -> void:
	for child in _slots_box.get_children():
		child.queue_free()
	_slots.clear()
	for id in items:
		var slot := _make_slot(id, defs.get(id, {}))
		slot.gui_input.connect(_on_slot_input.bind(id))
		_slots_box.add_child(slot)
		_slots[id] = slot


func _make_slot(id: String, def: Dictionary) -> Panel:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(SLOT, SLOT)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.add_theme_stylebox_override("panel", _box(Color(String(def.get("color", "#8a7a66"))), 16))
	var icon_path := String(def.get("icon", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var icon := _full_rect(TextureRect.new())
		icon.texture = load(icon_path)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
	else:
		var label := _full_rect(Label.new())
		label.text = tr(String(def.get("name", id)))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 22)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(label)
	return slot


func _on_slot_input(event: InputEvent, item: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_press_item = item
		_press_pos = event.global_position
		_dragging = false


func _input(event: InputEvent) -> void:
	if _press_item == "":
		return
	if event is InputEventMouseMotion:
		if not _dragging and event.position.distance_to(_press_pos) > DRAG_START:
			_dragging = true
			var slot: Panel = _slots.get(_press_item)
			if slot:
				_ghost.add_theme_stylebox_override("panel", slot.get_theme_stylebox("panel"))
			_ghost.show()
		if _dragging:
			_ghost.position = event.position - _ghost.size / 2.0
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var item := _press_item
		_press_item = ""
		_ghost.hide()
		if not _dragging:
			item_tapped.emit(item)
		else:
			var other := _slot_at(event.position)
			if other == "":
				item_dropped.emit(item, event.position)
			elif other != item:
				items_combined.emit(item, other)
		_dragging = false
		get_viewport().set_input_as_handled()


func _slot_at(pos: Vector2) -> String:
	for id in _slots:
		if _slots[id].get_global_rect().has_point(pos):
			return id
	return ""


# --- Speech, choices, toasts -----------------------------------------------

## Shows a subtitle until the player taps or it times out.
func say(speaker: String, color: Color, text: String) -> void:
	_say_token += 1
	var token := _say_token
	_subtitle_name.text = speaker
	_subtitle_name.visible = speaker != ""
	_subtitle_name.add_theme_color_override("font_color", color)
	_subtitle_text.text = text
	_subtitle.show()
	_catcher.show()
	get_tree().create_timer(1.6 + text.length() * 0.055).timeout.connect(func():
		if token == _say_token:
			_advance.emit())
	await _advance
	_subtitle.hide()
	_catcher.hide()


func choose(labels: Array) -> int:
	for child in _choices.get_children():
		child.queue_free()
	for i in labels.size():
		var b := Button.new()
		b.text = labels[i]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func(): _chosen.emit(i))
		_choices.add_child(b)
	_choices.show()
	_bar.hide()
	var index: int = await _chosen
	_choices.hide()
	_bar.show()
	return index


func toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast.show()
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)


# --- Fades and cutscenes ---------------------------------------------------

func fade(alpha: float, time: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", alpha, time)
	await tw.finished


## Full-screen cutscene picture. Falls back to a plain colour while the art does not exist.
func show_image(color: Color, texture_path: String, caption: String) -> void:
	_image_color.color = color
	_image_tex.texture = load(texture_path) if texture_path != "" and ResourceLoader.exists(texture_path) else null
	_image_caption.text = caption
	_image_layer.show()


func clear_image() -> void:
	_image_layer.hide()


func letterbox(on: bool) -> void:
	for b in _bars:
		b.visible = on
	_bar.visible = not on
	_hint_button.visible = not on


func title_screen(has_save: bool) -> String:
	var screen := _full_rect(ColorRect.new())
	screen.color = Color("#3b2a1a")
	_root.add_child(screen)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	screen.add_child(box)
	var title := Label.new()
	title.text = tr("UI_GAME_TITLE")
	title.add_theme_font_size_override("font_size", 96)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = tr("UI_GAME_SUBTITLE")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	if has_save:
		box.add_child(_title_button("UI_CONTINUE", "continue"))
	box.add_child(_title_button("UI_NEW_GAME", "new"))
	box.reset_size()
	box.position = (Room.SIZE - box.size) / 2.0
	await fade(0.0, 0.3)
	var choice: String = await _title_choice
	await fade(1.0, 0.25)
	screen.queue_free()
	return choice


func _title_button(key: String, choice: String) -> Button:
	var b := Button.new()
	b.text = tr(key)
	b.custom_minimum_size = Vector2(420, 96)
	b.pressed.connect(func(): _title_choice.emit(choice))
	return b


# --- Building --------------------------------------------------------------

func _build_image_layer() -> void:
	_image_layer = _full_rect(Control.new())
	_image_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image_layer.hide()
	_root.add_child(_image_layer)
	_image_color = _full_rect(ColorRect.new())
	_image_color.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image_layer.add_child(_image_color)
	_image_tex = _full_rect(TextureRect.new())
	_image_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_image_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image_layer.add_child(_image_tex)
	_image_caption = _full_rect(Label.new())
	_image_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_image_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_image_caption.add_theme_font_size_override("font_size", 64)
	_image_caption.add_theme_color_override("font_color", Color("#3b2a1a"))
	_image_layer.add_child(_image_caption)


func _build_inventory_bar() -> void:
	_bar = PanelContainer.new()
	_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bar.offset_top = -BAR_H
	_bar.add_theme_stylebox_override("panel", _box(Color(0.12, 0.08, 0.05, 0.85), 0))
	_root.add_child(_bar)
	_slots_box = HBoxContainer.new()
	_slots_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_slots_box.add_theme_constant_override("separation", 14)
	_bar.add_child(_slots_box)


func _build_hint_button() -> void:
	_hint_button = Button.new()
	_hint_button.text = "★ " + tr("UI_HINT")
	_hint_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_hint_button.offset_left = -260
	_hint_button.offset_top = 24
	_hint_button.offset_right = -24
	_hint_button.offset_bottom = 120
	_hint_button.pressed.connect(func(): hint_pressed.emit())
	_root.add_child(_hint_button)


func _build_letterbox() -> void:
	for preset in [Control.PRESET_TOP_WIDE, Control.PRESET_BOTTOM_WIDE]:
		var b := ColorRect.new()
		b.color = Color.BLACK
		b.set_anchors_and_offsets_preset(preset)
		if preset == Control.PRESET_TOP_WIDE:
			b.offset_bottom = 110
		else:
			b.offset_top = -110
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.hide()
		_root.add_child(b)
		_bars.append(b)


func _build_choices() -> void:
	_choices = VBoxContainer.new()
	_choices.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_choices.offset_left = -700
	_choices.offset_right = 700
	_choices.offset_top = -420
	_choices.offset_bottom = -40
	_choices.alignment = BoxContainer.ALIGNMENT_END
	_choices.add_theme_constant_override("separation", 12)
	_choices.hide()
	_root.add_child(_choices)


func _build_subtitle() -> void:
	_catcher = _full_rect(Control.new())
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_advance.emit())
	_catcher.hide()
	_root.add_child(_catcher)
	_subtitle = PanelContainer.new()
	_subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_subtitle.offset_left = -760
	_subtitle.offset_right = 760
	_subtitle.offset_top = 130
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.72), 18, 24))
	_subtitle.hide()
	_root.add_child(_subtitle)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle.add_child(box)
	_subtitle_name = Label.new()
	_subtitle_name.add_theme_font_size_override("font_size", 30)
	box.add_child(_subtitle_name)
	_subtitle_text = Label.new()
	_subtitle_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_text.custom_minimum_size = Vector2(1460, 0)
	box.add_child(_subtitle_text)


func _build_toast() -> void:
	_toast = Label.new()
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.offset_left = -600
	_toast.offset_right = 600
	_toast.offset_top = -BAR_H - 80
	_toast.offset_bottom = -BAR_H - 20
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_color", Color("#ffd27f"))
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 10)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.hide()
	_root.add_child(_toast)


func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 36
	theme.set_stylebox("normal", "Button", _box(Color(0.16, 0.1, 0.05, 0.88), 14, 18))
	theme.set_stylebox("hover", "Button", _box(Color(0.3, 0.2, 0.1, 0.92), 14, 18))
	theme.set_stylebox("pressed", "Button", _box(Color("#4f361f"), 14, 18))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	return theme


func _box(color: Color, radius: int, margin := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


func _full_rect(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c
