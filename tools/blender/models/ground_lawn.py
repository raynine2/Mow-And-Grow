"""Zone 1 ground (Backyard Lawn): a back garden lawn with mown stripes across the field, a darker forest floor on
both sides, and hills beyond. Placed at Config.zoneStartZ(1); see _zonekit for the layout."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _groundkit as g  # noqa: E402
import _zonekit as zk  # noqa: E402

PREVIEW = zk.PREVIEW


def build(lib):
    grass = zk.base(lib, g.GRASS, g.GRASS_DARK)
    light = lib.material("Grass", (116, 190, 66))
    mid = lib.material("Grass", (100, 176, 58))
    g.stripes(lib, "stripe", -48, 48, -4, 100, 8, light, mid, layer=2)
    g.patch(lib, "edge", 0, 48, 104, 112, lib.material("Grass", (90, 162, 54)), seed=11, layer=1, wobble=2.5)
    zk.hills(lib, 17, grass, lib.material("Grass", g.GRASS_DARK))
