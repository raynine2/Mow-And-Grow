"""The smooth cartoon models: trees, bushes and rocks for the whole world, and the hub town's buildings and props.

Every builder takes a skit.Model and draws in game space (studs; x right, y up, front = -z). A model's design origin
is where the game places it (its foot): for the props that replace a server/HubKit model it's the same origin and
layout as that model, so the builders' colliders, prompts and lights still line up.
"""
import math

from skit import T, Rx, Ry, Rz, S, dark, light, mix

# --------------------------------------------------------------------------------------------------- colours
BARK = (128, 88, 58)
BARK_D = (100, 68, 46)
LOG = (182, 128, 78)
LOG2 = (164, 112, 66)
LOG_END = (226, 188, 132)
PLANK = (166, 112, 68)
PLANK_L = (196, 146, 96)
PLANK_D = (98, 64, 40)
STONE = (168, 166, 160)
STONE2 = (140, 138, 134)
STONE3 = (190, 186, 178)
PLASTER = (244, 232, 206)
IRON = (54, 54, 62)
GLASS = (255, 214, 140)
GLASS_B = (150, 210, 236)
WATER = (92, 186, 232)
WATER_L = (160, 222, 246)
GRASS = (98, 170, 64)
LEAF = (90, 168, 70)
HAY = (232, 196, 100)
GOLD = (255, 200, 60)
WHITE = (246, 244, 236)
FLOWERS = [(255, 96, 126), (255, 214, 64), (250, 250, 250), (160, 126, 255), (255, 150, 60)]

ROOFS = {"red": (198, 76, 60), "blue": (74, 116, 178), "green": (86, 146, 92), "brown": (122, 80, 56), "teal": (60, 150, 150)}

CANOPY = {
    "meadow": (92, 172, 70),
    "meadow2": (112, 182, 64),
    "blossom": (246, 168, 206),
    "autumn": (238, 146, 56),
    "autumn2": (222, 100, 52),
    "pine": (56, 128, 82),
    "swamp": (96, 140, 70),
    "frost": (72, 128, 104),
    "ember": (226, 92, 40),
    "birch": (168, 200, 78),
}


# =================================================================================================== nature
def _trunk(m, h, r, lean=0.0, colour=BARK, roots=4):
    m.cyl(r, h, T(0, 0, 0) @ Rz(lean), colour, seg=10, r2=r * 0.7)
    for i in range(roots):
        a = i * 360 / roots + m.rng.uniform(-20, 20)
        m.cone(r * 0.75, r * 1.5, Ry(a) @ T(0, 0, r * 0.75) @ Rx(-25), colour, seg=6, tip=0.15, smooth=True)


def oak(m, kind="meadow", h=7.0):
    """A round cartoon tree: tapered trunk with root flares, two branches, and a puffy canopy of soft lumps."""
    col = CANOPY[kind]
    col2 = CANOPY.get(kind + "2", light(col, 0.12))
    _trunk(m, h + 1.5, 0.95)
    for a in (40, 220):
        m.cyl(0.38, 3.6, T(0, h - 1.6, 0) @ Ry(a) @ Rz(42), BARK, seg=8, r2=0.22)
    cy = h + 3.2
    m.blob(4.6, T(0, cy, 0), col, squash=(1, 0.82, 1))
    n = m.rng.randint(5, 6)
    for i in range(n):
        a = math.radians(i * 360 / n + m.rng.uniform(-15, 15))
        r = m.rng.uniform(3.0, 3.6)
        rr = m.rng.uniform(2.6, 3.3)
        m.blob(rr, T(math.cos(a) * r, cy + m.rng.uniform(-1.4, 0.6), math.sin(a) * r), col if i % 2 else col2, squash=(1, 0.85, 1))
    m.blob(3.0, T(m.rng.uniform(-0.8, 0.8), cy + 3.0, m.rng.uniform(-0.8, 0.8)), col2, squash=(1, 0.85, 1))


def birch(m):
    col = CANOPY["birch"]
    m.cyl(0.55, 10, T(0, 0, 0), WHITE, seg=10, r2=0.4)
    for i in range(7):
        y = 1 + i * 1.3 + m.rng.uniform(-0.3, 0.3)
        a = m.rng.uniform(0, 360)
        m.box((0.5, 0.18, 0.12), T(0, y, 0) @ Ry(a) @ T(0, 0, -0.5), IRON)
    cy = 10.5
    m.blob(3.2, T(0, cy, 0), col, squash=(0.9, 1.15, 0.9))
    for i in range(4):
        a = math.radians(i * 90 + 45)
        m.blob(2.2, T(math.cos(a) * 2.2, cy - 1.2 + (i % 2), math.sin(a) * 2.2), light(col, 0.08) if i % 2 else col, squash=(1, 1.1, 1))
    m.blob(2.0, T(0, cy + 2.8, 0), light(col, 0.1))


