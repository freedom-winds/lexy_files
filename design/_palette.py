"""Extract palette from design.png - which contains the color swatches."""
from PIL import Image
import os
from collections import Counter

p = 'f:/projects/lexy_files/design/design.png'
if not os.path.exists(p):
    print('design.png not found!')
else:
    im = Image.open(p).convert('RGBA')
    W, H = im.size
    print(f'size {W}x{H}')

    # Grid-sample and keep unique saturated / distinct colors
    bucket = Counter()
    for y in range(0, H, 4):
        for x in range(0, W, 4):
            r,g,b,a = im.getpixel((x,y))
            if a < 40: continue
            # bucket by /8
            rr = (r//8)*8; gg = (g//8)*8; bb = (b//8)*8
            bucket[(rr,gg,bb)] += 1
    for (r,g,b), n in bucket.most_common(30):
        print(f'  #{r:02X}{g:02X}{b:02X}  x{n}')
