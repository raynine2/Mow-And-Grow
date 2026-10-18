"""Weed Whacker (hand tool): a string trimmer. Green motor housing with a black pull-start and a red fuel cap at the
back, a rubber grip with a trigger (the origin), a long black shaft with a loop handle, and at the far end a
gearbox, a green guard and a round spool with a white line sticking out both sides.

Grip at the origin, the shaft along +Y; the head is tilted so it spins flat when the shaft points ~35 deg down."""
import math
import bpy
from mathutils import Matrix, Vector

PREVIEW = dict(dist=8.0, height=3.6, target_z=0.6, yaw=70)


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
    green = lib.material("SmoothPlastic", (88, 190, 64))
    black = lib.material("SmoothPlastic", (36, 36, 42))
    grey = lib.material("Metal", (120, 124, 134))
    red = lib.material("SmoothPlastic", (226, 52, 46))
    white = lib.material("SmoothPlastic", (245, 245, 240))

    # motor housing behind the hand
    lib.box("motor", (0.85, 1.25, 0.95), (0, -1.2, 0.12), mat=green, bevel=0.14, taper=(0.85, 0.9))
    lib.box("motor_cover", (0.95, 0.7, 0.6), (0, -1.05, 0.62), mat=green, bevel=0.14, taper=(0.7, 0.8))
    lib.box("tank", (0.7, 0.75, 0.42), (0, -1.25, -0.48), mat=black, bevel=0.1)
    lib.cyl("fuel_cap", 0.14, 0.16, (0.22, -1.45, -0.72), mat=red, verts=8, bevel=0.03)
    lib.cyl("pull", 0.3, 0.16, (-0.48, -1.25, 0.15), rot=(0, 90, 0), mat=black, verts=10, bevel=0.04)
    lib.box("pull_handle", (0.1, 0.4, 0.12), (-0.58, -1.25, 0.15), mat=red)
    lib.box("vents", (0.97, 0.5, 0.1), (0, -1.45, 0.42), mat=black)
    for i in range(2):
        lib.box("vent%d" % i, (0.97, 0.5, 0.06), (0, -1.45, 0.22 - i * 0.16), mat=black)
    # rubber grip with a trigger underneath (the hand sits here)
    rod(lib, "grip", (0, -0.6, 0), (0, 0.6, 0), 0.2, black, verts=8, bevel=0.04)
    beam(lib, "trigger", (0, -0.15, -0.18), (0, 0.15, -0.36), (0.12, 0.12), red, bevel=0.03)
    beam(lib, "guard_loop", (0, -0.45, -0.15), (0, 0.4, -0.48), (0.1, 0.1), black, bevel=0)
    # shaft
    rod(lib, "shaft", (0, 0.55, 0), (0, 4.7, 0), 0.12, black, verts=8, bevel=0)
    # loop handle (an upside-down U over the shaft)
    for x in (-0.38, 0.38):
        beam(lib, "loop_leg%d" % (x > 0), (x * 0.4, 1.5, 0.05), (x, 1.5, 0.75), (0.13, 0.13), black, bevel=0.03)
    beam(lib, "loop_top", (-0.42, 1.5, 0.78), (0.42, 1.5, 0.78), (0.2, 0.2), black, bevel=0.05)
    lib.box("clamp", (0.36, 0.3, 0.36), (0, 1.5, 0), mat=green, bevel=0.06)
    # gearbox + head, tilted so the line spins flat when the shaft points down at the grass
    head = Vector((0, 5.0, -0.05))
    lib.box("gearbox", (0.42, 0.55, 0.42), (0, 4.75, 0), rot=(35, 0, 0), mat=grey, bevel=0.07)
    tilt = Matrix.Rotation(math.radians(35), 3, "X")
    up = tilt @ Vector((0, 0, 1))
    hub = head - up * 0.25
    lib.cyl("spool", 0.5, 0.36, hub, rot=(35, 0, 0), mat=black, verts=12, bevel=0.06)
    lib.cyl("spool_cap", 0.32, 0.5, hub, rot=(35, 0, 0), mat=green, verts=10, bevel=0.05)
    lib.cyl("bump", 0.18, 0.3, hub - up * 0.28, rot=(35, 0, 0), mat=grey, verts=8, bevel=0.04)
    # white trimmer line through the spool
    beam(lib, "line", hub + Vector((-1.3, 0, 0)), hub + Vector((1.3, 0, 0)), (0.06, 0.06), white, bevel=0, roll=0)
    # guard: a curved green half-disc behind the spool (toward the hand), from three angled plates
    for i, a in enumerate((-55, 0, 55)):
        d = Matrix.Rotation(math.radians(a), 3, "Z") @ Vector((0, -0.72, 0))
        c = head + tilt @ d + up * 0.1
        g = lib.box("guard%d" % i, (0.85, 0.3, 0.12), c, mat=green, bevel=0.05)
        g.rotation_euler = (tilt @ Matrix.Rotation(math.radians(a), 3, "Z")).to_euler()
    lift_preview(lib, 1.1)
