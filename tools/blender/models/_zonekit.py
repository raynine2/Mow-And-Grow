"""Shared builder for the five zone grounds (ground_lawn ... ground_jungle).

A zone's ground model is placed at (0, 0, Config.zoneStartZ(z)). In model studs: the field (where the grass clumps
grow) is x -48..48, z 0..96; the tile runs from z = -10 (just before the zone's gate) to z = 110 (the next gate),
and 350 studs to each side so the side forests and the mountains stand on ground."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _groundkit as g  # noqa: E402

PREVIEW = dict(dist=150, height=95, target_z=0, yaw=200, ground=False)
Z0, Z1 = -10, 110
FIELD = (0, 48, 96, 106)  # cx, cz, w, d of the field patch


def base(lib, grass_rgb, floor_rgb, holes=()):
    """Grass tile with a darker forest floor on both sides; `holes` are cut out of every sheet (water channels)."""
    grass = lib.material("Grass", grass_rgb)
    floor = lib.material("Grass", floor_rgb)
    zc, d = (Z0 + Z1) / 2, Z1 - Z0
    g.rect_holes(lib, "base", 0, zc, 700, d, holes, grass, 0)
    for side in (-1, 1):
        g.rect(lib, "floor%d" % side, side * 205, zc, 290, d, floor, 1)
    return grass


def hills(lib, seed, mat_a, mat_b):
    import random
    rnd = random.Random(seed)
    for side in (-1, 1):
        g.hill(lib, "hill%d" % side, side * rnd.uniform(175, 210), rnd.uniform(10, 100), rnd.uniform(50, 75), rnd.uniform(14, 26),
               mat_a if side < 0 else mat_b)
