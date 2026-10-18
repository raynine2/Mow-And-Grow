"""Rocket Mower (ride-on mower): a sleek red-orange sci-fi racer that is still clearly a ride-on mower. A pointed nose
with cyan light slits, slick low-profile tyres with glowing cyan rims, a glass windscreen, a high-back seat, two
white-banded rocket boosters on the rear fenders with tail fins and a spoiler wing, a big centre booster under a tall
tail fin, orange Neon exhaust flames, and a wide out-front deck with a glowing cyan edge and hazard stripes.

Front +Y, wheels on z = 0; the seat cushion top is flat at z = 3 around (0, -1). About 6 wide x 10 long x 5.2 tall."""
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
def booster(lib, name, x, z, y0, y1, r, red, white, dark, flame, flame_len=2.2):
    """Rocket booster along Y from y0 (back) to y1 (front): body, white bands, nose cone, nozzle and a Neon flame."""
    lib.cyl(name, r, y1 - y0, (x, (y0 + y1) / 2, z), rot=(90, 0, 0), mat=red, verts=12, bevel=0.06)
    for t in (0.25, 0.7):
        lib.cyl(name + "_band%d" % int(t * 10), r * 1.06, 0.25, (x, y0 + (y1 - y0) * t, z), rot=(90, 0, 0), mat=white, verts=12)
    lib.cyl(name + "_nose", r, r * 2, (x, y1 + r, z), rot=(-90, 0, 0), mat=white, verts=12, top_scale=0.2)
    lib.cyl(name + "_nozzle", r * 0.75, r * 0.9, (x, y0 - r * 0.45, z), rot=(90, 0, 0), mat=dark, verts=12, top_scale=1.3)
    lib.cyl(name + "_flame", r * 0.85, r * flame_len, (x, y0 - r * 0.9 - r * flame_len / 2, z), rot=(90, 0, 0), mat=flame, verts=8, top_scale=0.1)


