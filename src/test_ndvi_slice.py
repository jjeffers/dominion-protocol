from PIL import Image

ndvi = Image.open('/home/jdjeffers/Documents/NDVI_84.bw.png').convert('L')
mask = Image.open('/home/jdjeffers/Documents/etopo-landmask.png').convert('L')

nw, nh = ndvi.size
mw, mh = mask.size

# The mask is 4096x2048, NDVI is 1024x512.
# Let's sample a vertical slice at X = 512 (which is lon=0, prime meridian, passes through UK, France, Spain, Africa)
# We will print out the V coordinate, Mask value, and NDVI value.

print("V     | Mask (Land?) | NDVI Val")
print("---------------------------------")
for v_step in range(0, 50, 1):
    v = v_step / 50.0  # 0.0 to 1.0 (North to South)
    
    # ETOPO is South-Up, so V=v is correct (North is at V=1)
    mask_y = int(v * mh)
    mask_val = mask.getpixel((int(0.5 * mw), mask_y))
    is_land = mask_val > 128
    
    # NDVI is North-Up?
    ndvi_north_y = int((1.0 - v) * (nh - 1))
    ndvi_north_val = ndvi.getpixel((int(0.5 * nw), ndvi_north_y))
    
    # NDVI is South-Up?
    ndvi_south_y = int(v * (nh - 1))
    ndvi_south_val = ndvi.getpixel((int(0.5 * nw), ndvi_south_y))
    
    print(f"{v:.2f}  | {'LAND ' if is_land else 'OCEAN'}  | NorthUp: {ndvi_north_val:3d} | SouthUp: {ndvi_south_val:3d}")
