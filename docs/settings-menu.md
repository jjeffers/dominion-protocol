# Settings Menu Layout

This document details the layout and functionality of the in-game Settings Menu. 

## Structure

The `SettingsMenu` is a full-screen `Control` node that overlays the game interface.
- **Background**: A semi-transparent black `ColorRect` to obscure the game context behind the menu.
- **Layout Container**: A `CenterContainer` housing a `VBoxContainer` which vertically stacks elements with a fixed minimum width.

## Elements

1. **Title**: A large "Settings" header label.
2. **Save Game Button**: Saves the current state of the game. Specifics to be detailed later.
3. **Load Game Button**: Loads a saved state. Specifics to be detailed later.
4. **Audio Settings Button**: Opens the Audio Settings submenu/dialog.
5. **Exit To Desktop Button**: Closes the application completely (`get_tree().quit()`).

## Audio Settings Submenu
The Audio Settings are managed via an `AcceptDialog` containing sliders for adjusting bus volumes:
- **Master Volume**: Controls the main output bus.
- **SFX Volume**: Controls sound effects volume.
- **Music Volume**: Controls background music volume.
