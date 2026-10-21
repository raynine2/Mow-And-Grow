"""The hub buildings and props as voxel models, the same size and layout as the toy models they replace (so the
game's colliders, prompts and text panels still line up). Coordinates are voxels; front is -z; the model's origin
(where the game puts its pivot) is voxel (0, 0, 0)'s corner... see ORIGIN below. Each returns
(voxels, palette, voxel_size)."""
import math
import random

WOOD = [(120, 74, 44), (146, 92, 56), (170, 112, 68), (92, 56, 36)]  # logs: mid, light, lighter, dark
ROOF = [(214, 84, 52), (236, 112, 64), (184, 64, 44)]
STONE = [(128, 128, 136), (150, 150, 158), (104, 104, 114)]
GLOW = (255, 214, 120)
DARK = (44, 34, 30)
WHITE = (250, 246, 236)
GREEN = (84, 202, 53)


class V:
    """A voxel canvas with a palette that grows as colours are used."""

    def __init__(self, vs):
        self.vox = {}
        self.pal = []
        self.idx = {}
        self.vs = vs

    def c(self, rgb):
        rgb = tuple(int(v) for v in rgb)
        if rgb not in self.idx:
            self.idx[rgb] = len(self.pal)
            self.pal.append(rgb)
        return self.idx[rgb]

    def box(self, a, b, col):
        """Fill the voxels a..b inclusive. col: an rgb, or a function (x, y, z) -> rgb."""
        for x in range(min(a[0], b[0]), max(a[0], b[0]) + 1):
            for y in range(min(a[1], b[1]), max(a[1], b[1]) + 1):
                for z in range(min(a[2], b[2]), max(a[2], b[2]) + 1):
                    self.vox[(x, y, z)] = self.c(col(x, y, z) if callable(col) else col)

    def cyl(self, cx, cz, r, y0, y1, col):
        ir = int(math.ceil(r))
        for x in range(-ir, ir + 1):
            for z in range(-ir, ir + 1):
                if x * x + z * z <= r * r + 0.25:
                    self.box((cx + x, y0, cz + z), (cx + x, y1, cz + z), col)

    def clear(self, a, b):
        for x in range(min(a[0], b[0]), max(a[0], b[0]) + 1):
            for y in range(min(a[1], b[1]), max(a[1], b[1]) + 1):
                for z in range(min(a[2], b[2]), max(a[2], b[2]) + 1):
                    self.vox.pop((x, y, z), None)

    def out(self):
        return self.vox, self.pal, self.vs


def logs(x, y, z):
    """Horizontal logs: rows alternate shade, the odd knot darker."""
    r = random.Random(x * 7919 + y * 104729 + z * 1299709)
    c = WOOD[0] if y % 2 == 0 else WOOD[1]
    return WOOD[3] if r.random() < 0.06 else c


def planks(x, y, z):
    return WOOD[1] if (x + z) % 2 == 0 else WOOD[2]


