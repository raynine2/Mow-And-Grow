"""Zone 4 ground (Swamp Reeds): boggy mud under the field, two sunken water channels along its edges (see-through
water over a mud bed), dark mossy grass round the sides, and hills beyond."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _groundkit as g  # noqa: E402
import _zonekit as zk  # noqa: E402

PREVIEW = zk.PREVIEW
CHANNELS = [(-46.5, 48, 6, 72), (46.5, 48, 6, 72)]


def build(lib):
    grass = zk.base(lib, (84, 140, 76), (66, 118, 64), holes=CHANNELS)
    mud = lib.material("Mud", g.MUD)
    moss = lib.material("Grass", (92, 128, 70))
    water = lib.material("Glass", (46, 120, 110), transparency=0.35)
    bed = lib.material("Mud", (70, 58, 44))
    # the field's mud is cut around the channels too, so the water shows
    field_holes = [(x, z, w + 0.2, d) for x, z, w, d in CHANNELS]
    g.rect_holes(lib, "bog", 0, 48, 92, 104, field_holes, mud, layer=2)
    for i, (x, z, r) in enumerate([(-20, 20, 5), (14, 64, 6), (30, 12, 4), (-30, 80, 5)]):
        g.blob(lib, "moss%d" % i, x, z, r, moss, seed=40 + i, layer=3)
    for i, (x, z, w, d) in enumerate(CHANNELS):
        g.water(lib, "channel%d" % i, x, z, w, d, water, bed, depth=2.4, layer=2)
    zk.hills(lib, 68, grass, lib.material("Grass", (66, 118, 64)))
