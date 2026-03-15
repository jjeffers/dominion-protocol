from PIL import Image

ndvi = Image.open('/home/jdjeffers/Documents/NDVI_84.bw.png').convert('L')
mask = Image.open('/home/jdjeffers/Documents/etopo-landmask.png').convert('L')

nw, nh = ndvi.size
mw, mh = mask.size

# Sample a horizontal slice at V = 0.5 (Equator)
print("U     | Mask (Land?) | NDVI NorthUp | NDVI SouthUp")
print("--------------------------------------------------")
for u_step in range(0, 50, 1):
    u = u_step / 50.0  # 0.0 to 1.0 (West to East)
    
    # MASK uses direct U and V
    # Equator is exactly halfway V=0.5
    mask_x = int(u * mw)
    mask_y = int(0.5 * mh)
    mask_val = mask.getpixel((mask_x, mask_y))
    is_land = mask_val > 128
    
    # Let's say NDVI uses direct U.
    ndvi_x = int(u * nw)
    
    # Try North-Up (V=0.5 -> 0.5)
    ndvi_north_y = int((1.0 - 0.5) * (nh - 1))
    ndvi_north_val = ndvi.getpixel((ndvi_x, ndvi_north_y))
    
    print(f"{u:.2f}  | {'LAND ' if is_land else 'OCEAN'}  | NorthUp: {ndvi_north_val:3d}")
