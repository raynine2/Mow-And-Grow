# The drawn boss-omen pictures (client/BossOmen; 30 Oct): omen_vignette.png (the screen's edges bleeding dark with
# glowing veins, the middle clear) and omen_lines_dark.png / omen_lines_light.png (manga speed lines for the roar's
# impact frames; the dark one is uploaded as omen_lines, at 1024 x 576). Run it in assets/fx/omen:
#   cd assets/fx/omen && python3 ../../../tools/omen_textures.py
import math, random
from PIL import Image, ImageDraw, ImageFilter, ImageChops
random.seed(7)
# 1. the omen vignette: blood-dark edges with glowing veins creeping in, the middle clear
W, H = 1024, 576
alpha = Image.new("L", (W, H), 0)
px = alpha.load()
for y in range(H):
    for x in range(W):
        dx = (x - W / 2) / (W / 2); dy = (y - H / 2) / (H / 2)
        d = math.sqrt(dx * dx * 0.85 + dy * dy * 1.0)
        t = min(1, max(0, (d - 0.55) / 0.6))
        t = t * t * (3 - 2 * t)
        px[x, y] = int(255 * (0.97 * t))
col = Image.new("RGB", (W, H), (0, 0, 0))
cp = col.load()
for y in range(H):
    for x in range(W):
        a = px[x, y] / 255
        # deep red in the ring, near black at the very edge
        r = int(110 * (1 - a) ** 0.6 * min(1, a * 3) + 12)
        cp[x, y] = (r, 0, int(r * 0.18))
# veins: branching cracks from the edges toward the middle
veins = Image.new("L", (W, H), 0)
dv = ImageDraw.Draw(veins)
def branch(x, y, ang, length, width, depth):
    for _ in range(int(length / 6)):
        nx = x + math.cos(ang) * 6; ny = y + math.sin(ang) * 6
        dv.line([(x, y), (nx, ny)], fill=255, width=max(1, int(width)))
        x, y = nx, ny
        ang += random.uniform(-0.35, 0.35)
        width *= 0.985
        if depth < 3 and random.random() < 0.06:
            branch(x, y, ang + random.choice([-1, 1]) * random.uniform(0.4, 0.9), length * 0.45, width * 0.7, depth + 1)
for i in range(22):
    side = i % 4
    if side == 0: x, y, ang = random.uniform(0, W), 0, math.pi / 2
    elif side == 1: x, y, ang = random.uniform(0, W), H, -math.pi / 2
    elif side == 2: x, y, ang = 0, random.uniform(0, H), 0
    else: x, y, ang = W, random.uniform(0, H), math.pi
    ang += random.uniform(-0.5, 0.5)
    branch(x, y, ang, random.uniform(120, 260), random.uniform(3, 6), 0)
glow = veins.filter(ImageFilter.GaussianBlur(6))
vein_rgb = Image.new("RGB", (W, H), (255, 40, 60))
col = Image.composite(vein_rgb, col, ImageChops.lighter(veins, glow.point(lambda v: int(v * 0.8))))
# veins only where the vignette has some alpha (they fade toward the clear middle)
va = ImageChops.multiply(ImageChops.lighter(veins, glow), alpha.point(lambda v: min(255, int(v * 1.6))))
alpha = ImageChops.lighter(alpha, va)
out = col.convert("RGBA"); out.putalpha(alpha)
out.save("omen_vignette.png")
# 2. manga speed lines for the impact frame: white wedges on black, the middle empty
W, H = 1280, 720
for name, bg, fg in (("omen_lines_dark.png", 0, 255), ("omen_lines_light.png", 255, 0)):
    random.seed(11)
    im = Image.new("L", (W * 2, H * 2), bg)
    d = ImageDraw.Draw(im)
    cx, cy = W, H
    R = math.hypot(W, H) * 1.05
    for i in range(170):
        a = random.uniform(0, math.tau)
        w = random.uniform(0.004, 0.022)
        rin = R * random.uniform(0.28, 0.55)
        p0 = (cx + math.cos(a) * rin, cy + math.sin(a) * rin)
        p1 = (cx + math.cos(a - w) * R, cy + math.sin(a - w) * R)
        p2 = (cx + math.cos(a + w) * R, cy + math.sin(a + w) * R)
        d.polygon([p0, p1, p2], fill=fg)
    im = im.resize((W, H), Image.LANCZOS)
    im.convert("RGB").save(name)
print("done")
