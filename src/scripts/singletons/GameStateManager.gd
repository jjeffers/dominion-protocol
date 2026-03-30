extends Node

var current_loaded_state: Dictionary = {}

func save_game(file_path: String) -> void:
    if get_tree() == null:
        return
        
    var main = get_tree().root.get_node_or_null("Main")
    if not main or not main.get("scenario_data"):
        push_error("GameStateManager: Could not find Main Node or scenario_data to save.")
        return
        
    var base_state = main.scenario_data.duplicate(true)
    
    # 1. Capture dynamic faction stats and unit states
    if base_state.has("factions"):
        for fac_name in base_state["factions"].keys():
            base_state["factions"][fac_name]["units"] = []
            
    # Serialize active units
    var all_units = get_tree().get_nodes_in_group("units")
    for unit in all_units:
        if unit.has_method("serialize"):
            var unit_data = unit.serialize()
            var f_name = unit.faction_name
            if base_state.has("factions") and base_state["factions"].has(f_name):
                base_state["factions"][f_name]["units"].append(unit_data)
                
    # Capture economy nuances directly from MainScene
    # If a city is destroyed, or oil hub toggled, it's generally synced into scenario_data over time,
    # but let's ensure the explicit current dict is fresh from `NetworkManager.scenario_data` if needed.
    # main.scenario_data is actively modified by events (e.g., nuke_hit), so it should be largely up to date.
    
    # 2. Capture Time
    if ConsoleManager != null:
        base_state["match_time"] = ConsoleManager.match_time
        
    # 3. File IO
    var file = FileAccess.open(file_path, FileAccess.WRITE)
    if not file:
        push_error("GameStateManager: Failed to open file for writing: " + file_path)
        return
        
    var json_str = JSON.stringify(base_state, "\t")
    file.store_string(json_str)
    file.close()

func load_game(file_path: String) -> bool:
    var file = FileAccess.open(file_path, FileAccess.READ)
    if not file:
        push_error("GameStateManager: Failed to open file for reading: " + file_path)
        return false
        
    var content = file.get_as_text()
    file.close()
    
    var json = JSON.new()
    var error = json.parse(content)
    if error != OK:
        push_error("GameStateManager: Failed to parse save file JSON: " + file_path)
        return false
        
    var data = json.get_data()
    if typeof(data) == TYPE_DICTIONARY:
        current_loaded_state = data
        return true
    else:
        push_error("GameStateManager: JSON data is not a Dictionary.")
        return false
