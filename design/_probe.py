from PIL import Image
import os
from collections import Counter

src = 'f:/projects/lexy_files/design/windows'

def dominant(im, box, topn=5):
    """Return top-n dominant colors (rounded to 8) in a crop."""
    c = im.crop(box)
    pixels = list(c.getdata())
    # Normalize alpha, round each channel to /16 for clustering
    bucket = Counter()
    for p in pixels:
        if len(p) == 4:
            r,g,b,a = p
        else:
            r,g,b = p; a = 255
        if a < 40: continue
        rr = (r//16)*16; gg = (g//16)*16; bb = (b//16)*16
        bucket[(rr,gg,bb)] += 1
    return [('#%02X%02X%02X' % c, n) for c,n in bucket.most_common(topn)]

for f in ['home.png','transfer.png','devices.png','files.png']:
    print('\n====', f, '====')
    im = Image.open(os.path.join(src, f)).convert('RGBA')
    W, H = im.size
    print('size', W, H)
    # Regions (L, T, R, B)
    regions = {
      'far-top-left (titlebar-ish)': (0, 0, 200, 40),
      'top-bar bg':                   (int(W*0.3), 0, int(W*0.7), 50),
      'left sidebar strip':           (0, int(H*0.1), 90, int(H*0.9)),
      'main content bg':              (int(W*0.4), int(H*0.5), int(W*0.6), int(H*0.6)),
      'hero-header zone':             (int(W*0.15), int(H*0.08), int(W*0.85), int(H*0.20)),
      'primary button area guess':    (int(W*0.70), int(H*0.20), int(W*0.85), int(H*0.28)),
      'card shadow zone':             (int(W*0.15), int(H*0.27), int(W*0.85), int(H*0.30)),
      'accent hero color':            (int(W*0.20), int(H*0.10), int(W*0.35), int(H*0.15)),
    }
    for name, box in regions.items():
        try:
            print(f'{name:40s} {box}  ->  {dominant(im, box, 5)}')
        except Exception as e:
            print(f'{name}: ERR {e}')
