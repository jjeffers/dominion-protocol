extends Control

@onready var save_game_button: Button = $CenterContainer/VBoxContainer/SaveGameButton
@onready var load_game_button: Button = $CenterContainer/VBoxContainer/LoadGameButton
@onready var audio_settings_button: Button = $CenterContainer/VBoxContainer/AudioSettingsButton
@onready var exit_button: Button = $CenterContainer/VBoxContainer/ExitButton

@onready var audio_dialog: AcceptDialog = $AudioSettingsDialog
@onready var save_dialog: FileDialog = $SaveGameDialog

func _ready() -> void:
    # Connect signals
    save_game_button.pressed.connect(_on_save_game_pressed)
    load_game_button.pressed.connect(_on_load_game_pressed)
    audio_settings_button.pressed.connect(_on_audio_settings_pressed)
    exit_button.pressed.connect(_on_exit_pressed)
    
    if save_dialog:
        save_dialog.file_selected.connect(_on_save_file_selected)

func setup_for_main_menu() -> void:
    if save_game_button: save_game_button.hide()
    if load_game_button: load_game_button.hide()


func _on_save_game_pressed() -> void:
    if save_dialog:
        if OS.has_feature("windows") or OS.has_feature("macos") or OS.has_feature("linux"):
            save_dialog.use_native_dialog = true
        save_dialog.popup_centered()

func _on_save_file_selected(path: String) -> void:
    if GameStateManager != null:
        GameStateManager.save_game(path)
        if ConsoleManager != null:
            ConsoleManager.log_message("Game saved to " + path)

func _on_load_game_pressed() -> void:
    # Load game is primarily intended to be executed from the Main Menu.
    ConsoleManager.log_message("To load a game, please exit to the Main Menu.")

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
