from PIL import Image

topo = Image.open('/home/jdjeffers/Documents/Topography.jpg').convert('L')
w, h = topo.size

print("Checking USA roughly (1115, 1342) vs (1115, 705)")
# Let's scan an area around (1115, 705)
print("Area around 705:")
vals1 = [topo.getpixel((x, 705)) for x in range(1000, 1200, 10)]
print(vals1)

print("Area around 1342:")
vals2 = [topo.getpixel((x, 1342)) for x in range(1000, 1200, 10)]
print(vals2)

