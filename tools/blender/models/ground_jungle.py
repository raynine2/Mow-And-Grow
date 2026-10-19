"""Zone 5 ground (Mega Jungle): a leafy jungle floor under the field with muddy hollows, a deep green forest floor
round the sides, and hills beyond."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _groundkit as g  # noqa: E402
import _zonekit as zk  # noqa: E402

PREVIEW = zk.PREVIEW


def build(lib):
    grass = zk.base(lib, (64, 138, 52), (46, 110, 40))
    leafy = lib.material("LeafyGrass", g.LEAFY)
    mud = lib.material("Mud", (84, 70, 50))
    g.patch(lib, "floor", 0, 48, 98, 108, leafy, seed=51, layer=2, wobble=4)
    for i, (x, z, r) in enumerate([(-30, 30, 6), (22, 70, 7), (36, 16, 4.5), (-12, 90, 5)]):
        g.blob(lib, "hollow%d" % i, x, z, r, mud, seed=55 + i, layer=3)
    zk.hills(lib, 85, grass, lib.material("Grass", (46, 110, 40)))