def pine(m, kind="pine", snow=False):
    """Stacked soft cones getting smaller to a point, on a short trunk; snow caps in the frost area."""
    col = CANOPY[kind]
    m.cyl(0.6, 3, T(0, 0, 0), BARK_D, seg=8, r2=0.45)
    y = 2.0
    tiers = [(5.0, 4.2), (4.1, 3.9), (3.2, 3.6), (2.3, 3.3), (1.4, 2.8)]
    for i, (r, h) in enumerate(tiers):
        c = col if i % 2 == 0 else light(col, 0.08)
        m.cone(r, h, T(0, y, 0) @ Ry(i * 18), c, seg=9, tip=0.25, smooth=False)
        if snow:
            # snow lying on the lower edge of each tier (the part the tier above doesn't cover)
            k = 0.32
            m.cone(r * 1.03, h * k, T(0, y + 0.02, 0) @ Ry(i * 18), WHITE, seg=9, tip=(r - (r - 0.25) * k) * 1.03, smooth=False)
        y += h * 0.62
    m.cone(0.35, 1.2, T(0, y + 0.5, 0), col, seg=6, tip=0.0)


def willow(m):
    col = CANOPY["swamp"]
    _trunk(m, 8, 1.0, colour=BARK_D)
    cy = 10
    m.blob(4.4, T(0, cy, 0), col, squash=(1, 0.7, 1))
    for i in range(14):
        a = math.radians(i * 360 / 14)
        r = 3.8 + m.rng.uniform(-0.4, 0.4)
        ln = m.rng.uniform(3.5, 5.5)
        m.box((0.55, ln, 0.55), T(math.cos(a) * r, cy - ln / 2, math.sin(a) * r), dark(col, 0.08), bevel=0.15)


def dead(m):
    """The ember area's charred tree with a few glowing leaves."""
    _trunk(m, 7, 0.9, colour=(70, 56, 52))
    for a, tilt, ln in ((20, 35, 4.5), (150, 40, 4), (260, 30, 5), (90, 15, 3)):
        m.cyl(0.32, ln, T(0, 4.5 + ln * 0.2, 0) @ Ry(a) @ Rz(tilt), (70, 56, 52), seg=6, r2=0.12)
    col = CANOPY["ember"]
    for i in range(5):
        a = math.radians(i * 72)
        m.blob(1.6, T(math.cos(a) * 2.6, 8 + (i % 2) * 1.2, math.sin(a) * 2.6), col)


def bush(m, kind="meadow", flowers=False):
    col = CANOPY.get(kind, CANOPY["meadow"])
    m.blob(1.8, T(0, 1.4, 0), col, squash=(1.2, 0.8, 1.1))
    for i in range(3):
        a = math.radians(i * 120 + 30)
        m.blob(1.3, T(math.cos(a) * 1.3, 1.0, math.sin(a) * 1.3), light(col, 0.06) if i % 2 else col)
    if flowers:
        for i in range(7):
            a = math.radians(i * 51)
            m.blob(0.3, T(math.cos(a) * 1.5, 2.0 + (i % 3) * 0.25, math.sin(a) * 1.4), FLOWERS[i % len(FLOWERS)], sub=1, noise=0, grad=0)


def rock(m, big=False):
    k = 1.6 if big else 1.0
    m.rock(1.8 * k, T(0, 0.4 * k, 0), STONE)
    m.rock(1.1 * k, T(1.6 * k, 0.2 * k, 0.6 * k), STONE2)
    if big:
        m.rock(1.0 * k, T(-1.4 * k, 0.1 * k, -0.9 * k), STONE3)


# =================================================================================================== building parts
def window(m, cf, w=2.4, h=2.6, glass=GLASS, shutters=True, box=True):
    """A framed window on a wall at cf (cf's -z looks out of the wall)."""
    m.box((w, h, 0.12), cf @ T(0, 0, -0.04), glass, shade=False)
    t = 0.3
    for x, y, sw, sh in ((0, h / 2, w + 2 * t, t), (0, -h / 2, w + 2 * t, t), (w / 2, 0, t, h), (-w / 2, 0, t, h)):
        m.box((sw, sh, 0.3), cf @ T(x, y, -0.15), PLANK_D, bevel=0.06)
    m.box((w, 0.14, 0.2), cf @ T(0, 0, -0.14), PLANK_D)
    m.box((0.14, h, 0.2), cf @ T(0, 0, -0.14), PLANK_D)
    m.box((w + 0.9, 0.22, 0.6), cf @ T(0, -h / 2 - 0.2, -0.3), PLANK_L, bevel=0.06)  # sill
    if shutters:
        for s in (-1, 1):
            m.box((w * 0.42, h + 0.1, 0.16), cf @ T(s * (w / 2 + w * 0.24), 0, -0.12), (78, 120, 96) if box else PLANK_D, bevel=0.05)
    if box:
        m.box((w + 0.3, 0.55, 0.65), cf @ T(0, -h / 2 - 0.6, -0.45), PLANK, bevel=0.08)
        for i in range(5):
            m.blob(0.36, cf @ T(-w / 2 + 0.3 + i * (w - 0.6) / 4, -h / 2 - 0.2, -0.45), FLOWERS[i % len(FLOWERS)] if i % 2 == 0 else LEAF, sub=1, noise=0.05, grad=0)


