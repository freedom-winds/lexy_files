from PIL import Image
import os
from collections import Counter, defaultdict

SRC="f:/projects/lexy_files/design/windows"
FILES=["home.png","transfer.png","devices.png","files.png"]

PAGE_BG=(5,20,36)
SURFACE=(18,33,49)
CYAN=(0,240,255)

def hx(rgb):
    return "#%02X%02X%02X" % tuple(rgb[:3])

def close(a,b,tol=4):
    return all(abs(a[i]-b[i])<=tol for i in range(3))

def dominant(im, box, topn=5, bucket=16):
    c=im.crop(box); pixels=c.getdata(); cnt=Counter()
    for p in pixels:
        r,g,b=p[:3]
        if len(p)==4 and p[3]<40: continue
        cnt[((r//bucket)*bucket,(g//bucket)*bucket,(b//bucket)*bucket)] += 1
    total=sum(cnt.values()) or 1
    return [(hx(col), n, round(100*n/total,1)) for col,n in cnt.most_common(topn)]

def find_sidebar_right(px, W, H):
    y=H//2
    for x in range(1,W):
        if close(px[x,y], PAGE_BG, 3):
            return x
    return None

def find_topbar_bottom(px, W, H, sidebar_x):
    x=min((sidebar_x or 80)+200, W-20)
    run_start=None
    for y in range(0,H):
        c=px[x,y]
        if close(c, PAGE_BG, 3):
            if run_start is None: run_start=y
            if y-run_start > 60:
                return run_start
        else:
            run_start=None
    return None

def find_hero_bottom(px, W, H, sidebar_x, topbar_y):
    if sidebar_x is None or topbar_y is None: return None
    x_left=sidebar_x+30; x_right=W-40
    for y in range(topbar_y+40, H-40):
        rc=Counter()
        for x in range(x_left, x_right, 8):
            c=px[x,y]
            rc[(c[0]//16*16,c[1]//16*16,c[2]//16*16)] += 1
        top_col, top_n = rc.most_common(1)[0]
        if top_n/sum(rc.values()) > 0.92:
            return y
    return None

def detect_cards(px, W, H, sidebar_x, start_y):
    cards=[]
    if sidebar_x is None: return cards
    x_left=sidebar_x+10; x_right=W-10
    y=start_y if start_y else 0
    rows=[]
    while y < H-10:
        run_best=0; run_cur=0; x=x_left
        while x < x_right:
            c=px[x,y]
            is_s = close(c, SURFACE, 8) or (20 < c[0] < 55 and 40 < c[2] < 100)
            if is_s:
                run_cur += 1
                if run_cur > run_best: run_best=run_cur
            else:
                run_cur=0
            x += 2
        rows.append((y, run_best*2))
        y += 6
    band_start=None
    for yy, rb in rows:
        if rb > 200:
            if band_start is None: band_start=yy
        else:
            if band_start is not None and yy-band_start > 30:
                cards.append((band_start, yy))
            band_start=None
    if band_start is not None:
        cards.append((band_start, rows[-1][0]))
    return cards

def find_cyan_regions(px, W, H):
    pts=[]
    for y in range(0,H,4):
        for x in range(0,W,4):
            r,g,b=px[x,y][:3]
            if g>150 and b>150 and r<80:
                pts.append((x,y))
    if not pts: return []
    grid=defaultdict(list); CELL=40
    for x,y in pts: grid[(x//CELL,y//CELL)].append((x,y))
    visited=set(); regions=[]
    for k in list(grid.keys()):
        if k in visited: continue
        stack=[k]; members=[]
        while stack:
            cur=stack.pop()
            if cur in visited: continue
            visited.add(cur)
            if cur in grid:
                members.extend(grid[cur])
                for dx in (-1,0,1):
                    for dy in (-1,0,1):
                        nk=(cur[0]+dx, cur[1]+dy)
                        if nk in grid and nk not in visited:
                            stack.append(nk)
        if len(members) < 5: continue
        xs=[m[0] for m in members]; ys=[m[1] for m in members]
        regions.append((min(xs),min(ys),max(xs),max(ys),len(members)))
    regions.sort(key=lambda r:-r[4])
    return regions

def find_sidebar_active(px, W, H, sidebar_x):
    if sidebar_x is None: return None
    rows=[]
    for y in range(0,H):
        count=0
        for x in range(0, sidebar_x, 3):
            r,g,b=px[x,y][:3]
            if g>180 and b>180 and r<60: count+=1
        rows.append(count)
    best=(0,0,0); cur_start=None; cur_total=0
    for y,c in enumerate(rows):
        if c >= 2:
            if cur_start is None: cur_start=y
            cur_total += c
        else:
            if cur_start is not None:
                if cur_total > best[0]: best=(cur_total, cur_start, y-1)
                cur_start=None; cur_total=0
    if cur_start is not None and cur_total > best[0]:
        best=(cur_total, cur_start, len(rows)-1)
    if best[0]==0: return None
    xs=[]
    for y in range(best[1], best[2]+1):
        for x in range(0, sidebar_x):
            r,g,b=px[x,y][:3]
            if g>180 and b>180 and r<60: xs.append(x)
    if not xs: return None
    return dict(y_start=best[1], y_end=best[2], x_min=min(xs), x_max=max(xs), height=best[2]-best[1]+1, width=max(xs)-min(xs)+1, pixel_count=best[0])

def text_density_rows(im, sidebar_x, topbar_y, row_h=40):
    px=im.load(); W,H=im.size
    x0=(sidebar_x or 0)+20; x1=W-20
    rows=[]; y=topbar_y or 0
    while y+row_h < H:
        edges=0
        for yy in range(y, y+row_h, 2):
            prev=px[x0,yy][:3]
            for x in range(x0+1, x1):
                cur=px[x,yy][:3]
                d=max(abs(prev[i]-cur[i]) for i in range(3))
                if d > 40: edges += 1
                prev=cur
        rows.append((y, y+row_h, edges))
        y += row_h
    return rows

def analyze(fn):
    path=os.path.join(SRC, fn)
    im=Image.open(path).convert("RGBA")
    W,H=im.size; px=im.load()
    print(chr(10)+"="*70)
    print("IMAGE:", fn, " size:", W, "x", H)
    print("="*70)
    sidebar_x=find_sidebar_right(px, W, H)
    print("sidebar_right_edge_x =", sidebar_x)
    topbar_y=find_topbar_bottom(px, W, H, sidebar_x)
    print("topbar_bottom_y     =", topbar_y)
    hero_y=find_hero_bottom(px, W, H, sidebar_x, topbar_y)
    print("hero_bottom_y       =", hero_y)
    print(chr(10)+"-- region palettes --")
    regions={}
    regions["sidebar_full"]=(0, 60, sidebar_x or 80, H-20)
    regions["sidebar_active"]=(0, int(H*0.10), sidebar_x or 80, int(H*0.22))
    regions["topbar"]=((sidebar_x or 80)+10, 0, W-10, topbar_y or 70)
    regions["hero"]=((sidebar_x or 80)+10, (topbar_y or 70), W-10, hero_y or ((topbar_y or 70)+200))
    regions["content"]=((sidebar_x or 80)+10, (hero_y or 400), W-10, H-20)
    regions["bottom_right"]=(int(W*0.70), int(H*0.85), W-10, H-20)
    for name, box in regions.items():
        if box[2]<=box[0] or box[3]<=box[1]: continue
        palette=dominant(im, box, 6, 16)
        print("  %-16s %s -> %s" % (name, box, palette))
    print(chr(10)+"-- detected card bands --")
    cards=detect_cards(px, W, H, sidebar_x, hero_y or topbar_y or 70)
    for i,(a,b) in enumerate(cards):
        print("  card band #%d  y=%d..%d  height=%d" % (i+1, a, b, b-a))
        cy=(a+b)//2; cx=((sidebar_x or 80)+W)//2; c=px[cx,cy][:3]
        print("      center (%d,%d) color = %s" % (cx, cy, hx(c)))
    print(chr(10)+"-- cyan clusters --")
    cyan=find_cyan_regions(px, W, H)
    for (x1,y1,x2,y2,n) in cyan[:12]:
        w=x2-x1; h=y2-y1; ratio=(w/h) if h else 0
        zone="sidebar" if (sidebar_x and x1<sidebar_x) else "content"
        print("  bbox=(%d,%d..%d,%d)  w=%d h=%d  ratio=%.2f  n=%d  zone=%s" % (x1,y1,x2,y2,w,h,ratio,n,zone))
    print(chr(10)+"-- sidebar active-state marker --")
    act=find_sidebar_active(px, W, H, sidebar_x)
    if act:
        print("  y=%d..%d (h=%d)  x=%d..%d (w=%d)  cyan_pixels=%d" % (act["y_start"], act["y_end"], act["height"], act["x_min"], act["x_max"], act["width"], act["pixel_count"]))
        if act["x_min"] < 10 and act["width"] < 8:
            print("  -> THIN VERTICAL ACCENT BAR on sidebar left edge")
        elif act["width"] > 40:
            print("  -> FULL-WIDTH PILL/FILL across sidebar row")
        else:
            print("  -> icon or small accent")
    else:
        print("  (none detected)")
    print(chr(10)+"-- text-density per 40px row (top 12) --")
    rows=text_density_rows(im, sidebar_x, topbar_y, 40)
    rows_sorted=sorted(rows, key=lambda r:-r[2])[:12]
    for (a,b,e) in sorted(rows_sorted):
        print("  y=%d..%d  edges=%d" % (a,b,e))
    print(chr(10)+"-- SUMMARY --")
    print("  sidebar_width     = %s px" % sidebar_x)
    print("  top_bar_height    = %s px" % topbar_y)
    print("  hero_bottom_y     = %s px" % hero_y)
    print("  background_color  = #051424")
    print("  surface_color     = #122131")
    print("  primary_accent    = #00F0FF")
    print("  text_primary      = ~#D0E0F0")
    print("  text_secondary    = ~#8B9BAE")
    return dict(file=fn, W=W, H=H, sidebar_x=sidebar_x, topbar_y=topbar_y, hero_y=hero_y, cards=cards, cyan=cyan[:8], active=act)

results={}
for fn in FILES:
    results[fn]=analyze(fn)

print(chr(10)+chr(10)+"================ CROSS-COMPARISON ================")
print("%-14s %-10s %-10s %-10s %-10s" % ("file","WxH","sidebar","topbar","hero_y"))
for fn, r in results.items():
    print("%-14s %dx%d  %-10s %-10s %-10s" % (fn, r["W"], r["H"], str(r["sidebar_x"]), str(r["topbar_y"]), str(r["hero_y"])))
