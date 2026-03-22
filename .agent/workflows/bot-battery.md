---
description: Run a battery of 10 automated headless Godot bot matches parsing win/loss records
---

# Bot Battery Workflow

This workflow explicitly runs 10 completely independent Godot skirmishes entirely headlessly. It isolates each network cluster linearly to UDP ports ranging 7001-7010 synchronously, lets them organically battle to conclusion natively, and then aggregates the finalized `[MATCH_RESULT]` metrics locally!

1. Deploy the 10 Execution Clusters Concurrently:
Run the utils/run_battery.sh