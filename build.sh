#!/bin/bash

# Ensure Godot Headless exists globally or locally
GODOT_EXE="godot"
if [ -f "./godot" ]; then
    GODOT_EXE="./godot"
elif command -v /usr/local/bin/godot &> /dev/null; then
    GODOT_EXE="/usr/local/bin/godot"
fi

echo "Initiating map generation protocol natively..."
$GODOT_EXE --headless -s src/scripts/tools/QuadSphereBaker.gd 
echo "Procedural map generation strictly complete."
