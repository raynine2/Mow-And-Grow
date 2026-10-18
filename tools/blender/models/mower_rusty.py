"""Rusty Rider (ride-on mower, the first one): a small, old, rusty orange lawn tractor. Dented hood knocked a bit
crooked, darker rust patches, one headlight left (the other socket is empty), a bent exhaust, a cracked brown seat,
bald black tyres, a sagging mowing deck under the middle with a side chute.

Front +Y, wheels on z = 0; the seat cushion top is flat at z = 3 around (0, -1). About 5 wide x 7.5 long x 5 tall."""
import math
from mathutils import Matrix, Vector

PREVIEW = dict(dist=15, height=8.5, target_z=2.2, yaw=40)


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


def wheel(lib, name, loc, r, w, tyre, hub, verts=14, hub_scale=0.55):
    """Wheel with its axle along X: a fat bevelled tyre, a hub disc and a centre cap."""
    x, y, z = loc
    s = 1 if x >= 0 else -1
    lib.cyl(name, r, w, loc, rot=(0, 90, 0), mat=tyre, verts=verts, bevel=min(0.12, r * 0.12))
    lib.cyl(name + "_hub", r * hub_scale, w + 0.1, loc, rot=(0, 90, 0), mat=hub, verts=10, bevel=0.05)
    lib.cyl(name + "_cap", r * 0.2, 0.2, (x + s * (w / 2 + 0.1), y, z), rot=(0, 90, 0), mat=tyre, verts=6)


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


