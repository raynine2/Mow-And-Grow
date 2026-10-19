"""Golf flag for the Golf Course zone: a white pole in a little cup ring with a red pennant and a gold knob on top,
and a golf ball resting by the cup."""
PREVIEW = dict(dist=16, height=6, target_z=4.5, yaw=30)


def build(lib):
    white = lib.material("SmoothPlastic", (245, 245, 240))
    red = lib.material("SmoothPlastic", (235, 60, 60))
    gold = lib.material("SmoothPlastic", (250, 200, 50))
    cup = lib.material("SmoothPlastic", (40, 44, 48))
    lib.cyl("cup", 0.9, 0.12, (0, 0, 0.06), mat=cup, verts=16)
    lib.cyl("rim", 1.05, 0.1, (0, 0, 0.1), mat=white, verts=16, top_scale=0.86)
    lib.cyl("pole", 0.22, 9.0, (0, 0, 4.5), mat=white, verts=8)
    lib.sphere("knob", 0.35, (0, 0, 9.1), mat=gold, subdiv=1)
    # pennant: two slabs at slight angles so it looks like it's waving
    lib.box("flag_a", (0.15, 1.7, 2.3), (0, 0.95, 7.8), rot=(0, 0, 4), mat=red, bevel=0.03)
    lib.box("flag_b", (0.15, 1.6, 1.5), (0.05, 2.5, 7.85), rot=(0, 0, -6), mat=red, bevel=0.03)
    lib.sphere("ball", 0.32, (1.8, -0.6, 0.32), mat=white, subdiv=2)
