from PIL import Image

ndvi = Image.open('/home/jdjeffers/Documents/NDVI_84.bw.png').convert('L')
topo = Image.open('/home/jdjeffers/Documents/Topography.jpg').convert('L')
mask = Image.open('/home/jdjeffers/Documents/etopo-landmask.png').convert('L')

def find_bounds(img, threshold):
    w, h = img.size
    min_x, max_x = w, 0
    min_y, max_y = h, 0
    # Sample every 10th pixel for speed
    for y in range(0, h, 10):
        for x in range(0, w, 10):
            if img.getpixel((x, y)) > threshold:
                min_x = min(min_x, x)
                max_x = max(max_x, x)
                min_y = min(min_y, y)
                max_y = max(max_y, y)
    return min_x, max_x, min_y, max_y

print("NDVI bounds (>16):", find_bounds(ndvi, 16))
print("Mask bounds (>128):", find_bounds(mask, 128))
