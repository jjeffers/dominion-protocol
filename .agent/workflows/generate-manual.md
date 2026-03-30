---
description: Generates the player manual as a PDF
---

Run the local script to generate the player manual as a PDF.

1. Generate documentation updates
Prompt the agent to read all markdown files in the `docs/` directory (excluding `player_manual.md`). Instruct the agent to cross-reference the detailed mechanic specifications (like oil, nuclear weapons, diplomacy, etc.) with the current `docs/player_manual.md` content and apply any missing mechanics, rules, or features to the player manual. Ensure the manual remains a cohesive, player-facing guide rather than a technical design document. Do not proceed to the next step until the agent has successfully updated `player_manual.md`.

// turbo
2. Execute the generation script
```bash
./utils/generate_manual.sh
```