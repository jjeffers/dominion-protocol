#!/bin/bash
for file in test/*.gd; do
  echo "--- Testing $file ---"
  timeout 3 /usr/local/bin/godot --headless --path . -s "addons/gut/gut_cmdln.gd" -gtest="$file" > /dev/null 2>&1
  if [ $? -eq 124 ]; then
    echo ">>>>> HANG DETECTED IN $file"
  else
    echo ">>>>> FINISHED $file"
  fi
done
