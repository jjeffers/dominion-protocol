import json
import math

RADIUS = 1.02

def lat_lon_to_vector3(lat_deg, lon_deg):
    lat_rad = math.radians(lat_deg)
    lon_rad = math.radians(lon_deg)
    
    x = RADIUS * math.cos(lat_rad) * math.cos(lon_rad)
    y = RADIUS * math.sin(lat_rad)
    z = RADIUS * math.cos(lat_rad) * math.sin(lon_rad)
    
    return {"x": x, "y": y, "z": z}

# Coordinates for Kaliningrad/Königsberg
lat, lon = 54.8104, 20.4522
vec3 = lat_lon_to_vector3(lat, lon)

with open('src/data/city_data.json', 'r') as f:
    data = json.load(f)

data["Königsberg"] = {
    "latitude": lat,
    "longitude": lon,
    "vector3": vec3
}

with open('src/data/city_data.json', 'w') as f:
    json.dump(data, f, indent=4)
    
print("Successfully injected Königsberg!")
