import math
from PIL import Image

ndvi = Image.open('/home/jdjeffers/Documents/NDVI_84.bw.png').convert('L')
w, h = ndvi.size

def sample_coord(name, lat_deg, lon_deg):
    lat = math.radians(lat_deg)
    lon = math.radians(lon_deg)
    
    # Same math from QuadSphereBaker
    u = (lon + math.pi) / (2.0 * math.pi)
    u = 1.0 - u # Flip East/West
    
    v_base = (lat + (math.pi / 2.0)) / math.pi
    v_north = 1.0 - v_base
    
    px = int(max(0, min(u * w, w - 1)))
    py = int(max(0, min(v_north * h, h - 1)))
    
    val = ndvi.getpixel((px, py))
    print(f"{name} ({lat_deg}N, {lon_deg}E): lightness {val} (normalized {val/255.0:.3f})")

print("Sampling NDVI values at key locations...")
sample_coord("Sahara Desert", 23.0, 11.0)
sample_coord("Egypt (Desert)", 27.0, 28.0)
sample_coord("Ukraine (Plains)", 48.0, 31.0)
sample_coord("Texas (Plains/Scrub)", 33.0, -100.0)
sample_coord("Amazon (Jungle)", -3.0, -60.0)
sample_coord("Congo (Jungle)", 0.0, 25.0)
sample_coord("Germany (Forest)", 51.0, 10.0)
sample_coord("Siberia (Forest/Tundra)", 62.0, 100.0)
