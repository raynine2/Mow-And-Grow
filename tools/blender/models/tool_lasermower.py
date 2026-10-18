"""Laser Mower (tool, sits on the ground in front of the player like the Push Mower): a sleek dark sci-fi deck with
a sloped nose, cyan Neon strips down both sides, a glowing reactor where the engine would be, wheels with glowing
rims, a cyan laser bar across the front between two emitter pods, and a dark push bar with a glowing grip.

Same layout as tool_pushmower: deck centred on the origin, wheels on z = 0, front +Y, grip at about (0, -3.6, 3.2)."""
import math
from mathutils import Matrix, Vector

PREVIEW = dict(dist=9.5, height=5.5, target_z=1.4, yaw=40)


# ---- helpers (local to this file) -------------------------------------------------------------------------------
def _frame(d):
    z = d.normalized()
    up = Vector((0, 0, 1)) if abs(z.z) < 0.95 else Vector((0, 1, 0))
    x = up.cross(z).normalized()
    return Matrix((x, z.cross(x), z)).transposed()


def beam(lib, name, p0, p1, size, mat, bevel=0.05, taper=None, roll=0):
    """Box running from p0 to p1; size = (width, height) across it; taper narrows it toward p1."""
    p0, p1 = Vector(p0), Vector(p1)
    o = lib.box(name, (size[0], size[1], (p1 - p0).length), mat=mat, bevel=bevel, taper=taper)
    o.rotation_euler = (_frame(p1 - p0) @ Matrix.Rotation(math.radians(roll), 3, "Z")).to_euler()
    o.location = (p0 + p1) / 2
    return o


# ---- model ------------------------------------------------------------------------------------------------------
def build(lib):
    body = lib.material("SmoothPlastic", (36, 40, 56))
    trim = lib.material("Metal", (104, 110, 130))
    black = lib.material("SmoothPlastic", (22, 22, 28))
    cyan = lib.material("Neon", (60, 232, 255))

    # deck: low tapered shell, a sloped nose, side skirts with neon strips
    lib.box("deck", (3.1, 2.6, 0.7), (0, -0.15, 0.85), mat=body, bevel=0.16, taper=(0.86, 0.88))
    lib.wedge("nose", (3.0, 1.0, 0.62), (0, 1.6, 0.84), mat=body, bevel=0.1)
    lib.box("skirt", (3.3, 3.3, 0.28), (0, 0.15, 0.5), mat=trim, bevel=0.08)
    for x in (-1.0, 1.0):
        lib.box("strip%d" % (x > 0), (0.08, 2.6, 0.14), (x * 1.66, 0.1, 0.5), mat=cyan)
        lib.box("fin%d" % (x > 0), (0.16, 1.4, 0.5), (x * 1.18, -0.6, 1.35), mat=trim, bevel=0.05, taper=(1, 0.5))
        lib.box("fin_glow%d" % (x > 0), (0.18, 1.0, 0.08), (x * 1.18, -0.75, 1.32), mat=cyan)
    # laser bar across the front between two emitter pods
    for x in (-1.0, 1.0):
        lib.box("pod%d" % (x > 0), (0.45, 0.6, 0.55), (x * 1.55, 1.95, 0.42), mat=trim, bevel=0.1)
        lib.cyl("lens%d" % (x > 0), 0.14, 0.2, (x * 1.32, 1.95, 0.42), rot=(0, 90, 0), mat=cyan, verts=8)
    lib.box("laser", (2.7, 0.14, 0.14), (0, 1.95, 0.42), mat=cyan)
    lib.box("laser_glow", (2.7, 0.06, 0.3), (0, 1.95, 0.42), mat=cyan)

    # wheels with glowing rims
    for x in (-1.0, 1.0):
        for y in (-1.05, 1.05):
            loc = (x * 1.62, y, 0.48)
            lib.cyl("tyre", 0.48, 0.38, loc, rot=(0, 90, 0), mat=black, verts=12, bevel=0.07)
            lib.cyl("rim", 0.3, 0.44, loc, rot=(0, 90, 0), mat=cyan, verts=8)
            lib.cyl("hub", 0.18, 0.5, loc, rot=(0, 90, 0), mat=trim, verts=8)

    # reactor: a dark base, a glowing core in a cage, a cap
    lib.box("reactor_base", (1.7, 1.6, 0.3), (0, -0.2, 1.32), mat=trim, bevel=0.08)
    lib.cyl("reactor", 0.62, 0.9, (0, -0.2, 1.9), mat=body, verts=10, bevel=0.08)
    lib.cyl("core", 0.68, 0.22, (0, -0.2, 1.88), mat=cyan, verts=10)
    lib.cyl("reactor_cap", 0.45, 0.25, (0, -0.2, 2.45), mat=trim, verts=10, bevel=0.06)
    lib.cyl("antenna", 0.06, 0.6, (0.3, -0.2, 2.8), mat=trim, verts=6)
    lib.box("antenna_tip", (0.16, 0.16, 0.16), (0.3, -0.2, 3.12), mat=cyan)
    # vents on the deck in front of the reactor
    for i in range(3):
        lib.box("vent%d" % i, (1.2, 0.12, 0.08), (0, 0.65 + i * 0.25, 1.22), mat=black)

    # push bar
    for x in (-1.15, 1.15):
        lib.box("bracket%d" % (x > 0), (0.26, 0.5, 0.5), (x, -1.25, 1.05), mat=trim, bevel=0.06)
        beam(lib, "leg%d" % (x > 0), (x, -1.3, 1.05), (x * 0.95, -3.4, 3.05), (0.2, 0.2), body, bevel=0.05)
        beam(lib, "leg_glow%d" % (x > 0), (x * 1.0, -1.7, 1.42), (x * 0.96, -3.0, 2.68), (0.22, 0.08), cyan, bevel=0)
    lib.box("crossbar", (2.4, 0.2, 0.2), (0, -2.35, 2.05), mat=body)
    beam(lib, "grip_bar", (-1.18, -3.55, 3.2), (1.18, -3.55, 3.2), (0.26, 0.26), body, bevel=0.06)
    beam(lib, "grip", (-0.85, -3.55, 3.2), (0.85, -3.55, 3.2), (0.32, 0.32), black, bevel=0.08)
    beam(lib, "grip_glow", (-0.6, -3.55, 3.2), (0.6, -3.55, 3.2), (0.36, 0.1), cyan, bevel=0)
    lib.box("screen", (0.6, 0.12, 0.4), (0, -3.4, 3.45), rot=(-30, 0, 0), mat=trim, bevel=0.04)
    lib.box("screen_glow", (0.45, 0.04, 0.28), (0, -3.33, 3.48), rot=(-30, 0, 0), mat=cyan)
