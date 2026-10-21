"""Every model in the game, as voxel shapes. Each function returns (voxels, palette, voxel_size_in_studs).
voxels: {(x, y, z): palette_index}, y is up. Colours follow the areas in src/shared/Zones.luau and
src/server/GrassStyle.luau so the meshes sit in the same world as the code-built parts."""
import math
import random

from kit import ball, box, cylinder


def _rng(seed):
    return random.Random(seed)


def _lift(c, k, add=0):
    return tuple(max(0, min(255, int(v * k + add))) for v in c)


def _light_tops(vox, first, last):
    """A leaf voxel with open sky above it gets one shade lighter: sunlit tops, like the reference trees."""
    for p, ci in list(vox.items()):
        if first <= ci < last and (p[0], p[1] + 1, p[2]) not in vox:
            vox[p] = ci + 1


# ---------------------------------------------------------------------------------------------------------------
# area colours
# ---------------------------------------------------------------------------------------------------------------
LEAVES = {
    "meadow": [(28, 92, 50), (40, 124, 58), (66, 154, 64), (118, 186, 78)],
    "wheat": [(184, 92, 30), (222, 130, 40), (244, 168, 56), (255, 206, 96)],
    "blossom": [(214, 100, 150), (246, 144, 190), (255, 184, 216), (255, 226, 240)],
    "swamp": [(40, 70, 30), (58, 96, 40), (82, 124, 52), (122, 156, 70)],
    "isles": [(110, 70, 200), (150, 110, 240), (190, 150, 255), (120, 236, 255)],
}
PINE = {
    "pine": [(18, 78, 58), (28, 104, 76), (44, 132, 92), (78, 164, 112)],
    "frost": [(52, 96, 128), (70, 122, 156), (96, 150, 182), (250, 252, 255)],
}
TRUNKS = {
    "meadow": [(88, 50, 34), (116, 68, 44), (142, 88, 58)],
    "wheat": [(92, 54, 36), (120, 72, 46), (148, 92, 60)],
    "blossom": [(86, 52, 50), (112, 70, 64), (136, 90, 80)],
    "pine": [(72, 46, 34), (96, 62, 44), (120, 80, 56)],
    "swamp": [(64, 50, 42), (84, 66, 54), (104, 84, 66)],
    "frost": [(80, 70, 70), (104, 92, 92), (130, 118, 118)],
    "ember": [(30, 24, 28), (44, 34, 40), (62, 50, 56)],
    "isles": [(90, 70, 120), (116, 92, 150), (142, 116, 176)],
}
ROCK = {
    "meadow": [(96, 100, 110), (120, 124, 134), (146, 150, 160), (70, 150, 66)],
    "wheat": [(132, 104, 84), (158, 128, 102), (184, 154, 126), (214, 170, 70)],
    "blossom": [(120, 112, 124), (146, 138, 150), (172, 164, 176), (255, 190, 220)],
    "pine": [(84, 92, 96), (106, 114, 118), (130, 138, 142), (50, 120, 84)],
    "swamp": [(70, 76, 64), (90, 96, 82), (112, 118, 100), (96, 130, 56)],
    "frost": [(120, 150, 180), (150, 180, 210), (186, 212, 236), (250, 252, 255)],
    "ember": [(34, 28, 32), (50, 42, 48), (68, 58, 64), (255, 110, 40)],
    "isles": [(84, 70, 130), (108, 92, 160), (134, 116, 190), (120, 236, 255)],
}
# grass: shades, an optional head colour (wheat ears, flowers, cattails, glowing tips)
GRASS = {
    "meadow": ([(48, 160, 64), (62, 180, 74), (38, 140, 58)], None),
    "wheat": ([(232, 176, 58), (246, 196, 80), (214, 150, 44)], (255, 232, 150)),
    "blossom": ([(86, 182, 96), (70, 160, 84)], (255, 140, 200)),
    "pine": ([(40, 150, 110), (54, 170, 124), (30, 126, 94)], None),
    "swamp": ([(110, 146, 58), (92, 128, 50)], (110, 70, 50)),
    "frost": ([(244, 250, 255), (220, 238, 255), (200, 226, 250)], None),
    "ember": ([(64, 52, 58), (80, 64, 70)], (255, 120, 40)),
    "isles": ([(180, 140, 255), (150, 110, 240)], (120, 240, 255)),
}
AREAS = ["meadow", "wheat", "blossom", "pine", "swamp", "frost", "ember", "isles"]


