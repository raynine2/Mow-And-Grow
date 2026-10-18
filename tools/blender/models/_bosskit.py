"""Private helpers for the five zone-boss weed monsters (boss_dandelion ... boss_jungle).

build.py skips files that start with "_", so this is never built as a model. Load it from a boss model with:

    import os, sys; sys.path.insert(0, os.path.dirname(__file__)); import _bosskit as bk

Everything here builds on lib (box / cyl / sphere ...) plus a few organic shapes: ellipsoids and domes, cones
between two points, tubes along a path, flat toothed leaves, and the cartoon face (eyes, pupils, angry brows,
toothy mouth) that sits on the front (+Y) of a head.
"""
import math
import bmesh
from mathutils import Euler, Matrix, Vector


def _xform(obj, loc=(0, 0, 0), rot=(0, 0, 0), quat=None):
    """Move an object built around the origin into place (rot in degrees XYZ, or a quaternion)."""
    r = quat.to_matrix().to_4x4() if quat is not None else Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4()
    obj.matrix_basis = Matrix.Translation(loc) @ r @ obj.matrix_basis
    return obj


# ---------------------------------------------------------------------------------------------------------------
# organic shapes
# ---------------------------------------------------------------------------------------------------------------
def ellipsoid(lib, name, radii, loc, mat, segs=12, rings=8, rot=(0, 0, 0), z_cut=None):
    """Low-poly lat/long ellipsoid. `z_cut` (-1..1) cuts off everything below that fraction of rz and caps it flat
    (0 = a dome / half-ellipsoid, flat side down)."""
    bm = bmesh.new()
    lo = -math.pi / 2 if z_cut is None else math.asin(max(-1.0, min(1.0, z_cut)))
    rows = []
    for i in range(rings + 1):
        t = lo + (math.pi / 2 - lo) * i / rings
        if i == rings:
            rows.append([bm.verts.new((0, 0, radii[2]))])
            continue
        if i == 0 and z_cut is None:
            rows.append([bm.verts.new((0, 0, -radii[2]))])
            continue
        c, s = math.cos(t), math.sin(t)
        rows.append([bm.verts.new((math.cos(2 * math.pi * j / segs) * c * radii[0], math.sin(2 * math.pi * j / segs) * c * radii[1],
                                   s * radii[2])) for j in range(segs)])
    for a, b in zip(rows, rows[1:]):
        if len(a) == 1:
            for j in range(segs):
                bm.faces.new((a[0], b[(j + 1) % segs], b[j]))
        elif len(b) == 1:
            for j in range(segs):
                bm.faces.new((a[j], a[(j + 1) % segs], b[0]))
        else:
            for j in range(segs):
                k = (j + 1) % segs
                bm.faces.new((a[j], a[k], b[k], b[j]))
    if z_cut is not None:
        bm.faces.new(list(reversed(rows[0])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = lib._finish(lib._from_bmesh(name, bm), mat, (0, 0, 0), (0, 0, 0), 0)
    return _xform(obj, loc, rot)


def cone(lib, name, base, tip, r, mat, verts=6, tip_r=0.0):
    """Spike / thorn / tooth from point `base` to point `tip` (base radius r)."""
    a = Vector(base); b = Vector(tip); d = b - a
    obj = lib.cyl(name, r, d.length, mat=mat, verts=verts, top_scale=max(tip_r / r, 0.001) if tip_r else 0.001)
    obj.rotation_mode = "QUATERNION"
    obj.location = tuple((a + b) / 2)
    obj.rotation_quaternion = d.normalized().to_track_quat("Z", "Y")
    return obj


def tube(lib, name, pts, radii, mat, verts=8, overlap=0.45):
    """A bendy vine / stem through `pts`: one cylinder per segment (radius from `radii`, a number or a list per
    point), each pushed a little past its ends so the joints don't open up."""
    if not isinstance(radii, (list, tuple)):
        radii = [radii] * len(pts)
    objs = []
    for i in range(len(pts) - 1):
        a = Vector(pts[i]); b = Vector(pts[i + 1]); d = (b - a)
        n = d.normalized()
        r0, r1 = radii[i], radii[i + 1]
        a2 = a - n * (r0 * overlap if i > 0 else 0); b2 = b + n * (r1 * overlap if i < len(pts) - 2 else 0)
        obj = lib.cyl("%s%d" % (name, i), r0, (b2 - a2).length, mat=mat, verts=verts, top_scale=r1 / r0)
        obj.rotation_mode = "QUATERNION"
        obj.location = tuple((a2 + b2) / 2)
        obj.rotation_quaternion = n.to_track_quat("Z", "Y")
        objs.append(obj)
    return objs


def helix(centre, z0, z1, r0, r1, turns, phase, n, wobble=0.0):
    """Points on a widening/narrowing spiral (for twisting vines)."""
    pts = []
    for i in range(n + 1):
        t = i / n
        a = phase + turns * 2 * math.pi * t
        r = r0 + (r1 - r0) * t + wobble * math.sin(t * 7 + phase)
        pts.append((centre[0] + math.cos(a) * r, centre[1] + math.sin(a) * r, z0 + (z1 - z0) * t))
    return pts


def flat_poly(lib, name, pts, thick, mat, bevel=0.0, bends=()):
    """Extrude a polygon drawn in the XY plane (list of (x, y), may be concave) along Z by `thick` (centred).
    `bends` = [(y, deg), ...] folds everything past y down by deg (a drooping leaf tip)."""
    bm = bmesh.new()
    lo = [bm.verts.new((x, y, -thick / 2)) for x, y in pts]
    hi = [bm.verts.new((x, y, thick / 2)) for x, y in pts]
    n = len(pts)
    bm.faces.new(list(reversed(lo)))
    bm.faces.new(hi)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for cut, _ in bends:
        bmesh.ops.bisect_plane(bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces), plane_co=(0, cut, 0), plane_no=(0, 1, 0))
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    orig = {v: v.co.y for v in bm.verts}
    for cut, deg in sorted(bends, reverse=True):
        rm = Matrix.Rotation(math.radians(-deg), 3, "X")
        piv = Vector((0, cut, 0))
        for v in bm.verts:
            if orig[v] > cut + 1e-5:
                v.co = rm @ (v.co - piv) + piv
    return lib._finish(lib._from_bmesh(name, bm), mat, (0, 0, 0), (0, 0, 0), bevel)


def leaf_outline(length, width, teeth=0, tooth=0.35, tip=0.12):
    """Outline of a leaf pointing along +Y from (0, 0): widest a bit past the middle, pointed tip. `teeth` > 0 cuts
    backward-pointing jags into both edges (a dandelion / thistle leaf)."""
    right = []
    n = max(teeth, 3) * 2
    for i in range(1, n):
        t = i / n
        w = width / 2 * math.sin(math.pi * t ** 0.85) * (1 - t * 0.15)
        y = length * t
        if teeth and i % 2 == 1:
            right.append((w * (1 - tooth), y))
        elif teeth:
            right.append((w * (1 + tooth * 0.3), y - length / n * 0.6))
        else:
            right.append((w, y))
    right.append((width * tip / 2, length * 0.98))
    left = [(-x, y) for x, y in reversed(right)]
    return [(width * 0.16, 0)] + right + [(0, length)] + left + [(-width * 0.16, 0)]


def leaf(lib, name, base, ang, tilt, length, width, thick, mat, teeth=0, tooth=0.35, bends=(), bevel=0.0, roll=0.0):
    """A flat leaf from `base` pointing out at heading `ang` (degrees around Z, 0 = +Y, 90 = +X), raised `tilt`
    degrees above the ground. `bends` = [(fraction of length, deg), ...] droops the outer part down by deg."""
    o = flat_poly(lib, name, leaf_outline(length, width, teeth, tooth), thick, mat, bevel,
                  bends=[(length * f, d) for f, d in bends])
    _xform(o, (0, 0, 0), (tilt, roll, 0))
    return _xform(o, base, (0, 0, -ang))


def prism_xz(lib, name, pts, depth, mat, bevel=0.0):
    """Extrude a convex polygon drawn in the XZ plane (list of (x, z)) along Y by `depth` (front face at +Y)."""
    bm = bmesh.new()
    f = [bm.verts.new((x, -depth / 2, z)) for x, z in pts]
    k = [bm.verts.new((x, depth / 2, z)) for x, z in pts]
    n = len(pts)
    bm.faces.new(f)
    bm.faces.new(list(reversed(k)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((f[i], f[j], k[j], k[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return lib._finish(lib._from_bmesh(name, bm), mat, (0, 0, 0), (0, 0, 0), bevel)


# ---------------------------------------------------------------------------------------------------------------
# the cartoon face
# ---------------------------------------------------------------------------------------------------------------
def ellip_surface(centre, radii):
    """surf(x, z) -> (point, normal) on the front (+Y) of an ellipsoid; for placing face parts on a round head."""
    cx, cy, cz = centre; rx, ry, rz = radii
    def surf(x, z):
        u, w = (x - cx) / rx, (z - cz) / rz
        v = math.sqrt(max(0.02, 1 - u * u - w * w))
        p = Vector((x, cy + v * ry, z))
        nrm = Vector((u / rx, v / ry, w / rz)).normalized()
        return p, nrm
    return surf


def flat_surface(y, lean=0.0):
    """surf(x, z) for a flat face at y (lean = degrees the face tips back, so it looks a little upward)."""
    nrm = Vector((0, math.cos(math.radians(lean)), math.sin(math.radians(lean))))
    def surf(x, z):
        return Vector((x, y, z)), nrm
    return surf


def _on(surf, obj, x, z, sink, spin=0.0):
    """Stick an object (built facing +Y around the origin) onto the surface at (x, z), `sink` studs into it."""
    p, n = surf(x, z)
    q = n.to_track_quat("Y", "Z")
    obj.matrix_basis = Matrix.Translation(p - n * sink) @ q.to_matrix().to_4x4() @ Euler((0, math.radians(spin), 0), "XYZ").to_matrix().to_4x4() @ obj.matrix_basis
    return obj


def eye(lib, name, surf, x, z, s, white, black, look=(0.0, 0.0), brow=None, brow_mat=None, glow=False, h=1.0, sink=None):
    """One cartoon eye: a white disc (s = radius) with a black pupil looking toward `look` (fraction of radius),
    and an angry brow (`brow` = slant in degrees, + lowers the inner end; side from the sign of x)."""
    side = 1 if x >= 0 else -1
    e = lib.cyl(name, s, s * 0.5, mat=white, verts=16, bevel=s * 0.12, rot=(90, 0, 0))
    e.scale = (1, h, 1)
    _xform(e)
    _on(surf, e, x, z, s * 0.1 if sink is None else sink)
    if black is not None:
        pr = s * (0.36 if glow else 0.5)
        p = lib.cyl(name + "_pupil", pr, s * 0.5, mat=black, verts=12, bevel=pr * 0.15, rot=(90, 0, 0))
        _on(surf, p, x + look[0] * s, z + look[1] * s, -s * 0.12)
        hl = lib.cyl(name + "_shine", pr * 0.32, s * 0.5, mat=white, verts=8, rot=(90, 0, 0))
        _on(surf, hl, x + look[0] * s + pr * 0.35 * -side, z + look[1] * s + pr * 0.38, -s * 0.18)
    if brow is not None:
        bw = s * 2.5
        b = lib.box(name + "_brow", (bw, s * 0.7, s * 0.62), mat=brow_mat or black, bevel=s * 0.12, taper=(0.9, 1))
        b.rotation_euler = (0, math.radians(-brow * side), 0)
        _xform(b)
        _on(surf, b, x - side * s * 0.12, z + s * 0.78, -s * 0.15)
    return e


def mouth(lib, name, surf, z, w, h, inside, teeth_mat, top_teeth=5, bottom_teeth=2, frown=0.25, tongue=None, x=0.0):
    """A wide open toothy mouth centred at (x, z) on the surface: w wide, h tall. `frown` raises the middle of the
    top lip (an angry snarl). Pointed teeth hang from the top lip, fangs stand on the bottom lip."""
    hw, hh = w / 2, h / 2
    top = [(-hw, -hh * 0.35), (-hw * 0.6, hh * (0.55 + frown)), (0, hh * (0.75 + frown)), (hw * 0.6, hh * (0.55 + frown)), (hw, -hh * 0.35)]
    bot = [(hw * 0.65, -hh * 0.95), (0, -hh * 1.05), (-hw * 0.65, -hh * 0.95)]
    pts = top + bot
    m = prism_xz(lib, name, pts, h * 0.3, inside, bevel=min(w, h) * 0.04)
    _on(surf, m, x, z, h * 0.08)

    def edge_z(px, line):
        for (x0, z0), (x1, z1) in zip(line, line[1:]):
            if x0 <= px <= x1:
                return z0 + (z1 - z0) * (px - x0) / (x1 - x0)
        return line[0][1]
    tw = w * 0.82 / max(top_teeth, 1)
    for i in range(top_teeth):
        px = -w * 0.41 + tw * (i + 0.5)
        ez = edge_z(px, top) - h * 0.04
        tl = h * (0.42 if abs(px) < w * 0.3 else 0.32)
        t = prism_xz(lib, "%s_t%d" % (name, i), [(-tw * 0.46, 0), (tw * 0.46, 0), (0, -tl)], h * 0.34, teeth_mat)
        _on(surf, t, x + px, z + ez, h * 0.06)
    bline = [(-hw, -hh * 0.35)] + list(reversed(bot)) + [(hw, -hh * 0.35)]
    for i in range(bottom_teeth):
        px = (-0.45 + 0.9 * i / max(bottom_teeth - 1, 1)) * w * 0.7 if bottom_teeth > 1 else 0
        ez = edge_z(px, bline) + h * 0.03
        tl = h * 0.4
        t = prism_xz(lib, "%s_f%d" % (name, i), [(-tw * 0.42, 0), (0, tl), (tw * 0.42, 0)], h * 0.34, teeth_mat)
        _on(surf, t, x + px, z + ez, h * 0.06)
    if tongue is not None:
        tg = lib.cyl(name + "_tongue", w * 0.2, h * 0.2, mat=tongue, verts=10, rot=(90, 0, 0))
        tg.scale = (1.0, 0.45, 1.0)
        _xform(tg)
        _on(surf, tg, x, z - hh * 0.62, h * 0.02)
    return m


def scale_all(f):
    """Scale the whole model about the origin (call at the end of build to fit a target height)."""
    import bpy
    m = Matrix.Scale(f, 4)
    for o in bpy.context.scene.objects:
        o.matrix_basis = m @ o.matrix_basis
