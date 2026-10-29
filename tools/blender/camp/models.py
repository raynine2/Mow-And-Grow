"""The area camps' models (owner, 29 Oct: "remake every zone hub except 1 ... bigger ... feel more alive ... if ur
going to add or make stuff use blender"). Each function builds one model with tools/blender/camp/_campkit.py;
tools/blender/camp/build.py turns them into native-part text for src/server/CampProps.luau and renders previews.

Front = +Y, ground at z = 0, 1 unit = 1 stud. "@role" colours are picked per area when placed (server/CampDress).
"""
import math


# ---------------------------------------------------------------------------------------------------------------
# shared pieces
# ---------------------------------------------------------------------------------------------------------------
def _wall_box(k, name, c, n, t_off, n_off, z, size_t, size_n, size_z, m, rot_n=0.0):
    """A box on a wall: c = point on the wall's outer face, n = outward normal (+-X or +-Y)."""
    nx, ny = n
    tx, ty = -ny, nx  # along the wall
    loc = (c[0] + tx * t_off + nx * n_off, c[1] + ty * t_off + ny * n_off, z)
    size = (size_t, size_n, size_z) if ny != 0 else (size_n, size_t, size_z)
    rot = (0, 0, 0) if rot_n == 0 else ((0, rot_n, 0) if ny != 0 else (rot_n, 0, 0))
    return k.box(name, size, loc, rot, m)


def window(k, name, c, n, z, w, h, trim, glass, shutter=None, box=None, flower=None, leaf=None):
    """A window on a wall: frame, pane, cross bars, sill, shutters and maybe a flower box."""
    _wall_box(k, name + "_frame", c, n, 0, 0.12, z, w + 0.6, 0.25, h + 0.6, trim)
    _wall_box(k, name + "_pane", c, n, 0, 0.22, z, w, 0.2, h, glass)
    _wall_box(k, name + "_mv", c, n, 0, 0.32, z, 0.18, 0.22, h, trim)
    _wall_box(k, name + "_mh", c, n, 0, 0.32, z + 0.1, w, 0.22, 0.18, trim)
    _wall_box(k, name + "_sill", c, n, 0, 0.32, z - h / 2 - 0.12, w + 0.9, 0.6, 0.25, trim)
    if shutter:
        for s in (-1, 1):
            _wall_box(k, name + "_sh%d" % s, c, n, s * (w / 2 + 0.62), 0.18, z, 0.9, 0.2, h + 0.15, shutter)
    if box:
        _wall_box(k, name + "_box", c, n, 0, 0.62, z - h / 2 - 0.62, w + 0.3, 0.75, 0.6, box)
        _wall_box(k, name + "_leaf", c, n, 0, 0.62, z - h / 2 - 0.24, w + 0.1, 0.6, 0.22, leaf)
        for i in (-1, 0, 1):
            _wall_box(k, name + "_fl%d" % i, c, n, i * (w / 3), 0.62, z - h / 2 - 0.02, 0.45, 0.45, 0.42, flower)


def hip_roof(k, name, r0, r1, z0, z1, m, steps=4, trim=None):
    """A four-sided roof in the world's stepped (voxel) look: square slabs from half-size r0 at z0 up to r1 at z1,
    each with a thin lip in `trim` under it."""
    out = []
    h = (z1 - z0) / steps
    for i in range(steps):
        r = r0 + (r1 - r0) * i / max(1, steps - 1)
        out.append(k.box("%s_%d" % (name, i), (r * 2, r * 2, h), (0, 0, z0 + h * (i + 0.5)), (0, 0, 0), m))
        if trim and i == 0:
            out.append(k.box("%s_lip" % name, (r * 2 + 0.3, r * 2 + 0.3, 0.25), (0, 0, z0 + 0.12), (0, 0, 0), trim))
    return out


# ---------------------------------------------------------------------------------------------------------------
# the camp house
# ---------------------------------------------------------------------------------------------------------------
def camp_house(k):
    W, D = 13.0, 10.0
    hx, hy = W / 2, D / 2
    z0, H = 1.0, 7.0
    base = k.mat("VStone", "@base")
    wall = k.mat("VPlank", "@wall")
    trim = k.mat("WoodPlanks", "@trim")
    roofm = k.mat("VRoof", "@roof")
    roof2 = k.mat("VRoof", "@roof2")
    doorm = k.mat("WoodPlanks", "@door")
    glass = k.mat("Glass", "@glass")
    stone = k.mat("VStone", "@stone")
    gold = k.mat("Metal", (230, 190, 90))
    flower = k.mat("SmoothPlastic", "@flower")
    leaf = k.mat("LeafyGrass", (80, 140, 60))
    shutter = k.mat("WoodPlanks", "@accent")
    log = k.mat("VLog", "@wood")
    dark = k.mat("SmoothPlastic", (40, 34, 30))

    k.box("plinth", (W + 1.2, D + 1.2, 1.0), (0, 0, 0.5), m=base)
    k.box("wallF", (W, 0.8, H), (0, hy - 0.4, z0 + H / 2), m=wall)
    k.box("wallB", (W, 0.8, H), (0, -hy + 0.4, z0 + H / 2), m=wall)
    k.box("wallL", (0.8, D - 1.6, H), (-hx + 0.4, 0, z0 + H / 2), m=wall)
    k.box("wallR", (0.8, D - 1.6, H), (hx - 0.4, 0, z0 + H / 2), m=wall)
    for sx in (-1, 1):
        for sy in (-1, 1):
            k.box("post%d%d" % (sx, sy), (1.1, 1.1, H + 0.2), (sx * (hx - 0.3), sy * (hy - 0.3), z0 + H / 2 + 0.1), m=trim)
    for nm, z in (("sill", z0 + 0.25), ("band", z0 + H - 0.25)):
        k.box(nm + "F", (W + 0.3, 0.3, 0.5), (0, hy + 0.05, z), m=trim)
        k.box(nm + "B", (W + 0.3, 0.3, 0.5), (0, -hy - 0.05, z), m=trim)
        k.box(nm + "L", (0.3, D + 0.3, 0.5), (-hx - 0.05, 0, z), m=trim)
        k.box(nm + "R", (0.3, D + 0.3, 0.5), (hx + 0.05, 0, z), m=trim)
    # roof (ridge along X) and its gables
    rise = 4.8
    k.roof("roof", W + 1.8, D, rise, z0 + H, roofm, over=1.0, thick=0.55, ridge_m=roof2, shingles=roof2)
    for sx in (-1, 1):
        k.gable("gable%d" % sx, D, rise, z0 + H, sx * (hx - 0.4), wall, thick=0.8)
        k.box("gwin%d" % sx, (0.3, 1.7, 1.7), (sx * (hx - 0.05), 0, z0 + H + 1.7), m=trim)
        k.box("gwinp%d" % sx, (0.25, 1.15, 1.15), (sx * (hx + 0.05), 0, z0 + H + 1.7), m=glass)
    # door, step and a little canopy over it
    k.box("doorframe", (3.4, 0.5, 5.7), (0, hy + 0.05, z0 + 2.85), m=trim)
    k.box("door", (2.6, 0.4, 5.1), (0, hy + 0.2, z0 + 2.55), m=doorm)
    for x in (-0.45, 0.45):
        k.box("doorline%.0f" % (x * 10), (0.14, 0.42, 5.1), (x, hy + 0.22, z0 + 2.55), m=trim)
    k.ball("knob", 0.2, (0.85, hy + 0.45, z0 + 2.5), m=gold)
    k.box("step", (4.2, 1.5, 0.5), (0, hy + 1.0, 0.75), m=stone)
    k.box("canopy", (4.8, 2.6, 0.35), (0, hy + 1.25, z0 + 6.25), (-18, 0, 0), m=roofm)
    for x in (-2.0, 2.0):
        k.beam("bracket%.0f" % x, (x, hy, z0 + 4.9), (x, hy + 1.9, z0 + 5.95), 0.3, 0.3, trim)
    # windows: two in front with flower boxes, one each side, one at the back
    for x in (-3.95, 3.95):
        window(k, "winF%.0f" % x, (x, hy, 0), (0, 1), z0 + 3.9, 2.2, 2.4, trim, glass, shutter, trim, flower, leaf)
    for sx in (-1, 1):
        window(k, "winS%d" % sx, (sx * hx, 0.6, 0), (sx, 0), z0 + 3.9, 2.0, 2.2, trim, glass, shutter)
    window(k, "winB", (2.5, -hy, 0), (0, -1), z0 + 3.9, 2.0, 2.2, trim, glass, shutter)
    # chimney on the back slope
    cx, cy = -hx + 2.4, -hy + 2.2
    k.box("chimney", (1.9, 1.9, 7.2), (cx, cy, z0 + H + 2.4), m=stone)
    k.box("chimcap", (2.4, 2.4, 0.5), (cx, cy, z0 + H + 6.1), m=stone)
    k.box("chimhole", (1.2, 1.2, 0.12), (cx, cy, z0 + H + 6.36), m=dark)
    k.box("Smoke", (0.5, 0.5, 0.5), (cx, cy, z0 + H + 6.8), m=k.mat("Mark", "Smoke"))
    # a lamp by the door, firewood stacked on the right
    k.box("Lamp", (0.4, 0.4, 0.4), (2.55, hy + 0.7, z0 + 4.9), m=k.mat("Mark", "Lamp"))
    for i, (y, z) in enumerate(((-1.5, 0.45), (-0.55, 0.45), (0.4, 0.45), (-1.0, 1.3), (-0.05, 1.3), (-0.55, 2.1))):
        k.cyl("firewood%d" % i, 0.45, 3.2, (hx + 1.1, y, z), (90, 0, 0), log)
    # a bench under the front window
    k.box("benchseat", (3.0, 0.9, 0.3), (-4.0, hy + 1.3, 1.45), m=trim)
    for x in (-5.2, -2.8):
        k.box("benchleg%.0f" % x, (0.3, 0.8, 1.3), (x, hy + 1.3, 0.65), m=trim)


