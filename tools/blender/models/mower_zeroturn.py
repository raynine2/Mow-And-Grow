"""Golden Zero-Turn (ride-on mower): a sleek, shiny gold zero-turn. Low frame, big rear drive tyres under gold
fenders, little front caster wheels on swivel forks, a very wide gold deck with black hazard stripes and side chute,
a high-back black seat between gold side pods, two lap-bar steering levers, a black engine with a gold cover and twin
chrome exhausts at the back, headlights in the front footplate.

Front +Y, wheels on z = 0; the seat cushion top is flat at z = 3 around (0, -1). About 6.4 wide x 8.6 long x 5 tall."""
import math
import bmesh
from mathutils import Matrix, Vector

PREVIEW = dict(dist=16, height=9, target_z=2.0, yaw=40)


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


def wheel(lib, name, loc, r, w, tyre, hub, verts=14, hub_scale=0.55, lugs=0):
    """Wheel with its axle along X: a fat bevelled tyre, a hub disc, a centre cap, optional tread lugs."""
    x, y, z = loc
    s = 1 if x >= 0 else -1
    lib.cyl(name, r, w, loc, rot=(0, 90, 0), mat=tyre, verts=verts, bevel=min(0.12, r * 0.12))
    lib.cyl(name + "_hub", r * hub_scale, w + 0.1, loc, rot=(0, 90, 0), mat=hub, verts=10, bevel=0.05)
    lib.cyl(name + "_cap", r * 0.2, w + 0.3, loc, rot=(0, 90, 0), mat=tyre, verts=6)
    for k in range(lugs):
        a = 360.0 * k / lugs
        for side in (-1, 1):   # chevron: two angled blocks per lug
            p = Vector((x + side * w * 0.25, y + r * math.cos(math.radians(a)), z + r * math.sin(math.radians(a))))
            lug = lib.box("%s_lug%d_%d" % (name, k, side), (w * 0.5, 0.22, 0.2), p, mat=tyre)
            lug.rotation_euler = (Matrix.Rotation(math.radians(a - 90), 3, "X")
                                  @ Matrix.Rotation(math.radians(25 * side), 3, "Z")).to_euler()


def hazard(lib, name, origin, u_axis, v_axis, length, height, depth, mats, width=0.5, slant=35):
    """Flat panel of diagonal hazard stripes (alternating mats) filling length x height exactly.
    origin = bottom-left corner on the panel's back face; u along the length, v up; it grows along u x v."""
    o, u, v = Vector(origin), Vector(u_axis).normalized(), Vector(v_axis).normalized()
    n = u.cross(v)
    s = height * math.tan(math.radians(slant))
    def clip(poly, lo):
        out = []
        keep = (lambda p: p[0] >= 0) if lo else (lambda p: p[0] <= length)
        lim = 0.0 if lo else length
        for i, a in enumerate(poly):
            b = poly[(i + 1) % len(poly)]
            if keep(a):
                out.append(a)
            if keep(a) != keep(b):
                t = (lim - a[0]) / (b[0] - a[0])
                out.append((lim, a[1] + t * (b[1] - a[1])))
        return out
    i = -int(s / width) - 1
    while i * width < length:
        u0 = i * width
        poly = clip(clip([(u0, 0), (u0 + width, 0), (u0 + width + s, height), (u0 + s, height)], True), False)
        if len(poly) >= 3:
            bm = bmesh.new()
            back = [bm.verts.new(o + u * a + v * b) for a, b in poly]
            front = [bm.verts.new(o + u * a + v * b + n * depth) for a, b in poly]
            bm.faces.new(back[::-1]); bm.faces.new(front)
            for k in range(len(poly)):
                bm.faces.new((back[k], back[(k + 1) % len(poly)], front[(k + 1) % len(poly)], front[k]))
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            lib._from_bmesh("%s%d" % (name, i), bm).data.materials.append(mats[i % 2])
        i += 1


