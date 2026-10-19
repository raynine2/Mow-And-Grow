"""Lobby ground: a wide grass meadow, a worn dirt clearing (the fenced lobby, 132 studs across) with trodden mud in
front of the party booths, a few grass islands left in the dirt, dirt paths to the buildings, and a ring of rolling
hills out past the forest. Same layout the Terrain version used (server/LobbyBuilder.luau), in Roblox studs."""
import math, os, random, sys
sys.path.insert(0, os.path.dirname(__file__))
import _groundkit as g  # noqa: E402

PREVIEW = dict(dist=260, height=150, target_z=0, yaw=20, ground=False)


def build(lib):
    grass = lib.material("Grass", g.GRASS)
    grass_dark = lib.material("Grass", g.GRASS_DARK)
    dirt = lib.material("Ground", g.DIRT)
    mud = lib.material("Mud", g.MUD)
    edge = 66
    g.rect(lib, "meadow", 0, 0, 900, 900, grass, 0)
    # darker grass ring under the forest so the clearing reads as a clearing
    for i, (cx, cz, w, d) in enumerate([(0, 150, 900, 160), (0, -150, 900, 160), (150, 0, 160, 140), (-150, 0, 160, 140)]):
        g.patch(lib, "forestfloor%d" % i, cx, cz, w, d, grass_dark, seed=40 + i, layer=1, wobble=6)
    g.patch(lib, "clearing", 0, 0, edge * 2 - 6, edge * 2 - 6, dirt, seed=5, layer=2, wobble=3.5)
    for i, x in enumerate((-18, 0, 18)):
        g.patch(lib, "mud%d" % i, x, 30, 16, 26, mud, seed=30 + x, layer=5, wobble=2.2)
    rnd = random.Random(8)
    for i, (x, z) in enumerate([(-24, -56), (26, -54), (-54, -58), (56, -46), (-20, 54)]):
        g.blob(lib, "island%d" % i, x, z, rnd.uniform(4, 5.5), grass, seed=i * 13, layer=3)
    # paths from the spawn up the lantern walk, and out to the classes cabin, garage and rewards stall
    g.path(lib, "walk", (0, -50), (0, 26), 12, mud, seed=3, layer=3)
    for i, (a, b) in enumerate([((-6, -22), (-36, -22)), ((6, -22), (36, -22)), ((-6, 18), (-40, 24))]):
        g.path(lib, "spur%d" % i, a, b, 6, mud, seed=10 + i, layer=4)
    # rolling hills between the forest and the mountains
    for i in range(12):
        t = i / 12 * math.pi * 2 + 0.2
        g.hill(lib, "hill%d" % i, math.cos(t) * 245, math.sin(t) * 245, rnd.uniform(45, 70), rnd.uniform(12, 24),
               grass if i % 2 else grass_dark)
