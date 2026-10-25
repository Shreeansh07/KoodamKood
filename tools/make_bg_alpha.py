#!/usr/bin/env python3
"""Makes colour-keyed copies (sky colour -> transparent) of a few Kenney Pixel
Platformer background tiles so they can be layered over a sky gradient.
Originals are kept; derived files are named tile_XXXX_a.png."""
import os
from PIL import Image
D = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "pixel_platformer", "bg")
for n in ("0008", "0009", "0010", "0011", "0012", "0014", "0015"):
    im = Image.open(os.path.join(D, f"tile_{n}.png")).convert("RGBA")
    key = im.getpixel((0, 0))
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            if px[x, y][:3] == key[:3]:
                px[x, y] = (0, 0, 0, 0)
    im.save(os.path.join(D, f"tile_{n}_a.png"))
    print(n, "keyed", key)
