---
description: Start the Godot executable to test the project automatically with Host and Client
---

1. Run the `godot` executable from the root directory to host the game as the Blue faction and auto-start, then launch a second `godot` client as the Red faction.

// turbo
```bash
godot --host --faction=Blue --auto-start &
sleep 2
godot --client --faction=Red
```
