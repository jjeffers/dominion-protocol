#!/bin/bash

killall -9 godot 2>/dev/null || true
rm -f host_match_*.log client_match_*.log

echo "Deploying 5 fully concurrent matches on UDP ports 7001-7005..."

for i in {1..5}; do
  PORT=$((7000 + i))
  echo "Spawning Match $i on PORT $PORT (Host=Blue, Client=Red)..."
  godot --headless --host --faction=Blue --bot=Blue --auto-start --port=$PORT --match-id=$i > "host_match_$i.log" 2>&1 &
done

echo "Giving hosts 3 seconds to spin up..."
sleep 3

for i in {1..5}; do
  PORT=$((7000 + i))
  godot --headless --client --faction=Red --bot=Red --port=$PORT --match-id=$i > "client_match_$i.log" 2>&1 &
done

echo "Waiting for all cluster matches to safely conclude organically..."
wait

echo ""
echo "=============================="
echo "    BOT BATTERY RESULTS       "
echo "=============================="
echo "Blue Wins: $(grep -h '\[MATCH_RESULT\].*FACTION=Blue WINNER=Blue' host_match_*.log 2>/dev/null | wc -l)"
echo "Red Wins:  $(grep -h '\[MATCH_RESULT\].*FACTION=Blue WINNER=Red' host_match_*.log 2>/dev/null | wc -l)"
echo "=============================="
