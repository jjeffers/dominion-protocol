from PIL import Image

ndvi = Image.open('/home/jdjeffers/Documents/NDVI_84.bw.png').convert('L')
w, h = ndvi.size

# We will sample 64x32 grid to fit in terminal
out_h = 32
out_w = 64
step_y = h / out_h
step_x = w / out_w

print("NDVI Approximation:")
for y in range(out_h):
    row = ""
    for x in range(out_w):
        val = ndvi.getpixel((int(x * step_x), int(y * step_y)))
        if val > 150:
            row += "M"
        elif val > 80:
            row += "m"
        elif val > 16:
            row += "."
        else:
            row += " "
    print(f"{y:02d} | {row}")

# Let's do the SAME for ETOPO mask for comparison!
mask = Image.open('/home/jdjeffers/Documents/etopo-landmask.png').convert('L')
mw, mh = mask.size
step_my = mh / out_h
step_mx = mw / out_w

print("\nETOPO Approximation:")
for y in range(out_h):
    row = ""
    for x in range(out_w):
        val = mask.getpixel((int(x * step_mx), int(y * step_my)))
        if val > 128:
            row += "M"
        else:
            row += " "
    print(f"{y:02d} | {row}")

