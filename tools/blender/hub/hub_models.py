"""The hub's extras as stud-voxel models (10 Nov 2026; owner: "make the models with blender but make it like the style we
have the stud voxel style", then "make it more detailed now it just looks like lego, look at other games"). Designs:
the Claude Design canvas "Mow And Grow Hub Remodel" (wheel booth, Top Mowers stage, Pet Garden).

Two layers per model, like the stud-built windmill and houses:
  * BRICKS: 1-stud voxels, built in Roblox as studded Plastic (server/StudKit's look), for the masses: floors, posts,
    hedges, pedestals, arches. Colours vary per plank / course / brick (a darker and a lighter shade of each), so
    no wall is one flat colour.
  * DETAIL: half-stud voxels, smooth, for everything small: trims, fringes, bulbs' sockets, bunting, flowers, lily
    pads, lanterns, trophies, the wheel's face.
A model's coordinates: x across, y up, z back to front with the FRONT at -z (Roblox's LookVector), the origin at the
bottom middle. `anchors` are named points in studs that the game hangs text, lights, prompts and eggs on.

    python3 tools/blender/hub/hub_models.py            # export src/shared/HubBrickData.luau + render previews
    python3 tools/blender/hub/hub_models.py --no-render
Previews go to $HUB_PREVIEWS (default assets/previews/hub).
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
OUT = os.path.join(ROOT, "src", "shared", "HubBrickData.luau")
PREVIEW_DIR = os.environ.get("HUB_PREVIEWS", os.path.join(ROOT, "assets", "previews", "hub"))

# --- colours (shared/HubBricks tones the studded ones down like StudKit) --------------------------------------------
BASE = {
    "cream": (245, 236, 214), "red": (226, 66, 56), "white": (250, 242, 230), "purple": (92, 56, 156),
    "gold": (255, 200, 60), "wood": (150, 98, 58), "woodDark": (98, 64, 40), "chalk": (47, 74, 58),
    "silver": (206, 214, 226), "bronze": (214, 132, 74), "iron": (58, 54, 72), "lamp": (255, 236, 160),
    "hedge": (66, 150, 60), "lawn": (148, 212, 106), "water": (94, 199, 240), "stone": (186, 180, 168),
    "soil": (120, 80, 50), "straw": (226, 186, 106), "leaf": (84, 176, 74), "trunk": (110, 72, 46),
    "pink": (255, 128, 176), "yellow": (255, 214, 64), "violet": (160, 130, 255), "orange": (255, 150, 60),
    "blue": (90, 170, 240), "teal": (80, 210, 200), "green": (110, 200, 90), "carpet": (196, 40, 52),
    "s1": (120, 200, 90), "s2": (90, 170, 240), "s3": (250, 200, 60), "s4": (240, 120, 170),
    "s5": (150, 110, 230), "s6": (255, 150, 60), "s7": (80, 220, 210), "s8": (255, 80, 80), "hubCap": (255, 248, 236),
}
PAL = {}
for _k, (_r, _g, _b) in BASE.items():
    PAL[_k] = (_r, _g, _b)
    PAL[_k + "_d"] = tuple(max(0, int(c * 0.86)) for c in (_r, _g, _b))
    PAL[_k + "_l"] = tuple(min(255, int(c * 1.09 + 6)) for c in (_r, _g, _b))
# smooth even as bricks: metal, glass, light, the wheel's face
SMOOTH_BASE = {"gold", "silver", "bronze", "water", "lamp", "hubCap", "s1", "s2", "s3", "s4", "s5", "s6", "s7", "s8"}
SMOOTH = {k for k in PAL if k.split("_")[0] in SMOOTH_BASE}


def h3(x, y, z, seed=0):
    n = (x * 73856093) ^ (y * 19349663) ^ (z * 83492791) ^ (seed * 2654435761)
    return (n & 0xFFFF) / 65535.0


def var(c, x, y, z, seed=0, spread=0.33):
    """A shade of colour c for this spot: mostly the base, sometimes darker or lighter."""
    r = h3(x, y, z, seed)
    if r < spread:
        return c + "_d"
    if r > 1 - spread * 0.7:
        return c + "_l"
    return c


class M:
    """A model being built: bricks (1-stud) and detail (half-stud), plus anchors."""

    def __init__(self):
        self.b = {}  # (x, y, z) studs -> colour
        self.f = {}  # (x, y, z) half studs -> colour
        self.a = {}

    def brick(self, x0, y0, z0, x1, y1, z1, c, vary=None, seed=0):
        """Bricks; vary: None (one colour), "voxel", "x" / "y" / "z" (one shade per row along that axis)."""
        for x in range(x0, x1):
            for y in range(y0, y1):
                for z in range(z0, z1):
                    if vary is None:
                        col = c
                    elif vary == "voxel":
                        col = var(c, x, y, z, seed)
                    else:
                        key = {"x": (x, 0, 0), "y": (0, y, 0), "z": (0, 0, z)}[vary]
                        col = var(c, *key, seed=seed)
                    self.b[(x, y, z)] = col

    def fine(self, x0, y0, z0, x1, y1, z1, c):
        """Detail in STUDS (multiples of 0.5); filled at half-stud resolution."""
        for x in range(int(round(x0 * 2)), int(round(x1 * 2))):
            for y in range(int(round(y0 * 2)), int(round(y1 * 2))):
                for z in range(int(round(z0 * 2)), int(round(z1 * 2))):
                    self.f[(x, y, z)] = c

    def dot(self, x, y, z, c):
        """One half-stud voxel at (x, y, z) in studs (its low corner)."""
        self.f[(int(round(x * 2)), int(round(y * 2)), int(round(z * 2)))] = c


# --- little props in detail voxels ----------------------------------------------------------------------------------
def flower(m, x, y, z, c):
    m.fine(x + 0.25, y, z + 0.25, x + 0.75, y + 0.5, z + 0.75, "leaf_d")
    m.fine(x, y + 0.5, z, x + 1, y + 1, z + 1, c)
    m.dot(x + 0.25, y + 1, z + 0.25, "yellow_l" if c != "yellow" else "orange")


def lantern(m, x, y, z):
    """A hanging lantern, 1 x 1.5 studs, top at y."""
    m.fine(x + 0.25, y - 0.5, z + 0.25, x + 0.75, y, z + 0.75, "iron")
    m.fine(x, y - 1.5, z, x + 1, y - 0.5, z + 1, "lamp")
    m.fine(x, y - 2, z, x + 1, y - 1.5, z + 1, "iron")


def bunting(m, xa, xb, y, z, colours, sag=1.5):
    """A string of little triangle flags from xa to xb, hanging lower in the middle."""
    n = int((xb - xa) * 2)
    for i in range(n):
        x = xa + i * 0.5
        t = (x - xa) / max(0.001, xb - xa)
        yy = y - sag * math.sin(math.pi * t)
        yy = round(yy * 2) / 2
        m.dot(x, yy, z, "white_d")
        if i % 3 == 1:
            c = colours[(i // 3) % len(colours)]
            m.fine(x - 0.5, yy - 0.5, z, x + 1, yy, z + 0.5, c)
            m.fine(x - 0.0, yy - 1.0, z, x + 0.5, yy - 0.5, z + 0.5, c)


def gems(m, x, y, z):
    """A little pile of gems (prizes)."""
    cols = ["teal", "violet", "blue", "pink", "teal_l"]
    for i, (dx, dz, dy) in enumerate([(0, 0, 0), (0.5, 0, 0), (1, 0.5, 0), (0.5, 0.5, 0.5), (0, 0.5, 0), (1, 0, 0), (0.5, 1, 0)]):
        m.dot(x + dx, y + dy, z + dz, cols[i % len(cols)])


def giftbox(m, x, y, z, c, ribbon):
    m.fine(x, y, z, x + 1.5, y + 1.5, z + 1.5, c)
    m.fine(x + 0.5, y, z - 0.01, x + 1, y + 1.5, z + 1.5, ribbon)
    m.fine(x, y + 1.5, z + 0.5, x + 1.5, y + 2, z + 1, ribbon)


def trophy(m, x, y, z, c="gold"):
    m.fine(x, y, z, x + 1.5, y + 0.5, z + 1.5, "woodDark")
    m.fine(x + 0.5, y + 0.5, z + 0.5, x + 1, y + 1.5, z + 1, c + "_d")
    m.fine(x, y + 1.5, z, x + 1.5, y + 3, z + 1.5, c)
    m.fine(x - 0.5, y + 2, z + 0.5, x, y + 2.5, z + 1, c)
    m.fine(x + 1.5, y + 2, z + 0.5, x + 2, y + 2.5, z + 1, c)
    m.fine(x + 0.5, y + 2.5, z + 0.5, x + 1, y + 3, z + 1, c + "_d")


def bush(m, cx, cz, r, seed):
    rnd = random.Random(seed)
    for x in range(int(cx - r) - 1, int(cx + r) + 1):
        for z in range(int(cz - r) - 1, int(cz + r) + 1):
            d = math.hypot(x + 0.5 - cx, z + 0.5 - cz)
            if d < r:
                hgt = 1 + (1 if d < r * 0.6 else 0)
                m.brick(x, 0, z, x + 1, hgt, z + 1, "hedge", "voxel", seed)
                if rnd.random() < 0.25:
                    flower(m, x, hgt, z, rnd.choice(["pink", "yellow", "white", "violet"]))


# --- 1. the wheel booth (still) -------------------------------------------------------------------------------------
def wheel_booth():
    m = M()
    # a stone footing, two steps up at the front, a plank floor (one shade per plank)
    m.brick(-11, 0, -5, 11, 1, 4, "stone", "voxel", 1)
    m.brick(-9, 0, -7, 9, 1, -5, "stone", "voxel", 2)
    m.brick(-10, 1, -5, 10, 2, 4, "wood", "x", 3)
    m.fine(-10, 1.5, -5.5, 10, 2, -5, "woodDark")  # the floor's front edge
    # candy-stripe posts on dark plinths, gold finials
    for px in (-9, 7):
        m.brick(px - 1, 2, -2, px + 3, 3, 2, "woodDark")
        for y in range(3, 17):
            for dx in range(2):
                for dz in range(2):
                    m.b[(px + dx, y, -1 + dz)] = "red" if ((y + dx + dz) // 2) % 2 == 0 else "white"
        m.fine(px - 0.25, 16.5, -1.25, px + 2.25, 17, 1.25, "gold")
        lantern(m, px + 0.5, 13, -2.5)
        m.fine(px + 0.75, 13, -2, px + 1.25, 13.5, -1, "iron")
    # the crossbar the axle hangs on
    m.brick(-9, 9, 1, 9, 10, 2, "woodDark")
    m.brick(-1, 8, 0, 1, 10, 2, "woodDark")
    m.fine(-0.5, 8.5, -0.5, 0.5, 9.5, 0, "gold")
    # the canopy: striped, a gold edge, a scalloped fringe of half studs, a stepped roof with a flag on top
    for x in range(-11, 11):
        c = "red" if ((x + 11) // 2) % 2 == 0 else "white"
        for z in range(-4, 3):
            m.b[(x, 17, z)] = c
            m.b[(x, 18, z)] = c
        if -10 <= x < 10:
            for z in range(-3, 2):
                m.b[(x, 19, z)] = c
        if -9 <= x < 9:
            for z in range(-2, 1):
                m.b[(x, 20, z)] = c
    m.fine(-11, 17, -4.5, 11, 17.5, -4, "gold")
    for i in range(44):
        x = -11 + i * 0.5
        c = "red" if (int((x + 11) // 2)) % 2 == 0 else "white"
        drop = [1.5, 1.0, 0.5, 1.0][i % 4]
        m.fine(x, 17 - drop, -4.5, x + 0.5, 17, -4, c)
    m.fine(-0.25, 21, -0.75, 0.25, 25, -0.25, "woodDark")
    m.fine(0.25, 23.5, -0.75, 2.25, 25, -0.25, "yellow")
    m.fine(0.25, 24, -0.75, 1.25, 24.5, -0.25, "red")
    # the marquee on top: purple in a gold frame, stars either side
    m.brick(-7, 21, -3, 7, 26, -2, "purple", "voxel", 4)
    m.fine(-7.5, 20.5, -3.5, 7.5, 21, -3, "gold")
    m.fine(-7.5, 26, -3.5, 7.5, 26.5, -3, "gold")
    m.fine(-7.5, 21, -3.5, -7, 26, -3, "gold")
    m.fine(7, 21, -3.5, 7.5, 26, -3, "gold")
    for sx in (-9.5, 8):
        for dx, dy in [(0.5, 0), (0.5, 0.5), (0, 0.5), (1, 0.5), (0.5, 1), (0.5, 1.5), (0, 1), (1, 1)]:
            m.dot(sx + dx, 22.5 + dy, -3.5, "gold")
    m.a["marquee"] = (0, 23.5, -3.5)
    # the pointer over the wheel, in front of it: red with a gold rim
    m.fine(-1.5, 15, -2.5, 1.5, 15.5, -1, "gold")
    m.fine(-1, 14.5, -2.5, 1, 15, -1, "red")
    m.fine(-0.5, 14, -2.5, 0.5, 14.5, -1, "red")
    m.fine(-0.25, 13.5, -2.5, 0.25, 14, -1, "red_d")
    # bunting across the front, under the canopy
    bunting(m, -8, 8, 16, -2.5, ["blue", "yellow", "pink", "teal", "orange"], 1.2)
    # the prize shelf on the viewer's left (model +x): a plank shelf on legs, gems, gift boxes, a plush critter
    m.brick(10, 2, -3, 15, 3, 1, "wood", "x", 5)
    for lx in (10, 14):
        m.brick(lx, 0, -3, lx + 1, 2, -2, "woodDark")
    m.brick(10, 3, 0, 15, 6, 1, "wood", "y", 6)
    gems(m, 10.5, 3, -2.5)
    giftbox(m, 12, 3, -2.5, "blue", "yellow")
    giftbox(m, 13.25, 3, -1.25, "pink", "white")
    # a plush bunny on the shelf
    m.fine(11, 3, -1, 12, 4, 0, "white")
    m.fine(11, 4, -1, 12, 4.5, 0, "white_l")
    m.fine(11, 4.5, -0.75, 11.5, 5.5, -0.25, "white")
    m.fine(11.5, 4.5, -0.75, 12, 5.5, -0.25, "white")
    m.dot(11, 4, -1.5, "iron")
    m.dot(11.5, 4, -1.5, "iron")
    # the odds board on the viewer's right (model -x): an easel, a chalkboard in a wooden frame, a chalk tray
    m.brick(-17, 0, -1, -16, 5, 0, "woodDark")
    m.brick(-12, 0, -1, -11, 5, 0, "woodDark")
    m.brick(-19, 4, -1, -9, 16, 0, "wood", "y", 7)
    m.brick(-18, 5, -2, -10, 15, -1, "chalk", "voxel", 8)
    m.fine(-18, 4.5, -3, -10, 5, -2, "woodDark")
    m.dot(-16, 5, -2.5, "white")
    m.dot(-15, 5, -2.5, "yellow")
    m.fine(-19.5, 16, -1.5, -8.5, 16.5, 0.5, "gold")
    m.a["odds"] = (-14, 10, -2)
    # flowers and little bushes round the footing
    for x, z, c in [(-11, -6, "pink"), (-10, -6, "yellow"), (9, -6, "violet"), (10, -6, "pink"), (-11, 2, "white"), (10, 2, "yellow")]:
        flower(m, x, 1, z, c)
    m.a["wheel"] = (0, 8.9, -0.5)  # the wheel's middle (client/HubWheel turns the "wheel" model there)
    m.a["prompt"] = (0, 3, -6)
    return m


# --- 2. the wheel (turns): 8 slices in the order of Config.HUB_FUN.prizes, slice 1 at the top, counter-clockwise ---
def wheel():
    m = M()
    for x in range(-14, 14):
        for y in range(-14, 14):
            cx, cy = x + 0.5, y + 0.5
            r = math.hypot(cx, cy)
            if r > 13.6:
                continue
            ang = math.atan2(-cx, cy)  # 0 at the top, counter-clockwise as you look at it
            if r > 12.6:
                c = "gold"
            elif r > 11.2:
                c = "woodDark" if (int((ang + math.pi) / (math.pi / 16))) % 2 else "wood"
            elif r < 2.6:
                c = "hubCap" if r < 1.8 else "gold"
            else:
                i = int(math.floor((ang + math.pi / 8) / (math.pi / 4))) % 8
                c = "s%d" % (i + 1)
                # a slightly lighter band round the outer edge of each slice
                if r > 10.2:
                    c += "_l"
            m.f[(x, y, 0)] = c
            m.f[(x, y, 1)] = c
    return m


# --- 3. the Top Mowers stage ----------------------------------------------------------------------------------------
def podium_stage():
    m = M()
    # a stone base, a plank stage on it (one shade per plank), two steps up at the front, a red carpet to #1
    m.brick(-15, 0, -8, 15, 1, 7, "stone", "voxel", 11)
    m.brick(-15, 1, -7, 15, 2, 7, "wood", "x", 12)
    m.brick(-12, 0, -10, 12, 1, -8, "stone", "voxel", 13)
    m.fine(-15, 1.5, -7.5, 15, 2, -7, "woodDark")
    m.fine(-2, 2, -7.5, 2, 2.5, -3, "carpet")
    m.fine(-2.5, 2, -7.5, -2, 2.5, -3, "gold")
    m.fine(2, 2, -7.5, 2.5, 2.5, -3, "gold")
    m.fine(-2, 1, -10, 2, 1.5, -7.5, "carpet")
    places = [("1", -3, 10, "gold"), ("2", 5, 8, "silver"), ("3", -11, 6, "bronze")]  # #2 on the viewer's left
    for n, x0, h, metal in places:
        m.brick(x0, 2, -3, x0 + 6, 3, 3, "woodDark")  # a dark plinth
        m.brick(x0, 3, -3, x0 + 6, h, 3, "cream", "y", 20 + int(n))
        m.fine(x0 - 0.5, h, -3.5, x0 + 6.5, h + 1, 3.5, metal)  # the metal top, overhanging
        m.fine(x0 - 0.5, h - 0.5, -3.5, x0 + 6.5, h, -3, metal + "_d")
        # the name plaque: a dark frame, a plank face
        m.fine(x0 + 0.5, 3.5, -3.5, x0 + 5.5, 6, -3, "woodDark")
        m.fine(x0 + 1, 4, -3.75, x0 + 5, 5.5, -3.5, "wood")
        for sx in (x0 + 0.75, x0 + 5):
            m.dot(sx, 5.5, -3.75, "gold")
            m.dot(sx, 3.75, -3.75, "gold")
        m.a["plaque" + n] = (x0 + 3, 4.75, -3.75)
        m.a["top" + n] = (x0 + 3, h + 1, 0)
        # a star on the front over the plaque
        if h - 6 >= 2:
            sy = 6.5 + (h - 7) / 2 - 0.5
            for dx, dy in [(0.5, 0), (0.5, 0.5), (0, 0.5), (1, 0.5), (0.5, 1), (0, 0), (1, 0)]:
                m.dot(x0 + 2.5 + dx, sy + dy, -3.5, metal)
    # the arch behind: columns with bases and capitals, a stepped crown, gold lines, tassels, a crown on top
    for px in (-15, 13):
        m.brick(px - 1, 2, 3, px + 3, 3, 7, "stone", "voxel", 30 + px)
        m.brick(px, 3, 4, px + 2, 20, 6, "purple", "y", 31)
        m.brick(px - 1, 20, 3, px + 3, 21, 7, "gold")
        for y in (6, 10, 14):
            m.fine(px - 0.5, y, 3.5, px + 2.5, y + 0.5, 6.5, "gold")
        # a long purple pennant down the column's front
        m.fine(px + 0.5, 11, 3.5, px + 1.5, 19, 4, "purple_l")
        m.fine(px + 0.5, 10.5, 3.5, px + 1, 11, 4, "purple_l")
        m.fine(px + 0.25, 18.5, 3.25, px + 1.75, 19, 3.5, "gold")
    m.brick(-15, 21, 4, 15, 25, 6, "purple", "voxel", 32)
    m.brick(-10, 25, 4, 10, 27, 6, "purple", "voxel", 33)
    m.brick(-5, 27, 4, 5, 28, 6, "purple", "voxel", 34)
    for y in (21, 24.5):
        m.fine(-15, y, 3.5, 15, y + 0.5, 4, "gold")
    m.fine(-10, 26.5, 3.5, 10, 27, 4, "gold")
    for i in range(30):
        x = -15 + i
        if i % 2 == 0:
            m.fine(x + 0.25, 20, 3.5, x + 0.75, 21, 4, "gold")
            m.dot(x + 0.25, 19.5, 3.5, "gold_d")
    # the crown
    m.fine(-2, 28, 4.5, 2, 29, 5.5, "gold")
    for x in (-2, -0.25, 1.5):
        m.fine(x, 29, 4.5, x + 0.5, 30, 5.5, "gold")
    m.dot(-0.25, 30, 4.5, "red")
    m.dot(-1.25, 28.5, 4.25, "blue")
    m.dot(0.75, 28.5, 4.25, "teal")
    m.a["banner"] = (0, 22.75, 4)
    # laurels: leaves climbing the inner side of each column
    for px, side in ((-12.5, 1), (12, -1)):
        for i in range(16):
            y = 6 + i * 0.75
            dx = math.sin(i / 15 * math.pi) * 1.5 * side
            m.dot(px + dx, y, 3.5, "leaf" if i % 2 else "leaf_d")
            m.dot(px + dx + 0.5 * side, y + 0.25, 3.5, "leaf_l")
    # two ornate lamp posts at the front corners
    for px in (-17, 16):
        m.brick(px - 1, 0, -9, px + 2, 1, -6, "stone", "voxel", 40)
        m.fine(px, 1, -8, px + 1, 13, -7, "iron")
        m.fine(px - 0.5, 1, -8.5, px + 1.5, 2, -6.5, "iron_d")
        m.fine(px - 0.5, 13, -8.5, px + 1.5, 13.5, -6.5, "iron_d")
        m.fine(px - 0.5, 13.5, -8.5, px + 1.5, 15.5, -6.5, "lamp")
        m.fine(px - 1, 15.5, -9, px + 2, 16, -6, "iron")
        m.fine(px - 0.5, 16, -8.5, px + 1.5, 16.5, -6.5, "iron")
        m.fine(px, 16.5, -8, px + 1, 17, -7, "gold")
        m.a["lamp%s" % ("R" if px < 0 else "L")] = (px + 0.5, 14.5, -7.5)
    # trophies and flower pots on the stage's front corners
    trophy(m, -13.5, 2, -6.5, "gold")
    trophy(m, 11.5, 2, -6.5, "gold")
    for x in (-15, 13.5):
        m.fine(x, 2, -4, x + 1.5, 3, -2.5, "orange_d")
        flower(m, x + 0.25, 3, -3.75, "pink")
        flower(m, x + 0.75, 3, -3.25, "yellow")
    return m


# --- 4. the Pet Garden ----------------------------------------------------------------------------------------------
def pet_garden():
    # (10 Nov, owner: "proportion the garden to make it fit ... why is it not in the middle") a compact garden that
    # sits ON the path south of the spawn, its gate to the spawn and a back gate on to the lookout, so the path runs
    # through it: hedge ring r 9-11 (was 11.5-13.6), the eggs just outside the front gate. 27.5 studs front to back.
    m = M()
    rnd = random.Random(7)
    R_IN, R_OUT = 9.0, 11.0
    pond = (5.0, 2.0, 2.4)
    beds = [(-5.5, -3.5), (5.0, -4.5)]
    tree = (-6.5, 2.5)
    for x in range(-11, 11):
        for z in range(-11, 11):
            cx, cz = x + 0.5, z + 0.5
            r = math.hypot(cx, cz)
            gate = abs(cx) < 2.6  # the way through, front and back
            if R_IN <= r < R_OUT and not gate:
                hgt = 3 if h3(x, 0, z, 9) > 0.7 else 2
                m.brick(x, 0, z, x + 1, hgt, z + 1, "hedge", "voxel", 5)
                if h3(x, 1, z, 3) > 0.86:
                    flower(m, x, hgt, z, rnd.choice(["pink", "white", "yellow"]))
            elif r < R_OUT and gate and r >= R_IN - 0.5:
                m.b[(x, 0, z)] = var("stone", x, 0, z, 2)
            elif r < R_IN:
                pr = math.hypot(cx - pond[0], cz - pond[1])
                if pr < pond[2]:
                    m.b[(x, 0, z)] = "water_d" if pr < pond[2] - 1.2 else "water"
                elif pr < pond[2] + 1.0:
                    m.b[(x, 0, z)] = var("stone", x, 0, z, 4)
                    if h3(x, 2, z, 1) > 0.55:
                        m.b[(x, 1, z)] = var("stone", x, 1, z, 6)
                else:
                    m.b[(x, 0, z)] = "lawn" if (z // 2) % 2 == 0 else "lawn_d"  # mown stripes
                    if h3(x, 3, z, 2) > 0.9:
                        m.dot(x + 0.25, 1, z + 0.25, "leaf_d")
                        m.dot(x + 0.25, 1.5, z + 0.25, "leaf")
    # the pond: lily pads with a flower, reeds, a little plank bridge over its near side
    px, pz = pond[0], pond[1]
    for (lx, lz, fl) in [(-0.5, -1, True), (1, 1, False), (-0.5, 1.5, True)]:
        m.fine(px + lx, 1, pz + lz, px + lx + 1.5, 1.25 + 0.25, pz + lz + 1, "green")
        if fl:
            m.dot(px + lx + 0.5, 1.5, pz + lz + 0.25, "pink")
    for (rx, rz) in [(2.5, 2), (3, -1.5), (-2.5, 2.5)]:
        m.fine(px + rx, 1, pz + rz, px + rx + 0.5, 3, pz + rz + 0.5, "leaf_d")
        m.fine(px + rx, 3, pz + rz, px + rx + 0.5, 4, pz + rz + 0.5, "trunk")
    for i in range(6):
        m.fine(px - 2.5 + i * 0.5, 1.5, pz - 1.5, px - 2 + i * 0.5, 2, pz + 1.5, "wood" if i % 2 else "wood_d")
    m.fine(px - 2.5, 2, pz - 1.5, px + 0.5, 2.5, pz - 1, "woodDark")
    m.fine(px - 2.5, 2, pz + 1, px + 0.5, 2.5, pz + 1.5, "woodDark")
    # stepping stones from the front gate to the back gate
    for i, z in enumerate(range(-9, 9, 2)):
        x0 = -1 + (1 if i % 2 else -1)
        for x in range(x0, x0 + 2):
            m.b[(x, 0, z)] = var("stone", x, 0, z, 8)
        m.fine(x0, 1, z, x0 + 2, 1.25 + 0.25, z + 1, "stone_l")
    # flower beds: a plank border, soil, flowers on stems
    flowers = ["pink", "yellow", "violet", "white", "orange"]
    for bx, bz in beds:
        for x in range(int(math.floor(bx)) - 3, int(math.floor(bx)) + 3):
            for z in range(int(math.floor(bz)) - 2, int(math.floor(bz)) + 3):
                d = math.hypot(x + 0.5 - bx, z + 0.5 - bz)
                if d < 2.4:
                    m.b[(x, 1, z)] = "wood_d" if d > 1.6 else var("soil", x, 1, z, 3)
                    if d <= 1.6 and rnd.random() < 0.7:
                        flower(m, x, 2, z, rnd.choice(flowers))
    # a tree at the side: a trunk, a lumpy round crown with fruit
    tx, tz = int(tree[0]), int(tree[1])
    m.brick(tx, 1, tz, tx + 2, 7, tz + 2, "trunk", "y", 2)
    m.brick(tx - 1, 1, tz, tx, 2, tz + 1, "trunk_d")
    m.brick(tx + 2, 1, tz + 1, tx + 3, 2, tz + 2, "trunk_d")
    for x in range(tx - 4, tx + 6):
        for y in range(6, 12):
            for z in range(tz - 4, tz + 6):
                d = math.hypot(x + 0.5 - (tx + 1), (y + 0.5 - 8.8) * 1.25, z + 0.5 - (tz + 1))
                if d < 4.2 + (h3(x, y, z, 12) - 0.5) * 0.9:
                    m.b[(x, y, z)] = var("leaf", x, y, z, 11)
                    if d > 3.4 and h3(x, y, z, 13) > 0.93:
                        m.dot(x + 0.25, y + 0.25, z - 0.25, "red")
    # mushrooms by the tree, a bench by the back gate, a birdhouse on the right
    for (mx, mz) in [(-7.5, -0.5), (-7, 0.5), (-3.5, 6)]:
        m.fine(mx, 1, mz, mx + 0.5, 1.5, mz + 0.5, "white")
        m.fine(mx - 0.25, 1.5, mz - 0.25, mx + 0.75, 2, mz + 0.75, "red")
        m.dot(mx, 2, mz, "white")
    m.fine(2.5, 1, 5.5, 5.5, 1.5, 6.5, "wood")
    m.fine(2.5, 1.5, 5.5, 5.5, 2, 6.5, "wood_l")
    m.fine(2.5, 2, 6.5, 5.5, 3, 7, "wood")
    for lx in (2.5, 5):
        m.fine(lx, 1, 5.5, lx + 0.5, 1.5, 7, "woodDark")
    m.fine(7.5, 1, -1.5, 8, 5, -1, "woodDark")
    m.fine(7, 5, -2, 8.5, 6.5, -0.5, "red")
    m.fine(6.75, 6.5, -2.25, 8.75, 7, -0.25, "woodDark")
    m.dot(7.5, 5.5, -2.25, "iron")
    # the gate arch: stone-footed posts, a curved plank top, flowers climbing, lanterns, the sign
    for px2 in (-4, 3):
        m.brick(px2, 0, -11, px2 + 1, 1, -9, "stone")
        m.brick(px2, 1, -11, px2 + 1, 8, -9, "woodDark", "y", 7)
        for y in range(2, 8, 2):
            flower(m, px2 + (0.75 if px2 > 0 else -0.75), y, -11.5, flowers[y % len(flowers)])
        lantern(m, px2 + (1.25 if px2 > 0 else -1.25), 7.5, -10.5)
    m.brick(-5, 8, -11, 5, 9, -9, "wood", "x", 9)
    m.brick(-4, 9, -11, 4, 10, -9, "wood", "x", 10)
    m.brick(-2, 10, -11, 2, 11, -9, "wood", "x", 11)
    for x in range(-5, 5, 2):
        flower(m, x, 9, -11.5, flowers[(x // 2) % len(flowers)])
    m.fine(-3, 6.5, -11.5, 3, 8, -11, "wood_l")
    m.a["sign"] = (0, 7.25, -11.5)
    # the back gate: two low stone posts with a lantern each
    for px2 in (-4, 3):
        m.brick(px2, 0, 9, px2 + 1, 3, 11, "stone", "y", 12)
        lantern(m, px2 + 0.25, 3, 9.75)
    # the egg nests outside, either side of the way in: a stone pedestal with a plank trim, a straw nest
    for name, nx in (("nestA", 5), ("nestB", -8)):
        m.brick(nx, 0, -16, nx + 3, 2, -13, "stone", "voxel", 14 + nx)
        m.fine(nx - 0.5, 2, -16.5, nx + 3.5, 2.5, -12.5, "wood")
        for i in range(12):
            a = i / 12 * 2 * math.pi
            m.dot(nx + 1.25 + math.cos(a) * 1.25, 2.5, -14.75 + math.sin(a) * 1.25, "straw" if i % 2 else "straw_d")
            m.dot(nx + 1.25 + math.cos(a) * 1.0, 3.0, -14.75 + math.sin(a) * 1.0, "straw_l")
        m.fine(nx + 0.5, 2.5, -15.5, nx + 2.5, 3, -13.5, "straw_d")
        m.a[name] = (nx + 1.5, 3, -14.5)
        m.a[name + "Sign"] = (nx + 1.5, 1, -16.5)
    m.a["pond"] = pond
    m.a["beds"] = beds
    m.a["tree"] = (tree[0] + 1, tree[1] + 1, 3)
    m.a["lawnR"] = R_IN - 1
    return m


MODELS = {"wheel_booth": wheel_booth, "wheel": wheel, "podium_stage": podium_stage, "pet_garden": pet_garden}


# --- greedy merge ---------------------------------------------------------------------------------------------------
def merge(vox):
    left = dict(vox)
    boxes = []
    for key in sorted(vox, key=lambda k: (k[1], k[2], k[0])):
        if key not in left:
            continue
        c = left[key]
        x0, y0, z0 = key
        x1 = x0 + 1
        while left.get((x1, y0, z0)) == c:
            x1 += 1
        z1 = z0 + 1
        while all(left.get((x, y0, z1)) == c for x in range(x0, x1)):
            z1 += 1
        y1 = y0 + 1
        while all(left.get((x, y1, z)) == c for x in range(x0, x1) for z in range(z0, z1)):
            y1 += 1
        for x in range(x0, x1):
            for y in range(y0, y1):
                for z in range(z0, z1):
                    del left[(x, y, z)]
        boxes.append((x0, y0, z0, x1, y1, z1, c))
    return boxes


def lua_value(val):
    if isinstance(val, (list, tuple)) and val and isinstance(val[0], (list, tuple)):
        return "{ " + ", ".join(lua_value(x) for x in val) + " }"
    if isinstance(val, (list, tuple)):
        return "{ " + ", ".join(fmt(x) for x in val) + " }"
    return fmt(val)


def fmt(x):
    if isinstance(x, float):
        s = ("%.3f" % x).rstrip("0").rstrip(".")
        return s if s not in ("", "-0") else "0"
    return str(x)


def export(built):
    lines = [
        "-- GENERATED by tools/blender/hub/hub_models.py (do not edit by hand: change the script and run it again).",
        "-- The hub's extras as stud-voxel models: bricks { x0, y0, z0, x1, y1, z1, colour } in studs (studded) and detail",
        "-- { x0, y0, z0, x1, y1, z1, colour } in HALF studs (smooth), in the model's own space (front = -z, origin = the",
        "-- bottom middle); the colours, which colours are smooth, and named anchor points (studs).",
        "return {",
        "\tcolours = {",
    ]
    for k in sorted(PAL):
        r, g, b = PAL[k]
        lines.append("\t\t[\"%s\"] = Color3.fromRGB(%d, %d, %d)," % (k, r, g, b))
    lines.append("\t},")
    lines.append("\tsmooth = { " + ", ".join("[\"%s\"] = true" % k for k in sorted(SMOOTH)) + " },")
    lines.append("\tmodels = {")
    for name, (bricks, detail, anchors) in built.items():
        lines.append("\t\t%s = {" % name)
        for key, boxes in (("bricks", bricks), ("detail", detail)):
            lines.append("\t\t\t%s = {" % key)
            for b in boxes:
                lines.append('\t\t\t\t{ %d, %d, %d, %d, %d, %d, "%s" },' % b)
            lines.append("\t\t\t},")
        lines.append("\t\t\tanchors = {")
        for k in sorted(anchors):
            lines.append("\t\t\t\t%s = %s," % (k, lua_value(anchors[k])))
        lines.append("\t\t\t},")
        lines.append("\t\t},")
    lines.append("\t},")
    lines.append("}")
    with open(OUT, "w") as f:
        f.write("\n".join(lines) + "\n")


# --- previews (Cycles; studs as little cylinders on the bricks' open tops) ------------------------------------------
def render(name, model, extra=None):
    import bpy
    import bmesh
    from mathutils import Vector

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    mats = {}

    def mat(c):
        if c not in mats:
            mm = bpy.data.materials.new(c)
            mm.use_nodes = True
            bsdf = mm.node_tree.nodes["Principled BSDF"]
            r, g, b = [(x / 255) ** 2.2 for x in PAL[c]]
            k = 1.0 if c in SMOOTH else 0.85
            bsdf.inputs["Base Color"].default_value = (r * k, g * k, b * k, 1)
            bsdf.inputs["Roughness"].default_value = 0.25 if c in SMOOTH else 0.45
            if c.startswith("lamp"):
                bsdf.inputs["Emission Color"].default_value = (1, 0.85, 0.5, 1)
                bsdf.inputs["Emission Strength"].default_value = 3
            mats[c] = mm
        return mats[c]

    bm_by = {}

    def add_boxes(boxes, k, ox=0.0, oy=0.0, oz=0.0):
        for (x0, y0, z0, x1, y1, z1, c) in boxes:
            bm = bm_by.setdefault(c, bmesh.new())
            lo = Vector((x0 * k + ox, -(z1 * k + oz), y0 * k + oy))
            hi = Vector((x1 * k + ox, -(z0 * k + oz), y1 * k + oy))
            g = bmesh.ops.create_cube(bm, size=1)
            for vert in g["verts"]:
                vert.co = Vector((lo.x + (vert.co.x + 0.5) * (hi.x - lo.x) * 0.996, lo.y + (vert.co.y + 0.5) * (hi.y - lo.y) * 0.996, lo.z + (vert.co.z + 0.5) * (hi.z - lo.z) * 0.996))

    add_boxes(merge(model.b), 1)
    add_boxes(merge(model.f), 0.5)
    if extra:
        em, (ex, ey, ez) = extra
        add_boxes(merge(em.f), 0.5, ex, ey, ez)
    for (x, y, z), c in model.b.items():
        if c in SMOOTH or (x, y + 1, z) in model.b:
            continue
        bm = bm_by[c]
        g = bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=0.3, radius2=0.3, depth=0.2)
        for vert in g["verts"]:
            vert.co += Vector((x + 0.5, -(z + 0.5), y + 1.1))
    for c, bm in bm_by.items():
        me = bpy.data.meshes.new(c)
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new(c, me)
        ob.data.materials.append(mat(c))
        scene.collection.objects.link(ob)
    bpy.ops.mesh.primitive_plane_add(size=300, location=(0, 0, 0))
    ground = bpy.context.object
    gm = bpy.data.materials.new("ground")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.22, 0.5, 0.14, 1)
    ground.data.materials.append(gm)
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 3.4
    sun.angle = math.radians(8)
    so = bpy.data.objects.new("sun", sun)
    so.rotation_euler = (math.radians(48), math.radians(-18), math.radians(-35))
    scene.collection.objects.link(so)
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.75, 0.95, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
    scene.world = world
    pts = [Vector((x, -z, y)) for (x, y, z) in model.b] + [Vector((x / 2, -z / 2, y / 2)) for (x, y, z) in model.f]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    mid = (lo + hi) / 2
    size = max(hi - lo)
    cam = bpy.data.cameras.new("cam")
    cam.lens = 45
    co = bpy.data.objects.new("cam", cam)
    flat = name == "pet_garden"
    off = Vector((-size * 0.42, size * (0.95 if flat else 1.35), size * (0.85 if flat else 0.42)))
    co.location = mid + off
    co.rotation_euler = (mid - co.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(co)
    scene.camera = co
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1000
    scene.render.resolution_y = 760
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    scene.render.filepath = os.path.join(PREVIEW_DIR, name + ".png")
    bpy.ops.render.render(write_still=True)


def main():
    built = {}
    models = {}
    for name, fn in MODELS.items():
        m = fn()
        models[name] = m
        bricks, detail = merge(m.b), merge(m.f)
        built[name] = (bricks, detail, m.a)
        print("%s: %d + %d voxels -> %d bricks + %d detail" % (name, len(m.b), len(m.f), len(bricks), len(detail)))
    export(built)
    print("wrote", OUT)
    if "--no-render" not in sys.argv:
        only = [a for a in sys.argv[1:] if not a.startswith("--")]
        for name, m in models.items():
            if name == "wheel" or (only and name not in only):
                continue
            extra = None
            if name == "wheel_booth":
                ax, ay, az = m.a["wheel"]
                extra = (models["wheel"], (ax, ay, az - 0.5))
            render(name, m, extra)


if __name__ == "__main__":
    main()
