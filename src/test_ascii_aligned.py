from PIL import Image

ndvi = Image.open('/home/jdjeffers/Documents/NDVI_84.bw.png').convert('L')
mask = Image.open('/home/jdjeffers/Documents/etopo-landmask.png').convert('L')

nw, nh = ndvi.size
out_h, out_w = 32, 64

u_off = 0.01
v_s = 0.76
v_off = 0.14

print("Aligned NDVI Approximation:")
for y in range(out_h):
    row = ""
    # ETOPO is South-Up, so y=0 is South Pole, y=31 is North Pole.
    # v goes from 0 to 1 (South to North)
    v = y / float(out_h - 1)
    
    for x in range(out_w):
        u = x / float(out_w)
        
        ndvi_u = (u + u_off) % 1.0
        ndvi_v = (v * v_s) + v_off
        
        # NDVI is North-Up. v=1(N) -> Y=0
        ndvi_y = int((1.0 - ndvi_v) * (nh-1))
        
        if 0 <= ndvi_y < nh:
            val = ndvi.getpixel((int(ndvi_u * nw), ndvi_y))
            if val > 150: row += "M"
            elif val > 80: row += "m"
            elif val > 16: row += "."
            else: row += " "
        else:
            row += " "
            
    print(f"{y:02d} | {row}")

# Print ETOPO for comparison!
mw, mh = mask.size
print("\nETOPO Approximation (South-Up):")
for y in range(out_h):
    row = ""
    v = y / float(out_h - 1)
    for x in range(out_w):
        u = x / float(out_w)
        mask_val = mask.getpixel((int(u * mw), int(v * (mh-1))))
        if mask_val > 128:
            row += "M"
        else:
            row += " "
    print(f"{y:02d} | {row}")