def build(lib):
    red = lib.material("SmoothPlastic", (255, 70, 40))   # Config colour of the Rocket Mower
    white = lib.material("SmoothPlastic", (240, 240, 245))
    dark = lib.material("Metal", (58, 60, 70))
    tyre = lib.material("Plastic", (36, 36, 40))
    cyan = lib.material("Neon", (70, 225, 255))
    flame = lib.material("Neon", (255, 120, 20))
    glass = lib.material("Glass", (170, 220, 255))

    # slick tyres with glowing rims: big at the back, small at the front, red fairings over them
    for x in (-1, 1):
        s = x > 0
        for nm, y, r, w in (("rear", -2.4, 1.25, 1.1), ("front", 1.9, 0.85, 0.8)):
            wheel(lib, "%s%d" % (nm, s), (x * 2.3 if nm == "rear" else x * 2.05, y, r), r, w, tyre, dark, verts=16 if nm == "rear" else 12)
            lib.cyl("%s_glow%d" % (nm, s), r * 0.72, w + 0.04, (x * 2.3 if nm == "rear" else x * 2.05, y, r), rot=(0, 90, 0),
                    mat=cyan, verts=12)
        fender(lib, "fender_r%d" % s, x * 2.3, -2.4, 1.25, 1.5, 1.3, red, arc=(10, 60, 120, 178))
        fender(lib, "fender_f%d" % s, x * 2.05, 1.9, 0.85, 1.1, 1.0, red, arc=(15, 75, 135, 175))
    lib.box("frame", (1.8, 6.2, 0.5), (0, -0.4, 1.05), mat=dark, bevel=0.08)
    lib.box("axle", (3.6, 0.4, 0.4), (0, -2.4, 1.25), mat=dark)

    # pointed nose with a white racing stripe and cyan light slits, low side skirts
    beam(lib, "nose", (0, -0.4, 1.85), (0, 3.3, 1.35), (2.5, 1.2), red, bevel=0.2, taper=(0.4, 0.5))
    beam(lib, "nose_stripe", (0, -0.3, 2.44), (0, 3.15, 1.62), (0.55, 0.1), white, bevel=0.03, taper=(0.45, 1))
    for x in (-1, 1):
        s = x > 0
        beam(lib, "slit%d" % s, (x * 1.05, 1.3, 1.85), (x * 0.55, 3.0, 1.45), (0.08, 0.16), cyan, bevel=0)
        beam(lib, "skirt%d" % s, (x * 1.45, -1.3, 1.25), (x * 1.3, 1.3, 1.2), (0.45, 0.4), dark, bevel=0.08)

    # cockpit: red tub under the seat, dash, glass windscreen, steering wheel, seat with white back
    lib.box("tub", (2.9, 2.9, 1.2), (0, -1.3, 2.05), mat=red, bevel=0.25, taper=(0.95, 0.95))
    lib.box("tub_trim", (2.96, 2.96, 0.12), (0, -1.3, 1.55), mat=dark, bevel=0.04)
    lib.box("dash", (2.2, 0.9, 0.9), (0, 0.35, 2.5), mat=red, bevel=0.2, taper=(0.9, 0.6))
    lib.box("windscreen", (2.0, 0.1, 0.9), (0, 0.65, 3.1), rot=(40, 0, 0), mat=glass, bevel=0.03, taper=(0.85, 1))
    lib.box("screen_frame", (2.1, 0.2, 0.14), (0, 0.85, 2.72), rot=(40, 0, 0), mat=dark)
    steering_wheel(lib, (0, -0.3, 3.95), 50, 0.55, dark, white, column_to=(0, 0.25, 2.9))
    seat(lib, white, white, dark, y=-1.0, top=3.0, width=2.0, depth=1.7)
    beam(lib, "headrest", (0, -2.0, 4.4), (0, -2.08, 4.95), (1.3, 0.36), white, bevel=0.13)

    # boosters: one on each rear fender, a big one in the middle under a tall tail fin, spoiler wing over the back
    for x in (-1, 1):
        s = x > 0
        booster(lib, "booster%d" % s, x * 2.3, 3.1, -3.4, -0.9, 0.5, red, white, dark, flame, flame_len=1.8)
        lib.wedge("fin%d" % s, (0.14, 1.1, 0.9), (x * 2.3, -3.0, 3.95), mat=white, bevel=0.03)
        beam(lib, "cyan_line%d" % s, (x * 1.47, -2.6, 2.15), (x * 1.47, -0.1, 2.15), (0.06, 0.14), cyan, bevel=0)
    booster(lib, "booster_main", 0, 2.25, -3.6, -2.2, 0.72, red, white, dark, flame, flame_len=1.2)
    lib.wedge("tail_fin", (0.18, 1.6, 2.3), (0, -3.2, 4.1), mat=red, bevel=0.04)
    lib.box("wing", (5.4, 1.0, 0.14), (0, -3.25, 4.45), rot=(-8, 0, 0), mat=white, bevel=0.05)
    for x in (-1, 1):
        lib.box("wing_tip%d" % (x > 0), (0.14, 1.1, 0.5), (x * 2.72, -3.3, 4.55), mat=red, bevel=0.04)

    # out-front deck on two arms: red housing, white top, cyan glowing front edge, hazard stripes on the sides
    for x in (-1, 1):
        beam(lib, "deck_arm%d" % (x > 0), (x * 0.6, 2.4, 1.05), (x * 1.3, 3.2, 0.9), (0.25, 0.25), dark, bevel=0.04)
    lib.box("deck", (5.9, 2.0, 0.55), (0, 4.0, 0.6), mat=red, bevel=0.18, taper=(0.94, 0.85))
    lib.box("deck_top", (3.8, 1.3, 0.28), (0, 3.95, 1.0), mat=white, bevel=0.12, taper=(0.8, 0.75))
    lib.box("deck_rim", (6.1, 2.2, 0.16), (0, 4.0, 0.28), mat=dark, bevel=0.05)
    lib.box("deck_glow", (5.4, 0.1, 0.16), (0, 5.0, 0.55), mat=cyan)
    for x in (-1, 1):
        hazard(lib, "deck_stripe%d" % (x > 0), (x * 2.98, 4.8 if x > 0 else 3.2, 0.36), (0, -x, 0), (0, 0, 1), 1.6, 0.26,
               0.04, (white, dark), width=0.4)