def steering_wheel(lib, centre, tilt, r, mat, hub_mat, column_to=None):
    """Ring of 8 beams facing the driver (at -Y), tilted `tilt` degrees from flat, with a hub and 3 spokes."""
    c = Vector(centre)
    t = math.radians(tilt)
    n = Vector((0, -math.sin(t), math.cos(t)))
    ex = Vector((1, 0, 0)); ey = n.cross(ex)
    pts = [c + r * (math.cos(k * math.pi / 4) * ex + math.sin(k * math.pi / 4) * ey) for k in range(8)]
    for k in range(8):
        a, b = pts[k], pts[(k + 1) % 8]
        beam(lib, "sw_ring%d" % k, a + (a - b) * 0.08, b + (b - a) * 0.08, (0.16, 0.16), mat, bevel=0)
    for k in (2, 5, 7):
        beam(lib, "sw_spoke%d" % k, c, pts[k], (0.1, 0.08), hub_mat, bevel=0)
    lib.cyl("sw_hub", 0.18, 0.2, c, mat=hub_mat, verts=8).rotation_euler = _frame(n).to_euler()
    if column_to:
        beam(lib, "sw_column", c - n * 0.1, column_to, (0.18, 0.18), hub_mat, bevel=0.03)


def seat(lib, cushion, back, base, y=-1.0, top=3.0, width=2.0, depth=1.7):
    """Driver seat: a flat cushion whose top is exactly at z = top around y, a tilted backrest, a pedestal."""
    lib.box("seat_cushion", (width, depth, 0.42), (0, y, top - 0.21), mat=cushion, bevel=0.14)
    beam(lib, "seat_back", (0, y - depth / 2 + 0.1, top - 0.1), (0, y - depth / 2 - 0.2, top + 1.55), (width * 0.92, 0.38),
         back, bevel=0.14, taper=(0.9, 1))
    lib.box("seat_pan", (width * 0.85, depth * 0.85, 0.3), (0, y, top - 0.55), mat=base, bevel=0.06)


def fender(lib, name, x, cy, cz, r, width, mat, arc=(5, 50, 100, 150, 178)):
    """Mudguard over a wheel (axle along X at y = cy, z = cz) from a few plates on an arc of radius r."""
    for k in range(len(arc) - 1):
        a0, a1 = math.radians(arc[k]), math.radians(arc[k + 1])
        p0 = Vector((x, cy + r * math.cos(a0), cz + r * math.sin(a0)))
        p1 = Vector((x, cy + r * math.cos(a1), cz + r * math.sin(a1)))
        beam(lib, "%s_%d" % (name, k), p0 + (p0 - p1) * 0.04, p1 + (p1 - p0) * 0.04, (width, 0.22), mat, bevel=0.07)


# ---- model ------------------------------------------------------------------------------------------------------