# -----------------------------------------------------------------------------------------------------------------
def cabin():
    """log_cabin (31 x 18 x 24): room inside faces at x +-12, z 9.5 (back) after ADJUST shifts the model +0.5 z;
    5-wide door in the front wall, a porch to z -12 under its own roof, a gable roof with an overhang, glowing
    windows, a chimney. ADJUST also drops it 0.5 so the deck is level with the game's floor collider (top 0.5)."""
    v = V(1.0)
    # platform: stone edge, plank deck
    v.box((-14, 0, -13), (13, 0, 10), lambda x, y, z: STONE[(x + z) % 3] if x in (-14, 13) or z in (-13, 10) else planks(x, y, z))
    # walls: logs with crossed corner ends sticking out
    for y in range(1, 12):
        v.box((-14, y, 9), (13, y, 10), logs)  # back
        v.box((-14, y, -4), (-13, y, 10), logs)  # left
        v.box((12, y, -4), (13, y, 10), logs)  # right
        v.box((-14, y, -4), (13, y, -3), logs)  # front
        if y % 2 == 0:
            for (x, z) in ((-15, -4), (14, -4), (-15, 10), (14, 10), (-14, -5), (13, -5), (-14, 11), (13, 11)):
                v.box((x, y, z), (x, y, z), WOOD[2])
    v.clear((-3, 1, -4), (2, 8, -3))  # the door (6 wide, 8 high)
    v.box((-4, 9, -5), (3, 9, -4), WOOD[3])  # lintel
    # windows: glowing panes in dark frames on the sides and either side of the door
    for x in (-14, 12):  # side windows
        v.box((x, 4, 1), (x + 1, 7, 5), DARK)
        v.box((x, 5, 2), (x + 1, 6, 4), GLOW)
    for x0 in (-11, 6):  # front windows either side of the door
        v.box((x0, 4, -4), (x0 + 4, 7, -3), DARK)
        v.box((x0 + 1, 5, -4), (x0 + 3, 6, -3), GLOW)
    # porch posts and its roof
    # (the porch roof sits high enough that the game's sign, y 8.9..11.9 at z -12.3, hangs clear under it)
    for x in (-14, 13):
        v.box((x, 1, -13), (x, 12, -13), WOOD[3])
    v.box((-16, 13, -14), (15, 13, -4), lambda x, y, z: ROOF[(x // 2) % 2])
    # gable roof over the room, ridge along x
    for k in range(7):
        z0, z1 = -5 + k, 11 - k
        if z0 > z1:
            break
        v.box((-16, 12 + k, z0), (15, 12 + k, z1), lambda x, y, z: ROOF[2] if z in (z0, z1) else ROOF[(x // 2) % 2])
    # gable ends (logs) under the roof
    for k in range(6):
        v.box((-14, 12 + k, -3 + k), (-14, 12 + k, 9 - k), logs)
        v.box((13, 12 + k, -3 + k), (13, 12 + k, 9 - k), logs)
    # chimney
    v.box((7, 12, 5), (9, 19, 7), lambda x, y, z: STONE[(x + y + z) % 3])
    v.box((7, 20, 5), (9, 20, 7), STONE[2])
    return v.out()


# -----------------------------------------------------------------------------------------------------------------
def stall(width=15, height=12, depth_front=-6, awning=((235, 70, 70), (250, 246, 236)), sign=(110, 70, 42)):
    """A market stall with a striped awning. Used for bag_stand: back counter x -7..7 top at 3.5, three stumps for
    the bags at x -5/0/5, z -4.5 (tops at 2), a sign board high up the back."""
    v = V(0.5)
    S = lambda s: int(round(s * 2))  # studs -> voxels (voxel 0.5)
    hw = S(width / 2) - 1
    # counter
    v.box((-S(7), 0, S(-0.8)), (S(7) - 1, S(3.5) - 1, S(2.2) - 1), planks)
    v.box((-S(7.2), S(3.5) - 1, S(-1.0)), (S(7.2) - 1, S(3.5) - 1, S(2.4) - 1), WOOD[2])
    # posts
    for x in (-hw, hw - 1):
        v.box((x, 0, S(2.0)), (x + 1, S(height) - 2, S(2.6)), WOOD[3])
        v.box((x, 0, S(-3.5)), (x + 1, S(9) - 1, S(-3.5) + 1), WOOD[3])
    # awning: stripes along x, sloping down to the front
    for z in range(S(depth_front + 1.5), S(2.8)):
        t = (z - S(depth_front + 1.5)) / (S(2.8) - S(depth_front + 1.5))
        y = int(S(9) + t * S(1.6))
        v.box((-hw - 1, y, z), (hw, y, z), lambda x, yy, zz: awning[(x // 3) % 2])
    # scalloped front edge
    for x in range(-hw - 1, hw + 1):
        if x % 3 != 1:
            v.box((x, S(9) - 1, S(depth_front + 1.5)), (x, S(9) - 1, S(depth_front + 1.5)), awning[(x // 3) % 2])
    # sign board up the back (the game writes on it at y 10.6, z 0.9)
    v.box((-S(5), S(10) - 1, S(1.2)), (S(5) - 1, S(height) - 1, S(1.8)), sign)
    # stumps for the bags
    for sx in (-5, 0, 5):
        v.cyl(S(sx), S(-4.5), 2.6, 0, S(2) - 1, lambda x, y, z: WOOD[0] if y < S(2) - 1 else (226, 176, 120))
    return v.out()


def bag_stand():
    return stall()


# -----------------------------------------------------------------------------------------------------------------
def rewards_stall():
    """rewards_stall (19 x 15.5 x 8.6): back wall x -8.5..8.5 at z 2.3..3.1 up to 9, posts at x +-7.9, two counters
    (x +-3.3, z -4.4..-1.8, top 3.8), a roof, and the REWARDS board across the top (front face z -0.6)."""
    v = V(0.5)
    S = lambda s: int(round(s * 2))
    gold = [(255, 205, 60), (240, 170, 40)]
    v.box((-S(8.5), 0, S(2.3)), (S(8.5) - 1, S(9) - 1, S(3.1) - 1), lambda x, y, z: (60, 120, 200) if (y // 4) % 2 == 0 else (70, 140, 220))
    for x in (-S(7.9) - 1, S(7.9) - 1):
        v.box((x, 0, -S(2.2)), (x + 2, S(12) - 1, S(3.2) - 1), WOOD[3])
    for cx in (-3.3, 3.3):
        v.box((S(cx - 2.1), 0, S(-4.4)), (S(cx + 2.1) - 1, S(3.8) - 1, S(-1.8) - 1), planks)
        v.box((S(cx - 2.2), S(3.8) - 1, S(-4.5)), (S(cx + 2.2) - 1, S(3.8) - 1, S(-1.7) - 1), gold[0])
    # roof
    for z in range(S(-4.3), S(4)):
        v.box((-S(9.5), S(12), z), (S(9.5) - 1, S(12) + 1, z), lambda x, y, zz: ROOF[(x // 3) % 2])
    # the board across the top
    v.box((-S(8.5), S(12) + 2, S(-0.6)), (S(8.5) - 1, S(15.5) - 1, S(0.3)), (44, 30, 60))
    v.box((-S(8.5), S(12) + 2, S(-0.7)), (S(8.5) - 1, S(12) + 2, S(-0.6)), gold[0])
    # a gift box on each counter
    for cx, col in ((-3.3, (255, 90, 120)), (3.3, (90, 200, 255))):
        v.box((S(cx) - 2, S(3.8), S(-3.4) - 2), (S(cx) + 1, S(3.8) + 3, S(-3.4) + 1), col)
        v.box((S(cx), S(3.8), S(-3.4) - 2), (S(cx), S(3.8) + 4, S(-3.4) + 1), gold[0])
    return v.out()


# -----------------------------------------------------------------------------------------------------------------
def lantern_post():
    """lantern_post (1.3 x 6.2 x 3.1): a post with an arm reaching forward and a glowing lantern hanging from it."""
    v = V(0.25)
    S = lambda s: int(round(s * 4))
    v.box((-2, 0, -2), (1, S(5.8), 1), lambda x, y, z: WOOD[3] if y < 3 else WOOD[0])
    v.box((-3, 0, -3), (2, 1, 2), STONE[0])
    v.box((-1, S(5.4), -S(2.4)), (0, S(5.8), -2), WOOD[0])  # the arm
    v.box((-2, S(4.0), -S(2.6)), (1, S(4.3), -S(1.7)), DARK)  # lantern cap and base
    v.box((-2, S(3.0), -S(2.6)), (1, S(4.0), -S(1.7)), GLOW)
    v.box((-2, S(2.9), -S(2.6)), (1, S(3.0), -S(1.7)), DARK)
    v.box((-1, S(4.3), -S(2.3)), (0, S(5.4), -S(2.1)), DARK)  # chain
    return v.out()


def gas_pump():
    """gas_pump (3.7 x 6.3 x 3): a red pump with a screen, a white top and a hose."""
    v = V(0.25)
    S = lambda s: int(round(s * 4))
    red = [(230, 60, 60), (200, 44, 44)]
    v.box((-S(1.5), 0, -S(1.2)), (S(1.5) - 1, S(5.4), S(1.2) - 1), lambda x, y, z: red[1] if y < 2 else red[0])
    v.box((-S(1.7), S(5.4), -S(1.4)), (S(1.7) - 1, S(6.3) - 1, S(1.4) - 1), WHITE)
    v.box((-S(1.0), S(3.6), -S(1.2) - 1), (S(1.0) - 1, S(4.8), -S(1.2) - 1), (40, 40, 52))
    v.box((-S(0.8), S(3.8), -S(1.2) - 1), (S(0.8) - 1, S(4.6), -S(1.2) - 1), (120, 255, 140))
    v.box((S(1.5), S(2.4), -2), (S(1.85) - 1, S(3.4), 1), (40, 40, 52))  # nozzle holder
    for y in range(S(0.4), S(2.4)):
        v.box((S(1.5) + 1, y, -1), (S(1.5) + 1, y, 0), (30, 30, 36))  # hose
    return v.out()


# -----------------------------------------------------------------------------------------------------------------
def board(width, height, depth, title_y, body, top=None, frame=(90, 58, 40)):
    """A notice board: a dark face (front face at z ~ -0.35) in a wooden frame on two legs."""
    v = V(0.5)
    S = lambda s: int(round(s * 2))
    hw = S(width / 2)
    # legs and feet
    for x in (-hw, hw - 2):
        v.box((x, 0, -1), (x + 1, S(height) - 2, 0), frame)
        v.box((x - 1, 0, -S(depth / 2)), (x + 2, 1, S(depth / 2) - 1), WOOD[3])
    # the face
    v.box((-hw + 2, S(2), -1), (hw - 3, S(height) - 3, 0), (40, 34, 46))
    # frame round it
    v.box((-hw + 1, S(2) - 1, -1), (hw - 2, S(2) - 1, 0), frame)
    v.box((-hw + 1, S(height) - 2, -1), (hw - 2, S(height) - 2, 0), frame)
    # a title strip (gold) under the top edge
    v.box((-hw + 2, S(title_y) - 1, -2), (hw - 3, S(title_y) - 1, -2), (255, 205, 60))
    if top:
        top(v, S, height)
    return v.out()


def leaderboard():
    return board(14.5, 13.0, 4.7, 9.9, None)


def trophy_board():
    def trophy(v, S, height):
        gold = (255, 205, 60)
        v.box((-2, S(height) - 2, -1), (1, S(height) - 1, 0), (90, 58, 40))
        v.cyl(0, 0, 2.2, S(height), S(height) + 1, gold)
        v.box((-1, S(height) + 2, -1), (0, S(height) + 3, 0), gold)
        v.cyl(0, 0, 3.4, S(height) + 4, S(height) + 7, gold)
        v.cyl(0, 0, 2.2, S(height) + 6, S(height) + 7, (220, 160, 30))
    return board(13.7, 13.0, 3.1, 10.2, None, top=trophy)


# -----------------------------------------------------------------------------------------------------------------
def party_booth():
    """party_booth (16.9 x 12.4 x 16.4), the run's garage bay: open at the front (-z), posts at the back corners,
    low side rails, a back rail, a sloped roof and the sign board at the back (z ~ 5.9)."""
    v = V(1.0)
    v.box((-8, 0, -7), (7, 0, 8), lambda x, y, z: (110, 110, 120) if (x + z) % 2 == 0 else (124, 124, 134))  # floor
    for x in (-8, 7):
        v.box((x, 1, 6), (x, 10, 7), WOOD[3])
        v.box((x, 1, -7), (x, 9, -7), WOOD[3])
        v.box((x, 2, -7), (x, 2, 7), WOOD[1])  # side rail
    v.box((-8, 2, 7), (7, 2, 7), WOOD[1])
    v.box((-6, 4, 6), (5, 8, 6), (44, 34, 30))  # sign board
    for z in range(-8, 9):
        y = 10 + (z + 8) // 6
        v.box((-9, y, z), (8, y, z), lambda x, yy, zz: ROOF[(x // 2) % 2])
    return v.out()


def shredder():
    """shredder (7.8 x 11.3 x 14.6): an orange machine, the hopper on top toward the back (+z; mouth at y 8.8,
    z 4.8 at scale 1), steel rollers, the coin chute low at the front (-z)."""
    v = V(0.5)
    S = lambda s: int(round(s * 2))
    orange = [(255, 140, 40), (240, 120, 30)]
    yellow = [(255, 205, 50), (240, 185, 40)]
    v.box((-S(3.9), 0, S(-7.3)), (S(3.9) - 1, 1, S(5.9) - 1), (60, 60, 70))  # chassis
    v.box((-S(3.6), 2, S(-5)), (S(3.6) - 1, S(7.5), S(5.5) - 1), lambda x, y, z: orange[(y // 3) % 2])
    # hopper: stepped funnel getting wider upward
    for k in range(6):
        w = S(2.6) + k
        v.box((-w, S(7.5) + 1 + k, S(1.5) - k), (w - 1, S(7.5) + 1 + k, S(5.8) + k // 2), yellow[k % 2])
    v.clear((-S(2.2), S(7.5) + 3, S(2.4)), (S(2.2) - 1, S(7.5) + 6, S(5.2)))  # the mouth
    v.box((-S(2.2), S(7.5) + 2, S(2.4)), (S(2.2) - 1, S(7.5) + 2, S(5.2)), (35, 30, 40))
    for z in (S(3.0), S(4.6)):
        v.box((-S(2.0), S(7.5) + 3, z), (S(2.0) - 1, S(7.5) + 3, z), (190, 190, 205))  # rollers
    # coin chute and tray at the front
    v.box((-S(1.4), 2, S(-7.0)), (S(1.4) - 1, S(2.4), S(-5.0)), (60, 60, 70))
    v.box((-S(1.8), 0, S(-7.3)), (S(1.8) - 1, 1, S(-5.6)), yellow[0])
    # wheels
    for x in (-S(3.9), S(3.9) - 2):
        for z in (S(-5), S(4)):
            v.box((x, 0, z), (x + 1, 3, z + 3), (30, 30, 36))
    return v.out()


def sell_pad():
    """sell_pad (13 x 1.3 x 13): a log frame round a glowing green pad."""
    v = V(0.5)
    S = lambda s: int(round(s * 2))
    h = S(6.5)
    v.box((-h, 0, -h), (h - 1, 1, h - 1), lambda x, y, z: (110, 230, 90) if (x // 2 + z // 2) % 2 == 0 else (90, 210, 70))
    for a in (-h, h - 2):
        v.box((a, 0, -h), (a + 1, 2, h - 1), logs)
        v.box((-h, 0, a), (h - 1, 2, a + 1), logs)
    return v.out()


def turntable():
    v = V(0.5)
    v.cyl(0, 0, 10.2, 0, 1, lambda x, y, z: (70, 70, 78) if (x * x + z * z) > 80 else (96, 96, 106))
    return v.out()


# extra shift (studs) of a prop against the toy model's origin, to line its walls up with the game's colliders
ADJUST = {
    "log_cabin": (0.0, -0.5, 0.5),
}

PROPS = {
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
}
