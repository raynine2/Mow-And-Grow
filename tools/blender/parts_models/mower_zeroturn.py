"""Golden Zero-Turn, low-part version (~6.6 wide x 9.3 long x 5 tall): a low shiny gold zero-turn. Big lugged rear
tyres under gold fenders, little front caster wheels, a diamond-plate footboard with a gold nose and two headlights,
a black high-back seat between gold side pods with two chrome lap-bar levers, a black engine with a gold cover and
twin chrome exhausts at the back, and a wide gold deck out front with a hazard-striped lip. Front +Y, wheels on
z = 0, seat cushion top at z = 3 around (0, -1)."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _mowerkit as kit  # noqa: E402


def build(lib):
    gold = lib.material("SmoothPlastic", (250, 196, 50))
    gold_d = lib.material("SmoothPlastic", (214, 158, 32))
    tyre = lib.material("SmoothPlastic", (34, 34, 38))
    chrome = lib.material("Metal", (200, 205, 215))
    plate = lib.material("DiamondPlate", (90, 90, 98))
    black = lib.material("SmoothPlastic", (40, 40, 46))
    light = lib.material("Neon", (255, 240, 190))
    for sx in (-1, 1):
        kit.wheel(lib, "rear%d" % sx, sx * 2.75, -2.6, 1.5, 1.2, tyre, gold)
        lib.box("fender%d" % sx, (1.5, 3.2, 0.35), (sx * 2.75, -2.6, 3.15), mat=gold)
        kit.wheel(lib, "caster%d" % sx, sx * 2.3, 2.6, 0.55, 0.5, tyre, chrome, hub_r=0.3)
        lib.box("fork%d" % sx, (0.25, 0.25, 1.0), (sx * 2.3, 2.6, 1.3), mat=chrome)
        lib.box("pod%d" % sx, (1.0, 3.0, 1.2), (sx * 1.65, -0.8, 2.3), mat=gold)
        lib.box("lever%d" % sx, (0.18, 0.18, 1.6), (sx * 1.2, 0.2, 3.5), rot=(-25, 0, 0), mat=chrome)
        lib.box("grip%d" % sx, (0.9, 0.22, 0.22), (sx * 0.85, 0.55, 4.2), mat=black)
        lib.box("lamp%d" % sx, (0.5, 0.15, 0.35), (sx * 0.8, 3.35, 1.7), mat=light)
        lib.cyl("exhaust%d" % sx, 0.18, 1.6, (sx * 0.7, -4.2, 3.3), mat=chrome, verts=8)
    lib.box("frame", (3.4, 7.8, 0.7), (0, -0.4, 1.4), mat=gold_d)
    lib.box("footboard", (3.0, 2.4, 0.2), (0, 1.8, 1.85), mat=plate)
    lib.box("nose", (3.0, 1.0, 0.9), (0, 3.0, 1.55), mat=gold)
    lib.box("engine", (2.6, 2.0, 1.4), (0, -3.6, 2.5), mat=black)
    lib.box("engine_cover", (2.8, 2.2, 0.35), (0, -3.6, 3.35), mat=gold)
    kit.seat(lib, black, black)
    kit.deck(lib, 6.6, 2.6, 1.2, 0.85, gold, lib.material("SmoothPlastic", (250, 206, 30)), black)
