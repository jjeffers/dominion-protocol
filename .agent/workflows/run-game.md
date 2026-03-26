---
description: Start the Godot executable to test the project automatically with Host and Client
---

1. Run the `godot` executable from the root directory to host the game as the CFS faction and auto-start, then launch a second `godot` client as the CSP faction.

// turbo
```bash
godot --host --faction=CFS --host-ip=127.0.0.1 --host-port=7001 --auto-start &
sleep 2
godot --client --faction=CSP --port=7001
```