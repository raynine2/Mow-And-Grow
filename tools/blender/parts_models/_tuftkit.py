"""Shared builder for the low-part grass clumps (parts_models/tuft_*.py), made only from boxes and wedges so each
clump is a handful of native Roblox parts (a run grows ~600 of them).

A clump is a crown block on the ground and a few blades: each blade is a thin slab leaning out from the centre with a
wedge tip, so the silhouette still reads as pointed grass. Blades use the Grass material (the game recolours Grass
parts when a patch turns out to be a mutation). The cut version keeps the crown and a ring of short stubs with pale
cut tops."""
import math


def blade(lib, name, angle, lean, length, width, mat, tip_mat, base_r=0.35, thick=0.32):
    """A blade rising from the crown at compass `angle` (deg), leaning out by `lean` (deg from upright)."""
    a = math.radians(angle)
    lr = math.radians(lean)
    # centre of the slab, halfway up its length, pushed out along its lean
    cx = math.sin(a) * (base_r + math.sin(lr) * length / 2)
    cy = math.cos(a) * (base_r + math.sin(lr) * length / 2)
    cz = math.cos(lr) * length / 2
    lib.box(name, (width, thick, length), (cx, cy, cz), rot=(-lean, 0, -angle), mat=mat)
    # wedge tip on top of the slab, same lean
    tx = math.sin(a) * (base_r + math.sin(lr) * (length + 0.35))
    ty = math.cos(a) * (base_r + math.sin(lr) * (length + 0.35))
    tz = math.cos(lr) * (length + 0.35)
    lib.wedge(name + "_tip", (width * 0.9, thick, 0.8), (tx, ty, tz), rot=(-lean, 0, -angle), mat=tip_mat)


def clump(lib, blades, crown_rgb, blade_rgbs, tip_rgb, crown=(1.3, 1.3, 0.5)):
    """blades: list of (angle, lean, length, width)."""
    lib.box("crown", crown, (0, 0, crown[2] / 2), rot=(0, 0, 20), mat=lib.material("Grass", crown_rgb))
    mats = [lib.material("Grass", c) for c in blade_rgbs]
    tip = lib.material("Grass", tip_rgb)
    for i, (ang, lean, ln, w) in enumerate(blades):
        blade(lib, "blade%d" % i, ang, lean, ln, w, mats[i % len(mats)], tip)


def stubble(lib, n, radius, crown_rgb, stub_rgb, cut_rgb, height=0.7, crown=(1.3, 1.3, 0.4)):
    """The cut clump: the crown plus `n` short stubs in a ring, each with a pale fresh-cut top."""
    lib.box("crown", crown, (0, 0, crown[2] / 2), rot=(0, 0, 20), mat=lib.material("Grass", crown_rgb))
    stub = lib.material("Grass", stub_rgb)
    cut = lib.material("Grass", cut_rgb)
    for i in range(n):
        a = math.radians(i * 360 / n + 15)
        x, y = math.sin(a) * radius, math.cos(a) * radius
        h = height * (0.75 + 0.25 * ((i * 7) % 3) / 2)
        lib.box("stub%d" % i, (0.5, 0.36, h), (x, y, h / 2), rot=(0, 0, -i * 360 / n), mat=stub)
        lib.box("cut%d" % i, (0.52, 0.38, 0.08), (x, y, h + 0.04), rot=(0, 0, -i * 360 / n), mat=cut)