# ---------------------------------------------------------------------------------------------------------------
# trees
# ---------------------------------------------------------------------------------------------------------------
def round_tree(seed=1, area="meadow", scale=1.0):
    """Big round tree: thick trunk with roots and branches, a canopy of overlapping voxel balls, dark below and
    sunlit on top."""
    R = _rng(seed)
    pal = TRUNKS[area] + LEAVES[area]
    vox = {}
    H = int(13 * scale)

    def bark(p):
        x, y, z = p
        return 1 if (x + y * 2 + z) % 3 else (0 if (x * 7 + y) % 5 == 0 else 2)

    box(vox, (-1, 0, -1), (1, H, 1), bark)
    box(vox, (-2, 0, -1), (2, 1, 1), bark)
    box(vox, (-1, 0, -2), (1, 1, 2), bark)
    for dx, dz in ((3, 0), (-3, 0), (0, 3), (0, -3)):
        vox[(dx, 0, dz)] = 0
    for dx, dz in ((1, 0), (-1, 1), (0, -1)):
        for k in range(1, 5):
            vox[(dx * (1 + k), H - 4 + k, dz * (1 + k))] = 1
            vox[(dx * (1 + k), H - 5 + k, dz * (1 + k))] = 0
    top = (0, H + int(4 * scale), 0)
    centres = [(top, 6.2 * scale)]
    n = 6 if scale < 1.3 else 8
    for k in range(n):
        a = k / n * math.pi * 2 + R.uniform(-0.4, 0.4)
        d = R.uniform(5, 6.5) * scale
        centres.append(((int(round(math.cos(a) * d)), top[1] + R.randint(-3, 2), int(round(math.sin(a) * d))), R.uniform(3.8, 4.8) * scale))
    centres.append(((0, top[1] + int(5 * scale), 0), 4.2 * scale))
    lo = min(c[1] - r for c, r in centres)
    hi = max(c[1] + r for c, r in centres)

    def leaf(p, local, r):
        t = (p[1] - lo) / (hi - lo) + (local[1] / r) * 0.18 + R.uniform(-0.12, 0.12)
        return 6 if t > 0.8 else 5 if t > 0.52 else 4 if t > 0.26 else 3

    for c, r in centres:
        ball(vox, c, r, leaf)
    _light_tops(vox, 3, 6)
    return vox, pal, 1.6


def pine_tree(seed=1, area="pine", scale=1.0):
    """Layered pine: stacked studded discs getting smaller to a point, each layer's rim drooping one voxel. Frost
    pines get snow on every layer."""
    R = _rng(seed)
    pal = TRUNKS[area] + PINE[area]
    snow = area == "frost"
    vox = {}
    H = int(6 * scale)
    box(vox, (-1, 0, -1), (1, H + 4, 1), lambda p: 1 if (p[1] + p[0]) % 3 else 0)
    y = H
    layers = int(7 * scale) + 1
    for k in range(layers):
        r = (7.5 - k * 7.0 / layers) * scale ** 0.5 * (1.0 if k else 1.05)
        thick = 3
        for x in range(-int(r) - 1, int(r) + 2):
            for z in range(-int(r) - 1, int(r) + 2):
                d = math.sqrt(x * x + z * z)
                if d > r:
                    continue
                edge = d > r - 1.4
                y0 = y - (1 if edge else 0)
                for t in range(thick - (1 if edge else 0)):
                    yy = y0 + t
                    shade = 3 if t == 0 else 4 if t == 1 else 5
                    if R.random() < 0.15:
                        shade = max(3, shade - 1)
                    vox[(x, yy, z)] = shade
                top_y = y0 + thick - (1 if edge else 0)
                if snow and (d < r - 2.2 or R.random() < 0.35):
                    vox[(x, top_y, z)] = 6
                elif not snow and d < r - 1 and R.random() < 0.35:
                    vox[(x, top_y - 1, z)] = 6
        y += 2
    for t in range(3):
        vox[(0, y + t, 0)] = 6 if snow else 5
    return vox, pal, 1.6


