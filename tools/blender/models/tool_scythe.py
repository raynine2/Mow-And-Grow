"""Mega Scythe (hand tool): a long purple-brown handle with wraps, a side grip, a dark metal collar with a glowing gem,
and a huge curved blade built from angled segments: a dark metal spine outside, a glowing purple Neon edge inside.

Grip at the origin, handle along +Y; the blade rises (+Z) from the top of the handle and curves back toward the hand,
in the YZ plane, like a reaper's scythe. About 7.5 studs long."""
import math
import bpy
from mathutils import Matrix, Vector

PREVIEW = dict(dist=11.5, height=4.5, target_z=1.8, yaw=78)


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
    wood = lib.material("Wood", (104, 62, 84))
    wrap = lib.material("Fabric", (52, 30, 62))
    dark = lib.material("Metal", (66, 44, 86))
    glow = lib.material("Neon", (186, 84, 255))

    top = 5.7
    rod(lib, "handle", (0, -1.6, 0), (0, top, 0), 0.19, wood, verts=8, bevel=0.04)
    rod(lib, "butt", (0, -1.85, 0), (0, -1.5, 0), 0.25, dark, verts=8, bevel=0.05)
    for i, y in enumerate((-0.45, 0.0, 0.45)):
        rod(lib, "wrap%d" % i, (0, y - 0.16, 0), (0, y + 0.16, 0), 0.215, wrap, verts=8, bevel=0.03)
    # side grip: a peg sticking up from the handle with its own wrap and knob
    rod(lib, "side_peg", (0, 2.5, 0), (0, 2.4, 0.95), 0.13, wood, verts=8, bevel=0.03)
    rod(lib, "side_wrap", (0, 2.43, 0.35), (0, 2.41, 0.85), 0.165, wrap, verts=8, bevel=0.03)
    lib.box("side_knob", (0.32, 0.32, 0.22), (0, 2.4, 1.02), mat=dark, bevel=0.06)
    lib.box("side_clamp", (0.48, 0.4, 0.48), (0, 2.5, 0), mat=dark, bevel=0.07)
    # collar at the top with a glowing gem
    lib.box("collar", (0.6, 0.7, 0.6), (0, top - 0.15, 0.05), mat=dark, bevel=0.1)
    lib.box("gem", (0.66, 0.26, 0.26), (0, top - 0.15, 0.05), mat=glow, bevel=0.05)
    beam(lib, "tang", (0, top - 0.1, 0.25), (0, top + 0.05, 0.75), (0.3, 0.5), dark, bevel=0.06)

    # blade: arc of radius R in the YZ plane, rising from the collar (+Z) and curling back toward the hand (-Y)
    R, sweep, n = 3.7, 104.0, 8
    yc, zc = top + 0.15 - R, 0.55
    def pt(deg, off=0.0):
        t = math.radians(deg)
        r = R - off          # off > 0 = toward the centre (the inner, cutting side)
        return Vector((0, yc + r * math.cos(t), zc + r * math.sin(t)))
    for i in range(n):
        a0 = sweep * i / n - (1.5 if i else 0)
        a1 = sweep * (i + 1) / n + 1.5
        w0 = 0.2 + 1.0 * (1 - i / n) ** 0.7
        w1 = 0.2 + 1.0 * (1 - (i + 1) / n) ** 0.7
        beam(lib, "spine%d" % i, pt(a0, -w0 * 0.12), pt(a1, -w1 * 0.12), (0.26, w0 * 0.4), dark, bevel=0.05,
             taper=(1, w1 / w0))
        beam(lib, "edge%d" % i, pt(a0, w0 * 0.4), pt(a1, w1 * 0.4), (0.14, w0 * 0.72), glow, bevel=0.04,
             taper=(0.9, w1 / w0))
        if i in (1, 3, 5):   # spikes on the back of the blade
            p = pt((a0 + a1) / 2, -w0 * 0.3)
            out = (p - Vector((0, yc, zc))).normalized()
            rod(lib, "spike%d" % i, p, p + out * 0.55, 0.13, dark, verts=4, bevel=0, top_scale=0.1)
    # pointed tip
    beam(lib, "tip", pt(sweep, 0.1), pt(sweep + 14, 0.3), (0.13, 0.32), glow, bevel=0.02, taper=(0.5, 0.15))
    lift_preview(lib, 0.3)