# ---------------------------------------------------------------------------------------------------------------
# a canvas tent
# ---------------------------------------------------------------------------------------------------------------
def camp_tent(k):
    cloth = k.mat("Fabric", "@cloth")
    inner = k.mat("Fabric", (64, 50, 42))
    white = k.mat("Fabric", (240, 232, 214))
    wood = k.mat("VLog", "@wood")
    rope = k.mat("Fabric", (210, 190, 150))
    bed = k.mat("Fabric", "@accent")
    L, Wd, Ht = 7.0, 5.8, 4.4
    half = Wd / 2
    ang = math.atan2(Ht, half)
    slope = math.hypot(half, Ht)
    for s in (1, -1):
        nx, nz = s * math.sin(ang), math.cos(ang)
        k.box("canvas%d" % s, (slope + 0.2, L, 0.16), (s * half / 2 + nx * 0.08, 0, Ht / 2 + nz * 0.08), (0, s * math.degrees(ang), 0), cloth)
        # a pale stripe along the bottom edge
        k.box("stripe%d" % s, (0.6, L + 0.04, 0.18), (s * half * 0.88 + nx * 0.12, 0, Ht * 0.12 + nz * 0.12), (0, s * math.degrees(ang), 0), white)
    # the back closed, the front half open (dark inside)
    for y, m, rot_l in ((-L / 2 + 0.05, cloth, None), (L / 2 - 0.35, inner, None)):
        k.wedge("end_r%.0f" % y, (0.14, half, Ht), (half / 2, y, Ht / 2), (0, 0, -90), m)
        k.wedge("end_l%.0f" % y, (0.14, half, Ht), (-half / 2, y, Ht / 2), (0, 0, 90), m)
    k.wedge("flap", (0.16, half, Ht), (-half / 2, L / 2, Ht / 2), (0, 0, 90), cloth)
    k.rod("ridgepole", (0, -L / 2 - 0.3, Ht + 0.12), (0, L / 2 + 0.3, Ht + 0.12), 0.14, wood)
    for y in (-L / 2 - 0.25, L / 2 + 0.25):
        k.rod("pole%.0f" % y, (0, y, 0), (0, y, Ht + 0.45), 0.15, wood)
        sy = 1 if y > 0 else -1
        k.beam("rope%.0f" % y, (0, y, Ht + 0.3), (0, y + sy * 2.3, 0.12), 0.08, 0.08, rope)
        k.box("peg%.0f" % y, (0.25, 0.25, 0.5), (0, y + sy * 2.35, 0.2), m=wood)
    k.box("bedroll", (1.5, 3.4, 0.45), (0.75, 0.4, 0.23), m=bed)
    k.box("Lamp", (0.3, 0.3, 0.3), (0.0, L / 2 + 0.25, Ht - 0.3), m=k.mat("Mark", "Lamp"))


# ---------------------------------------------------------------------------------------------------------------
# the entrance arch with the camp's name
# ---------------------------------------------------------------------------------------------------------------
def camp_arch(k):
    log = k.mat("VLog", "@wood")
    stone = k.mat("VStone", "@base")
    roofm = k.mat("VRoof", "@roof")
    board = k.mat("VPlank", "@board")
    trim = k.mat("WoodPlanks", "@trim")
    cloth = k.mat("Fabric", "@cloth")
    acc = k.mat("Fabric", "@accent")
    iron = k.mat("Metal", (58, 56, 56))
    X = 6.6
    for sx in (-1, 1):
        k.box("foot%d" % sx, (2.5, 2.5, 1.6), (sx * X, 0, 0.8), m=stone)
        k.box("post%d" % sx, (1.5, 1.5, 9.8), (sx * X, 0, 1.6 + 4.9), m=log)
        k.beam("brace%d" % sx, (sx * X, 0, 7.0), (sx * (X - 2.6), 0, 9.3), 0.7, 0.7, log)
        k.box("Lamp%d" % sx, (0.4, 0.4, 0.4), (sx * X, 1.25, 6.2), m=k.mat("Mark", "Lamp"))
    k.box("beam", (17.2, 1.4, 1.4), (0, 0, 10.9), m=log)
    k.box("beam2", (13.2, 1.0, 1.0), (0, 0, 9.4), m=log)
    k.roof("cap", 18.0, 2.2, 1.1, 11.6, roofm, over=0.35, thick=0.45, ridge_m=k.mat("VRoof", "@roof2"))
    for x in (-3.4, 3.4):
        k.box("chain%.0f" % x, (0.14, 0.14, 0.8), (x, 0, 8.55), m=iron)
    k.box("sign", (8.6, 0.4, 2.2), (0, 0, 7.1), m=board)
    k.box("signrim", (9.0, 0.3, 2.6), (0, -0.02, 7.1), m=trim)
    k.box("SignFace", (8.2, 0.46, 1.8), (0, 0, 7.1), m=k.mat("Mark", "SignFace"))
    for sx, nm in ((-1, "BanL"), (1, "BanR")):
        x = sx * 8.0
        k.group(nm, (x, 0, 10.2))
        k.box(nm + "_cloth", (1.7, 0.14, 3.8), (x, 0, 8.3), m=cloth)
        k.box(nm + "_stripe", (1.7, 0.16, 0.4), (x, 0, 9.7), m=acc)
        k.box(nm + "_emblem", (0.75, 0.16, 0.75), (x, 0, 8.0), (0, 45, 0), m=acc)
        k.wedge(nm + "_tl", (0.14, 0.85, 0.7), (x - 0.43, 0, 6.05), (90, 0, 90), cloth)
        k.wedge(nm + "_tr", (0.14, 0.85, 0.7), (x + 0.43, 0, 6.05), (90, 0, -90), cloth)
        k.group(None)


