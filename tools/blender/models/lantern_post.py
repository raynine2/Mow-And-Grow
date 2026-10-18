"""Lantern post for the lobby paths: a square wooden post ~6 tall with a small arm reaching to the front (+Y) and a
lantern hanging from it: dark metal cage (plates, corner bars, little roof, hanging ring) around a yellow Neon glow."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _yardkit as kit  # noqa: E402

PREVIEW = dict(dist=11, height=5, target_z=3.3, yaw=50)


def build(lib):
    wood = lib.material("Wood", (150, 98, 58))
    metal = lib.material("Metal", (42, 42, 46))
    glow = lib.material("Neon", (255, 210, 70))
    lib.box("base", (1.3, 1.3, 0.5), (0, 0, 0.25), mat=wood, bevel=0.1)
    lib.box("post", (0.7, 0.7, 6.0), (0, 0, 3.0), mat=wood, bevel=0.1)
    lib.box("cap", (0.95, 0.95, 0.3), (0, 0, 6.1), mat=wood, bevel=0.08)
    # arm + brace toward the front
    lib.box("arm", (0.4, 2.0, 0.4), (0, 1.2, 5.6), mat=wood, bevel=0.06)
    lib.box("brace", (0.3, 1.3, 0.3), (0, 0.75, 5.0), rot=(45, 0, 0), mat=wood, bevel=0.04)
    # lantern hanging from the end of the arm
    lx, ly, top = 0, 1.85, 5.2
    lib.box("hook", (0.1, 0.1, 0.5), (lx, ly, top + 0.15), mat=metal)
    lib.cyl("ring", 0.22, 0.12, (lx, ly, top + 0.05), rot=(90, 0, 0), mat=metal, verts=8)
    lib.box("roof", (1.25, 1.25, 0.35), (lx, ly, top - 0.25), mat=metal, bevel=0.05, taper=(0.45, 0.45))
    lib.box("top_plate", (1.05, 1.05, 0.15), (lx, ly, top - 0.48), mat=metal, bevel=0.03)
    lib.box("glow", (0.75, 0.75, 1.0), (lx, ly, top - 1.08), mat=glow)
    for sx in (-1, 1):
        for sy in (-1, 1):
            lib.box("bar%d%d" % (sx, sy), (0.14, 0.14, 1.1), (lx + sx * 0.44, ly + sy * 0.44, top - 1.08), mat=metal)
    lib.box("bot_plate", (1.0, 1.0, 0.18), (lx, ly, top - 1.68), mat=metal, bevel=0.03)
    lib.box("bot_knob", (0.35, 0.35, 0.2), (lx, ly, top - 1.86), mat=metal)
