# Icons for MeeRevive list entries that have no app icon of their own (patches,
# settings, scripts). Same style as our app icons: the dark N9 squircle of the
# MeeRevive icon (EKG line removed) with a pale green line drawing.
# Usage: python3 component-icons.py <icon-source.png> <n9mask.png> <out-dir>
import sys, math, os
import numpy as np
from PIL import Image, ImageDraw

ICON, MASK, OUT = sys.argv[1:4]
COL = (226, 250, 207, 255)
S = 8                       # supersampling
N = 80 * S
W = 4.2 * S                 # stroke width (80 px icon: about 4 px, like the app icons)

# background: smyhu's source of the MeeRevive icon (art/icon-source.png) with the
# EKG line painted out (row-wise interpolation, as in icon.py), fitted like the icon
from PIL import ImageFilter
src = np.asarray(Image.open(ICON).convert('RGB')).astype(float)
r, g, b = src[..., 0], src[..., 1], src[..., 2]
m = Image.fromarray((((g > 60) & (g - r > 6)) * 255).astype('uint8')).filter(ImageFilter.MaxFilter(15))
m = np.asarray(m) > 0
xs = np.arange(src.shape[1])
for y in range(src.shape[0]):
    row = m[y]
    if row.any() and (~row).sum() > 2:
        for c in range(3):
            src[y, row, c] = np.interp(xs[row], xs[~row], src[y, ~row, c])
BG = Image.fromarray(src.clip(0, 255).astype('uint8')).crop((12, 6, 1242, 1245)).resize((80, 80), Image.LANCZOS).convert('RGBA')
mask = Image.open(MASK).convert('L').resize((80, 80))

def canvas():
    img = Image.new('L', (N, N), 0)
    return img, ImageDraw.Draw(img)

def P(x, y):
    return (x * S, y * S)

def line(d, pts, w=W):
    d.line([P(*p) for p in pts], fill=255, width=int(w), joint='curve')
    for p in (pts[0], pts[-1]):
        x, y = P(*p); d.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=255)

def circle(d, cx, cy, r, w=W, fill=False):
    x, y = P(cx, cy)
    box = (x - r * S, y - r * S, x + r * S, y + r * S)
    if fill: d.ellipse(box, fill=255)
    else: d.ellipse(box, outline=255, width=int(w))

def rrect(d, x0, y0, x1, y1, r, w=W):
    d.rounded_rectangle((x0 * S, y0 * S, x1 * S, y1 * S), radius=r * S, outline=255, width=int(w))

def gear(d):
    cx, cy, ro, ri, teeth = 40, 40, 22, 16.5, 8
    pts = []
    for i in range(teeth * 4):
        ang = 2 * math.pi * i / (teeth * 4) + math.pi / (teeth * 4)
        r = ro if (i % 4) in (1, 2) else ri
        pts.append((cx + r * math.cos(ang), cy + r * math.sin(ang)))
    pts.append(pts[0])
    d.line([P(*p) for p in pts], fill=255, width=int(W), joint='curve')
    circle(d, cx, cy, 7)

def lock(d):
    rrect(d, 23, 37, 57, 61, 4)
    d.arc((29 * S, 18 * S, 51 * S, 44 * S), 180, 360, fill=255, width=int(W))
    line(d, [(29, 31), (29, 37)]); line(d, [(51, 31), (51, 37)])
    circle(d, 40, 47, 3, fill=True); line(d, [(40, 48), (40, 54)])

def smiley(d):
    circle(d, 40, 40, 22)
    circle(d, 32, 34, 2.8, fill=True); circle(d, 48, 34, 2.8, fill=True)
    d.arc((28 * S, 30 * S, 52 * S, 52 * S), 25, 155, fill=255, width=int(W))

def picture(d):
    rrect(d, 17, 22, 63, 58, 4)
    line(d, [(21, 53), (34, 38), (43, 47), (50, 41), (59, 51)])
    circle(d, 50, 31, 3.5, fill=True)

def globe(d):
    circle(d, 40, 40, 22)
    d.ellipse((31 * S, 18 * S, 49 * S, 62 * S), outline=255, width=int(W * 0.8))
    line(d, [(18, 40), (62, 40)], W * 0.8)
    d.arc((22 * S, 2 * S, 58 * S, 34 * S), 40, 140, fill=255, width=int(W * 0.8))
    d.arc((22 * S, 46 * S, 58 * S, 78 * S), 220, 320, fill=255, width=int(W * 0.8))

def document(d):
    d.line([P(25, 17), P(47, 17), P(57, 27), P(57, 63), P(25, 63), P(25, 17)], fill=255, width=int(W), joint='curve')
    line(d, [(47, 18), (47, 27), (56, 27)])
    for y in (37, 45, 53):
        line(d, [(32, y), (50, y)], W * 0.8)

def weather(d):
    for i in range(8):
        ang = 2 * math.pi * i / 8
        line(d, [(48 + 11 * math.cos(ang), 30 + 11 * math.sin(ang)), (48 + 15 * math.cos(ang), 30 + 15 * math.sin(ang))], W * 0.8)
    circle(d, 48, 30, 6.5)
    # cloud in front of the sun
    cl = Image.new('L', (N, N), 0); c = ImageDraw.Draw(cl)
    for cx, cy, r in ((27, 48, 9), (38, 42, 11), (49, 48, 9)):
        circle(c, cx, cy, r, fill=True)
    c.rectangle((27 * S, 48 * S, 49 * S, 57 * S), fill=255)
    return cl

def packages(d):   # apt mirrors: box with arrow down
    d.line([P(18, 32), P(40, 22), P(62, 32), P(62, 54), P(40, 64), P(18, 54), P(18, 32)], fill=255, width=int(W), joint='curve')
    line(d, [(18, 32), (40, 42), (62, 32)]); line(d, [(40, 42), (40, 64)])

GLYPHS = {'settings': gear, 'lock': lock, 'emoji': smiley, 'image': picture,
          'browser': globe, 'document': document, 'weather': weather, 'packages': packages}

os.makedirs(OUT, exist_ok=True)
for name, fn in GLYPHS.items():
    img, d = canvas()
    cut = fn(d)
    alpha = img.resize((80, 80), Image.LANCZOS)
    icon = BG.copy()
    if cut is not None:          # cloud: dark fill hides the sun behind it, then outline
        cm = cut.resize((80, 80), Image.LANCZOS)
        icon.paste(BG, (0, 0), cm)
        alpha = Image.fromarray(np.where(np.asarray(cm) > 0, 0, np.asarray(alpha)).astype('uint8'))
        o = Image.new('L', (N, N), 0); od = ImageDraw.Draw(o)
        edge = cut.copy()
        from PIL import ImageFilter
        ring = Image.fromarray(((np.asarray(cut.filter(ImageFilter.MaxFilter(int(W) | 1))) > 0) & ~(np.asarray(cut) > 0)).astype('uint8') * 255)
        alpha = Image.fromarray(np.maximum(np.asarray(alpha), np.asarray(ring.resize((80, 80), Image.LANCZOS))))
    layer = Image.new('RGBA', (80, 80), COL)
    icon.paste(layer, (0, 0), alpha)
    icon.putalpha(Image.fromarray(np.minimum(np.asarray(icon.split()[3]), np.asarray(mask))))
    icon.save(os.path.join(OUT, name + '.png'))
print('ok', sorted(GLYPHS))
