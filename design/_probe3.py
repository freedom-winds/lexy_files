"""Find exact cyan accent + card colors. Save crops for inspection."""
from PIL import Image
import os

src = 'f:/projects/lexy_files/design/windows'
out = 'f:/projects/lexy_files/design/crops'
os.makedirs(out, exist_ok=True)

# Export focus crops of key design regions
crops = {
    'home_topleft.png': ('home.png', (0, 0, 600, 300)),
    'home_sidebar.png': ('home.png', (0, 60, 260, 1000)),
    'home_hero.png':    ('home.png', (260, 80, 1623, 280)),
    'home_full.png':    ('home.png', (0, 0, 1623, 1061)),

    'transfer_topleft.png': ('transfer.png', (0, 0, 600, 300)),
    'transfer_hero.png':    ('transfer.png', (260, 80, 1585, 280)),
    'transfer_content.png': ('transfer.png', (260, 300, 1585, 900)),

    'devices_topleft.png': ('devices.png', (0, 0, 600, 300)),
    'devices_hero.png':    ('devices.png', (260, 80, 1448, 280)),
    'devices_cards.png':   ('devices.png', (260, 300, 1448, 1000)),

    'files_topleft.png': ('files.png', (0, 0, 600, 300)),
    'files_hero.png':    ('files.png', (260, 80, 1553, 280)),
    'files_list.png':    ('files.png', (260, 300, 1553, 1000)),
}

for name, (src_file, box) in crops.items():
    im = Image.open(os.path.join(src, src_file))
    im.crop(box).save(os.path.join(out, name))
    print(f'saved {name}')

# Sample exact pixels at known landmarks
print('\n=== EXACT PIXEL SAMPLES ===')
for f in ['home.png','transfer.png','devices.png','files.png']:
    im = Image.open(os.path.join(src, f)).convert('RGBA')
    W, H = im.size
    points = {
        'top-left pixel':         (5, 5),
        'sidebar mid':            (30, H//2),
        'sidebar below':          (30, int(H*0.85)),
        'page bg center':         (W//2, H//2),
        'page right edge':        (W-20, H//2),
        'card mid':               (int(W*0.5), int(H*0.5)),
        'hero top-left':          (int(W*0.22), int(H*0.12)),
        'hero top-right':         (int(W*0.80), int(H*0.12)),
    }
    print(f'\n--- {f} ({W}x{H}) ---')
    for name, (x,y) in points.items():
        r,g,b,a = im.getpixel((x,y))
        print(f'  {name:25s} ({x:4d},{y:4d}) = #{r:02X}{g:02X}{b:02X}')