def door(m, cf, w=2.8, h=4.4, colour=PLANK_D):
    m.box((w, h, 0.3), cf @ T(0, h / 2, -0.05), colour, bevel=0.06)
    for x in (-w / 4, w / 4):
        m.box((w / 2 - 0.25, h - 0.6, 0.12), cf @ T(x, h / 2, -0.22), light(colour, 0.12), bevel=0.04)
    m.blob(0.16, cf @ T(w * 0.33, h * 0.45, -0.32), GOLD, sub=1, noise=0, grad=0)
    for x, y, sw, sh in ((0, h + 0.15, w + 0.8, 0.35), (w / 2 + 0.2, h / 2, 0.4, h), (-w / 2 - 0.2, h / 2, 0.4, h)):
        m.box((sw, sh, 0.45), cf @ T(x, y, -0.12), PLANK_L, bevel=0.06)


def lantern(m, cf, s=1.0):
    m.box((0.7 * s, 0.9 * s, 0.7 * s), cf, GLASS, shade=False)
    m.cone(0.6 * s, 0.45 * s, cf @ T(0, 0.45 * s, 0), IRON, seg=4, tip=0.05)
    m.box((0.8 * s, 0.14 * s, 0.8 * s), cf @ T(0, -0.5 * s, 0), IRON)


# =================================================================================================== cabin
def log_cabin(m):
    """The shops' log cabin, same layout as server/HubKit's (room x +-11.9, z -2.5..9.5, door 5 wide in the front
    wall at z -3.2, porch to z -11.9, sign spot at (0, 10.4, -12.3), chimney top at (8.5, 23, 7))."""
    # stone foundation and floors
    m.box((27.8, 0.7, 15.8), T(0, 0.15, 3.5), STONE2, bevel=0.2)
    for i in range(12):
        x = -13 + i * 2.35
        for z, s in ((-4.4, 1), (11.4, 1)):
            m.rock(0.55, T(x + m.rng.uniform(-0.3, 0.3), 0.25, z), STONE if i % 2 else STONE3, squash=(1.2, 0.6, 0.8), noise=0.15)
    m.box((24, 0.14, 12.2), T(0, 0.56, 3.5), PLANK)
    m.box((27, 0.5, 8.4), T(0, 0.25, -7.8), PLANK_L, bevel=0.08)
    for i in range(10):
        m.box((0.08, 0.04, 8.3), T(-12.15 + i * 2.7, 0.51, -7.8), PLANK_D, shade=False)
    m.log((-13.8, 0.3, -12), (13.8, 0.3, -12), 0.36, LOG2, LOG_END)
    m.box((7.4, 0.26, 1.3), T(0, 0.13, -12.7), PLANK_L, bevel=0.06)
    # log walls: rows of round logs crossing at the corners
    r = 0.62
    for row in range(10):
        y = 1.2 + row * 1.12
        c = LOG if row % 2 == 0 else LOG2
        lift = 0.56 * (row % 2)
        m.log((-13.7, y, 10.2), (13.7, y, 10.2), r, c, LOG_END)
        for x in (-12.65, 12.65):
            m.log((x, y + lift, -4.4), (x, y + lift, 11.2), r, c, LOG_END)
        if y > 8.6:
            m.log((-13.7, y, -3.2), (13.7, y, -3.2), r, c, LOG_END)
        else:
            m.log((-13.7, y, -3.2), (-2.6, y, -3.2), r, c, LOG_END)
            m.log((2.6, y, -3.2), (13.7, y, -3.2), r, c, LOG_END)
    for x in (-2.75, 2.75):
        m.box((0.5, 8.2, 1.5), T(x, 4.5, -3.2), PLANK_D, bevel=0.08)
    m.box((6.1, 0.6, 1.6), T(0, 8.6, -3.2), PLANK_D, bevel=0.08)
    for x in (-7.8, 7.8):
        window(m, T(x, 5.6, -3.9), 3.6, 3.0)
    for s in (-1, 1):
        window(m, T(s * 13.35, 5.6, 1) @ Ry(-90 * s), 3.2, 3.0)
    for x in (-3.7, 3.7):
        m.box((0.12, 0.12, 0.6), T(x, 7.6, -4.0), IRON)
        lantern(m, T(x, 7.2, -4.4), 0.8)
    # gables, roof and ridge
    rise, run = 6.6, 8.6
    for x in (-12.65, 12.65):
        m.hull([(x - 0.6, 12.3, 3.5 - run), (x + 0.6, 12.3, 3.5 - run), (x - 0.6, 12.3, 3.5 + run), (x + 0.6, 12.3, 3.5 + run), (x - 0.6, 12.3 + rise, 3.5), (x + 0.6, 12.3 + rise, 3.5)], T(), LOG)
        for i in range(4):
            yy = 12.9 + i * 1.3
            half = run * (1 - (yy - 12.3) / rise) - 0.3
            m.log((x, yy, 3.5 - half), (x, yy, 3.5 + half), 0.5, LOG2 if i % 2 else LOG)
    m.roof(30, 2 * (run + 1.2), rise + 0.6, T(0, 12.0, 3.5), ROOFS["brown"], thick=0.55, edge=PLANK_D)
    # the porch roof on log posts
    pl = 8.4
    m.box((29, 0.5, pl + 0.6), T(0, 11.4, -3.6 - pl / 2) @ Rx(-math.degrees(math.atan2(1.0, pl))), ROOFS["brown"], bevel=0.1)
    m.box((29, 0.7, 0.35), T(0, 10.85, -11.95), PLANK_D, bevel=0.06)
    for x in (-12.8, -4.4, 4.4, 12.8):
        m.cyl(0.42, 10.4, T(x, 0.5, -11.3), LOG, seg=10)
    for s in (-1, 1):
        for y in (1.7, 3.2):
            m.log((s * 4.4, y, -11.3), (s * 12.8, y, -11.3), 0.16, LOG2)
        for i in range(1, 6):
            m.box((0.22, 2.6, 0.22), T(s * (4.4 + i * 1.4), 1.8, -11.3), LOG2, bevel=0.05)
    # chimney
    m.box((2.6, 10.4, 2.6), T(8.5, 17.2, 7), STONE, bevel=0.15)
    for i in range(5):
        m.box((2.75, 0.12, 2.75), T(8.5, 13 + i * 1.8, 7), STONE2)
    m.box((3.1, 0.6, 3.1), T(8.5, 22.5, 7), STONE2, bevel=0.12)
    # a barrel and crates on the porch
    m.cyl(0.85, 1.8, T(-10.8, 0.5, -8.6), PLANK, seg=12, bevel=0.1)
    for y in (0.9, 1.9):
        m.cyl(0.9, 0.12, T(-10.8, y, -8.6), IRON, seg=12, smooth=True)
    m.box((1.7, 1.7, 1.7), T(10.8, 1.35, -8.8) @ Ry(12), PLANK_L, bevel=0.1)
    m.box((1.3, 1.3, 1.3), T(10.6, 2.85, -8.9) @ Ry(-8), PLANK, bevel=0.1)


