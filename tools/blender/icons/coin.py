"""Gold coin, tilted, with a raised rim and a star in the middle (like Chop A Forest's coin icon)."""
VIEW = dict(yaw=0, pitch=12, zoom=1.0)

def build(lib):
    gold = lib.material("SmoothPlastic", (255, 196, 40))
    dark = lib.material("SmoothPlastic", (226, 150, 20))
    light = lib.material("SmoothPlastic", (255, 226, 110))
    lib.cyl("coin", 5, 1.2, (0, 0, 0), rot=(90, 0, 0), mat=gold, verts=32, bevel=0.25)
    lib.cyl("face", 4.1, 1.35, (0, 0, 0), rot=(90, 0, 0), mat=dark, verts=32, bevel=0.1)
    lib.cyl("inner", 3.6, 1.45, (0, 0, 0), rot=(90, 0, 0), mat=gold, verts=32, bevel=0.15)
    for i in range(5):
        import math
        a = math.radians(90 + i * 72)
        lib.box("ray%d" % i, (0.9, 0.6, 2.4), (math.cos(a) * 1.1, -0.75, math.sin(a) * 1.1), rot=(0, -math.degrees(a) + 90, 0), mat=light, bevel=0.15, taper=(0.35, 1))
