#!/bin/bash
for i in {1..10}; do
  port=$((7000 + i))
  echo "Spawning Match $i on port $port (Host=Blue, Client=Red)..."
  godot --headless --host --faction=Blue --bot=Blue --auto-start --port=$port --match-id=$i > "host_match_$i.log" 2>&1 &
  sleep 2
  godot --headless --client --faction=Red --bot=Red --port=$port --match-id=$i > "client_match_$i.log" 2>&1 &
done

echo "Waiting for all 10 matches to conclude (this will take several minutes natively)..."
while true; do
  completed=$(grep -h "\[MATCH_RESULT\]" host_match_*.log 2>/dev/null | wc -l)
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
