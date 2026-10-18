"""Blue diamond gem with facets (a cut crown on top, a pointed pavilion below)."""
VIEW = dict(yaw=20, pitch=18, zoom=0.95)

def build(lib):
    top = lib.material("SmoothPlastic", (120, 210, 255))
    mid = lib.material("SmoothPlastic", (60, 160, 245))
    low = lib.material("SmoothPlastic", (35, 110, 220))
    lib.cyl("crown", 4.2, 1.6, (0, 0, 1.0), mat=top, verts=8, top_scale=0.6, bevel=0.05)
    lib.cyl("girdle", 4.4, 0.4, (0, 0, 0.0), mat=mid, verts=8, bevel=0.05)
    lib.cyl("pavilion", 4.4, 4.2, (0, 0, -2.3), rot=(180, 0, 0), mat=low, verts=8, top_scale=0.02, bevel=0.05)
    lib.cyl("table", 2.4, 0.25, (0, 0, 1.85), mat=lib.material("SmoothPlastic", (200, 240, 255)), verts=8)
