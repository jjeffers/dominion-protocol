from PIL import Image

ndvi = Image.open('/home/jdjeffers/Documents/NDVI_84.bw.png').convert('L')
mask = Image.open('/home/jdjeffers/Documents/etopo-landmask.png').convert('L')

nw, nh = ndvi.size
mw, mh = mask.size

# Sample a horizontal slice at V = 0.5 (Equator) with more resolution
print("U     | ETOPO  | NDVI_u  | NDVI_flip |")
print("--------------------------------------")
for u_step in range(0, 100, 2):
    u = u_step / 100.0  # 0.0 to 1.0 (West to East)
    
    # MASK uses direct U and V
    mask_x = int(u * mw)
    mask_y = int(0.5 * mh)
    mask_val = mask.getpixel((mask_x, mask_y))
    is_land = mask_val > 128
    
    # 1. Direct U mapping (Shifted East 1% based on previous test)
    ndvi_u_direct = (u + 0.01) % 1.0
    ndvi_x1 = int(ndvi_u_direct * nw)
    
    # 2. Flipped U mapping (Maybe it's reversed West/East?)
    # U=0 means West edge. If image is reversed, U=0 is East.
    ndvi_u_flip = ((1.0 - u) + 0.01) % 1.0
    ndvi_x2 = int(ndvi_u_flip * nw)
    
    # Equator v_base = 0.5
    # ndvi_v = (0.5 * 0.76) + 0.14 = 0.52
    # ndvi_v_north = 1.0 - 0.52 = 0.48
    ndvi_y = int(0.48 * (nh-1))
    
    val1 = ndvi.getpixel((ndvi_x1, ndvi_y))
    val2 = ndvi.getpixel((ndvi_x2, ndvi_y))
    
    print(f"{u:.2f}  |   {'L' if is_land else ' '}    |   {val1:3d}   |   {val2:3d}   |")
