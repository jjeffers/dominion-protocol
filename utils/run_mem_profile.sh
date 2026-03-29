#!/bin/bash
killall -9 godot 2>/dev/null || true
echo "Running Godot host under Massif..."
rm -f massif.out.*
valgrind --tool=massif --massif-out-file=massif_host.out godot --headless --host --faction=CFS --bot=CFS --auto-start --port=7200 >/dev/null 2>&1 &
HOST_PID=$!
sleep 3
echo "Running Godot client under Massif..."
timeout 30 valgrind --tool=massif --massif-out-file=massif_client.out godot --headless --client --faction=CSP --bot=CSP --port=7200 >/dev/null 2>&1
kill -9 $HOST_PID wait
echo "Host massif report:"
ms_print massif_host.out | head -n 40
echo "Client massif report:"
ms_print massif_client.out | head -n 40
