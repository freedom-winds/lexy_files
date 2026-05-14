"""Finer color sampling. The design is DARK - navy + cyan accent."""
from PIL import Image
import os
from collections import Counter

src = 'f:/projects/lexy_files/design/windows'

def dominant(im, box, topn=8, min_count=50):
    c = im.crop(box)
    pixels = list(c.getdata())
    bucket = Counter()
    for p in pixels:
        r,g,b,a = (p + (255,))[:4]
        if a < 40: continue
        # bucket by /8 for finer resolution
        rr = (r//8)*8; gg = (g//8)*8; bb = (b//8)*8
        bucket[(rr,gg,bb)] += 1
    return [f'#{c[0]:02X}{c[1]:02X}{c[2]:02X} x{n}' for c,n in bucket.most_common(topn) if n >= min_count]

for f in ['home.png','transfer.png','devices.png','files.png']:
    print(f'\n====== {f} ======')
    im = Image.open(os.path.join(src, f)).convert('RGBA')
    W, H = im.size

    # For 1448x1149 devices: sidebar ends at ~90px, content starts
    # Sample very small specific rectangles
    samples = [
      ('page bg (content middle)',        (W//2-50, H//2-20, W//2+50, H//2+20)),
      ('sidebar bg (mid)',                (30, H//2, 60, H//2+30)),
      ('sidebar active pill',             (30, int(H*0.2), 60, int(H*0.22))),
      ('top bar bg',                      (W//2, 15, W//2+100, 25)),
      ('search bar bg',                   (int(W*0.40), 30, int(W*0.45), 38)),
      ('card bg (upper-mid)',             (int(W*0.45), int(H*0.35), int(W*0.50), int(H*0.37))),
      ('text primary sample',             (int(W*0.30), int(H*0.20), int(W*0.35), int(H*0.21))),
      ('button primary (bottom-right)',   (int(W*0.75), int(H*0.90), int(W*0.85), int(H*0.93))),
      ('icon area (hero left)',           (int(W*0.22), int(H*0.12), int(W*0.24), int(H*0.14))),
    ]
    for name, box in samples:
        print(f'  {name:35s} -> {dominant(im, box, 4, 5)}')
