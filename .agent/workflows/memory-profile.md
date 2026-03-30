---
description: Conduct a memory profile using 2 headless bots
---

This workflow launches two headless instances of the game and enables profiling. The host will act as the server and auto-start the match. Any unassigned factions (CFS and CSP) will automatically be assigned to the `TacticalAI` bot logic by the Host upon starting. 
Once the match concludes, peak memory consumption and subsystem breakdowns are written to `host_profile.log` and `client_profile.log`.

1. Start the Host Instance
// turbo
```bash
godot --headless --host --faction=CFS --bot=CFS --profile --auto-start &
```

2. Start the Client Instance
// turbo
```bash
sleep 2 && godot --headless --client --faction=CSP --bot=CSP --profile &
```

3. View resulting profile reports (wait for match completion first)
```bash
cat host_profile.log client_profile.log
```
