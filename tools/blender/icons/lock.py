"""Gold padlock."""
VIEW = dict(yaw=15, pitch=10, zoom=1.0)

def build(lib):
    gold = lib.material("SmoothPlastic", (250, 180, 40))
    steel = lib.material("Metal", (190, 195, 205))
    dark = lib.material("SmoothPlastic", (80, 50, 20))
    lib.box("body", (5, 2.4, 4), (0, 0, 2), mat=gold, bevel=0.45)
    for x in (-1.6, 1.6):
        lib.box("leg%d" % (x > 0), (0.8, 0.8, 2.6), (x, 0, 5), mat=steel, bevel=0.2)
    lib.box("arch", (4, 0.8, 0.8), (0, 0, 6.3), mat=steel, bevel=0.3)
    lib.box("key", (0.7, 0.3, 1.4), (0, 1.25, 1.8), mat=dark, bevel=0.1)
