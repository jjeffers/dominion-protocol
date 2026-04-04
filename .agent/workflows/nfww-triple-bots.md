---
description: Start 3 visual clients with 'near future world war' automatically loaded, all managed by AI bots.
---

This workflow boots a Host and two Connecting Clients. It uses automated CLI arguments to force the host to select the "Near Future World War" scenario, add an additional faction, and auto-start the game once all 3 factions are joined by bots.

1. Launch the visual Host instance that automatically selects the NFWW scenario, adds 1 additional faction dynamically, and assigns Faction 1 to a bot.
// turbo
```bash
godot --host --host-ip=127.0.0.1 --host-port=7001 --scenario="near_future_world_war" --add-factions=1 --expected-players=3 --faction="Faction 1" --bot="Faction 1" --auto-start &
```

2. Wait 2 seconds and launch the first visual Client instance that assigns Faction 2 to a bot automatically.
// turbo
```bash
sleep 2; godot --client --port=7001 --faction="Faction 2" --bot="Faction 2" &
```

3. Wait another 2 seconds and launch the second visual Client instance that assigns Faction 3 to a bot automatically.
// turbo
```bash
sleep 4; godot --client --port=7001 --faction="Faction 3" --bot="Faction 3" &
```
