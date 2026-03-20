---
description: Run a battery of 10 automated headless Godot bot matches parsing win/loss records
---

# Bot Battery Workflow

This workflow explicitly runs 10 completely independent Godot skirmishes entirely headlessly. It isolates each network cluster linearly to UDP ports ranging 7001-7010 synchronously, lets them organically battle to conclusion natively, and then aggregates the finalized `[MATCH_RESULT]` metrics locally!

1. Deploy the 10 Execution Clusters Concurrently:
// turbo-all
```bash
for i in {1..10}; do
  port=$((7000 + i))
  echo "Spawning Match $i on port $port (Host=Blue, Client=Red)..."
  /usr/local/bin/godot --headless --host --faction=Blue --bot=Blue --auto-start --port=$port --match-id=$i > "host_match_$i.log" 2>&1 &
  sleep 2
  /usr/local/bin/godot --headless --client --faction=Red --bot=Red --port=$port --match-id=$i > "client_match_$i.log" 2>&1 &
done
```

2. Automatically Wait for Match Completions & Aggregate Analytics:
// turbo-all
```bash
echo "Waiting for all 10 matches to conclude (this will take several minutes natively)..."
while true; do
  completed=$(grep -r "\[MATCH_RESULT\]" host_match_*.log 2>/dev/null | wc -l)
  if [ "$completed" -ge 10 ]; then
    echo "All 10 matches concluded successfully!"
    break
  fi
  sleep 10
done

echo ""
echo "=============================="
echo "    BOT BATTERY RESULTS       "
echo "=============================="
echo "Blue Wins:" $(grep -h "\[MATCH_RESULT\].*FACTION=Blue WINNER=Blue" host_match_*.log 2>/dev/null | wc -l)
echo "Red Wins:" $(grep -h "\[MATCH_RESULT\].*FACTION=Blue WINNER=Red" host_match_*.log 2>/dev/null | wc -l)
echo "=============================="
```
