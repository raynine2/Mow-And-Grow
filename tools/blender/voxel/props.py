"""The hub: buildings, stalls, boards and dressing as detailed voxel models.

The buildings keep the size and layout of the toy models they replace (the game's colliders, prompts and text
panels are placed in those models' studs), so: front is -z, the model's origin is voxel (0, 0, 0)'s corner times
the voxel size, and ADJUST nudges a model against the toy's origin. A model can be several meshes (a coarse
structure plus fine detail at a smaller voxel): a function returns either (voxels, palette, voxel_size) or
{piece: (voxels, palette, voxel_size)}.

Colours come from small fixed families (each with a dark/mid/light/highlight step) so the props' shared atlas
stays small, and every surface still gets variation: logs alternate, stones mix, shingles step, planks knot."""
import math
import random

# --- colour families ---------------------------------------------------------------------------------------------
LOG = [(96, 58, 36), (122, 76, 46), (146, 94, 58), (170, 116, 74)]
PLANK = [(150, 98, 58), (176, 120, 72), (198, 142, 88), (216, 164, 108)]
DARKWOOD = [(58, 38, 28), (74, 48, 34), (92, 60, 40)]
STONE = [(104, 104, 114), (128, 128, 136), (150, 150, 158), (172, 172, 178)]
MOSS = [(70, 130, 56), (92, 156, 64)]
ROOF_RED = [(150, 48, 40), (184, 62, 48), (212, 84, 58), (234, 112, 72)]
ROOF_TEAL = [(32, 96, 112), (44, 124, 140), (60, 150, 162), (92, 182, 186)]
CLOTH_RED = [(200, 52, 52), (232, 72, 66)]
CLOTH_WHITE = [(232, 228, 216), (250, 246, 236)]
GOLD = [(196, 140, 36), (232, 178, 52), (255, 210, 80), (255, 236, 150)]
IRON = [(40, 40, 48), (58, 58, 68), (84, 84, 96)]
STEEL = [(150, 156, 168), (186, 192, 204), (214, 220, 230)]
WARM = [(255, 196, 96), (255, 226, 150)]  # lit windows and lantern glass (bright paint, not neon)
GREEN = [(52, 126, 52), (70, 154, 62), (96, 182, 72)]
LEAF = [(44, 120, 54), (62, 150, 64), (90, 178, 78)]
FLOWERS = [(255, 92, 120), (255, 214, 64), (250, 250, 250), (150, 120, 255), (255, 150, 60)]
ORANGE = [(220, 104, 30), (248, 140, 40), (255, 176, 70)]
YELLOW = [(230, 180, 40), (255, 210, 60)]
BLACK = [(30, 28, 34), (44, 42, 50)]
TEAL = [(40, 150, 150), (60, 184, 176)]
PURPLE = [(110, 70, 170), (140, 96, 206)]
BLUE = [(50, 110, 200), (70, 140, 230)]
PINK = [(240, 110, 170), (255, 150, 200)]
BOARD = (40, 34, 46)  # the dark face the game writes text on


def rng_at(*k):
    return random.Random(repr(k))  # stable between runs


class V:
    """A voxel canvas. Colours are rgb tuples; the palette is built as they're used."""

    def __init__(self, vs):
        self.vox = {}
        self.pal = []
        self.idx = {}
        self.vs = vs

    def put(self, p, rgb):
        rgb = tuple(int(c) for c in rgb)
        i = self.idx.get(rgb)
        if i is None:
            i = len(self.pal)
            self.idx[rgb] = i
            self.pal.append(rgb)
        self.vox[p] = i

    def box(self, a, b, col):
        for x in range(min(a[0], b[0]), max(a[0], b[0]) + 1):
            for y in range(min(a[1], b[1]), max(a[1], b[1]) + 1):
                for z in range(min(a[2], b[2]), max(a[2], b[2]) + 1):
                    self.put((x, y, z), col(x, y, z) if callable(col) else col)

    def clear(self, a, b):
        for x in range(min(a[0], b[0]), max(a[0], b[0]) + 1):
            for y in range(min(a[1], b[1]), max(a[1], b[1]) + 1):
                for z in range(min(a[2], b[2]), max(a[2], b[2]) + 1):
                    self.vox.pop((x, y, z), None)

    def cyl(self, cx, cz, r, y0, y1, col, axis="y"):
        ir = int(math.ceil(r))
        for u in range(-ir, ir + 1):
            for w in range(-ir, ir + 1):
                if u * u + w * w <= r * r + 0.3:
                    for t in range(y0, y1 + 1):
                        if axis == "y":
                            p = (cx + u, t, cz + w)
                        else:  # along x: (t, cx+u as y, cz+w)
                            p = (t, cx + u, cz + w)
                        self.put(p, col(*p) if callable(col) else col)

    def ball(self, c, r, col):
        ir = int(math.ceil(r))
        for x in range(-ir, ir + 1):
            for y in range(-ir, ir + 1):
                for z in range(-ir, ir + 1):
                    if x * x + y * y + z * z <= r * r + 0.3:
                        p = (c[0] + x, c[1] + y, c[2] + z)
                        self.put(p, col(*p) if callable(col) else col)

    def out(self):
        return self.vox, self.pal, self.vs


# --- surface patterns ----------------------------------------------------------------------------------------------
def logs_h(x, y, z):
    """Horizontal logs: rows alternate shade, the odd knot darker."""
    r = rng_at("log", x, y, z)
    if r.random() < 0.05:
        return LOG[0]
    return LOG[2] if y % 2 == 0 else LOG[1]


