from PIL import Image

mask = Image.open('/home/jdjeffers/Documents/etopo-landmask.png').convert('L')
ndvi = Image.open('/home/jdjeffers/Documents/NDVI_84.bw.png').convert('L')

mw, mh = mask.size
nw, nh = ndvi.size

print("Testing U Offsets for NDVI...")

v = 0.5  # Equator
mask_y = int(v * mh)
ndvi_y = int(0.48 * (nh-1))

u_points = [u/200.0 for u in range(200)] 

best_score = -1
best_offset = 0
best_is_flipped = False

# Try normal and flipped U mapping
for is_flipped in [False, True]:
    for off in range(-50, 50): # -50% to +50%
        u_off = off / 100.0
        score = 0
        
        for u in u_points:
            mask_val = mask.getpixel((int(u * mw), mask_y))
            is_land = mask_val > 128
            
            if is_flipped:
                ndvi_u = ((1.0 - u) + u_off) % 1.0
            else:
                ndvi_u = (u + u_off) % 1.0
                
            ndvi_x = min(int(ndvi_u * nw), nw - 1)
            ndvi_val = ndvi.getpixel((ndvi_x, ndvi_y))
            has_veg = ndvi_val > 10
            
            # Simple match scoring
            if (is_land and has_veg) or (not is_land and not has_veg):
                score += 1
            else:
                score -= 1
                
        if score > best_score:
            best_score = score
            best_offset = u_off
            best_is_flipped = is_flipped

print(f"Best Match Score: {best_score} / 200")
print(f"Is Flipped (1.0 - U): {best_is_flipped}")
print(f"Optimal U Offset: {best_offset}")