# ---------------------------------------------------------------------------------------------------------------
# a signpost (three arrows the camp turns toward the boss, the next area and the shop)
# ---------------------------------------------------------------------------------------------------------------
def camp_signpost(k):
    log = k.mat("VLog", "@wood")
    board = k.mat("VPlank", "@board")
    stone = k.mat("VStone", "@base")
    trim = k.mat("WoodPlanks", "@trim")
    k.box("foot", (1.5, 1.5, 0.6), (0, 0, 0.3), m=stone)
    k.box("post", (0.75, 0.75, 7.4), (0, 0, 0.6 + 3.7), m=log)
    k.box("cap", (1.05, 1.05, 0.4), (0, 0, 8.2), m=trim)
    for i, z in enumerate((7.1, 5.75, 4.4), 1):
        k.group("Arrow%d" % i, (0, 0, z))
        k.box("arrow%d" % i, (3.9, 0.32, 1.05), (2.3, 0, z), m=board)
        k.wedge("tipu%d" % i, (0.32, 0.75, 0.525), (4.62, 0, z + 0.2625), (0, 0, -90), board)
        k.wedge("tipd%d" % i, (0.32, 0.75, 0.525), (4.62, 0, z - 0.2625), (180, 0, 90), board)
        k.group(None)


# ---------------------------------------------------------------------------------------------------------------
# a notice board
# ---------------------------------------------------------------------------------------------------------------
def camp_noticeboard(k):
    log = k.mat("VLog", "@wood")
    board = k.mat("VPlank", "@board")
    trim = k.mat("WoodPlanks", "@trim")
    roofm = k.mat("VRoof", "@roof")
    pin = k.mat("SmoothPlastic", (220, 50, 40))
    for sx in (-1, 1):
        k.box("leg%d" % sx, (0.6, 0.6, 6.0), (sx * 2.45, 0, 3.0), m=log)
    k.box("board", (4.4, 0.35, 3.0), (0, 0, 3.9), m=board)
    k.box("frameT", (4.8, 0.45, 0.3), (0, 0, 5.5), m=trim)
    k.box("frameB", (4.8, 0.45, 0.3), (0, 0, 2.3), m=trim)
    k.roof("nbroof", 6.0, 1.4, 0.8, 6.0, roofm, over=0.35, thick=0.35, ridge_m=k.mat("VRoof", "@roof2"))
    papers = [((-1.35, 4.5), (250, 246, 230), 6), ((0.1, 4.7), (255, 236, 150), -4), ((1.4, 4.4), (255, 205, 220), 8),
              ((-0.7, 3.2), (200, 230, 255), -7), ((0.9, 3.1), (250, 246, 230), 3)]
    for i, ((x, z), col, tilt) in enumerate(papers):
        k.box("paper%d" % i, (1.05, 0.06, 1.25), (x, 0.21, z), (0, tilt, 0), k.mat("SmoothPlastic", col))
        k.box("pin%d" % i, (0.16, 0.12, 0.16), (x, 0.27, z + 0.5), m=pin)


# ---------------------------------------------------------------------------------------------------------------
# a banner on a pole (its cloth sways: group "Cloth")
# ---------------------------------------------------------------------------------------------------------------
def camp_banner(k):
    log = k.mat("VLog", "@wood")
    gold = k.mat("Metal", (230, 190, 90))
    cloth = k.mat("Fabric", "@cloth")
    acc = k.mat("Fabric", "@accent")
    stone = k.mat("VStone", "@base")
    k.box("foot", (1.3, 1.3, 0.5), (0, 0, 0.25), m=stone)
    k.cyl("pole", 0.24, 9.6, (0, 0, 0.5 + 4.8), m=log)
    k.ball("finial", 0.42, (0, 0, 10.4), m=gold)
    k.cyl("bar", 0.13, 2.9, (0, 0.3, 9.45), (0, 90, 0), log)
    k.group("Cloth", (0, 0.3, 9.4))
    k.box("cloth", (2.5, 0.12, 4.4), (0, 0.32, 7.2), m=cloth)
    k.box("stripe", (2.5, 0.14, 0.45), (0, 0.33, 8.85), m=acc)
    k.box("emblem", (1.05, 0.14, 1.05), (0, 0.34, 7.3), (0, 45, 0), m=acc)
    k.wedge("tail_l", (0.12, 1.25, 0.9), (-0.62, 0.32, 4.55), (90, 0, 90), cloth)
    k.wedge("tail_r", (0.12, 1.25, 0.9), (0.62, 0.32, 4.55), (90, 0, -90), cloth)
    k.group(None)


# ---------------------------------------------------------------------------------------------------------------
# a market cart with the area's goods
# ---------------------------------------------------------------------------------------------------------------
def camp_cart(k):
    wood = k.mat("VPlank", "@wood")
    dark = k.mat("Wood", (90, 62, 44))
    iron = k.mat("Metal", (60, 58, 56))
    cloth = k.mat("Fabric", "@cloth")
    white = k.mat("Fabric", (240, 232, 214))
    g1 = k.mat("SmoothPlastic", "@goods1")
    g2 = k.mat("SmoothPlastic", "@goods2")
    k.box("bed", (3.6, 6.0, 0.4), (0, 0, 2.0), m=wood)
    for sx in (-1, 1):
        k.box("side%d" % sx, (0.3, 6.0, 1.2), (sx * 1.95, 0, 2.7), m=wood)
        k.cyl("wheel%d" % sx, 1.45, 0.35, (sx * 2.3, -0.8, 1.45), (0, 90, 0), dark, verts=16)
        k.cyl("hub%d" % sx, 0.42, 0.55, (sx * 2.42, -0.8, 1.45), (0, 90, 0), iron)
        k.beam("shaft%d" % sx, (sx * 1.2, 3.0, 2.0), (sx * 0.9, 6.3, 1.0), 0.3, 0.3, dark)
        k.box("cpost%d" % sx, (0.25, 0.25, 3.6), (sx * 1.75, -2.75, 4.1), m=dark)
        k.box("cpostf%d" % sx, (0.25, 0.25, 3.0), (sx * 1.75, 2.75, 3.8), m=dark)
    k.box("back", (3.9, 0.3, 1.2), (0, -3.1, 2.7), m=wood)
    k.box("front", (3.9, 0.3, 0.8), (0, 3.1, 2.5), m=wood)
    k.rod("axle", (-2.2, -0.8, 1.45), (2.2, -0.8, 1.45), 0.15, iron)
    k.box("stand", (0.4, 0.4, 1.9), (0, 2.5, 0.95), m=dark)
    k.box("handle", (2.2, 0.3, 0.3), (0, 6.3, 1.0), m=dark)
    k.box("canopy", (4.4, 6.6, 0.25), (0, 0, 5.9), (-5, 0, 0), m=cloth)
    for y in (-1.6, 1.6):
        k.box("canstripe%.0f" % y, (4.42, 1.1, 0.27), (0, y, 5.9 + (y * 0.087)), (-5, 0, 0), m=white)
    for i, (x, y, s, m) in enumerate(((-0.8, -1.8, 1.2, g1), (0.8, -1.9, 1.1, g2), (-0.7, 0.0, 1.0, g2),
                                       (0.85, 0.2, 1.15, g1), (0.0, 1.8, 1.0, g1), (-0.1, -1.0, 0.9, g1))):
        z = 2.2 + s / 2 + (0.95 if i == 5 else 0)
        k.box("goods%d" % i, (s, s, s * 0.9), (x, y, z), (0, 0, (i * 23) % 40 - 20), m)


