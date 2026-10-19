"""Private helpers for the ground models (ground_*.py): flat layered sheets with world-space UVs.

The ground is a stack of thin sheets: a base sheet at z = 0, then patches (dirt, mud, sand ...) a little above it,
so a patch's ragged edge shows over the grass without z-fighting. Players walk on an invisible flat collider the
game adds at y = 0 (see server/GroundMesh.luau), so the sheets never need collisions.

Coordinates here are Roblox studs: (x, z) on the ground, with z pointing the Roblox way. Blender's y is -z.
"""
import math
import random
import bmesh

LAYER = 0.06  # height step between stacked sheets

GRASS = (98, 172, 58)
GRASS_DARK = (84, 156, 50)
LEAFY = (72, 142, 48)
DIRT = (150, 112, 72)
MUD = (96, 80, 60)
SAND = (214, 186, 128)


def _sheet(lib, name, pts, z, mat, tile=8.0):
    """A flat polygon (list of (x, rz) Roblox points, any order around the outline) at height z."""
    bm = bmesh.new()
    vs = [bm.verts.new((x, -rz, z)) for x, rz in pts]
    face = bm.faces.new(vs)
    face.normal_update()
    if face.normal.z < 0:
        face.normal_flip()
    bmesh.ops.triangulate(bm, faces=[face])
    obj = lib._finish(lib._from_bmesh(name, bm), mat, (0, 0, 0), (0, 0, 0), 0)
    lib.planar_uv(obj, tile)
    return obj


def rect(lib, name, cx, cz, w, d, mat, layer=0, tile=8.0):
    """A plain rectangle, w (x) by d (z), centred on (cx, cz)."""
    pts = [(cx - w / 2, cz - d / 2), (cx + w / 2, cz - d / 2), (cx + w / 2, cz + d / 2), (cx - w / 2, cz + d / 2)]
    return _sheet(lib, name, pts, layer * LAYER, mat, tile)


def rect_minus(cx, cz, w, d, holes):
    """Split a rectangle into smaller rectangles that leave out axis-aligned `holes` (each (cx, cz, w, d)).
    Returns a list of (cx, cz, w, d). Only handles holes that don't overlap each other."""
    out = [(cx - w / 2, cz - d / 2, cx + w / 2, cz + d / 2)]
    for hx, hz, hw, hd in holes:
        h0x, h0z, h1x, h1z = hx - hw / 2, hz - hd / 2, hx + hw / 2, hz + hd / 2
        nxt = []
        for x0, z0, x1, z1 in out:
            if h1x <= x0 or h0x >= x1 or h1z <= z0 or h0z >= z1:
                nxt.append((x0, z0, x1, z1))
                continue
            if h0z > z0:
                nxt.append((x0, z0, x1, h0z))
            if h1z < z1:
                nxt.append((x0, h1z, x1, z1))
            mz0, mz1 = max(z0, h0z), min(z1, h1z)
            if h0x > x0:
                nxt.append((x0, mz0, h0x, mz1))
            if h1x < x1:
                nxt.append((h1x, mz0, x1, mz1))
        out = nxt
    return [((a + c) / 2, (b + e) / 2, c - a, e - b) for a, b, c, e in out]


def rect_holes(lib, name, cx, cz, w, d, holes, mat, layer=0, tile=8.0):
    for i, (x, z, rw, rd) in enumerate(rect_minus(cx, cz, w, d, holes)):
        rect(lib, "%s%d" % (name, i), x, z, rw, rd, mat, layer, tile)


def patch(lib, name, cx, cz, w, d, mat, seed=1, layer=1, step=3.5, wobble=3.2, tile=8.0):
    """A rounded patch with a ragged natural edge (like a worn dirt clearing), w by d around (cx, cz)."""
    rnd = random.Random(seed)
    pts = []
    perim = 2 * (w + d)
    n = max(16, int(perim / step))
    corner = min(w, d) * 0.22
    for i in range(n):
        t = i / n * 2 * math.pi
        # a superellipse gives a rounded-rectangle outline
        c, s = math.cos(t), math.sin(t)
        ex = math.copysign(abs(c) ** 0.35, c)
        ez = math.copysign(abs(s) ** 0.35, s)
        rx = w / 2 - corner * 0.2
        rz = d / 2 - corner * 0.2
        jitter = rnd.uniform(-wobble, wobble * 0.6) + math.sin(t * 5 + seed) * wobble * 0.35
        x = cx + ex * (rx + jitter)
        z = cz + ez * (rz + jitter)
        pts.append((x, z))
    return _sheet(lib, name, pts, layer * LAYER, mat, tile)


def blob(lib, name, cx, cz, r, mat, seed=1, layer=1, n=22, wobble=0.28, tile=8.0):
    """A lumpy round patch of radius ~r."""
    rnd = random.Random(seed)
    pts = []
    for i in range(n):
        t = i / n * 2 * math.pi
        rr = r * (1 + rnd.uniform(-wobble, wobble) * 0.6 + math.sin(t * 3 + seed) * wobble * 0.4)
        pts.append((cx + math.cos(t) * rr, cz + math.sin(t) * rr))
    return _sheet(lib, name, pts, layer * LAYER, mat, tile)


