import json
import urllib.request
import urllib.parse
import time
import math

# We need to compute Godot Vector3 coordinates based on radius 1.02 (the unit radius)
# and the spherical mapping:
# x = r * cos(lat) * cos(lon)
# y = r * sin(lat)
# z = r * cos(lat) * sin(lon)
RADIUS = 1.02

def lat_lon_to_vector3(lat_deg, lon_deg):
    lat_rad = math.radians(lat_deg)
    lon_rad = math.radians(lon_deg)
    
    x = RADIUS * math.cos(lat_rad) * math.cos(lon_rad)
    y = RADIUS * math.sin(lat_rad)
    z = RADIUS * math.cos(lat_rad) * math.sin(lon_rad)
    
    return {"x": x, "y": y, "z": z}

def geocode_city(city_name):
    # Use Nominatim API (OpenStreetMap)
    # Requires a user-agent
    url = f"https://nominatim.openstreetmap.org/search?q={urllib.parse.quote(city_name)}&format=json&limit=1"
    req = urllib.request.Request(url, headers={'User-Agent': 'GodotGameGeocodingScript/1.0'})
    
    try:
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode())
            if data and len(data) > 0:
                lat = float(data[0]['lat'])
                lon = float(data[0]['lon'])
                return lat, lon
    except Exception as e:
        print(f"Error geocoding {city_name}: {e}")
    return None, None

def main():
    with open('/home/jdjeffers/.gemini/antigravity/playground/glowing-prominence/docs/cities.md', 'r') as f:
        cities = [line.strip() for line in f if line.strip()]
        
    results = {}
    
    for i, city in enumerate(cities):
        print(f"[{i+1}/{len(cities)}] Geocoding {city}...")
        lat, lon = geocode_city(city)
        if lat is not None and lon is not None:
            vec3 = lat_lon_to_vector3(lat, lon)
            results[city] = {
                "latitude": lat,
                "longitude": lon,
                "vector3": vec3
            }
        else:
            print(f" => Failed to geocode {city}")
            
        # Respect Nominatim's 1-request-per-second usage policy
        time.sleep(1.1)
        
    output_path = '/home/jdjeffers/.gemini/antigravity/playground/glowing-prominence/docs/city_data.json'
    with open(output_path, 'w') as f:
        json.dump(results, f, indent=4)
        
    print(f"\nDone! Saved {len(results)} cities to {output_path}")

if __name__ == "__main__":
    main()
