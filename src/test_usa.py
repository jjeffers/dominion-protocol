from PIL import Image
import math

# Load images
ndvi = Image.open('/home/jdjeffers/Documents/NDVI_84.bw.png').convert('L')
topo = Image.open('/home/jdjeffers/Documents/Topography.jpg').convert('L')

usa_lat = 40.0 * math.pi / 180.0
usa_lon = -100.0 * math.pi / 180.0

# UV coordinates (using same math as QuadSphereBaker)
u = (usa_lon + math.pi) / (2.0 * math.pi)
u = 1.0 - u

v = (usa_lat + (math.pi / 2.0)) / math.pi
# ETOPO is NOT flipped in our current script (we removed v = 1.0 - v)
# Wait, let's check what pixel we're reading in NDVI and Topo

print(f"USA center u: {u:.3f}, v: {v:.3f}")

ndvi_w, ndvi_h = ndvi.size
topo_w, topo_h = topo.size

ndvi_px = int(u * ndvi_w)
ndvi_py = int(v * ndvi_h)
val = ndvi.getpixel((ndvi_px, ndvi_py))
print(f"NDVI pixel at {ndvi_px}, {ndvi_py}: {val} ({(val/255.0):.2f})")

topo_px = int(u * topo_w)
topo_py = int(v * topo_h)
val2 = topo.getpixel((topo_px, topo_py))
print(f"Topo pixel at {topo_px}, {topo_py}: {val2} ({(val2/255.0):.2f})")
