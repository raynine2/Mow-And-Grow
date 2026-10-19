"""Zone 3 ground (Wheat Farm): golden ploughed soil under the field with darker furrow rows, a dry grass edge, and
hills beyond."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _groundkit as g  # noqa: E402
import _zonekit as zk  # noqa: E402

PREVIEW = zk.PREVIEW


def build(lib):
    grass = zk.base(lib, (124, 170, 64), (100, 150, 54))
    soil = lib.material("Ground", (176, 132, 78))
    furrow = lib.material("Ground", (150, 108, 62))
    g.patch(lib, "field", 0, 48, 98, 108, soil, seed=31, layer=2, wobble=3)
    for i in range(12):
        g.rect(lib, "furrow%d" % i, -44 + i * 8, 48, 1.6, 90, furrow, layer=3)
    g.path(lib, "track", (-50, -6), (-50, 104), 6, lib.material("Ground", g.DIRT), seed=33, layer=3)
    zk.hills(lib, 51, grass, lib.material("Grass", (100, 150, 54)))
