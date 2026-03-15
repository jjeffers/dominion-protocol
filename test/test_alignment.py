from PIL import Image

ndvi = Image.open('src/assets/NDVI_84.bw.png').convert('L')
topo = Image.open('src/assets/Topography.jpg').convert('L')

print("NDVI size:", ndvi.size)
print("Topo size:", topo.size)

# Scan a vertical column at u=0.272 (Florida's longitude) 
# to find where North America actually is!
u = 0.272
ndvi_x = int(u * ndvi.size[0])
topo_x = int(u * topo.size[0])

print(f"\nScanning column u={u} (Florida long)")
print("NDVI (North to South, v=0 to 1):")
ndvi_col = []
for v in [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]:
    y = int(v * ndvi.size[1])
    ndvi_col.append((v, ndvi.getpixel((ndvi_x, y))))
print(ndvi_col)

print("\nTopo (North to South, v=0 to 1):")
topo_col = []
for v in [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]:
    y = int(v * topo.size[1])
    topo_col.append((v, topo.getpixel((topo_x, y))))
print(topo_col)

# Also let's find the peak row means for both
ndvi_row_means = [sum(ndvi.getpixel((x, y)) for x in range(0, ndvi.size[0], 10)) / (ndvi.size[0]/10) for y in range(0, ndvi.size[1], 10)]
ndvi_brightest = ndvi_row_means.index(max(ndvi_row_means)) * 10
print(f"\nNDVI brightest row y={ndvi_brightest} (v={ndvi_brightest/ndvi.size[1]:.2f})")

topo_row_means = [sum(topo.getpixel((x, y)) for x in range(0, topo.size[0], 40)) / (topo.size[0]/40) for y in range(0, topo.size[1], 40)]
topo_brightest = topo_row_means.index(max(topo_row_means)) * 40
print(f"Topo brightest row y={topo_brightest} (v={topo_brightest/topo.size[1]:.2f})")