def dead_tree(seed=1, area="ember", scale=1.0):
    """Ember area: a charred, twisted trunk with bare branches ending in glowing tips."""
    R = _rng(seed)
    pal = TRUNKS[area] + [(255, 110, 30), (255, 170, 60)]
    vox = {}
    H = int(16 * scale)
    x = z = 0
    for y in range(H):
        if y > 4 and R.random() < 0.18:
            x += R.choice((-1, 1))
        if y > 4 and R.random() < 0.18:
            z += R.choice((-1, 1))
        w = 1 if y > H * 0.6 else 2 if y > 2 else 3
        box(vox, (x - w // 2 - (1 if w == 3 else 0), y, z - w // 2 - (1 if w == 3 else 0)), (x + w // 2, y, z + w // 2), lambda p: R.choice((0, 1, 1, 2)))
    tips = [(x, H, z)]
    for k in range(5):
        a = k / 5 * math.pi * 2 + R.uniform(-0.3, 0.3)
        sy = int(H * R.uniform(0.45, 0.85))
        bx, by, bz = 0, sy, 0
        for s in range(int(R.uniform(4, 7) * scale)):
            bx = int(round(math.cos(a) * s))
            bz = int(round(math.sin(a) * s))
            by = sy + s // 2
            vox[(bx, by, bz)] = 1
        tips.append((bx, by + 1, bz))
    for (tx, ty, tz) in tips:
        box(vox, (tx, ty, tz), (tx, ty + 1, tz), 3)
        vox[(tx, ty + 2, tz)] = 4
    return vox, pal, 1.6


def crystal_tree(seed=1, area="isles", scale=1.0):
    """Isles: a cluster of tall crystal shards on a rocky foot."""
    R = _rng(seed)
    pal = ROCK[area][:3] + [(150, 110, 240), (190, 150, 255), (120, 236, 255), (220, 250, 255)]
    vox = {}
    ball(vox, (0, 0, 0), 3.5, lambda p, l, r: R.choice((0, 1, 1, 2)))
    for p in [p for p in vox if p[1] < 0]:
        del vox[p]
    for k in range(6):
        a = k / 6 * math.pi * 2 + R.uniform(-0.3, 0.3)
        d = 0 if k == 0 else R.uniform(1.5, 3)
        h = int((18 if k == 0 else R.uniform(8, 14)) * scale)
        lean = R.uniform(-0.15, 0.15)
        cx, cz = math.cos(a) * d, math.sin(a) * d
        ci = 5 if k % 2 == 0 else 3
        for y in range(h):
            w = 1.6 if y < h - 3 else 0.8 if y < h - 1 else 0.3
            x0 = cx + math.cos(a) * lean * y
            z0 = cz + math.sin(a) * lean * y
            for x in range(int(x0 - 2), int(x0 + 3)):
                for z in range(int(z0 - 2), int(z0 + 3)):
                    if (x - x0) ** 2 + (z - z0) ** 2 <= w * w:
                        vox[(x, y + 2, z)] = 6 if y >= h - 2 else (ci if (x + z) % 2 else ci + 1)
    return vox, pal, 1.6


def mushroom_tree(seed=1, area="swamp", scale=1.0):
    """Swamp: a giant toadstool, a cream stem and a broad purple cap with white spots."""
    R = _rng(seed)
    pal = [(214, 200, 176), (236, 224, 200), (120, 54, 170), (150, 70, 200), (176, 100, 226), (255, 255, 255)]
    vox = {}
    H = int(14 * scale)
    for y in range(H):
        r = (2.4 if y > 2 else 3.2) * scale ** 0.8 + (0.4 if scale > 1 else 0)
        cylinder(vox, (0, 0), r, y, y, lambda p: 1 if (p[0] + p[2] + p[1]) % 4 else 0)
    R2 = 8 * scale
    for k in range(int(5 * scale) + 1):
        r = R2 - k * k * 0.5 * (1 / scale)
        if r < 1:
            break
        cylinder(vox, (0, 0), r, H + k, H + k, lambda p: 2 if k == 0 else 3 if k < 3 else 4)
    for x, y, z in list(vox):
        if y >= H + 1 and (x, y + 1, z) not in vox and R.random() < 0.12:
            vox[(x, y, z)] = 5
    return vox, pal, 1.6


def tree(area, seed=1, scale=1.0):
    if area in PINE:
        return pine_tree(seed, area, scale)
    if area == "ember":
        return dead_tree(seed, area, scale)
    if area == "isles":
        return crystal_tree(seed, area, scale)
    if area == "swamp" and seed % 2 == 0:
        return mushroom_tree(seed, area, scale)
    return round_tree(seed, area, scale)


# ---------------------------------------------------------------------------------------------------------------
# bushes, rocks, grass
# ---------------------------------------------------------------------------------------------------------------
def bush(seed=1, area="meadow"):
    R = _rng(seed)
    leaves = LEAVES.get(area) or PINE.get(area) or [(46, 36, 42), (60, 46, 52), (76, 60, 66), (255, 120, 40)]
    pal = list(leaves)
    vox = {}
    centres = [((0, 0, 0), 4.2)] + [((R.randint(-3, 3), R.randint(-1, 1), R.randint(-3, 3)), R.uniform(2.6, 3.4)) for _ in range(3)]

    def leaf(p, local, r):
        t = (p[1] + 1) / 6 + R.uniform(-0.15, 0.15)
        return 2 if t > 0.55 else 1 if t > 0.2 else 0

    for c, r in centres:
        ball(vox, c, r, leaf)
    for p in [p for p in vox if p[1] < 0]:
        del vox[p]
    _light_tops(vox, 0, 3)
    if area in ("blossom", "meadow"):
        flower = (255, 240, 120) if area == "meadow" else (255, 255, 255)
        pal.append(flower)
        for p in list(vox):
            if (p[0], p[1] + 1, p[2]) not in vox and R.random() < 0.08:
                vox[(p[0], p[1] + 1, p[2])] = len(pal) - 1
    return vox, pal, 1.0


def rock(seed=1, area="meadow", big=False):
    """A chunky boulder: three greys in rough bands, moss/snow/glow on top."""
    R = _rng(seed)
    pal = ROCK[area]
    vox = {}
    r0 = 5.5 if big else 3.5
    centres = [((0, 0, 0), r0)] + [((R.randint(-3, 3), R.randint(-1, 2), R.randint(-3, 3)), r0 * R.uniform(0.55, 0.8)) for _ in range(3)]
    for c, r in centres:
        for x in range(-int(r) - 1, int(r) + 2):
            for y in range(-int(r) - 1, int(r) + 2):
                for z in range(-int(r) - 1, int(r) + 2):
                    # squashed, faceted: a superellipse looks chiselled rather than round
                    if abs(x) ** 2.6 + abs(y * 1.25) ** 2.6 + abs(z) ** 2.6 <= r ** 2.6:
                        p = (c[0] + x, c[1] + y, c[2] + z)
                        vox[p] = R.choice((0, 1, 1, 2)) if (p[1] + R.randint(0, 1)) % 3 else 1
    for p in [p for p in vox if p[1] < -1]:
        del vox[p]
    for p in list(vox):
        if (p[0], p[1] + 1, p[2]) not in vox and R.random() < 0.6:
            vox[p] = 3
    return vox, pal, 1.2


def clump(seed=1, area="meadow", stubble=False):
    """A grass clump: thin brick blades with gaps between them, tallest in the middle, each blade's tip lighter
    and its foot darker. `stubble` is what's left after mowing: short stumps."""
    R = _rng(seed)
    shades, head = GRASS[area]
    tip = _lift(shades[0], 1.18, 14)
    foot = _lift(shades[0], 0.66)
    pal = [foot] + list(shades) + [tip] + ([head] if head else [])
    vox = {}
    RAD = 4.6
    spots = [(x, z) for x in range(-4, 5, 2) for z in range(-4, 5, 2)]
    spots += [(x + 1, z + 1) for x, z in spots if R.random() < 0.25]
    for (x, z) in spots:
        d = math.sqrt(x * x + z * z)
        if d > RAD or (d > 3 and R.random() < 0.3):
            continue
        if stubble:
            h = R.randint(1, 2)
        else:
            h = max(3, int(R.uniform(8, 14) * (1 - d / RAD * 0.5)))
        ci = R.randint(1, len(shades))
        for y in range(h):
            vox[(x, y, z)] = 0 if stubble else ci
        vox[(x, h - 1, z)] = len(shades) + 1 if not stubble else 0
        if head and not stubble and R.random() < 0.5:
            vox[(x, h, z)] = len(pal) - 1
            if area == "wheat":
                vox[(x, h + 1, z)] = len(pal) - 1
    return vox, pal, 0.6


# ---------------------------------------------------------------------------------------------------------------
# landmarks
# ---------------------------------------------------------------------------------------------------------------
def windmill(seed=1, part="body"):
    """The meadow windmill: stone foot, a tapered cream-and-timber tower, a stepped red roof, a door, windows. The
    sails are their own mesh (part="sails") so the game can spin them."""
    R = _rng(seed)
    STONE, STONE2, CREAM, TIMBER, ROOF, ROOF2, CLOTH, DOOR, GLOW = range(9)
    pal = [(128, 128, 136), (104, 104, 114), (246, 236, 214), (132, 82, 52), (210, 62, 52), (168, 42, 40),
           (250, 248, 240), (84, 56, 40), (255, 214, 120)]
    vox = {}
    H = 24
    if part == "sails":
        box(vox, (-1, -1, 0), (1, 1, 1), TIMBER)
        for (ax, ay) in ((1, 0), (0, 1), (-1, 0), (0, -1)):
            px, py = -ay, ax
            for s in range(2, 21):
                vox[(ax * s, ay * s, -1)] = TIMBER
                if s < 5:
                    continue
                for t in range(1, 5):
                    frame = t == 4 or s == 20 or s % 3 == 2
                    vox[(ax * s + px * t, ay * s + py * t, -1)] = TIMBER if frame else CLOTH
        return vox, pal, 1.2
    for y in range(H):
        r = 9.0 - y * 0.12
        for x in range(-10, 11):
            for z in range(-10, 11):
                dd = x * x + z * z
                if dd > r * r or dd < (r - 2) ** 2 and 0 < y < H - 1:
                    continue
                if y < 4:
                    ci = STONE if R.random() < 0.7 else STONE2
                elif dd > (r - 1) ** 2 and (abs(x) == abs(z) or x == 0 or z == 0):
                    ci = TIMBER
                elif y % 7 == 0:
                    ci = TIMBER
                else:
                    ci = CREAM
                vox[(x, y, z)] = ci
    for k in range(11):
        r = 8.4 - k * 0.8
        for x in range(-10, 11):
            for z in range(-10, 11):
                if x * x + z * z <= r * r:
                    vox[(x, H + k, z)] = ROOF if k % 2 == 0 else ROOF2
    box(vox, (-1, 0, -10), (1, 5, -7), DOOR)
    for y in (12, 20):
        for (wx, wz) in ((0, -8), (-7, -4), (7, -4)):
            box(vox, (wx, y, wz), (wx, y + 1, wz), GLOW)
    box(vox, (-1, H - 4, -10), (1, H - 2, -8), TIMBER)  # the axle the sails hang on
    return vox, pal, 1.2


def silo(seed=1):
    """Wheat landmark: a striped red silo with a domed cap, beside a red barn with white trim."""
    R = _rng(seed)
    RED, WHITE, DOME, DOME2, BARN, BARN2, TRIM, ROOF, DOOR = range(9)
    pal = [(214, 64, 54), (244, 238, 226), (196, 200, 210), (162, 166, 178), (200, 56, 48), (172, 44, 40),
           (250, 246, 236), (120, 46, 40), (110, 70, 44)]
    vox = {}
    H = 30
    for y in range(H):
        cylinder(vox, (0, 0), 6.5, y, y, RED if (y // 5) % 2 == 0 else WHITE)
    for k in range(7):
        r = math.sqrt(max(0, 6.8 ** 2 - (k * 1.1) ** 2))
        cylinder(vox, (0, 0), r, H + k, H + k, DOME if k % 2 == 0 else DOME2)
    # barn to the side (+x)
    bx0, bx1, bz0, bz1 = 9, 27, -8, 8
    box(vox, (bx0, 0, bz0), (bx1, 11, bz1), lambda p: BARN if (p[2] % 2) else BARN2)
    for k in range(7):
        box(vox, (bx0 - 1, 12 + k, bz0 + k - 1), (bx1 + 1, 12 + k, bz1 - k + 1), ROOF)
    box(vox, (bx0, 0, bz0 - 1), (bx1, 0, bz0 - 1), TRIM)
    box(vox, (bx0 + 6, 0, bz0 - 1), (bx0 + 12, 8, bz0 - 1), DOOR)
    for t in range(7):  # the white X on the door
        vox[(bx0 + 6 + t, 1 + t, bz0 - 2)] = TRIM
        vox[(bx0 + 12 - t, 1 + t, bz0 - 2)] = TRIM
    box(vox, (bx0 + 6, 8, bz0 - 2), (bx0 + 12, 8, bz0 - 2), TRIM)
    # hay bales
    for (hx, hz) in ((-9, -6), (-10, 3), (31, -10)):
        pal_i = len(pal)
        pal.append((236, 196, 90))
        box(vox, (hx, 0, hz), (hx + 3, 2, hz + 2), pal_i)
    return vox, pal, 1.2


def cherry(seed=7):
    """Blossom landmark: a giant cherry tree."""
    return round_tree(seed, "blossom", 2.3)


def elderpine(seed=3):
    """Pine landmark: one enormous pine."""
    return pine_tree(seed, "pine", 2.6)


def mushroomhut(seed=5):
    """Swamp landmark: a toadstool house with a door, glowing windows and a bubbling cauldron."""
    vox, pal, vs = mushroom_tree(seed, "swamp", 2.0)
    DOOR = len(pal)
    pal += [(90, 60, 50), (255, 220, 90), (40, 40, 50), (80, 230, 90)]
    box(vox, (-1, 0, -6), (1, 5, -4), DOOR)
    box(vox, (2, 9, -4), (3, 10, -4), DOOR + 1)
    box(vox, (-3, 9, -4), (-2, 10, -4), DOOR + 1)
    box(vox, (6, 0, -9), (9, 2, -6), DOOR + 2)
    box(vox, (7, 3, -8), (8, 3, -7), DOOR + 3)
    return vox, pal, vs


def icespire(seed=9):
    """Frost landmark: a tall spire of ice blocks with glowing cyan bands, ringed by leaning shards."""
    R = _rng(seed)
    pal = [(150, 200, 236), (186, 224, 250), (226, 244, 255), (90, 230, 255), (255, 255, 255)]
    vox = {}
    H = 60
    for y in range(H):
        r = 6.5 * (1 - y / H) ** 0.8 + 0.6
        ci = 3 if y % 12 in (0, 1) else R.choice((0, 1, 1, 2))
        cylinder(vox, (0, 0), r, y, y, ci)
    for k in range(7):
        a = k / 7 * math.pi * 2
        h = R.randint(14, 24)
        for y in range(h):
            d = 11 - y * 0.25
            cx, cz = math.cos(a) * d, math.sin(a) * d
            r = 1.8 * (1 - y / h) + 0.5
            cylinder(vox, (int(round(cx)), int(round(cz))), r, y, y, 4 if y > h - 3 else R.choice((1, 2)))
    return vox, pal, 1.2


def volcano(seed=11):
    """Ember landmark: a stepped dark cone with a glowing crater and lava running down its sides."""
    R = _rng(seed)
    pal = [(40, 32, 36), (54, 44, 50), (70, 58, 64), (255, 110, 30), (255, 170, 60)]
    vox = {}
    H = 20
    for y in range(H):
        r = 15 * (1 - y / (H + 4)) + 1.5
        inner = 3 if y > H - 3 else -1
        for x in range(-int(r), int(r) + 1):
            for z in range(-int(r), int(r) + 1):
                dd = x * x + z * z
                if dd <= r * r and (dd >= (r - 2) ** 2 or y in (0, H - 3)) and dd > inner * inner:
                    vox[(x, y, z)] = R.choice((0, 1, 1, 2))
    cylinder(vox, (0, 0), 3, H - 3, H - 3, 3)
    for k in range(5):
        a = k / 5 * math.pi * 2 + R.uniform(-0.2, 0.2)
        for y in range(H - 1, 0, -1):
            r = 15 * (1 - y / (H + 4)) + 1.5
            x, z = int(round(math.cos(a) * r)), int(round(math.sin(a) * r))
            w = 1 if y > H / 2 else 2
            for t in range(-w + 1, w):
                px, pz = int(round(math.cos(a) * r - math.sin(a) * t)), int(round(math.sin(a) * r + math.cos(a) * t))
                for p in ((px, y, pz),):
                    if p in vox or True:
                        vox[p] = 3 if (y + t) % 3 else 4
    return vox, pal, 2.8


def floatrock(seed=13):
    """Isles landmark: a floating island, grassy top, rock tapering below, a glowing crystal on top."""
    R = _rng(seed)
    pal = [(84, 70, 130), (108, 92, 160), (134, 116, 190), (150, 110, 240), (180, 140, 255), (120, 236, 255), (220, 250, 255)]
    vox = {}
    D = 22
    for y in range(D):
        r = 14 * (1 - y / D) ** 0.7 + R.uniform(-0.6, 0.6)
        cylinder(vox, (0, 0), max(1, r), -y, -y, R.choice((0, 1, 1, 2)))
    cylinder(vox, (0, 0), 14.5, 1, 1, 3)
    cylinder(vox, (0, 0), 13, 1, 1, 4)
    for y in range(12):
        w = 2.4 * (1 - y / 12) + 0.4
        cylinder(vox, (0, 0), w, 2 + y, 2 + y, 6 if y > 9 else 5)
    for p in [p for p in vox if p[1] < -D + 1]:
        del vox[p]
    return vox, pal, 1.2


LANDMARKS = {
    "meadow": "windmill",
    "wheat": "silo",
    "blossom": "cherry",
    "pine": "elderpine",
    "swamp": "mushroomhut",
    "frost": "icespire",
    "ember": "volcano",
    "isles": "floatrock",
}


def catalogue():
    """Every mesh to export: name -> (function, kwargs)."""
    out = {}
    for area in AREAS:
        for s in (1, 2, 3):
            out[f"Tree_{area}_{s}"] = (tree, dict(area=area, seed=s * 17 + 1, scale=1.0 if s < 3 else 1.3))
        out[f"Bush_{area}"] = (bush, dict(area=area, seed=3))
        out[f"Rock_{area}"] = (rock, dict(area=area, seed=5))
        out[f"Rock_{area}_big"] = (rock, dict(area=area, seed=9, big=True))
        for s in (1, 2):
            out[f"Clump_{area}_{s}"] = (clump, dict(area=area, seed=s * 31))
        out[f"Stubble_{area}"] = (clump, dict(area=area, seed=7, stubble=True))
    out["Landmark_windmill"] = (windmill, dict(part="body"))
    out["Landmark_windmill_sails"] = (windmill, dict(part="sails"))
    for area, lm in LANDMARKS.items():
        if lm != "windmill":
            out["Landmark_" + lm] = (globals()[lm], {})
    return out