# ---------------------------------------------------------------------------------------------------------------
# a stone well with a little roof
# ---------------------------------------------------------------------------------------------------------------
def camp_well(k):
    stone = k.mat("VStone", "@stone")
    cap = k.mat("VStone", "@base")
    water = k.mat("Glass", "@water", 0.1)
    log = k.mat("VLog", "@wood")
    roofm = k.mat("VRoof", "@roof")
    trim = k.mat("WoodPlanks", "@trim")
    rope = k.mat("Fabric", (210, 190, 150))
    wood = k.mat("WoodPlanks", (140, 100, 66))
    iron = k.mat("Metal", (60, 58, 56))
    for i in range(8):
        a = math.radians(i * 45)
        k.box("ring%d" % i, (2.2, 0.85, 2.3), (math.sin(a) * 2.15, math.cos(a) * 2.15, 1.15), (0, 0, -i * 45), stone)
        k.box("rim%d" % i, (2.35, 1.05, 0.4), (math.sin(a) * 2.2, math.cos(a) * 2.2, 2.5), (0, 0, -i * 45), cap)
    k.cyl("water", 1.9, 0.2, (0, 0, 1.5), m=water, verts=16)
    for sx in (-1, 1):
        k.box("wpost%d" % sx, (0.6, 0.6, 4.6), (sx * 2.25, 0, 2.7 + 2.3), m=log)
    k.roof("wroof", 5.8, 3.4, 1.5, 7.2, roofm, over=0.45, thick=0.4, ridge_m=k.mat("VRoof", "@roof2"))
    k.rod("crank", (-2.6, 0, 5.9), (2.6, 0, 5.9), 0.2, log)
    k.box("handle1", (0.25, 0.25, 1.1), (2.75, 0, 5.45), m=wood)
    k.box("handle2", (0.25, 0.9, 0.25), (2.75, 0.35, 4.95), m=wood)
    k.box("rope", (0.09, 0.09, 2.3), (0.35, 0, 4.7), m=rope)
    k.cyl("bucket", 0.48, 0.75, (0.35, 0, 3.2), m=wood)
    k.cyl("bucketband", 0.5, 0.12, (0.35, 0, 3.4), m=iron)


# ---------------------------------------------------------------------------------------------------------------
# a gnome villager (legs, arms and head move: client/CampLife)
# ---------------------------------------------------------------------------------------------------------------
def camp_gnome(k):
    skin = k.mat("SmoothPlastic", "@skin")
    coat = k.mat("Fabric", "@coat")
    pants = k.mat("Fabric", "@pants")
    hat = k.mat("Fabric", "@hat")
    beard = k.mat("SmoothPlastic", "@beard")
    boot = k.mat("Leather", (62, 44, 34))
    belt = k.mat("Leather", (52, 38, 30))
    gold = k.mat("Metal", (240, 200, 90))
    nose = k.mat("SmoothPlastic", (240, 150, 130))
    eye = k.mat("SmoothPlastic", (25, 22, 24))
    for s, nm in ((-1, "legL"), (1, "legR")):
        k.group(nm, (s * 0.36, 0, 1.15))
        k.box(nm + "_leg", (0.56, 0.6, 0.85), (s * 0.36, 0, 0.78), m=pants)
        k.box(nm + "_boot", (0.66, 0.98, 0.42), (s * 0.36, 0.13, 0.21), m=boot)
        k.group(None)
    k.box("body", (1.6, 1.15, 1.3), (0, 0, 1.8), m=coat)
    k.box("belt", (1.66, 1.21, 0.26), (0, 0, 1.36), m=belt)
    k.box("buckle", (0.42, 0.12, 0.32), (0, 0.63, 1.36), m=gold)
    for s, nm in ((-1, "armL"), (1, "armR")):
        k.group(nm, (s * 0.98, 0, 2.3))
        k.box(nm + "_arm", (0.46, 0.52, 1.05), (s * 1.02, 0, 1.85), m=coat)
        k.ball(nm + "_hand", 0.29, (s * 1.02, 0.06, 1.2), m=skin)
        if s > 0:
            k.box("Hand", (0.2, 0.2, 0.2), (s * 1.02, 0.1, 1.1), m=k.mat("Mark", "Hand"))
        k.group(None)
    k.group("Head", (0, 0, 2.45))
    k.box("head", (1.15, 1.05, 0.95), (0, 0, 2.92), m=skin)
    k.ball("nose", 0.23, (0, 0.6, 2.85), m=nose)
    for s in (-1, 1):
        k.box("eye%d" % s, (0.15, 0.06, 0.2), (s * 0.27, 0.535, 3.08), m=eye)
    k.box("beard", (1.22, 0.55, 0.85), (0, 0.42, 2.38), m=beard)
    k.box("beard2", (0.8, 0.45, 0.45), (0, 0.48, 1.88), m=beard)
    k.cyl("brim", 0.74, 0.2, (0, 0, 3.47), m=hat, verts=16)
    k.stepped_cone("hat", 0.62, 0.16, 3.55, 1.7, 4, hat)
    k.ball("tip", 0.17, (0, 0, 5.3), m=hat)
    k.group(None)


