import json
import urllib.request
import urllib.parse
import time
import math

RADIUS = 1.02

def lat_lon_to_vector3(lat_deg, lon_deg):
    lat_rad = math.radians(lat_deg)
    lon_rad = math.radians(lon_deg)
    return {
        "x": RADIUS * math.cos(lat_rad) * math.cos(lon_rad),
        "y": RADIUS * math.sin(lat_rad),
        "z": RADIUS * math.cos(lat_rad) * math.sin(lon_rad)
    }

def geocode_city(city_name):
    print(f"Geocoding {city_name} via Nominatim...")
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
    # Read desired
    with open('docs/cities.md', 'r') as f:
        desired_cities = [line.strip() for line in f if line.strip() and not line.startswith('#')]
        
    # Read current DB
    with open('src/data/city_data.json', 'r') as f:
        db = json.load(f)
        
    new_db = {}
    missing_cities = []
    
    # Prune and retain
    for city in desired_cities:
        if city in db:
            new_db[city] = db[city]
        else:
            missing_cities.append(city)
            
    # Geocode missing ones safely
    for city in missing_cities:
        lat, lon = geocode_city(city)
        if lat is not None and lon is not None:
            new_db[city] = {
                "latitude": lat,
                "longitude": lon,
                "vector3": lat_lon_to_vector3(lat, lon)
            }
        else:
            print(f"=> CRITICAL WARNING: Failed to geocode {city}")
        time.sleep(1.5) # generous sleep to avoid 429
        
    # Apply manual overrides globally just to force vector recalcs
    # London
    if "London" in new_db:
        new_db["London"]["latitude"] = 51.5074456
        new_db["London"]["longitude"] = 0.67
    if "Hamburg" in new_db:
        new_db["Hamburg"]["latitude"] = 53.85
        new_db["Hamburg"]["longitude"] = 9.2
    if "Bordeaux" in new_db:
        new_db["Bordeaux"]["latitude"] = 44.841225
        new_db["Bordeaux"]["longitude"] = -0.98
    if "Kolkata" in new_db:
        new_db["Kolkata"]["latitude"] = 21.0
        new_db["Kolkata"]["longitude"] = 88.3638953
    if "Saigon" in new_db:
        new_db["Saigon"]["latitude"] = 10.33
        new_db["Saigon"]["longitude"] = 107.15
    if "Athens" in new_db:
        new_db["Athens"]["latitude"] = 37.9838
        new_db["Athens"]["longitude"] = 23.7275
    if "Geneva" in new_db:
        new_db["Geneva"]["latitude"] = 46.2044
        new_db["Geneva"]["longitude"] = 6.1432
    if "Sevastopol" in new_db:
        new_db["Sevastopol"]["latitude"] = 44.6166
        new_db["Sevastopol"]["longitude"] = 33.5254
    if "Tunis" in new_db:
        new_db["Tunis"]["latitude"] = 36.8065
        new_db["Tunis"]["longitude"] = 10.1815
        
    for city, data in new_db.items():
        new_db[city]["vector3"] = lat_lon_to_vector3(data["latitude"], data["longitude"])

    # Write out
    with open('src/data/city_data.json', 'w') as f:
        json.dump(new_db, f, indent="\t")
        
    print(f"Reconciliation complete! Pruned {len(db) - len(new_db) + len(missing_cities)} old cities.")
    print(f"Added {len(missing_cities)} new cities: {missing_cities}")
    print(f"Total Database Size: {len(new_db)} cities.")

if __name__ == "__main__":
    main()
