from PIL import Image
import math

print("Loading images...")
ndvi = Image.open('/home/jdjeffers/Documents/NDVI_84.bw.png').convert('L')
mask = Image.open('/home/jdjeffers/Documents/etopo-landmask.png').convert('L')

nw, nh = ndvi.size
mw, mh = mask.size

# We want to find the best (u_offset, v_offset, v_scale) for NDVI
# such that when we sample NDVI at (u, v), we hit vegetation if and only if MASK is LAND at (u, v).
# MASK is South-Up, centered on Prime Meridian.
# If u = 0.5, v = 0.5 (Equator, Prime Meridian), Mask(0.5, 0.5)

# To speed up, we will sample a grid of u, v
u_points = [u/100.0 for u in range(100)]
v_points = [v/100.0 for v in range(10, 90)] # Skip pure poles

best_score = -1
best_params = None

print("Optimizing alignment parameters...")
# NDVI is North-Up.
# u_ndvi = fract(u + u_off)
# v_ndvi_north = (v * v_scale) + v_off
# ndvi_y = int((1.0 - v_ndvi_north) * nh)  <-- wait, if v is 0..1 (N to S), North-Up means v=0 is Y=0.
# Actually, ETOPO is South-Up. So v=0 is South Pole. v=1 is North Pole.
# Let's say v=0.0 is South, v=1.0 is North.
# NDVI is North-Up. So v=0 (South) should map to Y=nh. v=1 (North) should map to Y=0.
# A standard North-Up maps ETOPO's 'v' as: ndvi_y = int(v * nh) (since v=1 is North, v=0 is South... wait.)

# Let's be explicit:
# ETOPO: (px, py) where x goes West->East, y goes South->North
# So py=0 is SOUTH POLE. py=mh is NORTH POLE.
# Let's verify: In ASCII, ETOPO y=0 has MMM. So South-Up means y=0 is SOUTH POLE.
# NDVI: North-Up. py=0 is NORTH POLE. py=nh is SOUTH POLE.

# We will iterate through reasonable offsets.
for u_off in range(-20, 20, 1): # Shift -20% to +20%
    u_o = u_off / 100.0
    for v_scale_int in range(70, 100, 2): # Scale of Y axis (since poles might be cropped)
        v_s = v_scale_int / 100.0
        for v_off_int in range(-20, 20, 2): # Offset of Y axis
            v_o = v_off_int / 100.0
            
            score = 0
            for u in u_points:
                for v in v_points: # v=0 is South, v=1 is North
                    mask_is_land = mask.getpixel((int(u*mw), int(v*mh))) > 128
                    
                    ndvi_u = (u + u_o) % 1.0
                    ndvi_v = (v * v_s) + v_o # Assuming v is standard 0(S) to 1(N). NDVI is North-Up, so v=1(N) -> Y=0.
                    
                    # If NDVI is North-Up, y = (1.0 - ndvi_v) * nh
                    ndvi_y = int((1.0 - ndvi_v) * (nh-1))
                    
                    if 0 <= ndvi_y < nh:
                        ndvi_val = ndvi.getpixel((int(ndvi_u*nw), ndvi_y))
                        ndvi_is_land = ndvi_val > 10 # Any vegetation vs no vegetation
                        
                        if mask_is_land and ndvi_is_land:
                            score += 1
                        elif not mask_is_land and not ndvi_is_land:
                            score += 1
                        else:
                            score -= 1 # Penalty for mismatch
            
            if score > best_score:
                best_score = score
                best_params = (u_o, v_s, v_o)

print(f"Best score: {best_score}")
print(f"Params (U_offset, V_scale, V_offset): {best_params}")
