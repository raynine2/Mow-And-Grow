"""Monster Mulcher (ride-on mower): a big, heavy purple industrial mulcher. Four huge lugged tyres with yellow hubs,
a tall purple engine hood with a chunky grille, amber work lights and twin black exhaust stacks, a full roll cage with
a roof and a flashing beacon, diamond-plate steps, a yellow rear counterweight with hazard stripes, and out front a
wide mulching drum full of steel teeth under a purple housing striped black-and-yellow.

Front +Y, wheels on z = 0; the seat cushion top is flat at z = 3 around (0, -1). About 6.6 wide x 9.9 long x 7 tall."""
import math
import bmesh
from mathutils import Matrix, Vector

PREVIEW = dict(dist=17.5, height=10, target_z=2.6, yaw=40)


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
    lib.cyl(name + "_hub", r * hub_scale, w + 0.1, loc, rot=(0, 90, 0), mat=hub, verts=10)
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
    purple = lib.material("SmoothPlastic", (150, 60, 220))   # Config colour of the Monster Mulcher
    yellow = lib.material("SmoothPlastic", (255, 196, 30))
    black = lib.material("SmoothPlastic", (32, 30, 38))
    tyre = lib.material("Plastic", (40, 40, 44))
    steel = lib.material("Metal", (120, 124, 134))
    plate = lib.material("DiamondPlate", (140, 144, 150))
    amber = lib.material("Neon", (255, 170, 40))

    # four monster tyres (bigger at the back) with yellow hubs and chunky purple fenders
    for x in (-1, 1):
        s = x > 0
        wheel(lib, "rear%d" % s, (x * 2.45, -2.35, 1.75), 1.75, 1.45, tyre, yellow, verts=16, lugs=8)
        wheel(lib, "front%d" % s, (x * 2.4, 1.55, 1.3), 1.3, 1.25, tyre, yellow, verts=12, lugs=6)
        fender(lib, "fender_r%d" % s, x * 2.45, -2.35, 1.75, 2.0, 1.6, purple, arc=(10, 66, 122, 178))
        fender(lib, "fender_f%d" % s, x * 2.4, 1.55, 1.3, 1.55, 1.4, purple, arc=(15, 65, 115, 165))

    # heavy chassis, body under the seat, steps
    lib.box("frame", (2.4, 7.2, 0.7), (0, -0.4, 1.35), mat=black, bevel=0.1)
    lib.box("body", (3.3, 3.2, 1.3), (0, -2.0, 2.05), mat=purple, bevel=0.22)
    for x in (-1, 1):
        s = x > 0
        lib.box("step%d" % s, (1.3, 1.4, 0.22), (x * 1.75, -0.2, 1.3), mat=plate, bevel=0.04)
        lib.box("step_box%d" % s, (1.2, 1.3, 0.4), (x * 1.75, -0.2, 1.05), mat=black)

    # tall engine hood with a grille, work lights, side vents, twin exhaust stacks
    lib.box("hood", (2.9, 3.0, 2.1), (0, 1.35, 2.55), mat=purple, bevel=0.3, taper=(0.9, 0.92))
    lib.box("hood_top", (1.0, 2.6, 0.2), (0, 1.3, 3.65), mat=yellow, bevel=0.06)
    lib.box("grille", (2.3, 0.3, 1.5), (0, 2.85, 2.45), mat=black, bevel=0.1)
    for i in range(4):
        lib.box("grille_bar%d" % i, (2.0, 0.14, 0.16), (0, 3.02, 1.95 + i * 0.34), mat=steel)
    for x in (-1, 1):
        s = x > 0
        lib.box("light_box%d" % s, (0.7, 0.45, 0.5), (x * 1.05, 2.75, 3.55), mat=black)
        lib.box("light%d" % s, (0.5, 0.1, 0.32), (x * 1.05, 2.99, 3.55), mat=amber)
        for i in range(3):
            lib.box("vent%d_%d" % (s, i), (0.08, 1.2, 0.14), (x * 1.38, 1.3, 2.05 + i * 0.32), mat=black)
        lib.cyl("stack%d" % s, 0.22, 2.4, (x * 1.15, 0.2, 4.4), mat=black, verts=8)
        lib.cyl("stack_cap%d" % s, 0.29, 0.25, (x * 1.15, 0.2, 5.65), rot=(-20, 0, 0), mat=steel, verts=8)
        lib.box("stack_clamp%d" % s, (0.6, 0.6, 0.25), (x * 1.15, 0.2, 3.55), mat=steel)

    # dash, steering wheel, seat
    lib.box("dash", (2.2, 0.7, 1.2), (0, -0.05, 3.2), mat=black, bevel=0.14, taper=(0.9, 0.7))
    steering_wheel(lib, (0, -0.4, 4.3), 55, 0.62, black, steel, column_to=(0, 0.0, 3.6))
    seat(lib, black, black, purple, y=-1.05, top=3.0, width=2.1, depth=1.7)

    # roll cage with a roof, beacon on top
    for x in (-1, 1):
        s = x > 0
        beam(lib, "cage_back%d" % s, (x * 1.5, -3.15, 2.6), (x * 1.45, -3.0, 6.25), (0.3, 0.3), black, bevel=0)
        beam(lib, "cage_front%d" % s, (x * 1.4, 0.05, 3.6), (x * 1.45, -0.4, 6.25), (0.26, 0.26), black, bevel=0)
    lib.box("roof", (3.4, 3.2, 0.3), (0, -1.65, 6.35), mat=purple, bevel=0.12)
    hazard(lib, "roof_stripe", (1.7, -0.05, 6.22), (-1, 0, 0), (0, 0, 1), 3.4, 0.26, 0.04, (yellow, black), width=0.45)
    lib.box("beacon_base", (0.5, 0.5, 0.12), (0, -1.65, 6.56), mat=black)
    lib.cyl("beacon", 0.2, 0.3, (0, -1.65, 6.75), mat=amber, verts=8)

    # yellow counterweight with hazard stripes at the back, tow hitch
    lib.box("weight", (3.0, 0.8, 1.2), (0, -3.85, 1.85), mat=yellow, bevel=0.18)
    hazard(lib, "weight_stripe", (-1.4, -4.25, 1.45), (1, 0, 0), (0, 0, 1), 2.8, 0.45, 0.04, (black, yellow), width=0.45)
    lib.box("hitch", (0.6, 0.6, 0.3), (0, -4.35, 1.1), mat=black, bevel=0.05)

    # mulching head out front: push arms, purple housing over a toothed steel drum, skids, hazard stripes
    for x in (-1, 1):
        beam(lib, "head_arm%d" % (x > 0), (x * 0.9, 2.7, 1.3), (x * 1.6, 3.5, 1.35), (0.35, 0.35), black, bevel=0.06)
    lib.box("housing", (6.0, 1.7, 1.05), (0, 3.95, 1.75), mat=purple, bevel=0.22, taper=(0.97, 0.75))
    lib.box("housing_back", (5.6, 0.4, 0.9), (0, 3.3, 0.85), mat=black, bevel=0.06)
    hazard(lib, "head_stripe", (2.88, 4.83, 1.28), (-1, 0, 0), (0, 0, 1), 5.76, 0.36, 0.04, (yellow, black), width=0.6)
    for x in (-1, 1):
        lib.box("skid%d" % (x > 0), (0.3, 2.3, 1.6), (x * 3.0, 4.05, 1.0), mat=black, bevel=0.08)
    lib.cyl("drum", 0.55, 5.7, (0, 4.4, 0.68), rot=(0, 90, 0), mat=steel, verts=10)
    for i in range(7):
        x = -2.4 + i * 0.8
        for k in range(3):
            a = i * 0.9 + k * 2 * math.pi / 3
            p = (x, 4.4 + 0.6 * math.cos(a), 0.68 + 0.6 * math.sin(a))
            t = lib.box("tooth%d_%d" % (i, k), (0.28, 0.22, 0.3), p, mat=yellow)
            t.rotation_euler = (a - math.pi / 2, 0, 0)
