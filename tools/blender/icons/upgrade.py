"""Chunky green arrow pointing up and to the right (the UPGRADES button icon)."""
VIEW = dict(yaw=10, pitch=8, zoom=1.0, roll=0)

def build(lib):
    green = lib.material("SmoothPlastic", (110, 215, 60))
    dark = lib.material("SmoothPlastic", (70, 160, 40))
    lib.box("shaft", (2.4, 1.6, 5), (0, 0, 0), rot=(0, 35, 0), mat=green, bevel=0.3)
    lib.box("head", (5.4, 1.8, 3.4), (1.7, 0, 2.4), rot=(0, 35, 0), mat=dark, bevel=0.3, taper=(0.05, 1))