def path(lib, name, a, b, width, mat, seed=2, layer=2, tile=8.0):
    """A worn path from a=(x, z) to b=(x, z) with wobbly edges and round-ish ends."""
    rnd = random.Random(seed)
    ax, az = a; bx, bz = b
    dx, dz = bx - ax, bz - az
    ln = math.hypot(dx, dz)
    ux, uz = dx / ln, dz / ln
    nx, nz = -uz, ux
    n = max(3, int(ln / 4))
    left, right = [], []
    for i in range(n + 1):
        t = i / n
        px, pz = ax + dx * t, az + dz * t
        hw = width / 2 * rnd.uniform(0.85, 1.12)
        left.append((px + nx * hw, pz + nz * hw))
        right.append((px - nx * hw * rnd.uniform(0.9, 1.1), pz - nz * hw))
    # rounded caps
    cap_b = [(bx + ux * width * 0.35 + nx * width * 0.2, bz + uz * width * 0.35 + nz * width * 0.2),
             (bx + ux * width * 0.35 - nx * width * 0.2, bz + uz * width * 0.35 - nz * width * 0.2)]
    cap_a = [(ax - ux * width * 0.35 - nx * width * 0.2, az - uz * width * 0.35 - nz * width * 0.2),
             (ax - ux * width * 0.35 + nx * width * 0.2, az - uz * width * 0.35 + nz * width * 0.2)]
    pts = left + cap_b + list(reversed(right)) + cap_a
    return _sheet(lib, name, pts, layer * LAYER, mat, tile)


def stripes(lib, name, x0, x1, z0, z1, width, mat_a, mat_b, layer=1, tile=8.0):
    """Mown-lawn stripes running along z, alternating two shades."""
    x = x0
    i = 0
    while x < x1 - 0.01:
        w = min(width, x1 - x)
        rect(lib, "%s%d" % (name, i), x + w / 2, (z0 + z1) / 2, w, z1 - z0, mat_a if i % 2 == 0 else mat_b, layer, tile)
        x += width
        i += 1


def hill(lib, name, x, z, radius, height, mat, seg=18, rings=5, sink=0.6):
    """A low dome (spherical cap) `height` high and `radius` across at the ground, sunk a little into it."""
    r = (radius * radius + height * height) / (2 * height)
    cz = height - r
    bm = bmesh.new()
    top = bm.verts.new((x, -z, height - sink))
    ring_verts = []
    for j in range(1, rings + 1):
        rr = radius * j / rings
        hz = cz + math.sqrt(max(r * r - rr * rr, 0)) - sink
        ring_verts.append([bm.verts.new((x + math.cos(2 * math.pi * i / seg) * rr, -z + math.sin(2 * math.pi * i / seg) * rr, hz)) for i in range(seg)])
    for i in range(seg):
        bm.faces.new((top, ring_verts[0][i], ring_verts[0][(i + 1) % seg]))
    for j in range(rings - 1):
        a, b = ring_verts[j], ring_verts[j + 1]
        for i in range(seg):
            bm.faces.new((a[i], b[i], b[(i + 1) % seg], a[(i + 1) % seg]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = lib._finish(lib._from_bmesh(name, bm), mat, (0, 0, 0), (0, 0, 0), 0)
    lib.planar_uv(obj, 8.0)
    return obj


def water(lib, name, cx, cz, w, d, water_mat, bed_mat, depth=2.4, layer=0):
    """A sunken channel: a mud bed `depth` below the ground with sloped banks, and a see-through water sheet just
    under ground level. Leave a hole for it in the sheets above (rect_holes)."""
    bed = rect(lib, name + "_bed", cx, cz, w, d, bed_mat, 0)
    bed.location.z = -depth
    # banks: four sloped strips from the ground edge down to the bed
    bm = bmesh.new()
    x0, x1, z0, z1 = cx - w / 2, cx + w / 2, cz - d / 2, cz + d / 2
    inset = 0.9
    top = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]
    bot = [(x0 + inset, z0 + inset), (x1 - inset, z0 + inset), (x1 - inset, z1 - inset), (x0 + inset, z1 - inset)]
    tv = [bm.verts.new((x, -z, layer * LAYER)) for x, z in top]
    bv = [bm.verts.new((x, -z, -depth)) for x, z in bot]
    for i in range(4):
        bm.faces.new((tv[i], tv[(i + 1) % 4], bv[(i + 1) % 4], bv[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        if f.normal.z < 0:
            f.normal_flip()
    banks = lib._finish(lib._from_bmesh(name + "_banks", bm), bed_mat, (0, 0, 0), (0, 0, 0), 0)
    lib.planar_uv(banks, 8.0)
    surf = rect(lib, name + "_water", cx, cz, w - 0.4, d - 0.4, water_mat, 0)
    surf.location.z = -0.35
    return surf
