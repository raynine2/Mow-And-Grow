"""Reeds clump, low-part version (~7.5 tall): a low mud mound with five long reed blades bending out at their pale
tips and two cattails (a straight stem with a fat brown velvet head and a thin spike). 18 parts."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _tuftkit as kit  # noqa: E402


def build(lib):
    lib.box("mound", (1.9, 1.9, 0.5), (0, 0, 0.25), rot=(0, 0, 15), mat=lib.material("Mud", (96, 80, 60)))
    blades = [(0, 6, 5.6, 0.45), (72, 14, 5.0, 0.45), (144, 10, 5.4, 0.45), (216, 16, 4.8, 0.45), (288, 12, 5.2, 0.45)]
    mats = [lib.material("Grass", (84, 140, 76)), lib.material("Grass", (70, 122, 66))]
    tip = lib.material("Grass", (176, 196, 120))
    for i, (ang, lean, ln, w) in enumerate(blades):
        kit.blade(lib, "reed%d" % i, ang, lean, ln, w, mats[i % 2], tip, base_r=0.25, thick=0.26)
    stem = lib.material("Grass", (96, 140, 70))
    head = lib.material("Fabric", (112, 72, 44))
    for i, (x, y, h) in enumerate([(0.5, 0.3, 6.0), (-0.45, -0.35, 5.4)]):
        lib.box("stem%d" % i, (0.16, 0.16, h), (x, y, h / 2), mat=stem)
        lib.cyl("head%d" % i, 0.32, 1.3, (x, y, h - 0.5), mat=head, verts=10)