# =================================================================================================== town houses
def town_house(m, roof="red", plaster=PLASTER, glass=GLASS):
    """A two-storey cottage, 16 wide and 12 deep: stone ground floor with the door and two windows, a timber-
    framed plaster upper floor with three windows, a steep gable roof, a chimney, flower boxes."""
    W, D = 16, 12
    rc = ROOFS[roof]
    m.box((W + 0.4, 0.6, D + 0.4), T(0, 0.3, 0), STONE2, bevel=0.15)
    m.box((W, 4, D), T(0, 2.6, 0), STONE, bevel=0.12)
    for i in range(14):
        x = -W / 2 + 0.8 + i * (W - 1.6) / 13
        y = m.rng.uniform(1.2, 4.0)
        if abs(x) > 1.8:
            m.box((m.rng.uniform(0.9, 1.4), m.rng.uniform(0.5, 0.8), 0.2), T(x, y, -D / 2 - 0.05), STONE3, bevel=0.06)
    m.box((W + 0.5, 0.45, D + 0.5), T(0, 4.75, 0), PLANK_D, bevel=0.08)
    m.box((W, 6, D), T(0, 7.9, 0), plaster)
    # timber frame on the front and back
    for z, sgn in ((-D / 2, -1), (D / 2, 1)):
        for x in (-W / 2 + 0.25, -W / 2 + 5.4, W / 2 - 5.4, W / 2 - 0.25):
            m.box((0.5, 6, 0.3), T(x, 7.9, z + sgn * 0.1), PLANK_D, bevel=0.05)
        m.box((W, 0.45, 0.3), T(0, 10.7, z + sgn * 0.1), PLANK_D, bevel=0.05)
    for x in (-W / 2, W / 2):
        for zz in (-D / 2 + 0.25, 0, D / 2 - 0.25):
            m.box((0.3, 6, 0.5), T(x + (0.1 if x > 0 else -0.1), 7.9, zz), PLANK_D, bevel=0.05)
    # gables and the roof
    for x in (-W / 2 + 0.05, W / 2 - 0.05):
        m.hull([(x - 0.15, 10.9, -D / 2), (x + 0.15, 10.9, -D / 2), (x - 0.15, 10.9, D / 2), (x + 0.15, 10.9, D / 2), (x - 0.15, 16.6, 0), (x + 0.15, 16.6, 0)], T(), plaster)
        m.box((0.3, 0.4, D), T(x, 10.9, 0), PLANK_D)
        window(m, T(x + (0.2 if x > 0 else -0.2), 12.6, 0) @ Ry(90 if x < 0 else -90), 1.6, 1.8, glass, shutters=False, box=False)
    m.roof(W + 1.6, D + 2.4, 6.4, T(0, 10.6, 0), rc, thick=0.5, edge=dark(rc, 0.3))
    # dormer on the front slope
    m.box((3.4, 2.6, 2.6), T(0, 13.0, -3.4), plaster, bevel=0.08)
    window(m, T(0, 13.0, -4.75), 1.8, 1.6, glass, shutters=False, box=False)
    m.prism(4.2, 1.6, 3.4, T(0, 14.3, -3.4) @ Ry(90), rc)
    # chimney
    m.box((1.9, 7, 1.9), T(W / 2 - 3, 16, 2.6), STONE, bevel=0.12)
    m.box((2.3, 0.5, 2.3), T(W / 2 - 3, 19.6, 2.6), STONE2, bevel=0.1)
    # door with a little canopy and steps
    door(m, T(0, 0.6, -D / 2), 2.8, 3.6)
    m.box((4.2, 0.3, 1.2), T(0, 0.45, -D / 2 - 0.6), STONE3, bevel=0.08)
    m.box((4.4, 0.3, 2.0), T(0, 4.7, -D / 2 - 0.9) @ Rx(-12), rc, bevel=0.06)
    for x in (-1.9, 1.9):
        m.box((0.18, 0.9, 0.18), T(x, 4.2, -D / 2 - 1.7), IRON)
    lantern(m, T(2.4, 3.6, -D / 2 - 0.5), 0.6)
    # windows
    for x in (-5.0, 5.0):
        window(m, T(x, 2.6, -D / 2), 2.4, 2.0, glass)
        window(m, T(x, 2.6, D / 2) @ Ry(180), 2.4, 2.0, glass, box=False)
    for x in (-5.2, 0, 5.2):
        window(m, T(x, 8.0, -D / 2), 2.2, 2.4, glass)
        window(m, T(x, 8.0, D / 2) @ Ry(180), 2.2, 2.4, glass, box=False)
    for s in (-1, 1):
        window(m, T(s * W / 2, 8.0, 0) @ Ry(-90 * s), 2.2, 2.4, glass, box=False)


