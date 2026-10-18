"""Decoration boulder: a chunky low-poly grey Slate rock (~5 wide, ~2.6 tall) with flat-shaded facets, sitting on a
flattened base, plus a smaller rock and a pebble leaning against it."""
import random
import bmesh

PREVIEW = dict(dist=11, height=6, target_z=1.2)

def lump(lib, name, scale, loc, mat, seed, rot_z=0):
    """A jittered icosphere squashed to `scale` (full extents), flattened on the bottom so it sits on z = 0."""
    rnd = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.5)
    for v in bm.verts:
        j = rnd.uniform(0.86, 1.1)
        v.co.x *= scale[0] * j; v.co.y *= scale[1] * j; v.co.z *= scale[2] * rnd.uniform(0.9, 1.08)
        if v.co.z < -scale[2] * 0.2:
            v.co.z = -scale[2] * 0.2
        v.co.z += scale[2] * 0.2
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.01)
    obj = lib._from_bmesh(name, bm)
    for p in obj.data.polygons:
        p.use_smooth = False
    return lib._finish(obj, mat, loc, (0, 0, rot_z), 0)

def build(lib):
    grey = lib.material("Slate", (124, 126, 130))
    grey_dk = lib.material("Slate", (98, 100, 106))
    lump(lib, "boulder", (5.0, 3.8, 3.1), (0, 0, 0), grey, 4, 15)
    lump(lib, "side", (2.4, 2.0, 1.7), (2.2, 1.0, 0), grey_dk, 8, 40)
    lump(lib, "pebble", (1.2, 1.0, 0.8), (-2.2, 1.4, 0), grey_dk, 12, 70)
