---
description: Start 2 visual clients with 'near future world war' automatically loaded, both managed by AI.
---

This workflow boots a Host and a Connecting Client and uses automated CLI arguments to force the host to select the "Near Future World War" scenario, assigning both "Faction 1" and "Faction 2" to Tactical AI instances.

1. Launch the visual Host instance that automatically selects the NFWW scenario and assigns Faction 1 to a bot.
// turbo
```bash
godot --host --host-ip=127.0.0.1 --host-port=7001 --scenario="near_future_world_war" --faction="Faction 1" --bot="Faction 1" --auto-start &
```

2. Wait 2 seconds and launch a visual Client instance that assigns Faction 2 to a bot automatically.
// turbo
```bash
sleep 2; godot --client --port=7001 --faction="Faction 2" --bot="Faction 2" &
```
