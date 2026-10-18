"""Red shopping basket with a grey handle (the SHOP button icon)."""
VIEW = dict(yaw=25, pitch=22, zoom=1.0)

def build(lib):
    red = lib.material("SmoothPlastic", (230, 55, 55))
    dark = lib.material("SmoothPlastic", (180, 35, 40))
    grey = lib.material("SmoothPlastic", (120, 130, 150))
    lib.box("basket", (6, 4.4, 3.6), (0, 0, 1.8), mat=red, bevel=0.35, taper=(1.18, 1.18))
    lib.box("rim", (7.2, 5.4, 0.6), (0, 0, 3.75), mat=dark, bevel=0.2)
    for x in (-1.6, 0, 1.6):
        lib.box("slot%g" % x, (0.7, 0.2, 1.8), (x, -2.45, 1.9), mat=dark, bevel=0.1)
    lib.box("h_left", (0.6, 0.6, 3.2), (-2.6, 0, 5.3), rot=(0, -20, 0), mat=grey, bevel=0.2)
    lib.box("h_right", (0.6, 0.6, 3.2), (2.6, 0, 5.3), rot=(0, 20, 0), mat=grey, bevel=0.2)
    lib.box("h_top", (4.2, 0.6, 0.6), (0, 0, 6.8), mat=grey, bevel=0.2)
