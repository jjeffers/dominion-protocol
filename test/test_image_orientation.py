from PIL import Image

topo = Image.open('/home/jdjeffers/Documents/Topography.jpg').convert('L')
w, h = topo.size

# Check top row
top_row = [topo.getpixel((x, 0)) for x in range(0, w, 100)]
# Check bottom row
bottom_row = [topo.getpixel((x, h-1)) for x in range(0, w, 100)]

print("Top row avg:", sum(top_row)/len(top_row))
print("Bottom row avg:", sum(bottom_row)/len(bottom_row))

# Let's locate the brightest spot (usually Himalayas or Antarctica)
# Let's just find the max value row
row_maxes = []
for y in range(0, h, 10):
    row_vals = [topo.getpixel((x, y)) for x in range(0, w, 50)]
    row_maxes.append((y, max(row_vals)))

row_maxes.sort(key=lambda x: x[1], reverse=True)
print("Brightest rows:")
for i in range(5):
    print("y:", row_maxes[i][0], "val:", row_maxes[i][1])

