import json
with open("src/data/city_data.json", "r") as f:
    d = json.load(f)
d["London"]["latitude"] = 51.5074456
d["London"]["longitude"] = 0.67
d["Hamburg"]["latitude"] = 53.85
d["Hamburg"]["longitude"] = 9.2
d["Bordeaux"]["latitude"] = 44.841225
d["Bordeaux"]["longitude"] = -0.98
d["Kolkata"]["latitude"] = 21.0000000
d["Kolkata"]["longitude"] = 88.3638953
d["Reykjavik"] = {"latitude": 64.1485, "longitude": -21.9442}
d["Pearl Harbor"] = {"latitude": 21.3444, "longitude": -157.9405}
d["Rabaul"] = {"latitude": -4.1983, "longitude": 152.1793}
d["Port Moresby"] = {"latitude": -9.4431, "longitude": 147.1797}

# Add Vector3 math back in
import math
RADIUS = 1.02
for city, data in d.items():
    lat_r = math.radians(data['latitude'])
    lon_r = math.radians(data['longitude'])
    d[city]['vector3'] = {
        "x": RADIUS * math.cos(lat_r) * math.cos(lon_r),
        "y": RADIUS * math.sin(lat_r),
        "z": RADIUS * math.cos(lat_r) * math.sin(lon_r)
    }

with open("src/data/city_data.json", "w") as f:
    json.dump(d, f, indent="\t")