# ---------------------------------------------------------------------------------------------------------------
# the areas' landmarks
# ---------------------------------------------------------------------------------------------------------------
def camp_windmill(k):
    stone = k.mat("VStone", "@base")
    tower = k.mat("Plaster", "@tower")
    trim = k.mat("WoodPlanks", "@trim")
    roofm = k.mat("VRoof", "@roof")
    sail = k.mat("Fabric", "@sail")
    dark = k.mat("Wood", (92, 64, 46))
    glass = k.mat("Glass", "@glass")
    door = k.mat("WoodPlanks", "@door")
    k.box("plinth", (8.6, 8.6, 0.8), (0, 0, 0.4), m=stone)
    tiers = [(7.4, 0.8, 4.4), (6.6, 5.2, 4.0), (5.8, 9.2, 3.8), (5.0, 13.0, 3.2)]
    for i, (w, z, h) in enumerate(tiers):
        k.box("t%d" % i, (w, w, h), (0, 0, z + h / 2), m=tower)
        k.box("t%do" % i, (w * 0.86, w * 0.86, h), (0, 0, z + h / 2), (0, 0, 45), tower)
        k.box("b%d" % i, (w + 0.3, w + 0.3, 0.4), (0, 0, z + h), m=trim)
    k.box("doorframe", (2.7, 0.4, 4.4), (0, 3.65, 3.0), m=trim)
    k.box("door", (2.0, 0.4, 3.8), (0, 3.8, 2.7), m=door)
    for i, z in enumerate((7.2, 11.0)):
        w = tiers[i + 1][0] / 2
        k.box("wf%d" % i, (1.6, 0.3, 1.9), (0, w + 0.05, z), m=trim)
        k.box("wp%d" % i, (1.1, 0.3, 1.4), (0, w + 0.15, z), m=glass)
    k.roof("cap", 6.8, 5.4, 2.8, 16.2, roofm, over=0.6, thick=0.5, ridge_m=k.mat("VRoof", "@roof2"))
    for sx in (-1, 1):
        k.gable("capg%d" % sx, 5.4, 2.8, 16.2, sx * 2.6, tower, thick=0.6)
    k.group("Rotor", (0, 3.5, 15.0))
    k.cyl("hub", 0.75, 1.3, (0, 3.6, 15.0), (90, 0, 0), dark)
    for i in range(4):
        a = math.radians(i * 90 + 20)
        d = (math.sin(a), math.cos(a))
        sd = (math.cos(a), -math.sin(a))
        tip = (d[0] * 8.6, 4.2, 15.0 + d[1] * 8.6)
        k.beam("spar%d" % i, (0, 4.2, 15.0), tip, 0.45, 0.45, dark)
        for j, off in enumerate((0.25, 2.55)):
            p0 = (d[0] * 2.0 + sd[0] * off, 4.25, 15.0 + d[1] * 2.0 + sd[1] * off)
            p1 = (d[0] * 8.4 + sd[0] * off, 4.25, 15.0 + d[1] * 8.4 + sd[1] * off)
            k.beam("rail%d_%d" % (i, j), p0, p1, 0.18, 0.2, dark)
        c = (d[0] * 5.2 + sd[0] * 1.4, 4.3, 15.0 + d[1] * 5.2 + sd[1] * 1.4)
        k.box("sail%d" % i, (2.3, 0.12, 6.2), c, (0, math.degrees(a), 0), sail)
    k.group(None)


def camp_pavilion(k):
    stone = k.mat("VStone", "@base")
    post = k.mat("SmoothPlastic", "@post")
    deck = k.mat("VPlank", "@wood")
    roofm = k.mat("ClayRoofTiles", "@roof")
    trim = k.mat("WoodPlanks", "@trim")
    gold = k.mat("Metal", (230, 190, 90))
    k.box("platform", (10.4, 10.4, 1.2), (0, 0, 0.6), m=stone)
    k.box("deck", (9.6, 9.6, 0.3), (0, 0, 1.35), m=deck)
    k.box("step1", (3.6, 1.3, 0.6), (0, 5.8, 0.3), m=stone)
    k.box("step2", (3.6, 0.9, 0.6), (0, 5.55, 0.9), m=stone)
    for sx in (-1, 1):
        for sy in (-1, 1):
            k.box("pbase%d%d" % (sx, sy), (1.2, 1.2, 0.5), (sx * 3.9, sy * 3.9, 1.75), m=stone)
            k.box("post%d%d" % (sx, sy), (0.8, 0.8, 6.4), (sx * 3.9, sy * 3.9, 1.5 + 3.2), m=post)
            k.box("Lamp%d%d" % (sx, sy), (0.3, 0.3, 0.3), (sx * 3.2, sy * 3.2, 7.0), m=k.mat("Mark", "Lamp"))
    for i in range(4):
        a = math.radians(i * 90)
        dx, dy = math.sin(a), math.cos(a)
        tx, ty = -dy, dx
        k.box("beam%d" % i, (8.6 if dy else 0.6, 0.6 if dy else 8.6, 0.6), (dx * 3.9, dy * 3.9, 8.0), m=post)
        if i != 0:  # rails on three sides, the front open
            k.box("rail%d" % i, (7.0 if dy else 0.3, 0.3 if dy else 7.0, 0.3), (dx * 3.9, dy * 3.9, 3.6), m=trim)
            k.box("rail2%d" % i, (7.0 if dy else 0.3, 0.3 if dy else 7.0, 0.25), (dx * 3.9, dy * 3.9, 2.6), m=trim)
    hip_roof(k, "lower", 6.2, 3.0, 8.3, 10.3, roofm, steps=4, trim=k.mat("VRoof", "@roof2"))
    for sx in (-1, 1):
        for sy in (-1, 1):
            k.box("upturn%d%d" % (sx, sy), (1.2, 1.2, 0.45), (sx * 5.9, sy * 5.9, 9.0), (0, 0, 45), roofm)
    k.box("drum", (4.2, 4.2, 0.9), (0, 0, 10.6), m=post)
    hip_roof(k, "upper", 3.2, 0.9, 11.0, 12.9, roofm, steps=4, trim=k.mat("VRoof", "@roof2"))
    k.cyl("finial", 0.22, 1.4, (0, 0, 13.4), m=gold)
    k.ball("finialball", 0.38, (0, 0, 14.2), m=gold)


def camp_watchtower(k):
    log = k.mat("VLog", "@wood")
    deck = k.mat("VPlank", "@wood")
    roofm = k.mat("VRoof", "@roof")
    stone = k.mat("VStone", "@base")
    cloth = k.mat("Fabric", "@cloth")
    trim = k.mat("WoodPlanks", "@trim")
    for sx in (-1, 1):
        for sy in (-1, 1):
            k.box("foot%d%d" % (sx, sy), (1.4, 1.4, 0.6), (sx * 3.2, sy * 3.2, 0.3), m=stone)
            k.rod("leg%d%d" % (sx, sy), (sx * 3.2, sy * 3.2, 0.5), (sx * 2.5, sy * 2.5, 17.2), 0.42, log)
    for i in range(4):
        a = math.radians(i * 90)
        dx, dy = math.sin(a), math.cos(a)
        tx, ty = -dy, dx
        # a diagonal brace and a ring beam on each side
        k.beam("brace%d" % i, (dx * 3.05 - tx * 3.05, dy * 3.05 - ty * 3.05, 1.5), (dx * 2.75 + tx * 2.75, dy * 2.75 + ty * 2.75, 10.8), 0.32, 0.32, log)
        k.beam("ring%d" % i, (dx * 2.95 - tx * 2.95, dy * 2.95 - ty * 2.95, 6.2), (dx * 2.95 + tx * 2.95, dy * 2.95 + ty * 2.95, 6.2), 0.36, 0.36, log)
        k.beam("rail%d" % i, (dx * 3.3 - tx * 3.3, dy * 3.3 - ty * 3.3, 13.6), (dx * 3.3 + tx * 3.3, dy * 3.3 + ty * 3.3, 13.6), 0.3, 0.3, trim)
        k.beam("rail2%d" % i, (dx * 3.3 - tx * 3.3, dy * 3.3 - ty * 3.3, 12.9), (dx * 3.3 + tx * 3.3, dy * 3.3 + ty * 3.3, 12.9), 0.25, 0.25, trim)
    k.box("platform", (7.4, 7.4, 0.5), (0, 0, 12.2), m=deck)
    hip_roof(k, "roof", 4.6, 1.0, 17.0, 19.6, roofm, steps=4, trim=k.mat("VRoof", "@roof2"))
    k.cyl("flagpole", 0.12, 3.6, (0, 0, 21.0), m=log)
    k.group("Flag", (0, 0, 22.4))
    k.box("flag", (2.2, 0.1, 1.3), (1.1, 0, 22.1), m=cloth)
    k.group(None)
    for sx in (-1, 1):
        k.beam("ladder%d" % sx, (sx * 0.65, 3.9, 0), (sx * 0.65, 3.05, 12.2), 0.22, 0.22, log)
    for j in range(7):
        z = 1.2 + j * 1.6
        y = 3.9 - (3.9 - 3.05) * (z / 12.2)
        k.box("rung%d" % j, (1.5, 0.18, 0.18), (0, y, z), m=trim)
    k.box("Lamp", (0.3, 0.3, 0.3), (2.6, 2.6, 13.9), m=k.mat("Mark", "Lamp"))


