"""Probe design layout - identify rectangles for sidebar, hero, cards, buttons.
Generate annotated overlay so we can see structure."""
from PIL import Image, ImageDraw, ImageFont
import os
from collections import Counter

src = 'f:/projects/lexy_files/design/windows'
out = 'f:/projects/lexy_files/design/crops'
os.makedirs(out, exist_ok=True)


def edge_scan_horizontal(im, y, threshold=20):
    """Walk left-to-right across row y, find color changes."""
    px = im.load()
    W, H = im.size
    edges = []
    prev = px[0, y][:3]
    for x in range(1, W):
        cur = px[x, y][:3]
        diff = max(abs(prev[i] - cur[i]) for i in range(3))
        if diff > threshold:
            edges.append((x, prev, cur))
        prev = cur
    return edges


def find_sidebar_width(im):
    """Find where sidebar bg ends. Sample a row in the middle."""
    px = im.load()
    W, H = im.size
    y = H // 2
    sidebar_color = px[5, y][:3]
    for x in range(1, min(400, W)):
        c = px[x, y][:3]
        diff = max(abs(c[i] - sidebar_color[i]) for i in range(3))
        if diff > 30:
            return x, sidebar_color, c
    return None, sidebar_color, None


def find_unique_colors(im, x_start, x_end, y_start, y_end, step=4, min_count=20):
    px = im.load()
    bucket = Counter()
    for y in range(y_start, y_end, step):
        for x in range(x_start, x_end, step):
            r, g, b = px[x, y][:3]
            rr = (r // 16) * 16
            gg = (g // 16) * 16
            bb = (b // 16) * 16
            bucket[(rr, gg, bb)] += 1
    return [(f'#{c[0]:02X}{c[1]:02X}{c[2]:02X}', n) for c, n in bucket.most_common(10) if n >= min_count]


for fn in ['home.png', 'transfer.png', 'devices.png', 'files.png']:
    print(f'\n========== {fn} ==========')
    im = Image.open(os.path.join(src, fn)).convert('RGBA')
    W, H = im.size
    print(f'size {W}x{H}')

    # Sidebar
    sw, sb_col, content_col = find_sidebar_width(im)
    print(f'sidebar width = {sw} ; sidebar bg = #{sb_col[0]:02X}{sb_col[1]:02X}{sb_col[2]:02X}')
    if content_col:
        print(f'content bg right of sidebar = #{content_col[0]:02X}{content_col[1]:02X}{content_col[2]:02X}')

    # Sample sidebar interior - look for active-state pill (cyan)
    print('\nSidebar palette (full):')
    for c, n in find_unique_colors(im, 0, sw or 80, 0, H, step=3, min_count=50):
        print(f'  {c}  x{n}')

    # Hero header zone (just below top bar)
    print('\nHero zone palette:')
    for c, n in find_unique_colors(im, sw or 80, W - 30, 80, 280, step=4, min_count=80):
        print(f'  {c}  x{n}')

    # Content zone
    print('\nContent zone palette:')
    for c, n in find_unique_colors(im, sw or 80, W - 30, 350, H - 100, step=6, min_count=200):
        print(f'  {c}  x{n}')

    # Edges across hero row
    print('\nEdges on row 200 (hero):')
    edges = edge_scan_horizontal(im, 200, threshold=40)
    for x, p, c in edges[:25]:
        print(f'  x={x:4d}  #{p[0]:02X}{p[1]:02X}{p[2]:02X} -> #{c[0]:02X}{c[1]:02X}{c[2]:02X}')

    print('\nEdges on row 50 (top bar):')
    edges = edge_scan_horizontal(im, 50, threshold=40)
    for x, p, c in edges[:20]:
        print(f'  x={x:4d}  #{p[0]:02X}{p[1]:02X}{p[2]:02X} -> #{c[0]:02X}{c[1]:02X}{c[2]:02X}')
