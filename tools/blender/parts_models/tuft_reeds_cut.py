"""Cut Reeds, low-part version: the mud mound with four short reed stubs with pale cut tops. 9 parts."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _tuftkit as kit  # noqa: E402


def build(lib):
    lib.box("crown", (1.9, 1.9, 0.5), (0, 0, 0.25), rot=(0, 0, 15), mat=lib.material("Mud", (96, 80, 60)))
    stub = lib.material("Grass", (84, 140, 76))
    cut = lib.material("Grass", (200, 216, 160))
    import math
    for i in range(4):
        a = math.radians(i * 90 + 20)
        x, y = math.sin(a) * 0.5, math.cos(a) * 0.5
        lib.box("stub%d" % i, (0.4, 0.3, 1.0), (x, y, 0.5 + 0.25), mat=stub)
        lib.box("cut%d" % i, (0.42, 0.32, 0.08), (x, y, 1.29), mat=cut)