def camp_boat(k):
    hull = k.mat("WoodPlanks", "@wood")
    dark = k.mat("Wood", (80, 58, 40))
    oarm = k.mat("Wood", (170, 128, 86))
    paint = k.mat("WoodPlanks", "@accent")
    k.box("bottom", (2.0, 5.0, 0.3), (0, -0.3, 0.15), m=hull)
    for sx in (-1, 1):
        k.box("side%d" % sx, (0.28, 5.4, 1.1), (sx * 1.2, -0.4, 0.7), (0, sx * 14, 0), hull)
        k.box("stripe%d" % sx, (0.3, 5.42, 0.25), (sx * 1.28, -0.4, 1.05), (0, sx * 14, 0), paint)
        k.beam("bow%d" % sx, (sx * 1.25, 2.2, 0.7), (0, 3.6, 0.85), 0.3, 1.1, hull)
    k.box("stern", (2.7, 0.3, 1.1), (0, -3.05, 0.7), m=hull)
    for y in (-1.6, 0.8):
        k.box("seat%.0f" % y, (2.4, 0.6, 0.2), (0, y, 0.95), m=dark)
    for sx in (-1, 1):
        k.rod("oar%d" % sx, (sx * 0.6, -2.0, 1.15), (sx * 0.4, 1.8, 1.0), 0.09, oarm)
        k.box("blade%d" % sx, (0.12, 1.1, 0.5), (sx * 0.38, 2.1, 1.0), (0, 90, 0), oarm)


def camp_igloo(k):
    snow = k.mat("Snow", (240, 246, 252))
    snow2 = k.mat("Snow", (214, 226, 240))
    ice = k.mat("Ice", "@goods1")
    dark = k.mat("SmoothPlastic", (34, 46, 70))
    k.ball("dome", 4.6, (0, 0, 0.3), m=snow)
    k.cyl("band1", 4.5, 0.2, (0, 0, 1.45), m=snow2, verts=20)
    k.cyl("band2", 3.72, 0.2, (0, 0, 3.0), m=snow2, verts=20)
    k.cyl("tunnel", 1.6, 3.2, (0, 4.3, 0.55), (90, 0, 0), snow, verts=16)
    k.cyl("door", 1.15, 0.2, (0, 5.92, 0.55), (90, 0, 0), dark, verts=14)
    k.cyl("vent", 0.5, 0.5, (0, 0, 4.95), m=snow2)
    for i, (x, y, s) in enumerate(((3.6, 3.4, 1.0), (4.4, 2.4, 0.9), (4.0, 2.9, 0.8))):
        k.box("ice%d" % i, (s * 1.3, s, s * 0.85), (x, y, s * 0.42 + (0.8 if i == 2 else 0)), (0, 0, i * 25), ice)


def camp_snowman(k):
    snow = k.mat("Snow", (244, 248, 252))
    coal = k.mat("SmoothPlastic", (30, 30, 34))
    carrot = k.mat("SmoothPlastic", (240, 120, 30))
    scarf = k.mat("Fabric", "@cloth")
    hat = k.mat("Fabric", (40, 40, 46))
    stick = k.mat("Wood", (110, 76, 50))
    k.ball("b1", 1.65, (0, 0, 1.4), m=snow)
    k.ball("b2", 1.2, (0, 0, 3.55), m=snow)
    k.ball("b3", 0.88, (0, 0, 5.15), m=snow)
    for s in (-1, 1):
        k.ball("eye%d" % s, 0.12, (s * 0.3, 0.78, 5.35), m=coal)
        k.rod("arm%d" % s, (s * 1.0, 0, 3.8), (s * 2.5, 0.2, 4.9), 0.09, stick)
    k.rod("nose", (0, 0.8, 5.15), (0, 1.75, 5.08), 0.13, carrot)
    for z in (3.3, 3.9):
        k.ball("button%.0f" % (z * 10), 0.14, (0, 1.17 - (z - 3.3) * 0.12, z), m=coal)
    k.cyl("scarf", 0.98, 0.38, (0, 0, 4.48), m=scarf, verts=16)
    k.box("scarftail", (0.45, 0.2, 1.1), (0.5, 0.85, 4.0), (0, 10, 0), scarf)
    k.cyl("brim", 0.82, 0.14, (0, 0, 5.95), m=hat)
    k.cyl("crown", 0.56, 1.0, (0, 0, 6.5), m=hat)


def camp_forge(k):
    stone = k.mat("VStone", "@stone")
    metal = k.mat("VMetal", "@roof")
    iron = k.mat("Metal", (52, 50, 52))
    lava = k.mat("Neon", (255, 120, 40))
    leather = k.mat("Leather", (110, 70, 44))
    wood = k.mat("VLog", "@wood")
    plank = k.mat("VPlank", "@wood")
    water = k.mat("Glass", (60, 96, 120), 0.1)
    dark = k.mat("SmoothPlastic", (30, 24, 22))
    k.box("hearth", (6.0, 4.0, 3.0), (0, 0, 1.5), m=stone)
    k.box("mouth", (2.8, 0.3, 1.5), (0, 2.05, 1.7), m=dark)
    k.box("coals", (2.4, 0.34, 0.5), (0, 2.08, 1.15), m=lava)
    k.box("Embers", (1.0, 0.4, 0.4), (0, 1.6, 1.6), m=k.mat("Mark", "Embers"))
    k.box("hood", (5.0, 3.6, 1.6), (0, 0, 3.8), m=stone)
    k.box("hood2", (3.6, 2.6, 1.4), (0, 0, 5.3), m=stone)
    k.box("stack", (2.2, 2.2, 7.0), (0, 0, 9.5), m=stone)
    k.box("stackcap", (2.8, 2.8, 0.5), (0, 0, 13.2), m=stone)
    k.box("Smoke", (0.5, 0.5, 0.5), (0, 0, 13.9), m=k.mat("Mark", "Smoke"))
    k.group("Bellows", (-3.3, 0, 1.0))
    k.wedge("bellowA", (1.4, 2.0, 0.5), (-3.9, 0, 1.25), (0, 0, 90), leather)
    k.wedge("bellowB", (1.4, 2.0, 0.5), (-3.9, 0, 0.75), (180, 0, 90), leather)
    k.group(None)
    k.rod("nozzle", (-3.3, 0, 1.0), (-2.9, 0, 1.0), 0.18, iron)
    k.cyl("stump", 0.95, 1.6, (3.4, 3.4, 0.8), m=wood)
    k.box("anvilbase", (0.9, 0.7, 0.45), (3.4, 3.4, 1.82), m=iron)
    k.box("anvil", (1.9, 0.85, 0.6), (3.4, 3.4, 2.35), m=iron)
    k.wedge("horn", (0.85, 0.6, 0.45), (4.75, 3.4, 2.42), (0, 0, -90), iron)
    k.box("trough", (2.8, 1.3, 1.0), (-3.4, 3.4, 0.5), m=plank)
    k.box("trwater", (2.4, 0.9, 0.12), (-3.4, 3.4, 0.98), m=water)
    k.box("lava", (8.4, 0.9, 0.3), (0, -3.0, 0.15), m=lava)
    for y in (-3.6, -2.4):
        k.box("lavaedge%.0f" % y, (8.6, 0.35, 0.5), (0, y, 0.25), m=stone)
    for sx in (-1, 1):
        k.box("rackpost%d" % sx, (0.35, 0.35, 3.4), (5.6, sx * 1.3, 1.7), m=wood)
    k.box("rackbar", (0.3, 3.0, 0.3), (5.6, 0, 3.0), m=wood)
    for i, y in enumerate((-0.8, 0.0, 0.8)):
        k.box("handle%d" % i, (0.16, 0.16, 1.6), (5.75, y, 2.1), m=wood)
        k.box("head%d" % i, (0.5, 0.3, 0.32), (5.75, y, 1.3), m=iron)
    for sx in (-1, 1):
        k.box("shpost%d" % sx, (0.5, 0.5, 6.0), (sx * 2.4 + 3.0, 5.2, 3.0), m=wood)
    k.box("shelter", (6.6, 3.6, 0.35), (3.0, 4.1, 6.0), (16, 0, 0), metal)


