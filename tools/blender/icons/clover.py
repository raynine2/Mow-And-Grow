"""Four-leaf clover (luck): four heart-ish leaves from flattened spheres and a stem."""
VIEW = dict(yaw=0, pitch=60, zoom=1.0)

def build(lib):
    import math
    g = lib.material("SmoothPlastic", (70, 190, 60))
    d = lib.material("SmoothPlastic", (50, 150, 45))
    for i in range(4):
        a = math.radians(45 + i * 90)
        leaf = lib.sphere("leaf%d" % i, 1.9, (math.cos(a) * 2.0, math.sin(a) * 2.0, 0.1 * i), mat=g, subdiv=2)
        leaf.scale = (1.0, 1.0, 0.35)
    lib.sphere("centre", 0.9, (0, 0, 0.5), mat=d, subdiv=2).scale = (1, 1, 0.4)
    lib.box("stem", (0.6, 3.5, 0.6), (0.8, -3.6, -0.3), rot=(0, 0, 25), mat=d, bevel=0.15)