def planks_x(x, y, z):
    """Planks running along x: each plank row its own shade, joints every few voxels."""
    r = rng_at("pl", z, (x + z * 3) // 5)
    base = PLANK[r.randint(0, 2)]
    return PLANK[0] if (x + z * 3) % 5 == 0 and r.random() < 0.6 else base


def stones(x, y, z):
    r = rng_at("st", x // 2, y, z // 2)
    c = STONE[r.randint(0, 3)]
    return MOSS[0] if r.random() < 0.06 else c


def shingles(fam):
    def f(x, y, z):
        r = rng_at("sh", x // 2, y, z)
        k = 1 + (1 if (x // 2 + y) % 2 == 0 else 0)
        if r.random() < 0.12:
            k = 3
        return fam[k]
    return f


# --- small pieces used in several models -------------------------------------------------------------------------
def flower_box(v, x0, x1, y, z0, z1):
    """A planter under a window: plank box, leaves and bright flowers."""
    v.box((x0, y, z0), (x1, y + 1, z1), lambda x, yy, z: PLANK[1] if yy == y else PLANK[2])
    for x in range(min(x0, x1), max(x0, x1) + 1):
        for z in range(min(z0, z1), max(z0, z1) + 1):
            r = rng_at("fb", x, y, z)
            v.put((x, y + 2, z), LEAF[r.randint(0, 2)])
            if r.random() < 0.55:
                v.put((x, y + 3, z), FLOWERS[r.randint(0, len(FLOWERS) - 1)])


def lantern(v, x, y, z, s=1):
    """A little lantern: warm glass between an iron cap and base, a hook on top."""
    v.box((x - s, y, z - s), (x + s - 1, y + 2 * s - 1, z + s - 1), WARM[0])
    v.box((x - s, y + 2 * s, z - s), (x + s - 1, y + 2 * s, z + s - 1), IRON[1])
    v.box((x - s, y - 1, z - s), (x + s - 1, y - 1, z + s - 1), IRON[1])
    v.box((x - 1, y + 2 * s + 1, z - 1), (x, y + 2 * s + 1, z), IRON[0])


def barrel(v, cx, y0, cz, r=2.2, h=9):
    for y in range(y0, y0 + h):
        rr = r + (0.6 if 2 <= y - y0 <= h - 3 else 0)
        band = (y - y0) in (1, h - 2)
        v.cyl(cx, cz, rr, y, y, lambda x, yy, z: IRON[1] if band else (PLANK[1] if (x + z) % 3 else PLANK[0]))
    v.cyl(cx, cz, r - 0.6, y0 + h - 1, y0 + h - 1, PLANK[3])


def crate(v, x0, y0, z0, n=8):
    """A crate n voxels on a side: plank faces with darker frame edges."""
    def col(x, y, z):
        edge = sum(1 for a, a0 in ((x, x0), (y, y0), (z, z0)) if a in (a0, a0 + n - 1))
        return DARKWOOD[2] if edge >= 2 else (PLANK[1] if (y - y0) % 3 else PLANK[0])
    v.box((x0, y0, z0), (x0 + n - 1, y0 + n - 1, z0 + n - 1), col)


# ===================================================================================================================
# the log cabin (tool shop, classes, garage): 31 x 18 x 24
# ===================================================================================================================
def cabin():
    """Room inside faces at x +-12 and z 9.5 (with ADJUST), door 6 wide, porch to z -13 with railings and steps,
    stone foundation, log walls with crossed ends, windows, a shingle roof with a ridge cap and eaves, a stone
    chimney. Fine pieces (shutters, flower boxes, lanterns, barrels, crates, balusters) are the 'detail' mesh at
    half-size voxels."""
    v = V(1.0)
    # foundation and deck
    v.box((-14, -1, -13), (13, 0, 10), lambda x, y, z: stones(x, y, z) if x in (-14, 13) or z in (-13, 10) or y == -1 else planks_x(x, y, z))
    # porch steps (two)
    v.box((-4, -1, -15), (3, -1, -14), stones)
    v.box((-4, 0, -14), (3, 0, -14), stones)
    # walls
    for y in range(1, 12):
        v.box((-14, y, 9), (13, y, 10), logs_h)
        v.box((-14, y, -4), (-13, y, 10), logs_h)
        v.box((12, y, -4), (13, y, 10), logs_h)
        v.box((-14, y, -4), (13, y, -3), logs_h)
        if y % 2 == 1:  # crossed log ends at the corners, end grain lighter
            for (x, z) in ((-15, -4), (14, -4), (-15, 10), (14, 10), (-14, -5), (13, -5), (-14, 11), (13, 11)):
                v.put((x, y, z), LOG[3])
    v.clear((-3, 1, -4), (2, 8, -3))  # door
    v.box((-4, 9, -5), (3, 9, -4), DARKWOOD[1])  # lintel beam
    v.box((-4, 1, -5), (-4, 8, -5), DARKWOOD[2])  # door frame
    v.box((3, 1, -5), (3, 8, -5), DARKWOOD[2])
    # windows: deep frames and warm glass
    for x in (-14, 12):
        v.box((x, 4, 1), (x + 1, 7, 5), DARKWOOD[0])
        v.box((x, 5, 2), (x + 1, 6, 4), WARM[0])
    for x0 in (-11, 6):
        v.box((x0, 4, -4), (x0 + 4, 7, -3), DARKWOOD[0])
        v.box((x0 + 1, 5, -4), (x0 + 3, 6, -3), WARM[0])
        v.box((x0 + 2, 5, -4), (x0 + 2, 6, -4), DARKWOOD[1])  # mullion
    # porch posts with braces; the porch roof sits high enough for the game's sign under its front edge
    for x in (-14, 13):
        v.box((x, 1, -13), (x, 12, -13), DARKWOOD[2])
        v.put((x + (1 if x < 0 else -1), 11, -13), DARKWOOD[1])
        v.put((x, 11, -12), DARKWOOD[1])
    v.box((-16, 13, -15), (15, 13, -4), shingles(ROOF_RED))
    v.box((-16, 12, -15), (15, 12, -15), ROOF_RED[0])  # eave edge
    # porch rails at the sides (the front is left open for the steps)
    for x in (-14, 13):
        v.box((x, 3, -12), (x, 3, -5), DARKWOOD[2])
    v.box((-14, 3, -13), (-6, 3, -13), DARKWOOD[2])
    v.box((5, 3, -13), (13, 3, -13), DARKWOOD[2])
    # main roof: gable along x, shingles, dark eaves and a ridge cap
    for k in range(8):
        z0, z1 = -6 + k, 12 - k
        if z0 > z1:
            break
        v.box((-16, 12 + k, z0), (15, 12 + k, z1), shingles(ROOF_RED))
        v.box((-16, 12 + k, z0), (15, 12 + k, z0), ROOF_RED[0])
        v.box((-16, 12 + k, z1), (15, 12 + k, z1), ROOF_RED[0])
    v.box((-16, 20, 3), (15, 20, 3), ROOF_RED[0])
    # gable ends: vertical planks with a little round window
    for k in range(7):
        v.box((-14, 12 + k, -3 + k), (-14, 12 + k, 9 - k), lambda x, y, z: PLANK[1] if z % 2 else PLANK[0])
        v.box((13, 12 + k, -3 + k), (13, 12 + k, 9 - k), lambda x, y, z: PLANK[1] if z % 2 else PLANK[0])
    for x in (-14, 13):
        v.box((x, 14, 2), (x, 16, 4), DARKWOOD[0])
        v.put((x, 15, 3), WARM[1])
    # chimney
    v.box((7, 12, 5), (9, 21, 7), stones)
    v.box((6, 22, 4), (10, 22, 8), STONE[0])
    structure = v.out()

    d = V(0.5)
    S = lambda s: int(round(s * 2))
    # front windows: green slatted shutters and flower boxes
    for (wx0, wx1) in ((-11, -7), (6, 10)):
        for sx in (S(wx0) - 2, S(wx1 + 1)):
            d.box((sx, S(4), S(-4) - 1), (sx + 1, S(8) - 1, S(-4) - 1), lambda x, y, z: GREEN[1] if y % 2 else GREEN[0])
        flower_box(d, S(wx0), S(wx1 + 1) - 1, S(3) - 1, S(-4) - 3, S(-4) - 1)
    # side windows: shutters and flower boxes on the outside of the walls
    for wx in (-14, 13):
        xo = S(wx) - 1 if wx < 0 else S(wx + 1)
        for sz in (S(1) - 2, S(6)):
            d.box((xo, S(4), sz), (xo, S(8) - 1, sz + 1), lambda x, y, z: GREEN[1] if y % 2 else GREEN[0])
        x0 = xo - 2 if wx < 0 else xo
        flower_box(d, x0, x0 + 2, S(3) - 1, S(1), S(6) - 1)
    # lanterns hanging under the porch roof
    for lx in (-10, 9):
        d.box((S(lx), S(12) - 1, S(-12)), (S(lx), S(13) - 1, S(-12)), IRON[0])
        lantern(d, S(lx), S(10.6), S(-12), 1)
    # barrels and crates by the porch
    barrel(d, S(-17), 0, S(-9), 2.0, 8)
    barrel(d, S(-17), 0, S(-6.2), 2.0, 8)
    crate(d, S(15), 0, S(-11), 6)
    crate(d, S(15) + 1, 6, S(-11) + 1, 5)
    # porch balusters under the rails
    for z in range(S(-12), S(-4), 3):
        for x in (S(-14), S(13) + 1):
            d.box((x, S(1), z), (x, S(3) - 1, z), DARKWOOD[2])
    for x in list(range(S(-14), S(-6), 3)) + list(range(S(5), S(14), 3)):
        d.box((x, S(1), S(-13)), (x, S(3) - 1, S(-13)), DARKWOOD[2])
    # leaves and flowers along the foundation's front
    for x in range(S(-14), S(14)):
        r = rng_at("mf", x)
        if r.random() < 0.35 and not S(-4) <= x <= S(4):
            d.put((x, 0, S(-13) - 1), LEAF[r.randint(0, 2)])
            if r.random() < 0.45:
                d.put((x, 1, S(-13) - 1), FLOWERS[r.randint(0, 4)])
    return {"": structure, "detail": d.out()}


# ===================================================================================================================
# stalls
# ===================================================================================================================
def bag_stand():
    """bag_stand (15 x 11.9 x 8.6): back counter x -7..7 (top 3.5), three stumps for the bags (x -5/0/5, z -4.5,
    tops at 2), a scalloped red-and-white awning, a sign board up the back (the game writes at y 10.6, z 0.9),
    lanterns on the front posts, garden bags hanging up, crates and a flower pot."""
    v = V(0.5)
    S = lambda s: int(round(s * 2))
    v.box((-S(7), 0, S(-0.8)), (S(7) - 1, S(3.5) - 2, S(2.2) - 1),
          lambda x, y, z: (CLOTH_WHITE[0] if (x // 3) % 2 else CLOTH_RED[0]) if z == S(-0.8) and 2 <= y <= S(3.5) - 4 else planks_x(x, y, z))
    v.box((-S(7.3), S(3.5) - 1, S(-1.1)), (S(7.3) - 1, S(3.5) - 1, S(2.4) - 1), PLANK[3])
    for x in (-S(7.4), S(7.4) - 2):
        v.box((x, 0, S(2.0)), (x + 1, S(11.9) - 2, S(2.6)), DARKWOOD[2])
        v.box((x, 0, S(-4.6)), (x + 1, S(9) - 1, S(-4.6) + 1), DARKWOOD[2])
        lantern(v, x + 1, S(7.4), S(-4.6) - 2, 1)
    z0, z1 = S(-5.6), S(2.8)
    for z in range(z0, z1):
        t = (z - z0) / (z1 - z0)
        y = int(S(9) + t * S(1.4))
        v.box((-S(7.8), y, z), (S(7.8) - 1, y, z), lambda x, yy, zz: CLOTH_RED[1] if (x // 3) % 2 == 0 else CLOTH_WHITE[1])
    for x in range(-S(7.8), S(7.8)):
        if x % 3 != 2:
            c = CLOTH_RED[0] if (x // 3) % 2 == 0 else CLOTH_WHITE[0]
            v.put((x, S(9) - 1, z0), c)
            if x % 3 == 1:
                v.put((x, S(9) - 2, z0), c)
    v.box((-S(5), S(9.9) - 1, S(1.2)), (S(5) - 1, S(11.6) - 1, S(1.8)), BOARD)
    v.box((-S(5.3), S(9.9) - 2, S(1.2)), (S(5.3) - 1, S(9.9) - 2, S(1.9)), GOLD[1])
    v.box((-S(5.3), S(11.6), S(1.2)), (S(5.3) - 1, S(11.6), S(1.9)), GOLD[1])
    for sx in (-5, 0, 5):
        v.cyl(S(sx), S(-4.5), 2.6, 0, S(2) - 2, lambda x, y, z: LOG[1] if (x + z) % 2 else LOG[0])
        v.cyl(S(sx), S(-4.5), 2.6, S(2) - 1, S(2) - 1, lambda x, y, z, sx=sx: PLANK[3] if ((x - S(sx)) ** 2 + (z - S(-4.5)) ** 2) % 3 else PLANK[2])
    for bx, col in ((-4, GREEN), (-1, ORANGE), (2, BLUE), (5, PURPLE)):
        v.box((S(bx) - 1, S(7), S(1.6)), (S(bx) + 1, S(8.3), S(2.0)), col[1])
        v.box((S(bx) - 1, S(8.3) + 1, S(1.7)), (S(bx) + 1, S(8.3) + 1, S(1.9)), col[0])
    crate(v, S(-9.6), 0, S(-1.5), 5)
    crate(v, S(8), 0, S(-0.5), 5)
    v.cyl(S(8.8), S(-3.5), 1.5, 0, 3, ORANGE[0])
    v.ball((S(8.8), 5, S(-3.5)), 2.2, lambda x, y, z: FLOWERS[rng_at("pot", x, y, z).randint(0, 4)] if rng_at("pp", x, y, z).random() < 0.3 else LEAF[1])
    return v.out()


def rewards_stall():
    """rewards_stall (19 x 15.5 x 8.6): a gift booth. Back wall x -8.5..8.5 at z 2.3..3.1 up to 9 (the game writes
    the two bay panels at (+-3.9, 6.6, 2.3)), posts at x +-7.9, two counters (x +-3.3, top 3.8), a teal roof,
    the REWARDS board across the top (front face z -0.6), presents, balloons and a gold star on top."""
    v = V(0.5)
    S = lambda s: int(round(s * 2))
    v.box((-S(8.5), 0, S(2.3)), (S(8.5) - 1, S(9) - 1, S(3.1) - 1), lambda x, y, z: PURPLE[(y // 2) % 2])
    for cx in (-3.9, 3.9):
        v.box((S(cx - 3), S(4.9), S(2.3) - 1), (S(cx + 3) - 1, S(8.3) - 1, S(2.3) - 1), BOARD)
        v.box((S(cx - 3.2), S(4.9) - 1, S(2.3) - 1), (S(cx + 3.2) - 1, S(4.9) - 1, S(2.3) - 1), GOLD[2])
    for x in (-S(7.9) - 1, S(7.9) - 1):
        v.box((x, 0, -S(2.2)), (x + 2, S(12) - 1, -S(2.2) + 2), lambda xx, y, z: GOLD[2] if (y + xx + z) % 6 < 2 else CLOTH_WHITE[1])
        v.box((x, 0, S(2.6)), (x + 2, S(12) - 1, S(3.1)), DARKWOOD[2])
    for cx in (-3.3, 3.3):
        v.box((S(cx - 2.1), 0, S(-4.4)), (S(cx + 2.1) - 1, S(3.8) - 2, S(-1.8) - 1), lambda x, y, z: TEAL[(x // 2) % 2] if z == S(-4.4) else PLANK[1])
        v.box((S(cx - 2.3), S(3.8) - 1, S(-4.6)), (S(cx + 2.3) - 1, S(3.8) - 1, S(-1.6) - 1), GOLD[1])
    for z in range(S(-4.6), S(4.2)):
        v.box((-S(9.5), S(12), z), (S(9.5) - 1, S(12) + 1, z), shingles(ROOF_TEAL))
    for x in range(-S(9.5), S(9.5)):
        if x % 3 != 2:
            v.put((x, S(12) - 1, S(-4.6)), ROOF_TEAL[0])
    v.box((-S(8.5), S(12) + 2, S(-0.6)), (S(8.5) - 1, S(15.5) - 2, S(0.3)), BOARD)
    v.box((-S(8.8), S(15.5) - 1, S(-0.7)), (S(8.8) - 1, S(15.5) - 1, S(0.3)), GOLD[1])
    v.box((-S(8.8), S(12) + 2, S(-0.7)), (-S(8.5) - 1, S(15.5) - 1, S(0.3)), GOLD[1])
    v.box((S(8.5), S(12) + 2, S(-0.7)), (S(8.8) - 1, S(15.5) - 1, S(0.3)), GOLD[1])
    sy = S(15.5) + 1
    for (a, b) in (((-1, 0), (0, 4)), ((-3, 2), (2, 2)), ((-2, 1), (1, 3)), ((-2, -1), (-2, 0)), ((1, -1), (1, 0))):
        v.box((a[0], sy + a[1], 0), (b[0], sy + b[1], 1), GOLD[2])
    for (px, py, pz, n, col) in ((-3.3, S(3.8), -3.1, 4, PINK), (3.3, S(3.8), -3.1, 4, BLUE), (-6.2, 0, -5.4, 5, GREEN), (6.0, 0, -5.4, 4, ORANGE), (-5.0, 0, -6.8, 3, PURPLE)):
        x0, z0 = S(px) - n // 2, S(pz) - n // 2
        v.box((x0, py, z0), (x0 + n - 1, py + n - 1, z0 + n - 1), col[1])
        v.box((x0 + n // 2, py, z0), (x0 + n // 2, py + n - 1, z0 + n - 1), GOLD[2])
        v.box((x0, py, z0 + n // 2), (x0 + n - 1, py + n - 1, z0 + n // 2), GOLD[2])
        v.put((x0 + n // 2, py + n, z0 + n // 2), GOLD[3])
    for (bx, by, bz, col) in ((-S(9.4), S(13.5), -S(3.5), PINK), (-S(10.2), S(15), -S(2), BLUE), (S(9.2), S(14), -S(3.4), YELLOW), (S(10.2), S(15.6), -S(1.8), PURPLE)):
        v.ball((bx, by, bz), 2.2, col[1])
        v.put((bx, by - 3, bz), col[0])
        for y in range(S(12) - 1, by - 3):
            v.put((bx + (1 if bx < 0 else -1) * ((by - y) // 6), y, bz), CLOTH_WHITE[1])
    return v.out()


# ===================================================================================================================
# small props
# ===================================================================================================================
def lantern_post():
    """A chunky lamp post (about 8.5 studs): a stepped stone plinth with flowers, a dark wooden post with iron bands
    and a gold finial, an iron arm with a brace reaching forward (-z), and a lantern hanging from a chain: iron
    corner posts, a stepped roof, open sides. The game puts a warm glowing core and a light inside it
    (server/HubDressing), centred at (0, 4.75, -2.5) studs."""
    v = V(0.25)
    v.box((-5, 0, -5), (4, 2, 4), stones)
    v.box((-4, 3, -4), (3, 6, 3), lambda x, y, z: STONE[3] if y == 6 else STONE[2])
    for x in range(-5, 5):
        for z in (-6, 5):
            r = rng_at("lf", x, z)
            if r.random() < 0.6:
                v.put((x, 0, z), LEAF[r.randint(0, 2)])
                if r.random() < 0.5:
                    v.put((x, 1, z), FLOWERS[r.randint(0, 4)])
    v.box((-2, 7, -2), (1, 30, 1), lambda x, y, z: DARKWOOD[2] if (y // 3) % 2 else DARKWOOD[1])
    for y in (11, 19, 27):
        v.box((-3, y, -3), (2, y, 2), IRON[2])
    v.box((-3, 31, -3), (2, 31, 2), IRON[1])
    v.box((-1, 32, -1), (0, 34, 0), GOLD[2])
    # the arm, its brace and the chain
    v.box((-1, 27, -11), (0, 28, -3), IRON[1])
    for t in range(5):
        v.box((-1, 22 + t, -3 - t), (0, 22 + t, -3 - t), IRON[1])
    v.box((-1, 25, -11), (0, 26, -10), IRON[0])
    # the lantern: roof steps, corner posts, a band round the middle, a base and a drop finial
    v.box((-4, 23, -14), (3, 23, -7), IRON[2])
    v.box((-3, 24, -13), (2, 24, -8), IRON[1])
    v.box((-2, 25, -12), (1, 25, -9), IRON[1])
    for (x, z) in ((-3, -13), (2, -13), (-3, -8), (2, -8)):
        v.box((x, 15, z), (x, 22, z), IRON[1])
    for y in (15, 22):
        v.box((-3, y, -13), (2, y, -13), IRON[1])
        v.box((-3, y, -8), (2, y, -8), IRON[1])
        v.box((-3, y, -13), (-3, y, -8), IRON[1])
        v.box((2, y, -13), (2, y, -8), IRON[1])
    v.box((-3, 14, -13), (2, 14, -8), IRON[2])
    v.box((-1, 13, -11), (0, 13, -10), GOLD[1])
    return v.out()


def gas_pump():
    """gas_pump (3.7 x 6.3 x 3): a round-shouldered retro pump, red with a white band, a glowing globe on top,
    a dial face, a black hose and the nozzle in its holder."""
    v = V(0.25)
    S = lambda s: int(round(s * 4))
    v.box((-S(1.7), 0, -S(1.4)), (S(1.7) - 1, 1, S(1.4) - 1), IRON[1])
    for y in range(2, S(5.0)):
        inset = 1 if y > S(4.6) else 0
        col = CLOTH_WHITE[1] if S(2.0) <= y <= S(2.4) else CLOTH_RED[1]
        v.box((-S(1.4) + inset, y, -S(1.1) + inset), (S(1.4) - 1 - inset, y, S(1.1) - 1 - inset), col)
    v.box((-S(0.9), S(3.0), -S(1.1) - 1), (S(0.9) - 1, S(4.3), -S(1.1) - 1), CLOTH_WHITE[1])
    v.box((-S(0.6), S(3.3), -S(1.1) - 2), (S(0.6) - 1, S(4.0), -S(1.1) - 2), BLACK[1])
    v.box((-1, S(3.5), -S(1.1) - 3), (0, S(3.8), -S(1.1) - 3), YELLOW[1])
    v.box((-2, S(5.0), -2), (1, S(5.0) + 1, 1), IRON[2])
    v.ball((0, S(5.0) + 4, 0), 3.2, lambda x, y, z: WARM[1] if y > S(5.0) + 4 else WARM[0])
    for y in range(S(0.6), S(3.2)):
        v.put((S(1.4), y, -1), BLACK[0])
    v.box((S(1.4), S(3.2), -2), (S(1.4) + 1, S(3.8), 1), IRON[2])
    v.box((S(1.4) + 1, S(3.4), -3), (S(1.4) + 2, S(3.6), -2), STEEL[1])
    return v.out()


def board(width, height, depth, top_fn=None):
    """A notice board: dark face (front face at z ~ -0.35) in a carved wooden frame, stone feet, posts with lanterns,
    flowers at the base, a crest on top."""
    v = V(0.5)
    S = lambda s: int(round(s * 2))
    hw = S(width / 2)
    face_top = S(height) - 3
    for x in (-hw, hw - 2):
        v.box((x - 1, 0, -S(depth / 2)), (x + 2, 2, S(depth / 2) - 1), stones)
        v.box((x, 3, -1), (x + 1, S(height) - 1, 0), DARKWOOD[2])
        v.box((x - 1, S(height), -2), (x + 2, S(height) + 1, 1), DARKWOOD[1])
        lantern(v, x + 1, S(height) + 3, -1, 1)
    v.box((-hw + 2, S(2.4), -1), (hw - 3, face_top, 0), BOARD)
    v.box((-hw + 2, S(2.4) - 1, -2), (hw - 3, S(2.4) - 1, 0), DARKWOOD[2])
    v.box((-hw + 2, face_top + 1, -2), (hw - 3, face_top + 2, 0), DARKWOOD[2])
    v.box((-hw + 2, face_top + 3, -1), (hw - 3, face_top + 3, -1), GOLD[1])
    for x in range(-hw, hw):
        r = rng_at("bf", x, width)
        if r.random() < 0.5:
            v.put((x, 0, -S(depth / 2) - 1), LEAF[r.randint(0, 2)])
            if r.random() < 0.5:
                v.put((x, 1, -S(depth / 2) - 1), FLOWERS[r.randint(0, 4)])
    if top_fn:
        top_fn(v, face_top)
    return v.out()


def leaderboard():
    def crown(v, face_top):
        y = face_top + 4
        v.box((-6, y, -1), (5, y + 1, 0), GOLD[1])
        for x in (-6, -2, 1, 5):
            v.box((x, y + 2, -1), (x, y + 4, 0), GOLD[2])
            v.put((x, y + 5, -1), CLOTH_RED[1])
    return board(14.5, 13.0, 4.7, crown)


def trophy_board():
    def trophy(v, face_top):
        y = face_top + 4
        v.box((-3, y, -2), (2, y + 1, 1), DARKWOOD[1])
        v.box((-1, y + 2, -1), (0, y + 3, 0), GOLD[1])
        v.cyl(0, 0, 3.4, y + 4, y + 8, lambda x, yy, z: GOLD[2] if yy > y + 5 else GOLD[1])
        v.cyl(0, 0, 2.2, y + 8, y + 8, GOLD[0])
        for side in (-1, 1):
            v.box((side * 4, y + 5, 0), (side * 4 + side, y + 7, 0), GOLD[1])
    return board(13.7, 13.0, 3.1, trophy)


def party_booth():
    """party_booth (16.9 x 12.4 x 16.4), the run's garage bay: open front (-z), log posts, low rails, a
    corrugated roof, the sign board on the back wall (y 4..8, z ~6), tools hanging on the back wall, a tyre stack,
    an oil drum and a workbench."""
    v = V(1.0)
    v.box((-8, 0, -7), (7, 0, 8), lambda x, y, z: STONE[1] if (x + z) % 2 == 0 else STONE[2])
    for x in (-8, 7):
        v.box((x, 1, 6), (x, 10, 7), LOG[1])
        v.box((x, 1, -7), (x, 9, -7), LOG[1])
        v.box((x, 2, -6), (x, 2, 6), LOG[2])
        v.box((x, 4, -6), (x, 4, 6), LOG[2])
    v.box((-7, 1, 7), (6, 9, 7), logs_h)
    v.box((-6, 4, 6), (5, 8, 6), BOARD)
    v.box((-7, 9, 6), (6, 9, 6), GOLD[1])
    for z in range(-8, 9):
        y = 10 + (z + 8) // 6
        v.box((-9, y, z), (8, y, z), lambda x, yy, zz: ROOF_TEAL[2] if x % 2 else ROOF_TEAL[1])
    v.box((-9, 10, -8), (8, 10, -8), ROOF_TEAL[0])
    d = V(0.5)
    for tx, head in ((-5, "rake"), (2, "shovel"), (5, "hoe")):
        x = tx * 2
        d.box((x, 6, 12), (x, 15, 12), PLANK[1])
        if head == "rake":
            d.box((x - 2, 15, 12), (x + 2, 15, 12), STEEL[0])
            for k in (-2, 0, 2):
                d.put((x + k, 16, 12), STEEL[0])
        elif head == "shovel":
            d.box((x - 1, 3, 12), (x + 1, 5, 12), STEEL[1])
        else:
            d.box((x - 1, 15, 12), (x + 1, 15, 12), STEEL[1])
    for k in range(3):
        d.cyl(-12, -10, 2.6, k * 2 + 2, k * 2 + 3, BLACK[k % 2])
    barrel(d, 11, 2, -10, 2.2, 9)
    d.box((6, 2, 8), (13, 5, 11), PLANK[2])
    d.box((6, 6, 8), (13, 6, 11), PLANK[3])
    d.box((8, 7, 9), (9, 7, 10), CLOTH_RED[1])
    return {"": v.out(), "detail": d.out()}


def shredder():
    """shredder (7.8 x 11.3 x 14.6): an orange machine on a dark chassis with wheels, riveted panels, a stepped
    yellow hopper with hazard stripes round the mouth (y 8.8, z 4.8), steel roller teeth, a gear on each side, an
    exhaust pipe, warning lamps, and the coin chute at the front spilling coins onto its tray."""
    v = V(0.5)
    S = lambda s: int(round(s * 2))
    v.box((-S(3.9), 0, S(-7.3)), (S(3.9) - 1, 1, S(5.9) - 1), IRON[1])
    def body(x, y, z):
        if y % 4 == 0 and (x + z) % 4 == 0:
            return ORANGE[2]  # rivets
        return ORANGE[1] if (y // 4) % 2 == 0 else ORANGE[0]
    v.box((-S(3.6), 2, S(-5)), (S(3.6) - 1, S(7.5), S(5.5) - 1), body)
    for z in (S(-2), S(1.5)):
        v.box((-S(3.6), 2, z), (-S(3.6), S(7.5), z), ORANGE[0])
        v.box((S(3.6) - 1, 2, z), (S(3.6) - 1, S(7.5), z), ORANGE[0])
    for k in range(6):
        w = S(2.6) + k
        v.box((-w, S(7.5) + 1 + k, S(1.5) - k), (w - 1, S(7.5) + 1 + k, S(5.8) + k // 2), YELLOW[k % 2])
    v.clear((-S(2.2), S(7.5) + 3, S(2.4)), (S(2.2) - 1, S(7.5) + 6, S(5.2)))
    v.box((-S(2.2), S(7.5) + 2, S(2.4)), (S(2.2) - 1, S(7.5) + 2, S(5.2)), BLACK[0])
    top = S(7.5) + 6
    for x in range(-S(2.6) - 5, S(2.6) + 5):
        v.put((x, top + 1, S(1.5) - 5), BLACK[1] if (x // 2) % 2 else YELLOW[1])
    for z in (S(3.0), S(4.6)):
        v.box((-S(2.0), S(7.5) + 3, z), (S(2.0) - 1, S(7.5) + 3, z), STEEL[1])
        for x in range(-S(2.0), S(2.0), 2):
            v.put((x, S(7.5) + 4, z), STEEL[2])
    for x in (-S(3.6) - 1, S(3.6)):
        for a in range(16):
            ang = a / 16 * math.pi * 2
            rr = 4.5 if a % 2 == 0 else 3.5
            for t in range(int(rr) + 1):
                v.put((x, S(4.5) + int(round(math.sin(ang) * t)), S(-1) + int(round(math.cos(ang) * t))), STEEL[0] if t < 2 else STEEL[1])
        v.put((x, S(4.5), S(-1)), IRON[0])
    v.box((S(2.4), S(7.5) + 1, S(-4)), (S(2.4) + 1, S(10.8), S(-4) + 1), IRON[2])
    v.box((S(2.4) - 1, S(10.8) + 1, S(-4) - 1), (S(2.4) + 2, S(10.8) + 1, S(-4) + 2), IRON[1])
    for x in (-S(3), S(3) - 1):
        v.box((x, S(7.5) + 1, S(-4.5)), (x, S(7.5) + 2, S(-4.5)), CLOTH_RED[1])
    v.box((-S(1.4), 2, S(-7.0)), (S(1.4) - 1, S(2.4), S(-5.0)), IRON[1])
    v.box((-S(1.8), 0, S(-7.3)), (S(1.8) - 1, 1, S(-5.6)), GOLD[0])
    for k in range(18):
        r = rng_at("coin", k)
        v.put((r.randint(-S(1.6), S(1.6) - 1), 2 + (1 if r.random() < 0.3 else 0), r.randint(S(-7.3), S(-6))), GOLD[2] if r.random() < 0.6 else GOLD[3])
    for x in (-S(3.9), S(3.9) - 2):
        for z in (S(-5), S(4)):
            v.box((x, 0, z), (x + 1, 3, z + 3), BLACK[0])
            v.box((x + (0 if x < 0 else 1), 1, z + 1), (x + (0 if x < 0 else 1), 2, z + 2), STEEL[0])
    return v.out()


def sell_pad():
    """sell_pad (13 x 1.3 x 13): a log frame with corner posts round a plank deck painted with a green arrow
    pointing in, grass tufts on the posts."""
    v = V(0.5)
    S = lambda s: int(round(s * 2))
    h = S(6.5)
    def deck(x, y, z):
        ax = abs(x + 0.5)
        arrow = (-6 < z < 3 and ax < 2) or (3 <= z < 8 and ax < 8 - z)
        return GREEN[2] if arrow else planks_x(x, y, z)
    v.box((-h, 0, -h), (h - 1, 1, h - 1), deck)
    for a in (-h, h - 2):
        v.box((a, 0, -h), (a + 1, 2, h - 1), logs_h)
        v.box((-h, 0, a), (h - 1, 2, a + 1), logs_h)
    for (x, z) in ((-h, -h), (h - 2, -h), (-h, h - 2), (h - 2, h - 2)):
        v.box((x, 0, z), (x + 1, 4, z + 1), LOG[0])
        v.put((x, 5, z), LEAF[1])
        v.put((x + 1, 5, z + 1), LEAF[2])
    return v.out()


def turntable():
    v = V(0.5)
    v.cyl(0, 0, 10.2, 0, 0, IRON[1])
    def top(x, y, z):
        rr = x * x + z * z
        if rr > 60:
            return YELLOW[1] if int((math.atan2(z, x) + math.pi) * 6 / math.pi) % 2 == 0 else BLACK[1]
        return STEEL[1]
    v.cyl(0, 0, 9.4, 1, 1, top)
    for a in range(8):
        ang = a / 8 * math.pi * 2
        v.put((int(round(math.cos(ang) * 6)), 2, int(round(math.sin(ang) * 6))), IRON[2])
    return v.out()


# ===================================================================================================================
# dressing (new): placed round the hubs by server/HubDressing
# ===================================================================================================================
def barrel_prop():
    v = V(0.25)
    barrel(v, 0, 0, 0, 3.6, 12)
    return v.out()


def crate_stack():
    v = V(0.25)
    crate(v, -8, 0, -4, 8)
    crate(v, 1, 0, -5, 9)
    crate(v, -5, 8, -3, 8)
    return v.out()


def planter():
    """A long plank planter full of flowers (4 x 2 x 1.5)."""
    v = V(0.25)
    v.box((-8, 0, -3), (7, 3, 2), lambda x, y, z: PLANK[1] if y < 3 else PLANK[3])
    v.box((-7, 4, -2), (6, 4, 1), (90, 60, 40))
    for x in range(-7, 7):
        for z in range(-2, 2):
            r = rng_at("pl", x, z)
            v.put((x, 5, z), LEAF[r.randint(0, 2)])
            if r.random() < 0.5:
                v.put((x, 6 + (1 if r.random() < 0.3 else 0), z), FLOWERS[r.randint(0, 4)])
    return v.out()


def bench():
    """A park bench (6 x 3 x 2): plank seat and back on iron legs, facing -z."""
    v = V(0.25)
    for x in (-10, 9):
        v.box((x, 0, -3), (x + 1, 6, -3), IRON[1])
        v.box((x, 0, 3), (x + 1, 11, 3), IRON[1])
        v.box((x, 6, -3), (x + 1, 6, 3), IRON[1])
    for z in (-3, -1, 1):
        v.box((-12, 7, z), (11, 7, z + 1), PLANK[2] if z % 2 else PLANK[1])
    for y in (8, 10):
        v.box((-12, y, 4), (11, y + 1, 4), PLANK[2] if y == 10 else PLANK[1])
    return v.out()


def signpost():
    """A signpost with three arrow boards pointing different ways."""
    v = V(0.25)
    v.box((-1, 0, -1), (0, 30, 0), LOG[1])
    v.box((-2, 0, -2), (1, 2, 1), stones)
    for (y, (dx, dz), col) in ((26, (1, 0), PLANK[2]), (21, (0, 1), PLANK[1]), (16, (-1, 0), PLANK[3])):
        for t in range(1, 12):
            for yy in range(y, y + 3):
                v.put((dx * t, yy, dz * t), col)
        v.put((dx * 12, y + 1, dz * 12), col)
    v.box((-1, 31, -1), (0, 31, 0), LOG[3])
    return v.out()


def welcome_arch():
    """A big wooden arch over the path (24 wide, 21 high): log pillars on stone feet, a beam framing a sign board
    (the game writes on a panel just in front of it, centred at y 14.5, z -1.1), a little shingle roof, banners,
    lanterns, vines and flowers climbing the pillars."""
    v = V(1.0)
    for x in (-12, 10):
        v.box((x - 1, 0, -2), (x + 2, 2, 1), stones)
        v.box((x, 3, -1), (x + 1, 17, 0), logs_h)
    v.box((-14, 12, -1), (13, 12, 0), DARKWOOD[2])
    v.box((-14, 17, -1), (13, 17, 0), DARKWOOD[2])
    v.box((-9, 13, 0), (8, 16, 0), BOARD)
    for k in range(3):
        v.box((-15 + k, 18 + k, -2 + k), (14 - k, 18 + k, 1 - k), shingles(ROOF_RED))
    d = V(0.5)
    for (x, col) in ((-22, CLOTH_RED), (-14, GOLD), (12, GOLD), (20, CLOTH_RED)):
        d.box((x, 13, -3), (x + 3, 23, -3), col[1])
        d.box((x, 21, -3), (x + 3, 21, -3), col[0])
        d.box((x + 1, 12, -3), (x + 2, 12, -3), col[1])
    for x in (-18, 17):
        d.box((x, 22, -3), (x, 23, -3), IRON[0])
        lantern(d, x, 18, -3, 1)
    for x0 in (-24, 20):
        for y in range(4, 34):
            for (dx, dz) in ((-1, -3), (4, -3), (-1, 1), (4, 1)):
                r = rng_at("vine", x0, y, dx, dz)
                if r.random() < 0.45:
                    d.put((x0 + dx, y, dz), LEAF[r.randint(0, 2)])
                    if r.random() < 0.18:
                        d.put((x0 + dx, y, dz - (1 if dz < 0 else -1)), FLOWERS[r.randint(0, 4)])
    return {"": v.out(), "detail": d.out()}


def mower_statue():
    """The plaza's centrepiece: a golden push mower on a stepped stone plinth with flowers round its foot."""
    v = V(0.5)
    v.box((-8, 0, -8), (7, 1, 7), stones)
    v.box((-6, 2, -6), (5, 5, 5), stones)
    v.box((-5, 6, -5), (4, 6, 4), STONE[3])
    y = 7
    v.box((-4, y + 1, -4), (3, y + 3, 3), GOLD[1])
    v.box((-3, y + 4, -2), (2, y + 6, 1), GOLD[2])
    v.box((-1, y + 7, -1), (0, y + 7, 0), GOLD[3])
    for (x, z) in ((-5, -4), (4, -4), (-5, 3), (4, 3)):
        v.box((x, y, z - 1), (x, y + 2, z + 1), GOLD[0])
    for t in range(12):
        v.put((-3, y + 3 + t, 4 + t // 2), GOLD[1])
        v.put((2, y + 3 + t, 4 + t // 2), GOLD[1])
    v.box((-4, y + 15, 10), (3, y + 15, 10), GOLD[2])
    for k in range(10):
        r = rng_at("clip", k)
        v.put((r.randint(-7, 6), y + r.randint(1, 5), r.randint(-10, -6)), LEAF[r.randint(0, 2)])
    for x in range(-9, 9):
        for z in (-9, 8):
            r = rng_at("pf", x, z)
            if r.random() < 0.6:
                v.put((x, 0, z), LEAF[1])
                v.put((x, 1, z), FLOWERS[r.randint(0, 4)])
    return v.out()


def wheelbarrow():
    """A red wheelbarrow heaped with grass."""
    v = V(0.25)
    v.cyl(0, -9, 2.6, -1, 0, BLACK[0], axis="x")
    v.box((-5, 3, -7), (4, 7, 6), lambda x, y, z: CLOTH_RED[1] if y > 3 else CLOTH_RED[0])
    v.clear((-4, 5, -6), (3, 7, 5))
    for z in range(6, 13):
        v.put((-4, 3, z), PLANK[1])
        v.put((3, 3, z), PLANK[1])
    for x in (-4, 3):
        v.box((x, 0, 4), (x, 2, 4), IRON[1])
    for k in range(70):
        r = rng_at("wb", k)
        v.put((r.randint(-4, 3), r.randint(5, 9), r.randint(-6, 5)), GREEN[r.randint(0, 2)])
    return v.out()


def hay_bale():
    v = V(0.5)
    v.box((-6, 0, -4), (5, 7, 3), lambda x, y, z: YELLOW[0] if (x + y) % 3 else (214, 170, 60))
    for x in (-3, 2):
        v.box((x, 0, -4), (x, 7, 3), (150, 110, 60))
    return v.out()


# where each model sits against the toy model it replaces (studs)
ADJUST = {
    "log_cabin": (0.0, -0.5, 0.5),
}

PROPS = {
    # replacements (same layout as the toy models)
    "log_cabin": cabin,
    "bag_stand": bag_stand,
    "rewards_stall": rewards_stall,
    "lantern_post": lantern_post,
    "gas_pump": gas_pump,
    "leaderboard": leaderboard,
    "trophy_board": trophy_board,
    "party_booth": party_booth,
    "shredder": shredder,
    "sell_pad": sell_pad,
    "turntable": turntable,
    # dressing
    "barrel": barrel_prop,
    "crate_stack": crate_stack,
    "planter": planter,
    "bench": bench,
    "signpost": signpost,
    "welcome_arch": welcome_arch,
    "mower_statue": mower_statue,
    "wheelbarrow": wheelbarrow,
    "hay_bale": hay_bale,
}
