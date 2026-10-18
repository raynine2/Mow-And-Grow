"""Garden Scissors (hand tool): big chunky hedge shears in the Chop A Forest toy style. Two thick red handles with
black end caps meet at a chunky pivot bolt; two straight grey metal blades with lighter cutting edges point +Y.

Held in one hand: the grip (between the two handles) is at the origin, the blades point +Y, the shears open in
the XY plane (thickness along Z). About 3.6 studs long."""
import math
import bpy
from mathutils import Matrix, Vector

PREVIEW = dict(dist=5.4, height=4.4, target_z=0.6, yaw=120)


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


def lift_preview(lib, lift):
    """The grip sits at the origin, so half the tool is below the preview's ground. Raise the meshes for the
    preview render only (one shot, restores itself); the exported GLB keeps the grip at the origin."""
    orig = lib.preview

    def wrapped(*a, **k):
        lib.preview = orig
        objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
        for o in objs:
            o.location.z += lift
        try:
            return orig(*a, **k)
        finally:
            for o in objs:
                o.location.z -= lift
    lib.preview = wrapped


# ---- model ------------------------------------------------------------------------------------------------------
def build(lib):
    red = lib.material("SmoothPlastic", (226, 52, 46))
    black = lib.material("SmoothPlastic", (38, 38, 44))
    steel = lib.material("Metal", (150, 156, 168))
    edge = lib.material("Metal", (212, 216, 226))
    dark = lib.material("Metal", (82, 86, 96))

    pivot = Vector((0, 1.15, 0))
    open_deg = 11          # half-angle between the blades
    splay = 13             # half-angle between the handles
    for side in (-1, 1):
        z = 0.1 * side   # the two halves slide over each other
        # blade (forward, leaning to `side`) and the handle it belongs to (backward, the other side)
        a = math.radians(open_deg * side)
        fwd = Vector((math.sin(a), math.cos(a), 0))
        inward = Vector((-fwd.y, fwd.x, 0)) * (-side)
        root = pivot + Vector((0, 0, z)) - fwd * 0.3
        tip = pivot + Vector((0, 0, z)) + fwd * 2.35
        # thick spine on the outside, a thinner lighter cutting edge on the inside (two-tone, like the axe head)
        beam(lib, "blade%d" % side, root - inward * 0.12, tip - inward * 0.06, (0.6, 0.2), steel, bevel=0.06, taper=(0.55, 1))
        beam(lib, "edge%d" % side, root + fwd * 0.3 + inward * 0.26, tip + fwd * 0.05 + inward * 0.06, (0.3, 0.12),
             edge, bevel=0.04, taper=(0.35, 1))
        # handle: dark metal shank, then a thick red grip with a black end cap
        h = math.radians(180 + splay * -side)
        back = Vector((math.sin(h), math.cos(h), 0))
        s0 = pivot + Vector((0, 0, -z))
        s1 = s0 + back * 0.55
        beam(lib, "shank%d" % side, s0, s1, (0.26, 0.18), dark, bevel=0.05)
        g1 = s1 + back * 1.35
        beam(lib, "grip%d" % side, s1 - back * 0.05, g1, (0.36, 0.36), red, bevel=0.1, taper=(1.12, 1.12))
        beam(lib, "cap%d" % side, g1 - back * 0.02, g1 + back * 0.18, (0.42, 0.42), black, bevel=0.08)
        # finger ridges on the grip
        for i in range(2):
            p = s1 + back * (0.42 + i * 0.45)
            beam(lib, "ridge%d_%d" % (side, i), p - back * 0.05, p + back * 0.05, (0.4, 0.4), red, bevel=0.06)
        # rubber bumper that stops the handles closing
        beam(lib, "bump%d" % side, s1 + back * 0.02 + Vector((-side * 0.16, 0, 0)), s1 + back * 0.2 + Vector((-side * 0.18, 0, 0)),
             (0.14, 0.24), black, bevel=0.04)
    # pivot bolt + nut
    lib.cyl("bolt", 0.24, 0.5, pivot, mat=dark, verts=10, bevel=0.05)
    lib.cyl("nut", 0.16, 0.6, pivot, mat=edge, verts=6, bevel=0.03)
    lift_preview(lib, 0.6)
