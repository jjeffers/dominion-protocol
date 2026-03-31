---
description: Start 2 visual clients with 'near future world war' automatically loaded.
---

This workflow boots a Host and a Connecting Client and uses automated CLI arguments to force the host to select the "Near Future World War" scenario, join Faction 1 (Blue), and auto-start upon receiving a connection. The client is commanded to automatically join Faction 2 (Red).

1. Launch the visual Host instance that automatically selects the NFWW scenario and joins the blue faction.
// turbo
`godot --host --host-ip=127.0.0.1 --host-port=7001 --scenario="near_future_world_war" --faction="Faction 1" --auto-start &`

2. Wait 2 seconds and launch a visual Client instance that joins the red faction automatically.
// turbo
`sleep 2; godot --client --port=7001 --faction="Faction 2" &`
