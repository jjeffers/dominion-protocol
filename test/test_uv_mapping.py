from PIL import Image

# Create a 256x256 image
img = Image.new('RGB', (256, 256))
pixels = img.load()
for y in range(256):
    for x in range(256):
        # Red increases left to right (U)
        # Green increases top to bottom (V)
        pixels[x, y] = (x, y, 0)

# Make corners distinct
# Top Left = Red=0, Green=0 (Black)
# Top Right = Red=255, Green=0 (Red)
# Bottom Left = Red=0, Green=255 (Green)
# Bottom Right = Red=255, Green=255 (Yellow)

# Write a 10x10 white square at Top Left (U=0, V=0)
for y in range(20):
    for x in range(20):
        pixels[x, y] = (255, 255, 255)

img.save('/home/jdjeffers/Documents/uv_test.png')
print("Generated uv_test.png")
