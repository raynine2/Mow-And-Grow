"""A huge plain grass sheet just under every map, so the ground reaches the horizon behind the mountains."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _groundkit as g  # noqa: E402

PREVIEW = dict(dist=1400, height=600, target_z=0, ground=False)


def build(lib):
    sheet = g.rect(lib, "far", 0, 0, 2000, 2000, lib.material("Grass", (90, 160, 54)), 0, tile=16)
    sheet.location.z = -0.4