def camp_telescope(k):
    stone = k.mat("VStone", "@base")
    brass = k.mat("Metal", (214, 170, 80))
    tube = k.mat("SmoothPlastic", "@scope")
    lens = k.mat("Neon", (150, 230, 255))
    wood = k.mat("WoodPlanks", "@wood")
    glow = k.mat("Neon", "@accent")
    k.cyl("platform", 3.4, 1.0, (0, 0, 0.5), m=stone, verts=16)
    k.cyl("rim", 3.6, 0.25, (0, 0, 1.12), m=brass, verts=16)
    k.box("step", (2.4, 1.1, 0.5), (0, 3.7, 0.25), m=stone)
    for i in range(3):
        a = math.radians(90 + i * 120)
        k.rod("leg%d" % i, (math.cos(a) * 1.7, math.sin(a) * 1.7, 1.2), (0, 0, 4.4), 0.17, wood)
    k.cyl("mount", 0.48, 0.8, (0, 0, 4.6), m=brass)
    k.group("Scope", (0, 0, 5.0))
    k.rod("tube", (0, -2.4, 4.1), (0, 3.0, 6.6), 0.55, tube, verts=14)
    k.rod("front", (0, 2.5, 6.37), (0, 3.9, 7.02), 0.72, tube, verts=14)
    k.rod("lens", (0, 3.92, 7.03), (0, 4.0, 7.07), 0.62, lens, verts=14)
    k.rod("eye", (0, -2.4, 4.1), (0, -3.1, 3.78), 0.2, brass)
    for t in (0.25, 0.6):
        p0 = (0, -2.4 + 5.4 * t - 0.1, 4.1 + 2.5 * t - 0.05)
        p1 = (0, -2.4 + 5.4 * t + 0.1, 4.1 + 2.5 * t + 0.05)
        k.rod("band%.0f" % (t * 100), p0, p1, 0.6, brass, verts=14)
    k.group(None)
    k.cyl("pedestal", 0.4, 2.6, (2.3, -1.6, 2.4), m=brass)
    k.ball("globe", 0.7, (2.3, -1.6, 4.3), m=glow)


def camp_scarecrow(k):
    wood = k.mat("VLog", "@wood")
    shirt = k.mat("Fabric", (120, 150, 190))
    patch = k.mat("Fabric", (200, 80, 60))
    straw = k.mat("Fabric", (232, 196, 90))
    burlap = k.mat("Fabric", (214, 184, 140))
    hat = k.mat("Fabric", (140, 100, 60))
    black = k.mat("SmoothPlastic", (30, 26, 24))
    k.box("post", (0.5, 0.5, 6.6), (0, 0, 3.3), m=wood)
    k.box("bar", (4.8, 0.42, 0.42), (0, 0, 4.7), m=wood)
    k.box("shirt", (1.9, 0.9, 2.1), (0, 0.05, 4.0), m=shirt)
    k.box("patch", (0.6, 0.1, 0.6), (0.45, 0.52, 3.6), (0, 12, 0), patch)
    for s in (-1, 1):
        k.box("sleeve%d" % s, (1.5, 0.75, 0.75), (s * 1.6, 0.05, 4.7), m=shirt)
        k.box("straw%d" % s, (0.6, 0.5, 0.5), (s * 2.55, 0.05, 4.62), (0, s * 20, 0), straw)
    k.box("waist", (1.5, 0.6, 0.6), (0, 0.05, 2.75), m=straw)
    k.box("head", (1.25, 1.1, 1.25), (0, 0.05, 5.8), m=burlap)
    for s in (-1, 1):
        k.box("eye%d" % s, (0.22, 0.08, 0.22), (s * 0.28, 0.62, 5.95), m=black)
    k.box("mouth", (0.7, 0.08, 0.1), (0, 0.62, 5.5), m=black)
    k.cyl("brim", 1.05, 0.16, (0, 0.05, 6.5), m=hat)
    k.cyl("crown", 0.58, 0.9, (0, 0.05, 6.95), m=hat)


# ---------------------------------------------------------------------------------------------------------------
# critters (client/CampLife walks, hops, swims or perches them)
# ---------------------------------------------------------------------------------------------------------------
def critter_chicken(k):
    white = k.mat("SmoothPlastic", (248, 246, 240))
    wing = k.mat("SmoothPlastic", (226, 222, 214))
    red = k.mat("SmoothPlastic", (220, 50, 40))
    yellow = k.mat("SmoothPlastic", (250, 190, 40))
    black = k.mat("SmoothPlastic", (24, 22, 22))
    for s in (-1, 1):
        k.box("leg%d" % s, (0.12, 0.12, 0.46), (s * 0.18, 0, 0.23), m=yellow)
        k.box("wing%d" % s, (0.12, 0.72, 0.46), (s * 0.45, -0.05, 0.82), m=wing)
    k.box("body", (0.8, 1.1, 0.75), (0, 0, 0.82), m=white)
    k.wedge("tail", (0.55, 0.5, 0.6), (0, -0.7, 1.12), (0, 0, 180), white)
    k.group("Head", (0, 0.35, 1.1))
    k.box("head", (0.5, 0.5, 0.55), (0, 0.5, 1.42), m=white)
    k.wedge("beak", (0.2, 0.3, 0.18), (0, 0.88, 1.38), (0, 0, 0), yellow)
    k.box("comb", (0.12, 0.38, 0.26), (0, 0.48, 1.8), m=red)
    k.box("wattle", (0.12, 0.12, 0.22), (0, 0.8, 1.2), m=red)
    for s in (-1, 1):
        k.box("eye%d" % s, (0.06, 0.1, 0.1), (s * 0.26, 0.6, 1.5), m=black)
    k.group(None)


