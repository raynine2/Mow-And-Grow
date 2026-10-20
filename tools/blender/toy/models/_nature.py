"""Shared pieces for the toy nature models: bark grooves, lumpy two-tone canopies, cut-wood rings."""
import math
import random

from mathutils import Vector


def bark(freq=8, wave=0.5, axis="z", centre=(0.0, 0.0, 0.0)):
    """Wavy grooves running along the axis (> 0 inside a groove), for a region_mat layer."""
    cx, cy, cz = centre

    def f(c):
        if axis == "z":
            a, t = math.atan2(c.y - cy, c.x - cx), c.z
        else:  # along x (a lying log)
            a, t = math.atan2(c.z - cz, c.y - cy), c.x
        return 0.2 - abs(math.sin(a * freq + t * 1.3 + wave * math.sin(t * 4.0)))
    return f


def rings(centre, axis="z", spacing=0.07):
    """Growth rings on a cut face (> 0 on a ring line)."""
    cx, cy, cz = centre

    def f(c):
        if axis == "z":
            r = math.hypot(c.x - cx, c.y - cy)
        else:
            r = math.hypot(c.y - cy, c.z - cz)
        r += 0.015 * math.sin(math.atan2(c.y - cy, c.x - cx) * 5)
        return 0.012 - abs((r % spacing) - spacing / 2)
    return f


def trunk(k, name, coll, segments, roots, colour, groove, freq=8, res=0.035):
    """A trunk (and branches) of fused capsules, flared root capsules, cut flat at the ground, bark grooves."""
    els = [k.capsule(a, b, r) for a, b, r in segments + roots]
    obj = k.blob(name, coll, els, resolution=res)
    k.trim(obj, (0, 0, 0), (0, 0, -1), cap=True)
    k.sdf_attr(obj, "bark", bark(freq))
    k.set_mats(obj, k.region_mat(f"{name}Mat", colour, [("bark", groove, 0.95)], rough=0.85, coat=0.0,
                                 bump="fabric", bump_scale=14, bump_strength=0.25))
    return obj


def canopy(k, name, coll, lumps, base, lit, shade, leaves=None, seed=1, res=0.04, squash=0.85):
    """A lumpy leaf canopy: fused balls, sun-lit lighter on top, darker underneath with a wavy edge. Optional
    leaves=(count, length, width) pokes leaf tips out round the lower half for a leafy silhouette."""
    els = [dict(co=tuple(c), size=(r, r, r * squash)) for c, r in lumps]
    obj = k.blob(name, coll, els, resolution=res)
    zs = [Vector(c).z for c, _ in lumps]
    lo, hi = min(zs), max(zs)
    top = lo + (hi - lo) * 0.55 + 0.15
    bot = lo - 0.1
    k.sdf_attr(obj, "lit", lambda c: c.z - (top + 0.14 * math.sin(c.x * 4.3 + c.y * 3.1)))
    k.sdf_attr(obj, "shade", lambda c: (bot + 0.12 * math.sin(c.x * 3.7 - c.y * 4.6)) - c.z)
    k.set_mats(obj, k.region_mat(f"{name}Mat", base, [("lit", lit, 0.6), ("shade", shade, 0.75)], rough=0.7,
                                 coat=0.05, bump="fabric", bump_scale=9, bump_strength=0.35))
    if leaves:
        n, ln, wd = leaves
        rnd = random.Random(seed)
        m = k.mat(f"{name}Leaf", base, rough=0.65)
        for i in range(n):
            c, r = lumps[rnd.randrange(len(lumps))]
            c = Vector(c)
            a = rnd.uniform(0, 2 * math.pi)
            d = Vector((math.cos(a), math.sin(a), rnd.uniform(-0.5, 0.3))).normalized()
            k.leaf(f"{name}L{i}", coll, c + d * r * 0.7, d + Vector((0, 0, -0.2)), ln, wd, m, curl=0.25,
                   fold=0.1)
    return obj
