"""Sickle (hand tool): a chunky light-wood handle with a dark pommel and a metal ferrule, and a big hooked grey
blade built from angled segments: a thick darker spine on the outside, a thinner light cutting edge on the inside.

Grip at the origin, handle along +Y; the blade curls up (+Z) and back toward the hand, in the YZ plane."""
import math
import bpy
from mathutils import Matrix, Vector

PREVIEW = dict(dist=5.2, height=2.6, target_z=1.4, yaw=75)


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


def rod(lib, name, p0, p1, r, mat, verts=8, bevel=0.04, top_scale=1.0):
    p0, p1 = Vector(p0), Vector(p1)
    o = lib.cyl(name, r, (p1 - p0).length, mat=mat, verts=verts, bevel=bevel, top_scale=top_scale)
    o.rotation_euler = _frame(p1 - p0).to_euler()
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
    wood = lib.material("Wood", (204, 132, 72))
    wood_dark = lib.material("Wood", (120, 72, 44))
    steel = lib.material("Metal", (128, 134, 146))
    edge = lib.material("Metal", (208, 212, 222))

    # handle: fat at the hand, a pommel knob at the back, a grey ferrule where the blade goes in
    rod(lib, "handle", (0, -0.75, 0), (0, 0.95, 0), 0.22, wood, verts=8, bevel=0.05, top_scale=0.85)
    rod(lib, "pommel", (0, -0.98, 0), (0, -0.7, 0), 0.27, wood_dark, verts=8, bevel=0.06)
    for i, y in enumerate((-0.25, 0.3)):
        rod(lib, "ring%d" % i, (0, y - 0.05, 0), (0, y + 0.05, 0), 0.235, wood_dark, verts=8, bevel=0.02)
    rod(lib, "ferrule", (0, 0.88, 0), (0, 1.18, 0), 0.24, steel, verts=8, bevel=0.04)
    beam(lib, "tang", (0, 1.1, 0), (0, 1.45, 0.05), (0.16, 0.34), steel, bevel=0.04)

    # hooked blade: circle of radius R in the YZ plane, starting at the ferrule heading +Y and curling up and back
    R, y0, n, sweep = 1.1, 1.35, 9, 200.0
    def pt(deg, off=0.0):
        t = math.radians(deg)
        r = R - off          # off > 0 moves toward the centre (the inner, cutting side)
        return Vector((0, y0 + r * math.sin(t), R - r * math.cos(t)))
    for i in range(n):
        a0 = sweep * i / n - (2 if i else 0)
        a1 = sweep * (i + 1) / n + 3
        f0 = 1 - i / n; f1 = 1 - (i + 1) / n        # width falls off toward the tip
        w0 = 0.14 + 0.46 * f0 ** 0.8
        w1 = 0.14 + 0.46 * f1 ** 0.8
        # spine: outer half, thick
        beam(lib, "spine%d" % i, pt(a0, -w0 * 0.15), pt(a1, -w1 * 0.15), (0.17, w0 * 0.7), steel, bevel=0.04,
             taper=(1, max(w1 / w0, 0.3)), roll=0)
        # edge: inner half, thinner and lighter
        beam(lib, "edge%d" % i, pt(a0, w0 * 0.45), pt(a1, w1 * 0.45), (0.1, w0 * 0.55), edge, bevel=0.03,
             taper=(1, max(w1 / w0, 0.3)))
    # sharp tip
    beam(lib, "tip", pt(sweep, 0.05), pt(sweep + 22, 0.14), (0.13, 0.16), edge, bevel=0.02, taper=(0.4, 0.2))
    lift_preview(lib, 0.4)
