extends Control

const GAME_SCENE_PATH: String = "res://main.tscn"
const MASTER_BUS_NAME: StringName = &"Master"

@onready var main_panel: PanelContainer = $CenterContainer/MainPanel
@onready var options_panel: PanelContainer = $CenterContainer/OptionsPanel

@onready var play_button: Button = $CenterContainer/MainPanel/VBox/PlayButton
@onready var options_button: Button = $CenterContainer/MainPanel/VBox/OptionsButton
@onready var quit_button: Button = $CenterContainer/MainPanel/VBox/QuitButton

@onready var fullscreen_check: CheckButton = $CenterContainer/OptionsPanel/VBox/FullscreenCheck
@onready var volume_slider: HSlider = $CenterContainer/OptionsPanel/VBox/VolumeSlider
@onready var volume_value_label: Label = $CenterContainer/OptionsPanel/VBox/VolumeValueLabel
@onready var options_back_button: Button = $CenterContainer/OptionsPanel/VBox/BackButton


func _ready() -> void:
	get_tree().paused = false
	_show_main_panel()
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

	var master_bus_index: int = AudioServer.get_bus_index(MASTER_BUS_NAME)
	if master_bus_index >= 0:
		volume_slider.value = AudioServer.get_bus_volume_db(master_bus_index)

	volume_value_label.modulate = Color(0.08, 0.1, 0.15, 1.0)
	_update_volume_label(volume_slider.value)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_options_pressed() -> void:
	_show_options_panel()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_back_pressed() -> void:
	_show_main_panel()


func _on_fullscreen_toggled(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _on_master_volume_changed(value: float) -> void:
	var master_bus_index: int = AudioServer.get_bus_index(MASTER_BUS_NAME)
	if master_bus_index >= 0:
		AudioServer.set_bus_volume_db(master_bus_index, value)

	_update_volume_label(value)


func _update_volume_label(value: float) -> void:
	volume_value_label.text = "Master Volume: " + str(int(round(value))) + " dB"
