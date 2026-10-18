"""Turbo Tractor (ride-on mower): a blue garden tractor. Big lugged rear tyres with yellow hubs, small front tyres, a
long bevelled hood with a dark grille and two headlights, a chrome exhaust stack, diamond-plate footboards, a black
roll bar behind the seat, and a wide out-front mowing deck with hazard stripes and little caster wheels.

Front +Y, wheels on z = 0; the seat cushion top is flat at z = 3 around (0, -1). About 6 wide x 9 long x 6 tall."""
import math
import bmesh
from mathutils import Matrix, Vector

PREVIEW = dict(dist=17, height=9.5, target_z=2.4, yaw=40)


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
def build(lib):
    blue = lib.material("SmoothPlastic", (38, 112, 222))
    tyre = lib.material("Plastic", (40, 40, 44))
    dark = lib.material("Metal", (70, 74, 84))
    yellow = lib.material("SmoothPlastic", (252, 200, 40))
    plate = lib.material("DiamondPlate", (150, 154, 160))
    lamp = lib.material("Neon", (255, 244, 190))
    seat_mat = lib.material("SmoothPlastic", (34, 34, 40))

    # wheels: big lugged ones at the back, small ones at the front
    for x in (-1, 1):
        wheel(lib, "rear%d" % (x > 0), (x * 2.35, -2.3, 1.8), 1.8, 1.25, tyre, yellow, verts=16, lugs=10)
        wheel(lib, "front%d" % (x > 0), (x * 1.95, 1.75, 0.95), 0.95, 0.75, tyre, yellow, verts=12)
        fender(lib, "fender%d" % (x > 0), x * 2.35, -2.3, 1.8, 2.05, 1.45, blue)
    lib.box("axle_rear", (3.6, 0.4, 0.4), (0, -2.3, 1.8), mat=dark)
    lib.box("axle_front", (3.4, 0.35, 0.35), (0, 1.75, 0.95), mat=dark)

    # chassis, rear body under the seat, footboards
    lib.box("frame", (1.8, 6.4, 0.5), (0, -0.4, 1.3), mat=dark, bevel=0.08)
    lib.box("body", (3.1, 3.0, 1.1), (0, -2.05, 2.0), mat=blue, bevel=0.2)
    for x in (-1, 1):
        lib.box("footboard%d" % (x > 0), (1.2, 2.4, 0.2), (x * 1.65, 0.0, 1.55), mat=plate, bevel=0.04)
        lib.box("step%d" % (x > 0), (1.1, 2.2, 0.35), (x * 1.65, 0.0, 1.32), mat=dark, bevel=0.05)
    lib.box("hitch", (0.6, 0.7, 0.3), (0, -3.7, 1.25), mat=dark, bevel=0.05)

    # hood with grille, headlights, side vents, exhaust stack
    lib.box("hood", (2.5, 3.2, 1.7), (0, 1.6, 2.45), mat=blue, bevel=0.28, taper=(0.9, 0.95))
    lib.box("hood_stripe", (0.6, 3.25, 0.1), (0, 1.55, 3.32), mat=yellow, bevel=0.03)
    lib.box("grille_frame", (2.2, 0.3, 1.5), (0, 3.22, 2.4), mat=dark, bevel=0.1)
    for i in range(5):
        lib.box("slat%d" % i, (0.14, 0.12, 1.15), (-0.7 + i * 0.35, 3.38, 2.35), mat=seat_mat)
    for x in (-1, 1):
        lib.box("lamp_box%d" % (x > 0), (0.55, 0.4, 0.45), (x * 0.95, 3.2, 3.05), mat=dark, bevel=0.08)
        lib.box("lamp%d" % (x > 0), (0.38, 0.1, 0.3), (x * 0.95, 3.42, 3.05), mat=lamp, bevel=0.03)
        for i in range(3):
            lib.box("vent%d_%d" % (x > 0, i), (0.06, 0.9, 0.12), (x * 1.24, 1.6, 2.2 + i * 0.28), mat=seat_mat)
    lib.box("bumper", (2.6, 0.35, 0.45), (0, 3.45, 1.4), mat=dark, bevel=0.08)
    lib.cyl("stack", 0.17, 1.6, (0.85, 1.2, 3.8), mat=dark, verts=8, bevel=0.03)
    lib.cyl("stack_cap", 0.22, 0.2, (0.85, 1.2, 4.62), mat=seat_mat, verts=8)

    # dash, steering wheel, seat, roll bar
    lib.box("dash", (2.2, 0.8, 1.5), (0, -0.05, 2.95), mat=blue, bevel=0.15, taper=(0.9, 0.7))
    lib.box("dash_panel", (1.4, 0.1, 0.5), (0, -0.42, 3.25), rot=(-15, 0, 0), mat=dark, bevel=0.03)
    steering_wheel(lib, (0, -0.35, 4.25), 55, 0.66, seat_mat, dark, column_to=(0, 0.1, 3.5))
    seat(lib, seat_mat, seat_mat, dark, y=-1.05, top=3.0, width=2.0, depth=1.7)
    for x in (-1, 1):
        beam(lib, "roll_post%d" % (x > 0), (x * 1.5, -3.2, 2.4), (x * 1.5, -3.2, 5.6), (0.32, 0.32), seat_mat, bevel=0.06)
        lib.box("roll_foot%d" % (x > 0), (0.55, 0.55, 0.3), (x * 1.5, -3.2, 2.5), mat=dark, bevel=0.05)
    beam(lib, "roll_top", (-1.66, -3.2, 5.62), (1.66, -3.2, 5.62), (0.36, 0.36), seat_mat, bevel=0.08)
    lib.box("beacon", (0.4, 0.4, 0.3), (0, -3.2, 5.95), mat=yellow, bevel=0.06)

    # out-front mowing deck: arms from the frame, a wide housing, hazard stripes, caster wheels
    for x in (-1, 1):
        beam(lib, "deck_arm%d" % (x > 0), (x * 0.7, 2.6, 1.1), (x * 1.3, 3.3, 0.95), (0.25, 0.25), dark, bevel=0.04)
    lib.box("deck", (5.8, 2.0, 0.6), (0, 3.85, 0.62), mat=blue, bevel=0.18, taper=(0.95, 0.88))
    lib.box("deck_dome", (3.6, 1.3, 0.35), (0, 3.8, 1.05), mat=blue, bevel=0.14, taper=(0.85, 0.8))
    lib.box("deck_rim", (6.0, 2.2, 0.18), (0, 3.85, 0.3), mat=dark, bevel=0.05)
    hazard(lib, "deck_stripe", (2.7, 4.86, 0.42), (-1, 0, 0), (0, 0, 1), 5.4, 0.3, 0.04, (yellow, seat_mat))
    lib.box("chute", (0.8, 1.1, 0.45), (3.15, 3.7, 0.6), rot=(0, -10, -8), mat=dark, bevel=0.08, taper=(0.8, 0.8))
    for x in (-1, 1):
        lib.cyl("caster%d" % (x > 0), 0.28, 0.25, (x * 2.55, 4.6, 0.28), rot=(0, 90, 0), mat=tyre, verts=8)
        lib.box("caster_fork%d" % (x > 0), (0.1, 0.3, 0.4), (x * 2.4, 4.6, 0.45), mat=dark)