# ---- model ------------------------------------------------------------------------------------------------------
def build(lib):
    gold = lib.material("Metal", (246, 192, 52))
    black = lib.material("SmoothPlastic", (30, 30, 36))
    tyre = lib.material("Plastic", (40, 40, 44))
    chrome = lib.material("Metal", (212, 216, 224))
    plate = lib.material("DiamondPlate", (96, 98, 106))
    lamp = lib.material("Neon", (255, 248, 220))

    # drive wheels at the back, caster wheels on swivel forks at the front
    for x in (-1, 1):
        wheel(lib, "rear%d" % (x > 0), (x * 2.35, -2.4, 1.45), 1.45, 1.2, tyre, gold, verts=16, lugs=10)
        fender(lib, "fender%d" % (x > 0), x * 2.35, -2.4, 1.45, 1.7, 1.35, gold, arc=(0, 45, 90, 135, 175))
        lib.cyl("caster%d" % (x > 0), 0.6, 0.55, (x * 2.05, 3.15, 0.6), rot=(0, 90, 0), mat=tyre, verts=12, bevel=0.07)
        lib.cyl("caster_hub%d" % (x > 0), 0.3, 0.62, (x * 2.05, 3.15, 0.6), rot=(0, 90, 0), mat=chrome, verts=8)
        for s in (-1, 1):
            lib.box("fork%d%d" % (x > 0, s > 0), (0.12, 0.35, 0.9), (x * 2.05 + s * 0.36, 3.0, 0.95), rot=(-15, 0, 0), mat=chrome)
        lib.box("fork_top%d" % (x > 0), (0.9, 0.4, 0.18), (x * 2.05, 2.85, 1.42), mat=chrome, bevel=0.04)
        lib.cyl("swivel%d" % (x > 0), 0.16, 0.5, (x * 2.05, 2.85, 1.65), mat=chrome, verts=8)
        # side frame rail from the casters back to the drive wheels
        beam(lib, "rail%d" % (x > 0), (x * 1.8, 2.9, 1.8), (x * 1.55, -1.2, 1.6), (0.4, 0.5), black, bevel=0.08)
        beam(lib, "rail_front%d" % (x > 0), (x * 1.8, 2.9, 1.8), (x * 2.05, 2.85, 1.72), (0.4, 0.4), black, bevel=0.06)

    # wide deck slung between the wheels
    lib.box("deck", (6.2, 2.5, 0.6), (0, 0.65, 0.65), mat=gold, bevel=0.2, taper=(0.94, 0.88))
    lib.box("deck_top", (4.2, 1.7, 0.3), (0, 0.6, 1.05), mat=gold, bevel=0.12, taper=(0.9, 0.85))
    lib.box("deck_rim", (6.4, 2.7, 0.2), (0, 0.65, 0.32), mat=black, bevel=0.06)
    hazard(lib, "deck_stripe", (2.9, 2.02, 0.42), (-1, 0, 0), (0, 0, 1), 5.8, 0.32, 0.04, (black, gold))
    lib.box("chute", (0.9, 1.2, 0.5), (3.4, 0.4, 0.62), rot=(0, -12, -10), mat=black, bevel=0.1, taper=(0.75, 0.8))
    for x in (-1, 1):
        lib.cyl("spindle%d" % (x > 0), 0.3, 0.2, (x * 1.6, 0.6, 1.25), mat=chrome, verts=8)

    # front footplate with headlights, centre tunnel to the seat
    lib.box("footplate", (2.9, 1.5, 0.25), (0, 2.25, 1.75), rot=(14, 0, 0), mat=plate, bevel=0.05)
    lib.box("nose", (3.3, 0.55, 0.7), (0, 3.15, 1.75), mat=gold, bevel=0.16, taper=(0.92, 0.8))
    for x in (-1, 1):
        lib.box("lamp%d" % (x > 0), (0.55, 0.1, 0.28), (x * 0.95, 3.44, 1.78), mat=lamp, bevel=0.03)
    lib.box("tunnel", (1.6, 2.4, 0.7), (0, 0.35, 1.75), mat=black, bevel=0.12)

    # seat between two gold side pods (fuel tanks), lap bars in front of the hands
    lib.box("seat_base", (3.0, 2.4, 0.9), (0, -1.15, 2.0), mat=gold, bevel=0.22, taper=(0.95, 0.95))
    seat(lib, black, black, black, y=-1.0, top=3.0, width=2.0, depth=1.8)
    lib.box("headrest", (1.4, 0.36, 0.55), (0, -2.35, 4.95), rot=(-10, 0, 0), mat=black, bevel=0.14)
    for x in (-1, 1):
        lib.box("pod%d" % (x > 0), (0.85, 2.0, 0.9), (x * 1.55, -0.9, 2.75), mat=gold, bevel=0.22, taper=(0.85, 0.9))
        lib.cyl("pod_cap%d" % (x > 0), 0.2, 0.15, (x * 1.55, -0.6, 3.25), mat=chrome, verts=8)
        beam(lib, "lever%d" % (x > 0), (x * 1.5, -0.25, 3.0), (x * 1.5, 0.35, 4.05), (0.18, 0.18), chrome, bevel=0.03)
        beam(lib, "lever_bend%d" % (x > 0), (x * 1.5, 0.35, 4.05), (x * 0.95, 0.5, 4.1), (0.18, 0.18), chrome, bevel=0.03)
        beam(lib, "lever_grip%d" % (x > 0), (x * 0.95, 0.5, 4.1), (x * 0.25, 0.5, 4.1), (0.3, 0.3), black, bevel=0.08)

    # engine behind the seat, gold cover, twin chrome exhausts
    lib.box("engine", (2.4, 1.5, 1.4), (0, -3.0, 2.35), mat=black, bevel=0.16)
    lib.box("engine_cover", (2.2, 1.3, 0.4), (0, -3.05, 3.2), mat=gold, bevel=0.14, taper=(0.85, 0.8))
    lib.cyl("air_filter", 0.42, 0.35, (0, -3.05, 3.55), mat=black, verts=10, bevel=0.06)
    for x in (-1, 1):
        lib.cyl("exhaust%d" % (x > 0), 0.17, 0.9, (x * 0.6, -3.85, 2.0), rot=(90, 0, 0), mat=chrome, verts=8, bevel=0.03)
    lib.box("bumper", (3.0, 0.3, 0.4), (0, -3.9, 1.45), mat=black, bevel=0.08)
