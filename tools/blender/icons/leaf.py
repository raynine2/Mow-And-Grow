"""A big green leaf (window corner decoration)."""
VIEW = dict(yaw=0, pitch=80, zoom=1.0, roll=-30)

def build(lib):
    g = lib.material("SmoothPlastic", (110, 190, 60))
    v = lib.material("SmoothPlastic", (70, 140, 40))
    lib.cyl("leaf", 3, 0.5, (0, 0, 0), mat=g, verts=12, bevel=0.15).scale = (1.7, 1, 1)
    lib.box("vein", (8.6, 0.35, 0.6), (0, 0, 0.1), mat=v, bevel=0.1)
