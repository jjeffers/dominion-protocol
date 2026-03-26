extends Control

@onready var save_game_button: Button = $CenterContainer/VBoxContainer/SaveGameButton
@onready var load_game_button: Button = $CenterContainer/VBoxContainer/LoadGameButton
@onready var audio_settings_button: Button = $CenterContainer/VBoxContainer/AudioSettingsButton
@onready var exit_button: Button = $CenterContainer/VBoxContainer/ExitButton

@onready var audio_dialog: AcceptDialog = $AudioSettingsDialog

func _ready() -> void:
    # Connect signals
    save_game_button.pressed.connect(_on_save_game_pressed)
    load_game_button.pressed.connect(_on_load_game_pressed)
    audio_settings_button.pressed.connect(_on_audio_settings_pressed)
    exit_button.pressed.connect(_on_exit_pressed)

func setup_for_main_menu() -> void:
    if save_game_button: save_game_button.hide()
    if load_game_button: load_game_button.hide()


func _on_save_game_pressed() -> void:
    # TODO: Implement Save Game logic when detailed later
    print("Save Game pressed")

func _on_load_game_pressed() -> void:
    # TODO: Implement Load Game logic when detailed later
    print("Load Game pressed")

func _on_audio_settings_pressed() -> void:
    # Open the Audio Settings dialog
    audio_dialog.popup_centered()

func _on_exit_pressed() -> void:
    # Exit to desktop
    get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.physical_keycode == KEY_ESCAPE and event.pressed):
        if audio_dialog.visible:
            audio_dialog.hide()
        else:
            queue_free()
        get_viewport().set_input_as_handled()