# ---- model ------------------------------------------------------------------------------------------------------
def build(lib):
    rust = lib.material("CorrodedMetal", (200, 104, 44))
    rust_dark = lib.material("CorrodedMetal", (118, 64, 38))
    tyre = lib.material("Plastic", (44, 42, 44))
    steel = lib.material("Metal", (128, 124, 120))
    seat_mat = lib.material("Fabric", (92, 60, 40))
    lamp = lib.material("SmoothPlastic", (250, 236, 170))

    # wheels: big at the back, small at the front
    for x in (-1, 1):
        wheel(lib, "rear%d" % (x > 0), (x * 2.0, -2.0, 1.25), 1.25, 0.95, tyre, rust_dark, verts=14)
        wheel(lib, "front%d" % (x > 0), (x * 1.7, 2.45, 0.78), 0.78, 0.6, tyre, steel, verts=12)
    lib.box("axle_front", (3.2, 0.3, 0.3), (0, 2.45, 0.85), mat=steel)
    lib.box("axle_rear", (3.6, 0.36, 0.36), (0, -2.0, 1.25), mat=steel)

    # chassis + sagging deck under the middle, with a side chute
    lib.box("frame", (2.4, 6.2, 0.5), (0, 0.1, 1.15), mat=rust_dark, bevel=0.08)
    lib.box("deck", (4.2, 2.4, 0.6), (0.1, 0.15, 0.62), rot=(2, -3, 1), mat=rust, bevel=0.18, taper=(0.92, 0.9))
    lib.box("deck_rim", (4.4, 2.6, 0.2), (0.1, 0.15, 0.36), rot=(2, -3, 1), mat=rust_dark, bevel=0.06)
    lib.box("chute", (0.9, 1.1, 0.5), (2.55, 0.0, 0.6), rot=(0, -8, -12), mat=rust, bevel=0.1, taper=(0.7, 0.8))
    lib.box("deck_patch", (1.3, 0.9, 0.05), (-0.9, 0.55, 0.95), rot=(2, -3, 8), mat=rust_dark)

    # hood: knocked a bit crooked, a dent patch, a grille, one headlight
    lib.box("hood", (2.5, 2.7, 1.25), (0.05, 1.95, 2.05), rot=(-2, 1.5, -2), mat=rust, bevel=0.22, taper=(0.86, 0.92))
    lib.box("hood_top", (2.0, 2.2, 0.25), (0.05, 1.85, 2.72), rot=(-4, 1.5, -2), mat=rust, bevel=0.1)
    lib.box("dent", (0.8, 0.7, 0.06), (0.45, 2.2, 2.86), rot=(-6, 4, 15), mat=rust_dark)
    lib.box("patch_side", (0.05, 1.0, 0.6), (1.28, 1.6, 2.0), rot=(0, 0, -2), mat=rust_dark)
    lib.box("grille", (2.1, 0.25, 1.05), (0.02, 3.3, 1.95), rot=(0, 0, -2), mat=rust_dark, bevel=0.06)
    for i in range(4):
        lib.box("slat%d" % i, (1.8, 0.1, 0.1), (0.02, 3.44, 1.6 + i * 0.24), rot=(0, 0, -2), mat=steel)
    lib.box("bumper", (2.8, 0.35, 0.35), (0, 3.55, 1.1), rot=(0, 4, 0), mat=steel, bevel=0.08)
    lib.cyl("lamp_l", 0.28, 0.2, (-0.7, 3.42, 2.72), rot=(90, 0, 0), mat=steel, verts=10, bevel=0.04)
    lib.cyl("lamp_l_glass", 0.2, 0.08, (-0.7, 3.54, 2.72), rot=(90, 0, 0), mat=lamp, verts=10)
    lib.cyl("lamp_r", 0.28, 0.2, (0.75, 3.38, 2.7), rot=(90, 0, 0), mat=rust_dark, verts=10, bevel=0.04)  # empty socket

    # dash + steering
    lib.box("dash", (2.1, 0.8, 1.4), (0, 0.35, 2.55), mat=rust, bevel=0.14, taper=(0.9, 0.7))
    lib.box("gauge", (0.5, 0.1, 0.35), (0.45, -0.02, 2.9), rot=(-20, 0, 0), mat=steel, bevel=0.03)
    steering_wheel(lib, (0, -0.15, 3.85), 55, 0.62, tyre, steel, column_to=(0, 0.35, 3.05))

    # body behind the dash: footboards, rear deck under the seat, fenders over the back wheels
    for x in (-1, 1):
        lib.box("footboard%d" % (x > 0), (1.0, 2.2, 0.18), (x * 1.55, 0.4, 1.5), mat=steel, bevel=0.04)
        # fender: three plates hugging the top of the back wheel, the outer one bent down a little (dented)
        arc = [12, 58, 112, 168]
        for k in range(3):
            a0, a1 = math.radians(arc[k]), math.radians(arc[k + 1])
            rr = 1.55 if k != 0 else 1.62
            p0 = Vector((x * 2.0, -2.0 + rr * math.cos(a0), 1.25 + rr * math.sin(a0)))
            p1 = Vector((x * 2.0, -2.0 + 1.55 * math.cos(a1), 1.25 + 1.55 * math.sin(a1)))
            beam(lib, "fender%d_%d" % (x > 0, k), p0, p1, (1.12, 0.24), rust if k != 1 or x < 0 else rust_dark, bevel=0.07)
        lib.box("fender_side%d" % (x > 0), (0.2, 2.2, 0.9), (x * 1.5, -1.85, 2.2), mat=rust, bevel=0.06)
    lib.box("body", (2.9, 3.0, 1.2), (0, -1.75, 1.95), rot=(0, -1.5, 0), mat=rust, bevel=0.18)
    lib.box("tail", (2.6, 0.4, 0.9), (0, -3.35, 1.7), mat=rust_dark, bevel=0.1)
    lib.box("hitch", (0.4, 0.6, 0.15), (0, -3.7, 1.35), mat=steel)
    lib.box("patch_body", (0.9, 0.05, 0.5), (-0.6, -3.56, 1.85), rot=(0, 10, 0), mat=rust)
    for i, (x, z) in enumerate(((-1.0, 2.0), (1.0, 2.0), (-1.0, 1.45), (1.0, 1.45))):
        lib.box("bolt%d" % i, (0.14, 0.08, 0.14), (x, -3.57, z), mat=steel)

    seat(lib, seat_mat, seat_mat, steel, y=-1.0, top=3.0, width=1.8, depth=1.6)
    lib.box("seat_crack", (0.12, 0.9, 0.04), (0.3, -0.95, 3.0), rot=(0, 0, 25), mat=rust_dark)

    # bent exhaust pipe next to the hood
    beam(lib, "exhaust0", (-1.2, 1.2, 2.3), (-1.25, 1.15, 3.6), (0.24, 0.24), steel, bevel=0.04)
    beam(lib, "exhaust1", (-1.25, 1.15, 3.55), (-1.5, 1.0, 3.95), (0.24, 0.24), steel, bevel=0.04)
    lib.box("exhaust_tip", (0.32, 0.32, 0.18), (-1.52, 0.99, 4.02), rot=(0, -30, 0), mat=rust_dark, bevel=0.03)
