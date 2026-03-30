---
description: Run the memory profile locally and compare with existing gh-pages data before pushing commits
---

1. Run the headless bots to generate a new memory profile
// turbo-all
```bash
timeout 300 godot --headless --host --faction=CFS --bot=CFS --profile --auto-start || true &
sleep 2 && timeout 300 godot --headless --client --faction=CSP --bot=CSP --profile || true &
wait
```

2. Parse and compare against `gh-pages` baseline
```bash
python3 .agent/scripts/compare_memory_profile.py
```

3. Read the generated `memory_comparison_report.md` report
```bash
cat memory_comparison_report.md
```

**Note:** After reading the report, you (the agent) must present the `memory_comparison_report.md` to the user and wait for their approval before proceeding to push any commits.
