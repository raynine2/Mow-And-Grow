"""Decoration boulder (~5 wide, ~2.8 tall) in the chunky bevelled-block style of the rest of the game: a big
tapered Slate block leaning a little, a second block stacked off-centre on top, a smaller rock and a pebble at its
side, in two greys."""
import random

PREVIEW = dict(dist=11, height=6, target_z=1.2)

def build(lib):
    rnd = random.Random(4)
    grey = lib.material("Slate", (128, 130, 134))
    grey_dk = lib.material("Slate", (102, 104, 110))
    lib.box("base", (4.4, 3.4, 2.0), (0, 0, 0.85), rot=(4, -3, 18), mat=grey, bevel=0.35, taper=(0.78, 0.8))
    lib.box("top", (2.8, 2.4, 1.3), (-0.35, 0.15, 2.05), rot=(-7, 6, 40), mat=grey, bevel=0.3, taper=(0.7, 0.72))
    lib.box("side", (1.9, 1.7, 1.3), (2.05, 1.05, 0.55), rot=(6, 9, -20), mat=grey_dk, bevel=0.25, taper=(0.72, 0.75))
    lib.box("pebble", (0.9, 0.8, 0.6), (-2.25, 1.45, 0.25), rot=(0, -8, 30), mat=grey_dk, bevel=0.15, taper=(0.75, 0.75))
    lib.box("chip", (0.6, 0.55, 0.4), (1.0, -1.95, 0.15), rot=(5, 0, 12), mat=grey, bevel=0.1, taper=(0.75, 0.75))
