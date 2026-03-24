---
description: Start a Host and Client instance for AI bot match
---

This workflow launches two instances of the game. The host will act as the server and auto-start the match. Any unassigned factions (CFS and CSP) will automatically be assigned to the `TacticalAI` bot logic by the Host upon starting. 

1. Start the Host Instance
// turbo
```bash
godot --host --faction=CFS --bot=CFS --auto-start &
```

2. Start the Client Instance
// turbo
```bash
sleep 2 && godot --client --faction=CSP --bot=CSP &
```

