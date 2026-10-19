"""Cut Wheat, low-part version: five short golden stalk stubs with pale cut tops round a little straw pile. 11 parts."""
import math


def build(lib):
    stalk = lib.material("Grass", (214, 172, 70))
    cut = lib.material("Grass", (246, 226, 160))
    straw = lib.material("Grass", (226, 186, 90))
    lib.box("pile", (1.2, 1.0, 0.25), (0, 0, 0.125), rot=(0, 0, 25), mat=straw)
    for i in range(5):
        a = math.radians(i * 72 + 10)
        x, y = math.sin(a) * 0.45, math.cos(a) * 0.45
        lib.box("stub%d" % i, (0.24, 0.24, 0.8), (x, y, 0.4), mat=stalk)
        lib.box("cut%d" % i, (0.26, 0.26, 0.06), (x, y, 0.83), mat=cut)
