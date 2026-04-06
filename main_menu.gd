extends Control

const GAME_SCENE_PATH = "res://main.tscn"
const MASTER_BUS_NAME = "Master"

const REMAPPABLE_ACTIONS = [
	{"action": "move_up", "label": "Move Up"},
	{"action": "move_down", "label": "Move Down"},
	{"action": "move_left", "label": "Move Left"},
	{"action": "move_right", "label": "Move Right"},
	{"action": "attack", "label": "Attack"},
	{"action": "harvest", "label": "Harvest"},
	{"action": "build_spawn", "label": "Build Spawn"},
	{"action": "build_tower", "label": "Build Tower"},
	{"action": "place_object", "label": "Place Object"},
	{"action": "open_upgrades", "label": "Open Upgrades"}
]

@onready var main_panel = $CenterContainer/MainPanel
@onready var options_panel = $CenterContainer/OptionsPanel

@onready var play_button = $CenterContainer/MainPanel/VBox/PlayButton
@onready var options_button = $CenterContainer/MainPanel/VBox/OptionsButton
@onready var quit_button = $CenterContainer/MainPanel/VBox/QuitButton

@onready var fullscreen_check = $CenterContainer/OptionsPanel/VBox/FullscreenCheck
@onready var volume_slider = $CenterContainer/OptionsPanel/VBox/VolumeSlider
@onready var volume_value_label = $CenterContainer/OptionsPanel/VBox/VolumeValueLabel
@onready var mappings_container = $CenterContainer/OptionsPanel/VBox/MappingScroll/MappingsContainer
@onready var remap_hint_label = $CenterContainer/OptionsPanel/VBox/RemapHintLabel
@onready var options_back_button = $CenterContainer/OptionsPanel/VBox/BackButton

var action_buttons = {}
var remapping_action = ""


func _ready() -> void:
	get_tree().paused = false
	_show_main_panel()
	_build_input_mapping_rows()
	_sync_settings_to_ui()

	play_button.pressed.connect(_on_play_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	options_back_button.pressed.connect(_on_back_pressed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	volume_slider.value_changed.connect(_on_master_volume_changed)


func _show_main_panel() -> void:
	main_panel.visible = true
	options_panel.visible = false


func _show_options_panel() -> void:
	main_panel.visible = false
	options_panel.visible = true


func _sync_settings_to_ui() -> void:
	fullscreen_check.button_pressed = (
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	)

	var master_bus_index = AudioServer.get_bus_index(MASTER_BUS_NAME)
	if master_bus_index >= 0:
		volume_slider.value = AudioServer.get_bus_volume_db(master_bus_index)

	_update_volume_label(volume_slider.value)
	_refresh_action_button_texts()
	_update_remap_hint()


func _build_input_mapping_rows() -> void:
	for child in mappings_container.get_children():
		child.queue_free()

	action_buttons.clear()

	for mapping_entry in REMAPPABLE_ACTIONS:
		var action_name = String(mapping_entry.get("action", ""))
		var display_name = String(mapping_entry.get("label", ""))

		if action_name == "":
			continue

		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var action_label = Label.new()
		action_label.text = display_name
		action_label.custom_minimum_size = Vector2(170.0, 0.0)
		action_label.modulate = Color(0.08, 0.1, 0.15, 1.0)

		var remap_button = Button.new()
		remap_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		remap_button.text = _get_action_event_text(action_name)
		remap_button.pressed.connect(_begin_remap.bind(action_name))

		row.add_child(action_label)
		row.add_child(remap_button)
		mappings_container.add_child(row)

		action_buttons[action_name] = remap_button


func _refresh_action_button_texts() -> void:
	for mapping_entry in REMAPPABLE_ACTIONS:
		var action_name = String(mapping_entry.get("action", ""))
		if action_name == "":
			continue

		if action_name == remapping_action:
			continue

		var remap_button = action_buttons.get(action_name, null)
		if remap_button == null:
			continue

		remap_button.text = _get_action_event_text(action_name)


func _get_action_event_text(action_name: String) -> String:
	var events = InputMap.action_get_events(action_name)
	if events.is_empty():
		return "Unbound"

	var event = events[0]
	if event is InputEventKey:
		return event.as_text_physical_keycode()

	if event is InputEventMouseButton:
		return "Mouse " + _get_mouse_button_name(event.button_index)

	return event.as_text()


func _begin_remap(action_name: String) -> void:
	remapping_action = action_name
	var remap_button = action_buttons.get(action_name, null)
	if remap_button != null:
		remap_button.text = "Press any key..."

	_update_remap_hint()


func _apply_remapped_input(action_name: String, input_event: InputEvent) -> void:
	InputMap.action_erase_events(action_name)
	InputMap.action_add_event(action_name, input_event)

	remapping_action = ""
	_refresh_action_button_texts()
	_update_remap_hint()


func _update_remap_hint() -> void:
	if remapping_action == "":
		remap_hint_label.text = "Click a mapping button to remap. Press Esc to cancel remap."
		return

	var action_label = remapping_action.replace("_", " ").capitalize()
	remap_hint_label.text = "Waiting for input for: " + action_label + " (Esc to cancel)"


func _unhandled_input(event: InputEvent) -> void:
	if remapping_action == "":
		return

	if event is InputEventKey:
		if not event.pressed or event.echo:
			return

		if event.keycode == KEY_ESCAPE:
			remapping_action = ""
			_refresh_action_button_texts()
			_update_remap_hint()
			get_viewport().set_input_as_handled()
			return

		_apply_remapped_input(remapping_action, event)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		if not event.pressed:
			return

		_apply_remapped_input(remapping_action, event)
		get_viewport().set_input_as_handled()


func _get_mouse_button_name(button_index: int) -> String:
	match button_index:
		MOUSE_BUTTON_LEFT:
			return "Left"
		MOUSE_BUTTON_RIGHT:
			return "Right"
		MOUSE_BUTTON_MIDDLE:
			return "Middle"
		MOUSE_BUTTON_WHEEL_UP:
			return "Wheel Up"
		MOUSE_BUTTON_WHEEL_DOWN:
			return "Wheel Down"
		MOUSE_BUTTON_XBUTTON1:
			return "X1"
		MOUSE_BUTTON_XBUTTON2:
			return "X2"
		_:
			return str(button_index)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_options_pressed() -> void:
	_show_options_panel()
	_refresh_action_button_texts()
	_update_remap_hint()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_back_pressed() -> void:
	remapping_action = ""
	_refresh_action_button_texts()
	_update_remap_hint()
	_show_main_panel()


func _on_fullscreen_toggled(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _on_master_volume_changed(value: float) -> void:
	var master_bus_index = AudioServer.get_bus_index(MASTER_BUS_NAME)
	if master_bus_index >= 0:
		AudioServer.set_bus_volume_db(master_bus_index, value)

	_update_volume_label(value)


func _update_volume_label(value: float) -> void:
	volume_value_label.text = "Master Volume: " + str(int(round(value))) + " dB"
