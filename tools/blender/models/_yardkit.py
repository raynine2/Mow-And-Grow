"""Private helpers for the lobby / yard props (shredder, log cabin, booths, signs ...).

build.py skips files that start with "_", so this is never built as a model. Load it from a model with:

    import os, sys; sys.path.insert(0, os.path.dirname(__file__)); import _yardkit as kit
"""
import math
import bmesh
from mathutils import Vector

# reference colours sampled from Chop A Forest screenshots
LOG = (176, 124, 78)          # cabin / fence logs, warm tan-brown
LOG_DARK = (140, 94, 58)
LOG_END = (222, 188, 140)     # cut log ends, light
PLANK = (196, 140, 88)        # sign boards, floors
PLANK_LIGHT = (226, 180, 124)
ROOF = (112, 66, 44)          # shingle / plank roofs, dark reddish brown
ROOF_DARK = (88, 50, 34)
BOARD_DARK = (58, 40, 30)     # price boards, leaderboard face
ORANGE = (240, 116, 28)
HAZ_YELLOW = (250, 206, 30)
HAZ_BLACK = (30, 30, 34)
NEON_CYAN = (40, 230, 255)


def log(lib, name, p0, p1, r, mat, verts=10, bevel=0.0):
    """Round log (cylinder) from point p0 to point p1."""
    a = Vector(p0); b = Vector(p1); d = b - a
    obj = lib.cyl(name, r, d.length, loc=tuple((a + b) / 2), mat=mat, verts=verts, bevel=bevel)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = d.normalized().to_track_quat("Z", "Y")
    return obj


def end_disc(lib, name, centre, normal, r, mat, verts=10):
    """A flat one-sided disc (a cut log end) facing `normal`. Cheap: verts-2 triangles."""
    bm = bmesh.new()
    vs = [bm.verts.new((math.cos(2 * math.pi * i / verts) * r, math.sin(2 * math.pi * i / verts) * r, 0)) for i in range(verts)]
    bm.faces.new(vs)
    obj = lib._finish(lib._from_bmesh(name, bm), mat, centre, (0, 0, 0), 0)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector(normal).normalized().to_track_quat("Z", "Y")
    return obj


def log_ends(lib, name, p0, p1, r, mat, end_mat, verts=10, ends=(True, True)):
    """Log with light cut ends (flat discs just outside each cap)."""
    o = log(lib, name, p0, p1, r, mat, verts)
    a = Vector(p0); b = Vector(p1); d = (b - a).normalized()
    if ends[0]:
        end_disc(lib, name + "_e0", tuple(a - d * 0.02), tuple(-d), r * 0.86, end_mat, verts)
    if ends[1]:
        end_disc(lib, name + "_e1", tuple(b + d * 0.02), tuple(d), r * 0.86, end_mat, verts)
    return o


def prism(lib, name, pts, depth, loc=(0, 0, 0), rot=(0, 0, 0), mat=None, bevel=0.0):
    """Extrude a convex polygon drawn in the XZ plane (list of (x, z)) along Y by `depth` (centred)."""
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
    return lib._finish(lib._from_bmesh(name, bm), mat, loc, rot, bevel)


def _clip(poly, lo, hi, axis):
    """Clip a polygon to lo <= p[axis] <= hi (Sutherland-Hodgman, two planes)."""
    def cut(poly, keep, edge):
        out = []
        for i in range(len(poly)):
            p, q = poly[i], poly[(i + 1) % len(poly)]
            ip, iq = keep(p), keep(q)
            if ip:
                out.append(p)
            if ip != iq:
                t = (edge - p[axis]) / (q[axis] - p[axis])
                out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
        return out
    poly = cut(poly, lambda p: p[axis] >= lo, lo)
    if len(poly) >= 3:
        poly = cut(poly, lambda p: p[axis] <= hi, hi)
    return poly


def hazard(lib, name, w, h, depth, loc, rot, yellow, black, stripe=0.7, slant=None, bevel=0.04, back=True):
    """Black/yellow hazard panel: w along local X, h along local Z, thin along local Y.
    Yellow board with slanted black bars (clipped to the board) standing slightly proud of both faces."""
    if back:
        lib.box(name, (w, depth, h), loc, rot, mat=yellow, bevel=bevel)
    slant = h if slant is None else slant
    objs = []
    x = -w / 2 - slant - stripe
    i = 0
    while x < w / 2 + stripe:
        poly = [(x, -h / 2), (x + stripe, -h / 2), (x + stripe + slant, h / 2), (x + slant, h / 2)]
        poly = _clip(poly, -w / 2 + 0.02, w / 2 - 0.02, 0)
        if len(poly) >= 3:
            # drop near-duplicate points from clipping
            clean = []
            for p in poly:
                if not clean or abs(p[0] - clean[-1][0]) + abs(p[1] - clean[-1][1]) > 1e-4:
                    clean.append(p)
            if len(clean) >= 3 and abs(clean[0][0] - clean[-1][0]) + abs(clean[0][1] - clean[-1][1]) < 1e-4:
                clean.pop()
            if len(clean) >= 3:
                o = prism(lib, "%s_s%d" % (name, i), clean, depth + 0.06, mat=black)
                objs.append(o)
        x += stripe * 2
        i += 1
    # place the stripes in the panel's frame
    from mathutils import Euler, Matrix
    m = Matrix.Translation(loc) @ Euler([math.radians(r) for r in rot], "XYZ").to_matrix().to_4x4()
    for o in objs:
        o.matrix_basis = m @ o.matrix_basis
    return objs


def plank_board(lib, name, w, h, t, loc, rot, mat, mat_alt=None, rows=3, bevel=0.06, gap=0.08):
    """Sign board made of `rows` horizontal planks (w along local X, h along local Z, t thick along local Y)."""
    from mathutils import Euler, Matrix
    m = Matrix.Translation(loc) @ Euler([math.radians(r) for r in rot], "XYZ").to_matrix().to_4x4()
    ph = (h - gap * (rows - 1)) / rows
    for i in range(rows):
        z = -h / 2 + ph / 2 + i * (ph + gap)
        o = lib.box("%s_p%d" % (name, i), (w, t * (1 if i % 2 else 0.92), ph), (0, 0, z),
                    mat=(mat_alt if (mat_alt and i % 2) else mat), bevel=bevel)
        o.matrix_basis = m @ o.matrix_basis
    # a slab behind so gaps read dark but are not see-through
    o = lib.box(name + "_back", (w - 0.1, t * 0.6, h - 0.1), (0, -t * 0.15, 0), mat=mat, bevel=0)
    o.matrix_basis = m @ o.matrix_basis


def place(obj, loc, rot):
    """Move an object built around the origin into a parent frame (loc, rot in degrees)."""
    from mathutils import Euler, Matrix
    m = Matrix.Translation(loc) @ Euler([math.radians(r) for r in rot], "XYZ").to_matrix().to_4x4()
    obj.matrix_basis = m @ obj.matrix_basis
    return obj