def shop(m, stripe=(220, 70, 60), roof="teal"):
    """A small shop: plank walls, a big front window under a striped awning, crates of goods by the door, and a
    front gable with a round window. 14 wide, 10 deep."""
    W, D = 14, 10
    rc = ROOFS[roof]
    m.box((W + 0.4, 0.6, D + 0.4), T(0, 0.3, 0), STONE2, bevel=0.15)
    m.box((W, 8, D), T(0, 4.6, 0), PLANK_L, bevel=0.1)
    for i in range(16):
        m.box((W + 0.05, 0.06, D + 0.05), T(0, 1.0 + i * 0.5, 0), dark(PLANK_L, 0.12), shade=False)
    for x in (-W / 2, W / 2):
        for z in (-D / 2, D / 2):
            m.box((0.7, 8.2, 0.7), T(x, 4.7, z), PLANK_D, bevel=0.08)
    m.box((W + 0.6, 0.5, D + 0.6), T(0, 8.8, 0), PLANK_D, bevel=0.08)
    # shop window and door
    m.box((7.4, 3.6, 0.15), T(-2.2, 3.4, -D / 2 - 0.02), GLASS_B, shade=False)
    for x, y, sw, sh in ((-2.2, 5.3, 8.0, 0.35), (-2.2, 1.5, 8.0, 0.5), (-6.0, 3.4, 0.35, 3.8), (1.6, 3.4, 0.35, 3.8), (-2.2, 3.4, 0.2, 3.6)):
        m.box((sw, sh, 0.35), T(x, y, -D / 2 - 0.12), PLANK_D, bevel=0.05)
    door(m, T(4.4, 0.6, -D / 2), 2.4, 4.0, (80, 120, 150))
    # striped awning
    n = 9
    for i in range(n):
        x = -W / 2 + 0.2 + (i + 0.5) * (W - 0.4) / n
        c = stripe if i % 2 == 0 else WHITE
        m.box(((W - 0.4) / n, 0.2, 3.0), T(x, 6.6, -D / 2 - 1.3) @ Rx(-22), c)
        m.box(((W - 0.4) / n, 0.6, 0.12), T(x, 5.75, -D / 2 - 2.7), c)
    # front gable with a round window
    m.hull([(-W / 2 - 0.3, 9.0, -D / 2 - 0.1), (W / 2 + 0.3, 9.0, -D / 2 - 0.1), (0, 13.4, -D / 2 - 0.1), (-W / 2 - 0.3, 9.0, -D / 2 + 0.3), (W / 2 + 0.3, 9.0, -D / 2 + 0.3), (0, 13.4, -D / 2 + 0.3)], T(), PLASTER)
    m.cyl(1.1, 0.25, T(0, 10.9, -D / 2 - 0.15) @ Rx(-90), PLANK_D, seg=16)
    m.cyl(0.85, 0.3, T(0, 10.9, -D / 2 - 0.2) @ Rx(-90), GLASS, seg=16, shade=False)
    m.roof(D + 1.4, W + 1.4, 4.6, T(0, 8.9, 0) @ Ry(90), rc, thick=0.45, edge=dark(rc, 0.3))
    # crates of goods out front
    for i, (x, z) in enumerate(((-5.3, -6.6), (-3.2, -6.7), (-1.1, -6.6))):
        m.box((1.8, 1.0, 1.4), T(x, 0.5, z), PLANK, bevel=0.08)
        for k in range(4):
            m.blob(0.36, T(x - 0.5 + (k % 2) * 1.0, 1.15, z - 0.3 + (k // 2) * 0.6), [(220, 50, 50), (255, 150, 40), (130, 200, 60)][i], sub=1, noise=0.05, grad=0)
    m.cyl(0.6, 2.4, T(6.6, 0.6, -5.8), PLANK, seg=10)
    m.blob(0.9, T(6.6, 3.3, -5.8), LEAF, sub=1)


def market_stall(m, stripe=(70, 140, 220)):
    """A market stall, 8 wide: counter, four posts, a sloped striped canopy, baskets of produce."""
    m.box((7.6, 2.6, 2.4), T(0, 1.3, -0.6), PLANK_L, bevel=0.1)
    m.box((8.0, 0.3, 2.8), T(0, 2.75, -0.6), PLANK_D, bevel=0.06)
    for i in range(6):
        m.box((0.06, 2.4, 2.45), T(-3.1 + i * 1.25, 1.3, -0.6), dark(PLANK_L, 0.12), shade=False)
    for x in (-3.8, 3.8):
        m.cyl(0.22, 6.4, T(x, 0, -1.9), PLANK_D, seg=8)
        m.cyl(0.22, 7.4, T(x, 0, 1.6), PLANK_D, seg=8)
    n = 8
    for i in range(n):
        x = -4.2 + (i + 0.5) * 8.4 / n
        c = stripe if i % 2 == 0 else WHITE
        m.box((8.4 / n, 0.18, 4.6), T(x, 6.9, -0.2) @ Rx(-13), c)
        m.box((8.4 / n, 0.5, 0.1), T(x, 6.15, -2.45), c)
    produce = [(220, 50, 50), (255, 150, 40), (130, 200, 60), (250, 220, 70)]
    for i, x in enumerate((-2.7, -0.9, 0.9, 2.7)):
        m.cyl(0.75, 0.6, T(x, 2.9, -1.0), (150, 104, 60), seg=10)
        for k in range(5):
            a = k * 72
            m.blob(0.28, T(x + math.cos(math.radians(a)) * 0.35, 3.55, -1.0 + math.sin(math.radians(a)) * 0.35), produce[i], sub=1, noise=0.05, grad=0)
    m.box((1.4, 1.0, 1.0), T(-3.2, 0.5, -2.6) @ Ry(10), PLANK, bevel=0.08)
    m.box((1.2, 0.9, 1.0), T(3.0, 0.45, -2.6) @ Ry(-8), PLANK, bevel=0.08)


# =================================================================================================== plaza pieces
def fountain(m):
    """A round two-tier stone fountain, 12 across."""
    m.cyl(6.2, 0.4, T(0, 0, 0), STONE2, seg=24)
    n = 20
    for i in range(n):
        a = i * 360 / n
        m.box((2.0, 1.1, 0.9), Ry(a) @ T(0, 0.95, -5.6), STONE if i % 2 else STONE3, bevel=0.15)
    m.cyl(5.2, 0.55, T(0, 0.35, 0), WATER, seg=24, shade=False)
    m.cyl(0.9, 3.4, T(0, 0.4, 0), STONE, seg=12, r2=0.7)
    m.cyl(2.6, 0.55, T(0, 3.3, 0), STONE3, seg=16, r2=2.9, bevel=0.15)
    m.cyl(2.3, 0.2, T(0, 3.7, 0), WATER, seg=16, shade=False)
    m.cyl(0.45, 1.6, T(0, 3.7, 0), STONE, seg=10, r2=0.3)
    m.blob(0.55, T(0, 5.5, 0), WATER_L, sub=1, noise=0, grad=0)
    for i in range(6):
        a = math.radians(i * 60)
        m.cyl(0.18, 1.6, T(math.cos(a) * 2.7, 1.2, math.sin(a) * 2.7), WATER_L, seg=6, shade=False)


def well(m):
    n = 12
    for i in range(n):
        a = i * 360 / n
        m.box((1.25, 1.6, 0.8), Ry(a) @ T(0, 0.8, -1.9), STONE if i % 2 else STONE3, bevel=0.12)
    m.cyl(1.6, 1.2, T(0, 0, 0), (40, 80, 110), seg=12, shade=False)
    for x in (-2.2, 2.2):
        m.box((0.4, 4.6, 0.4), T(x, 2.3, 0), PLANK_D, bevel=0.06)
    m.roof(5.4, 4.2, 1.6, T(0, 4.5, 0), ROOFS["red"], thick=0.3)
    m.cyl(0.18, 4.2, T(-2.1, 3.4, 0) @ Rz(-90), PLANK_L, seg=8)
    m.cyl(0.4, 0.6, T(0.4, 2.0, 0), PLANK, seg=10)


def lantern_post(m):
    """A street lamp (about 8.8 high): stone foot, iron post, a scroll arm reaching forward (-z) with a lantern
    hanging from it. server/HubDressing puts the warm glass and the light at (0, 4.75, -2.5)."""
    m.cyl(0.85, 0.8, T(0, 0, 0), STONE, seg=8, bevel=0.1)
    m.cyl(0.5, 0.8, T(0, 0.8, 0), IRON, seg=10, r2=0.3)
    m.cyl(0.2, 7.0, T(0, 1.6, 0), IRON, seg=8, r2=0.16)
    m.blob(0.32, T(0, 8.75, 0), IRON, sub=1, noise=0, grad=0)
    m.cyl(0.11, 2.7, T(0, 7.4, 0) @ Rx(-90), IRON, seg=6)
    m.cyl(0.08, 1.6, T(0, 6.4, -0.1) @ Rx(-50), IRON, seg=6)
    m.cyl(0.06, 0.8, T(0, 6.55, -2.5), IRON, seg=4)
    m.cone(1.0, 0.6, T(0, 5.75, -2.5), IRON, seg=4, tip=0.1)
    m.box((1.25, 0.2, 1.25), T(0, 3.85, -2.5), IRON, bevel=0.04)
    for x in (-0.55, 0.55):
        for z in (-0.55, 0.55):
            m.box((0.12, 1.8, 0.12), T(x, 4.8, -2.5 + z), IRON)
    m.box((1.0, 1.6, 1.0), T(0, 4.75, -2.5), GLASS, shade=False)


def bench(m):
    for k in range(3):
        m.box((6, 0.2, 0.42), T(0, 1.45, -0.45 + k * 0.48), PLANK_L, bevel=0.06)
    for k in range(2):
        m.box((6, 0.4, 0.16), T(0, 2.15 + k * 0.6, 0.72) @ Rx(-10), PLANK_L, bevel=0.05)
    for x in (-2.5, 2.5):
        m.box((0.22, 1.35, 1.4), T(x, 0.7, 0.05), IRON, bevel=0.05)
        m.box((0.2, 1.7, 0.2), T(x, 2.3, 0.78) @ Rx(-10), IRON, bevel=0.04)
        m.box((0.24, 0.2, 1.3), T(x, 2.2, 0.05), IRON, bevel=0.04)


def barrel(m):
    m.cyl(0.95, 2.4, T(0, 0, 0), PLANK, seg=14, bevel=0.12)
    m.cyl(1.05, 0.5, T(0, 0.95, 0), PLANK, seg=14)
    for y in (0.35, 1.2, 2.05):
        m.cyl(1.07, 0.14, T(0, y - 0.07, 0), IRON, seg=14)
    m.cyl(0.85, 0.05, T(0, 2.4, 0), PLANK_D, seg=14, shade=False)


def _crate(m, cf, s):
    m.box((s, s, s), cf, PLANK_L, bevel=0.08)
    for y in (-s / 2 + 0.12, s / 2 - 0.12):
        m.box((s + 0.06, 0.22, s + 0.06), cf @ T(0, y, 0), PLANK_D, bevel=0.03)
    m.box((s * 1.3, 0.2, 0.06), cf @ T(0, 0, -s / 2 - 0.03) @ Rz(40), PLANK_D)


def crate_stack(m):
    _crate(m, T(-0.95, 0.9, 0), 1.8)
    _crate(m, T(1.0, 0.8, 0.1) @ Ry(9), 1.6)
    _crate(m, T(-0.2, 2.6, 0) @ Ry(-6), 1.6)


def hay_bale(m):
    m.cyl(1.9, 3.6, T(-1.8, 1.9, 0) @ Rz(-90), HAY, seg=18, bevel=0.3)
    for x in (-0.8, 0.8):
        m.cyl(1.95, 0.18, T(x - 0.09, 1.9, 0) @ Rz(-90), (176, 128, 64), seg=18)
    m.cyl(1.0, 0.06, T(-1.86, 1.9, 0) @ Rz(-90), dark(HAY, 0.15), seg=12, shade=False)
    m.cyl(1.0, 0.06, T(1.8, 1.9, 0) @ Rz(-90), dark(HAY, 0.15), seg=12, shade=False)


def planter(m):
    m.box((4, 1.2, 1.5), T(0, 0.6, 0), PLANK, bevel=0.1)
    m.box((4.2, 0.2, 1.7), T(0, 1.25, 0), PLANK_D, bevel=0.05)
    for i in range(6):
        x = -1.5 + i * 0.6
        m.blob(0.45, T(x, 1.5, (i % 2) * 0.3 - 0.15), LEAF, sub=1)
        m.blob(0.28, T(x, 1.95, (i % 2) * 0.3 - 0.15), FLOWERS[i % len(FLOWERS)], sub=1, noise=0, grad=0)


def flower_bed(m):
    """A round raised flower bed ringed with stones, 5 across."""
    n = 14
    for i in range(n):
        a = i * 360 / n
        m.rock(0.45, Ry(a) @ T(0, 0.25, -2.3), STONE if i % 2 else STONE3, squash=(1.3, 0.8, 0.9), noise=0.1)
    m.cyl(2.2, 0.55, T(0, 0, 0), (96, 66, 44), seg=14)
    for i in range(16):
        a = math.radians(i * 360 / 16 + 10)
        r = 1.5 if i % 2 else 0.8
        m.blob(0.42, T(math.cos(a) * r, 0.9, math.sin(a) * r), LEAF, sub=1)
        m.blob(0.3, T(math.cos(a) * r, 1.35, math.sin(a) * r), FLOWERS[i % len(FLOWERS)], sub=1, noise=0, grad=0)
    m.blob(0.7, T(0, 1.2, 0), LEAF, sub=1)


def cart(m):
    """A wooden handcart full of flowers."""
    m.box((4.2, 1.4, 2.4), T(0, 1.7, 0), PLANK_L, bevel=0.08)
    m.box((4.4, 0.2, 2.6), T(0, 2.45, 0), PLANK_D, bevel=0.04)
    for s in (-1, 1):
        m.cyl(1.05, 0.25, T(0.6, 1.05, s * 1.35) @ Rx(90 * s), PLANK_D, seg=14)
        m.cyl(0.25, 0.32, T(0.6, 1.05, s * 1.35) @ Rx(90 * s), IRON, seg=8)
    for s in (-1, 1):
        m.cyl(0.12, 3.0, T(-2.0, 1.6, s * 0.8) @ Rz(80), PLANK_D, seg=6)
    m.box((0.4, 0.8, 2.2), T(1.9, 0.6, 0), PLANK_D)
    for i in range(10):
        m.blob(0.5, T(-1.5 + (i % 5) * 0.75, 2.75, -0.55 + (i // 5) * 1.1), LEAF, sub=1)
        m.blob(0.32, T(-1.5 + (i % 5) * 0.75, 3.2, -0.55 + (i // 5) * 1.1), FLOWERS[i % len(FLOWERS)], sub=1, noise=0, grad=0)


def fence(m):
    """One 8-stud fence section: two round posts with rounded tops and two rails, along x."""
    for x in (-4, 4):
        m.cyl(0.32, 3.4, T(x, 0, 0), LOG2, seg=8)
        m.blob(0.33, T(x, 3.4, 0), LOG2, sub=1, noise=0, grad=0)
    for y in (1.3, 2.6):
        m.box((8, 0.35, 0.22), T(0, y, 0), LOG, bevel=0.06)


def picnic_table(m):
    m.box((5, 0.25, 2.4), T(0, 2.4, 0), PLANK_L, bevel=0.06)
    for s in (-1, 1):
        m.box((5, 0.2, 0.8), T(0, 1.4, s * 1.8), PLANK_L, bevel=0.05)
        for x in (-1.8, 1.8):
            m.box((0.25, 2.8, 0.25), T(x, 1.3, s * 0.7) @ Rx(s * 28), PLANK_D, bevel=0.04)


def mailbox(m):
    m.cyl(0.14, 3.0, T(0, 0, 0), PLANK_D, seg=6)
    m.box((0.9, 0.8, 1.4), T(0, 3.3, 0), (60, 110, 170), bevel=0.1)
    m.cyl(0.45, 1.4, T(0, 3.7, -0.7) @ Rx(90), (60, 110, 170), seg=10)
    m.box((0.1, 0.6, 0.3), T(0.5, 3.8, 0.3), (220, 60, 50))


def planter_pot(m):
    m.cyl(0.8, 1.2, T(0, 0, 0), (196, 104, 70), seg=12, r2=1.0)
    m.cyl(1.05, 0.25, T(0, 1.15, 0), (176, 92, 62), seg=12)
    m.blob(1.0, T(0, 2.0, 0), LEAF, sub=2)
    for i in range(4):
        a = math.radians(i * 90 + 20)
        m.blob(0.28, T(math.cos(a) * 0.75, 2.45, math.sin(a) * 0.75), FLOWERS[i], sub=1, noise=0, grad=0)


# =================================================================================================== catalogue
# name -> (builder, kwargs). Trees are about 15 studs tall at scale 1.
CATALOGUE = {
    "S_tree_meadow_1": (oak, {"kind": "meadow"}),
    "S_tree_meadow_2": (oak, {"kind": "meadow", "h": 6.0}),
    "S_tree_meadow_3": (oak, {"kind": "meadow", "h": 8.0}),
    "S_tree_birch_1": (birch, {}),
    "S_tree_blossom_1": (oak, {"kind": "blossom"}),
    "S_tree_blossom_2": (oak, {"kind": "blossom", "h": 6.0}),
    "S_tree_autumn_1": (oak, {"kind": "autumn"}),
    "S_tree_autumn_2": (oak, {"kind": "autumn", "h": 6.5}),
    "S_tree_pine_1": (pine, {}),
    "S_tree_pine_2": (pine, {}),
    "S_tree_frost_1": (pine, {"kind": "frost", "snow": True}),
    "S_tree_frost_2": (pine, {"kind": "frost", "snow": True}),
    "S_tree_swamp_1": (willow, {}),
    "S_tree_ember_1": (dead, {}),
    "S_bush_1": (bush, {}),
    "S_bush_2": (bush, {"flowers": True}),
    "S_bush_blossom": (bush, {"kind": "blossom"}),
    "S_bush_autumn": (bush, {"kind": "autumn"}),
    "S_bush_pine": (bush, {"kind": "pine"}),
    "S_rock_1": (rock, {}),
    "S_rock_2": (rock, {"big": True}),
    # hub buildings and props (S_<name> replaces server/HubKit's <name>)
    "S_log_cabin": (log_cabin, {}),
    "S_lantern_post": (lantern_post, {}),
    "S_bench": (bench, {}),
    "S_barrel": (barrel, {}),
    "S_crate_stack": (crate_stack, {}),
    "S_hay_bale": (hay_bale, {}),
    "S_planter": (planter, {}),
    # the town's own pieces
    "S_house_red": (town_house, {"roof": "red"}),
    "S_house_blue": (town_house, {"roof": "blue", "plaster": (236, 228, 214)}),
    "S_house_green": (town_house, {"roof": "green", "plaster": (246, 226, 190)}),
    "S_shop_teal": (shop, {"stripe": (220, 70, 60), "roof": "teal"}),
    "S_shop_red": (shop, {"stripe": (70, 140, 220), "roof": "red"}),
    "S_stall_blue": (market_stall, {"stripe": (70, 140, 220)}),
    "S_stall_red": (market_stall, {"stripe": (220, 70, 60)}),
    "S_stall_green": (market_stall, {"stripe": (80, 170, 80)}),
    "S_fountain": (fountain, {}),
    "S_well": (well, {}),
    "S_flower_bed": (flower_bed, {}),
    "S_cart": (cart, {}),
    "S_fence": (fence, {}),
    "S_picnic_table": (picnic_table, {}),
    "S_mailbox": (mailbox, {}),
    "S_pot": (planter_pot, {}),
}
