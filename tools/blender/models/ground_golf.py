"""Zone 2 ground (Golf Course): a pale fairway over the field with a round putting green, a sand bunker by the flag
on the right edge, rough grass round the sides, and hills beyond."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _groundkit as g  # noqa: E402
import _zonekit as zk  # noqa: E402

PREVIEW = zk.PREVIEW


def build(lib):
    grass = zk.base(lib, (92, 164, 56), (78, 146, 48))
    fairway = lib.material("Grass", (132, 204, 84))
    green = lib.material("Grass", (150, 220, 96))
    sand = lib.material("Sand", g.SAND)
    g.patch(lib, "fairway", 0, 48, 96, 106, fairway, seed=21, layer=2, wobble=4)
    g.blob(lib, "green", 34, 28, 9, green, seed=22, layer=3, wobble=0.12)
    g.patch(lib, "bunker", 44.5, 55, 9, 18, sand, seed=9, layer=4, wobble=1.4)
    g.blob(lib, "bunker2", -38, 78, 5, sand, seed=23, layer=4, wobble=0.3)
    zk.hills(lib, 34, grass, lib.material("Grass", (78, 146, 48)))
