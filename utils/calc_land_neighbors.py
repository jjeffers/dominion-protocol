import struct
import json

DATA_PATH = "src/data/map_data.bin"
REGIONS_PATH = "src/data/region_data.json"
OUTPUT_PATH = "src/data/city_land_neighbors.json"

TILE_STRUCT_SIZE = 32

print("Loading region data...")
with open(REGIONS_PATH, 'r') as f:
    raw_regions = json.load(f)

# Convert string keys to int
region_map = {}
for k, v in raw_regions.items():
    if '_' in k:
        # UUID calculation based on face, x, y - skip for now if not needed,
        # but the JSON might use integer strings
        continue
    region_map[int(k)] = v

print(f"Loaded {len(region_map)} region mappings.")

print("Reading quad tile binary data...")
with open(DATA_PATH, 'rb') as f:
    quad_data = f.read()

num_tiles = len(quad_data) // TILE_STRUCT_SIZE
print(f"Total tiles: {num_tiles}")

city_neighbors = {}

def get_terrain(tile_id):
    if tile_id < 0 or tile_id >= num_tiles: return 0
    offset = tile_id * TILE_STRUCT_SIZE
    return quad_data[offset + 28]

for tile_id in range(num_tiles):
    owner = region_map.get(tile_id)
    if not owner: continue
    
    terrain = get_terrain(tile_id)
    if terrain == 0: continue # Ocean/Lake
    
    offset = tile_id * TILE_STRUCT_SIZE
    
    # Read neighbors (uint32)
    n0, n1, n2, n3 = struct.unpack('<IIII', quad_data[offset + 12 : offset + 28])
    
    for n in (n0, n1, n2, n3):
        if n == 0xFFFFFFFF or n >= num_tiles: continue
        n_owner = region_map.get(n)
        if not n_owner: continue
        
        if n_owner != owner:
            n_terrain = get_terrain(n)
            if n_terrain > 0:
                if owner not in city_neighbors:
                    city_neighbors[owner] = set()
                city_neighbors[owner].add(n_owner)

# Convert sets to lists
out_data = {k: list(v) for k, v in city_neighbors.items()}

print(f"Found {len(out_data)} cities with land neighbors.")

with open(OUTPUT_PATH, 'w') as f:
    json.dump(out_data, f, indent=4)

print("Saved to", OUTPUT_PATH)
