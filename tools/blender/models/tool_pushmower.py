"""Push Mower (tool, sits on the ground in front of the player): a chunky orange deck with a rolled rim and a
hazard-stripe bumper, four fat black wheels with grey hubs, a dark engine block with a red fuel cap, pull-start and
air filter, a green grass bag at the back, and a black push bar rising toward -Y to a foam grip.

Deck centred on the origin, wheels on z = 0, front +Y, the grip at about (0, -3.6, 3.2) (see Tools.luau)."""
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


def wheel(lib, name, loc, r, w, tyre, hub, verts=12):
    """Wheel with its axle along X: fat bevelled tyre and a grey hub."""
    lib.cyl(name, r, w, loc, rot=(0, 90, 0), mat=tyre, verts=verts, bevel=0.08)
    lib.cyl(name + "_hub", r * 0.55, w + 0.1, loc, rot=(0, 90, 0), mat=hub, verts=8, bevel=0)


def hazard(lib, name, origin, u_axis, v_axis, length, height, depth, mats, width=0.42, slant=35):
    """Flat panel of diagonal hazard stripes (alternating mats) filling length x height exactly.
    origin = bottom-left corner on the panel's back face; u along the length, v up; it grows along u x v."""
    import bmesh
    o, u, v = Vector(origin), Vector(u_axis).normalized(), Vector(v_axis).normalized()
    n = u.cross(v)
    s = height * math.tan(math.radians(slant))
    def clip(poly, keep):
        out = []
        for i, a in enumerate(poly):
            b = poly[(i + 1) % len(poly)]
            ina, inb = keep(a), keep(b)
            if ina:
                out.append(a)
            if ina != inb:
                lim = 0.0 if not keep((-1e-9, 0)) else length
                t = (lim - a[0]) / (b[0] - a[0])
                out.append((lim, a[1] + t * (b[1] - a[1])))
        return out
    i = -int(s / width) - 1
    while i * width < length:
        u0 = i * width
        poly = [(u0, 0), (u0 + width, 0), (u0 + width + s, height), (u0 + s, height)]
        poly = clip(poly, lambda p: p[0] >= 0)
        poly = clip(poly, lambda p: p[0] <= length) if poly else poly
        if len(poly) >= 3:
            bm = bmesh.new()
            back = [bm.verts.new(o + u * a + v * b) for a, b in poly]
            front = [bm.verts.new(o + u * a + v * b + n * depth) for a, b in poly]
            bm.faces.new(back[::-1]); bm.faces.new(front)
            for k in range(len(poly)):
                bm.faces.new((back[k], back[(k + 1) % len(poly)], front[(k + 1) % len(poly)], front[k]))
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            ob = lib._from_bmesh("%s%d" % (name, i), bm)
            ob.data.materials.append(mats[i % 2])
        i += 1


# ---- model ------------------------------------------------------------------------------------------------------
def build(lib):
    orange = lib.material("SmoothPlastic", (255, 138, 28))
    black = lib.material("SmoothPlastic", (36, 36, 42))
    grey = lib.material("Metal", (150, 154, 162))
    red = lib.material("SmoothPlastic", (226, 52, 46))
    yellow = lib.material("SmoothPlastic", (250, 205, 40))
    bag = lib.material("Fabric", (70, 140, 60))

    # deck: a wide low shell with a raised rim, the front bumper with hazard stripes
    lib.box("deck", (3.2, 2.9, 0.75), (0, 0.05, 0.85), mat=orange, bevel=0.18, taper=(0.9, 0.9))
    lib.box("skirt", (3.35, 3.05, 0.25), (0, 0.05, 0.55), mat=orange, bevel=0.08)
    lib.box("bumper", (3.1, 0.3, 0.46), (0, 1.62, 0.62), mat=black, bevel=0.06)
    hazard(lib, "stripe", (1.4, 1.76, 0.44), (-1, 0, 0), (0, 0, 1), 2.8, 0.36, 0.04, (yellow, black))
    # side chute on the right
    lib.box("chute", (0.6, 0.9, 0.45), (1.75, 0.2, 0.75), rot=(0, 0, -10), mat=orange, bevel=0.1, taper=(0.8, 0.8))

    # wheels
    for x in (-1.55, 1.55):
        for y in (-1.05, 1.15):
            wheel(lib, "wheel%d%d" % (x > 0, y > 0), (x * 1.04, y, 0.5), 0.5, 0.42, black, grey)

    # engine: dark block, red fuel cap, pull-start, round air filter
    lib.box("engine_base", (1.9, 1.7, 0.3), (0, 0.15, 1.35), mat=black, bevel=0.08)
    lib.box("engine", (1.6, 1.4, 0.9), (0, 0.15, 1.9), mat=black, bevel=0.15, taper=(0.85, 0.85))
    lib.box("engine_top", (1.2, 1.05, 0.25), (0, 0.15, 2.45), mat=grey, bevel=0.08)
    lib.cyl("cap", 0.24, 0.3, (0.38, 0.45, 2.65), mat=red, verts=10, bevel=0.06)
    lib.cyl("filter", 0.38, 0.45, (-0.95, 0.55, 1.95), rot=(0, 90, 0), mat=grey, verts=10, bevel=0.06)
    lib.cyl("pull", 0.3, 0.18, (-0.15, -0.6, 2.05), rot=(90, 0, 0), mat=red, verts=10, bevel=0.05)
    lib.box("pull_handle", (0.45, 0.14, 0.14), (-0.15, -0.74, 2.05), mat=black)
    lib.cyl("muffler", 0.17, 0.6, (0.88, -0.25, 1.6), rot=(0, 90, 0), mat=grey, verts=8, bevel=0)

    # grass bag at the back, hanging between the bar legs
    lib.box("bag", (1.9, 1.6, 1.25), (0, -2.15, 1.25), rot=(-8, 0, 0), mat=bag, bevel=0.2, taper=(0.9, 0.85))
    lib.box("bag_frame", (2.0, 0.22, 0.22), (0, -1.45, 1.85), mat=black)

    # push bar: two legs from the back of the deck up to a crossbar, with a foam grip and a throttle lever
    for x in (-1.15, 1.15):
        lib.box("bracket%d" % (x > 0), (0.24, 0.5, 0.5), (x, -1.2, 1.05), mat=black, bevel=0.06)
        beam(lib, "leg%d" % (x > 0), (x, -1.25, 1.05), (x * 0.95, -3.4, 3.05), (0.2, 0.2), black, bevel=0.05)
    lib.box("crossbar", (2.5, 0.22, 0.22), (0, -2.35, 2.05), mat=black)
    beam(lib, "grip_bar", (-1.18, -3.55, 3.2), (1.18, -3.55, 3.2), (0.26, 0.26), black, bevel=0.06)
    beam(lib, "grip", (-0.85, -3.55, 3.2), (0.85, -3.55, 3.2), (0.34, 0.34), orange, bevel=0.1)
    beam(lib, "lever", (-0.7, -3.42, 3.36), (0.7, -3.42, 3.36), (0.12, 0.12), red, bevel=0)
