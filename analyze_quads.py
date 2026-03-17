import json
import os

filepath = 'src/data/quad_data.json'

with open(filepath, 'r') as f:
    data = json.load(f)

# Profile data fields
fields = set()
terrain_types = set()
for key, value in data.items():
    fields.update(value.keys())
    if "terrain" in value:
        terrain_types.add(value["terrain"])

print("Found fields:", fields)
print("Found terrain types:", terrain_types)

# See how much space we can save by dropping:
# 1. base_id (seems unused in MapData.gd)
# 2. coord_x, coord_y, face (already in the key name e.g. BACK_0_0)
# 3. is_port: false defaults

optimized_data = {}
for key, value in data.items():
    new_val = {}
    
    # Keep essential fields
    for k in ["terrain", "world_x", "world_y", "world_z"]:
        if k in value:
            # Don't store "OCEAN" since it's the fallback default in MapData.gd
            if k == "terrain" and value[k] == "OCEAN":
                continue
            new_val[k] = value[k]
            
    # Shorten neighbors into a clean ordered array [N, E, S, W] 
    # instead of a verbose dictionary
    new_val["n"] = []
    for d in ["N", "E", "S", "W"]:
        new_val["n"].append(value.get("neighbors", {}).get(d, ""))
    
    # Only store is_port if true
    if value.get("is_port", False):
        new_val["is_port"] = True
        
    optimized_data[key] = new_val

import tempfile
with tempfile.NamedTemporaryFile(mode='w', delete=False) as f:
    json.dump(optimized_data, f, separators=(',', ':'))
    opt_path = f.name

orig_size = os.path.getsize(filepath)
opt_size = os.path.getsize(opt_path)

print(f"Original size: {orig_size / 1024 / 1024:.2f} MB")
print(f"Optimized size: {opt_size / 1024 / 1024:.2f} MB")
print(f"Reduction: {(orig_size - opt_size) / orig_size * 100:.2f}%")

os.remove(opt_path)