def critter_koi(k):
    orange = k.mat("SmoothPlastic", (250, 120, 40))
    white = k.mat("SmoothPlastic", (250, 248, 240))
    black = k.mat("SmoothPlastic", (24, 22, 22))
    k.box("body", (0.5, 1.2, 0.4), (0, 0, 0.2), m=orange)
    k.box("head", (0.42, 0.42, 0.36), (0, 0.78, 0.2), m=white)
    k.wedge("tail_l", (0.08, 0.6, 0.5), (-0.14, -0.85, 0.2), (0, 0, 160), orange)
    k.wedge("tail_r", (0.08, 0.6, 0.5), (0.14, -0.85, 0.2), (0, 0, -160), orange)
    for s in (-1, 1):
        k.box("fin%d" % s, (0.35, 0.22, 0.06), (s * 0.38, 0.35, 0.1), (0, 0, s * 25), orange)
        k.box("eye%d" % s, (0.05, 0.08, 0.08), (s * 0.22, 0.88, 0.26), m=black)
    k.box("spot1", (0.3, 0.35, 0.05), (0.06, 0.1, 0.42), m=white)
    k.box("spot2", (0.22, 0.25, 0.05), (-0.08, -0.35, 0.42), m=black)


def critter_owl(k):
    brown = k.mat("SmoothPlastic", (140, 100, 70))
    cream = k.mat("SmoothPlastic", (232, 214, 176))
    yellow = k.mat("Neon", (255, 210, 60))
    black = k.mat("SmoothPlastic", (24, 22, 22))
    orange = k.mat("SmoothPlastic", (226, 150, 50))
    k.box("body", (1.0, 0.9, 1.2), (0, 0, 0.75), m=brown)
    k.box("belly", (0.7, 0.1, 0.85), (0, 0.46, 0.7), m=cream)
    for s in (-1, 1):
        k.box("wing%d" % s, (0.14, 0.8, 1.0), (s * 0.55, -0.05, 0.75), m=brown)
        k.box("foot%d" % s, (0.25, 0.3, 0.12), (s * 0.22, 0.2, 0.08), m=orange)
    k.group("Head", (0, 0, 1.35))
    k.box("head", (1.1, 0.95, 0.8), (0, 0, 1.75), m=brown)
    k.box("face", (0.9, 0.1, 0.62), (0, 0.48, 1.72), m=cream)
    for s in (-1, 1):
        k.ball("eye%d" % s, 0.17, (s * 0.22, 0.52, 1.8), m=yellow)
        k.box("pupil%d" % s, (0.1, 0.06, 0.12), (s * 0.22, 0.68, 1.8), m=black)
        k.wedge("tuft%d" % s, (0.2, 0.26, 0.22), (s * 0.38, 0, 2.25), (0, 0, 180 if s < 0 else 0), brown)
    k.wedge("beak", (0.14, 0.18, 0.2), (0, 0.58, 1.6), (0, 0, 0), orange)
    k.group(None)


def critter_frog(k):
    green = k.mat("SmoothPlastic", (90, 180, 70))
    belly = k.mat("SmoothPlastic", (200, 230, 150))
    white = k.mat("SmoothPlastic", (250, 250, 245))
    black = k.mat("SmoothPlastic", (24, 22, 22))
    k.box("body", (1.0, 1.1, 0.55), (0, 0, 0.4), m=green)
    k.box("belly", (0.8, 0.9, 0.1), (0, 0.05, 0.12), m=belly)
    k.box("head", (0.9, 0.6, 0.42), (0, 0.6, 0.55), m=green)
    for s in (-1, 1):
        k.ball("eye%d" % s, 0.2, (s * 0.28, 0.65, 0.82), m=white)
        k.box("pupil%d" % s, (0.12, 0.06, 0.14), (s * 0.28, 0.84, 0.84), m=black)
        k.box("leg%d" % s, (0.36, 0.85, 0.3), (s * 0.58, -0.25, 0.18), m=green)
        k.box("arm%d" % s, (0.22, 0.3, 0.35), (s * 0.42, 0.55, 0.18), m=green)


def critter_penguin(k):
    black = k.mat("SmoothPlastic", (36, 38, 48))
    white = k.mat("SmoothPlastic", (246, 246, 244))
    orange = k.mat("SmoothPlastic", (250, 150, 40))
    k.box("body", (1.0, 0.9, 1.4), (0, 0, 0.85), m=black)
    k.box("belly", (0.76, 0.1, 1.15), (0, 0.46, 0.8), m=white)
    k.box("head", (0.86, 0.8, 0.66), (0, 0, 1.85), m=black)
    for s in (-1, 1):
        k.box("eye%d" % s, (0.14, 0.06, 0.14), (s * 0.2, 0.42, 1.95), m=white)
        k.box("foot%d" % s, (0.32, 0.45, 0.12), (s * 0.25, 0.2, 0.06), m=orange)
        k.group("arm%s" % ("L" if s < 0 else "R"), (s * 0.5, 0, 1.3))
        k.box("flipper%d" % s, (0.14, 0.5, 0.95), (s * 0.57, 0, 0.9), (0, s * 10, 0), black)
        k.group(None)
    k.wedge("beak", (0.22, 0.3, 0.2), (0, 0.52, 1.82), (0, 0, 0), orange)


def critter_lizard(k):
    red = k.mat("SmoothPlastic", (214, 70, 40))
    belly = k.mat("SmoothPlastic", (250, 180, 90))
    glow = k.mat("Neon", (255, 160, 60))
    black = k.mat("SmoothPlastic", (24, 22, 22))
    k.box("body", (0.62, 1.25, 0.36), (0, 0, 0.3), m=red)
    k.box("belly", (0.5, 1.1, 0.08), (0, 0, 0.1), m=belly)
    k.box("head", (0.52, 0.62, 0.32), (0, 0.88, 0.32), m=red)
    k.box("tail1", (0.4, 0.8, 0.26), (0, -0.98, 0.24), m=red)
    k.box("tail2", (0.24, 0.8, 0.18), (0, -1.72, 0.18), m=red)
    for s in (-1, 1):
        for y in (0.4, -0.4):
            k.box("leg%d%.0f" % (s, y * 10), (0.5, 0.18, 0.16), (s * 0.48, y, 0.14), (0, 0, s * (20 if y > 0 else -20)), red)
        k.box("eye%d" % s, (0.06, 0.1, 0.1), (s * 0.27, 1.0, 0.42), m=black)
    for i, y in enumerate((0.3, -0.15, -0.6)):
        k.box("spot%d" % i, (0.2, 0.2, 0.06), (0.05 if i % 2 else -0.05, y, 0.5), m=glow)


MODELS = {
    "camp_house": camp_house, "camp_tent": camp_tent, "camp_arch": camp_arch, "camp_signpost": camp_signpost,
    "camp_noticeboard": camp_noticeboard, "camp_banner": camp_banner, "camp_cart": camp_cart, "camp_well": camp_well,
    "camp_gnome": camp_gnome, "camp_windmill": camp_windmill, "camp_pavilion": camp_pavilion,
    "camp_watchtower": camp_watchtower, "camp_boat": camp_boat, "camp_igloo": camp_igloo, "camp_snowman": camp_snowman,
    "camp_forge": camp_forge, "camp_telescope": camp_telescope, "camp_scarecrow": camp_scarecrow,
    "critter_chicken": critter_chicken, "critter_koi": critter_koi, "critter_owl": critter_owl,
    "critter_frog": critter_frog, "critter_penguin": critter_penguin, "critter_lizard": critter_lizard,
}
