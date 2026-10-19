"""Run hub ground (origin = world origin, the hub spans z -185..20): grass all around, a dirt yard round the tool
shop, shredder and garage, trodden mud at the sell pad, a dirt path out to the first field, and hills behind the
hub. Same layout the Terrain version used (server/RunBuilder.luau hub()), in Roblox studs."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _groundkit as g  # noqa: E402

PREVIEW = dict(dist=200, height=120, target_z=0, yaw=200, ground=False)


def build(lib):
    grass = lib.material("Grass", g.GRASS)
    grass_dark = lib.material("Grass", g.GRASS_DARK)
    dirt = lib.material("Ground", g.DIRT)
    mud = lib.material("Mud", g.MUD)
    # the base reaches far to the sides so the mountains stand on grass, and stops at z = 20 where zone 1 starts
    g.rect(lib, "base", 0, -90, 700, 220, grass, 0)
    g.rect(lib, "behind", 0, -360, 700, 320, grass, 0)
    for i, (cx, cz, w, d) in enumerate([(-105, -40, 100, 110), (105, -40, 100, 110), (0, -150, 300, 70)]):
        g.patch(lib, "forestfloor%d" % i, cx, cz, w, d, grass_dark, seed=60 + i, layer=1, wobble=5)
    g.patch(lib, "yard", 0, -48, 92, 56, dirt, seed=3, layer=2)
    g.path(lib, "road", (0, -30), (0, 26), 10, dirt, seed=4, layer=3)
    g.patch(lib, "sellmud", -8, -36, 16, 16, mud, seed=6, layer=5, wobble=2)
    g.path(lib, "spawnwalk", (0, -72), (0, -50), 7, mud, seed=7, layer=4)
    for i in range(-2, 3):
        g.hill(lib, "hill%d" % (i + 2), i * 70, -230, 70, 20 + (i % 2) * 8, grass if i % 2 else grass_dark)
