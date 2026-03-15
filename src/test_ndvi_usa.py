from PIL import Image
import math

# Load images
ndvi = Image.open('/home/jdjeffers/Documents/NDVI_84.bw.png').convert('L')
topo = Image.open('/home/jdjeffers/Documents/Topography.jpg').convert('L')

print("NDVI Size:", ndvi.size)
print("Topo Size:", topo.size)

# Sample Florida roughly
# Lat ~28 N, Lon ~-82 W
usa_lat = 28.0 * math.pi / 180.0
usa_lon = -82.0 * math.pi / 180.0

u = (usa_lon + math.pi) / (2.0 * math.pi)
v_normal = (usa_lat + (math.pi / 2.0)) / math.pi
v_flipped = 1.0 - v_normal

print(f"\nFlorida U: {u:.4f}")
print(f"Florida V (Normal): {v_normal:.4f}")
print(f"Florida V (Flipped): {v_flipped:.4f}")

def check_pixel(img, name, u_val, v_val):
    w, h = img.size
    px = int(u_val * w)
    py = int(v_val * h)
    val = img.getpixel((px, py))
    print(f"{name} at ({px}, {py}): {val} ({(val/255.0):.2f})")

check_pixel(ndvi, "NDVI (Normal V)", u, v_normal)
check_pixel(ndvi, "NDVI (Flipped V)", u, v_flipped)
check_pixel(topo, "Topo (Normal V)", u, v_normal)
check_pixel(topo, "Topo (Flipped V)", u, v_flipped)

# Let's also check the actual image pixel at 0,0
print(f"\nNDVI 0,0: {ndvi.getpixel((0,0))}")
print(f"Topo 0,0: {topo.getpixel((0,0))}")

