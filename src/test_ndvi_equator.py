from PIL import Image

ndvi = Image.open('/home/jdjeffers/Documents/NDVI_84.bw.png').convert('L')
nw, nh = ndvi.size

print("Scanning for the Equator (brightest vegetation bands) at specific longitudes:")

# South America (Lon ~ -60) -> U ~ 0.33
# Africa (Lon ~ 25) -> U ~ 0.57
# Indonesia (Lon ~ 115) -> U ~ 0.82

def scan_column(name, u):
    x = int(u * nw)
    max_val = -1
    max_y = -1
    for y in range(nh):
        val = ndvi.getpixel((x, y))
        if val > max_val:
            max_val = val
            max_y = y
    
    # Let's print the top 3 brightest Y coordinates in this column to see the cluster
    vals = [(y, ndvi.getpixel((x, y))) for y in range(max_y-5, max_y+6) if 0 <= y < nh]
    print(f"{name} (U={u}): Max Y={max_y} (Val={max_val}). Range: {vals}")

scan_column("South America (Amazon)", 0.33)
scan_column("Africa (Congo)", 0.57)
scan_column("Indonesia", 0.82)
