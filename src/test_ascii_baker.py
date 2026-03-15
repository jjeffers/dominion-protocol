from PIL import Image
import math

ndvi = Image.open('/home/jdjeffers/Documents/NDVI_84.bw.png').convert('L')
mask = Image.open('/home/jdjeffers/Documents/etopo-landmask.png').convert('L')
topo = Image.open('/home/jdjeffers/Documents/Topography.jpg').convert('L')

# Let's do an ASCII visualization of ALL 3 layers at U=0 to 1 based EXACTLY on Baker logic.
out_h = 24
out_w = 48

print("=== FINAL ASCI ALIGNMENT COMP (R=100) ===")
print("Mask (ETOPO)")
for y in range(out_h):
    row = ""
    # Baker logic: lat goes from -PI/2 (South) to PI/2 (North)
    # y=0 is TOP of screen (North)
    # let's map y=0 to lat = PI/2, y=out_h to lat=-PI/2
    lat = math.pi/2 - (math.pi * y / float(out_h - 1))
    
    for x in range(out_w):
        # x=0 to out_w is lon from -PI (West) to PI (East)
        lon = -math.pi + (2*math.pi * x / float(out_w - 1))
        
        u = (lon + math.pi) / (2.0 * math.pi)
        u = 1.0 - u # Flip U East/West Mirror
        
        v_base = (lat + (math.pi / 2.0)) / math.pi
        v_etopo = v_base # South-up
        
        px = int(u * mask.width) % mask.width
        py = int(v_etopo * mask.height) % mask.height
        if mask.getpixel((px, py)) > 128: row += "M"
        else: row += " "
    print(f"{y:02d} | {row}")

print("\nVeg (NDVI)")
for y in range(out_h):
    row = ""
    lat = math.pi/2 - (math.pi * y / float(out_h - 1))
    for x in range(out_w):
        lon = -math.pi + (2*math.pi * x / float(out_w - 1))
        
        u = (lon + math.pi) / (2.0 * math.pi)
        u = 1.0 - u
        v_base = (lat + (math.pi / 2.0)) / math.pi
        
        ndvi_u = (u + 0.01) % 1.0
        ndvi_v = (v_base * 0.76) + 0.14
        ndvi_v_north = 1.0 - ndvi_v
        
        px = int(ndvi_u * ndvi.width) % ndvi.width
        py = int(ndvi_v_north * ndvi.height) % ndvi.height
        if ndvi.getpixel((px, py)) > 16: row += "V"
        else: row += " "
    print(f"{y:02d} | {row}")
