"""Shared builder for the fx_clip_* grass clippings (see fx_clip_a.py)."""

def clip(lib, variant):
    body = lib.material("SmoothPlastic", (255, 255, 255))   # tinted in game
    cut = lib.material("SmoothPlastic", (238, 244, 196))    # fresh-cut end
    if variant == "a":
        # straight chunk: a thick slab cut flat at both ends
        lib.box("blade", (0.5, 0.95, 0.16), (0, 0, 0.6), rot=(0, 0, 0), mat=body, bevel=0.05, taper=(0.82, 1.0))
        lib.box("cutA", (0.47, 0.06, 0.15), (0, -0.48, 0.6), mat=cut, bevel=0.02)
        lib.box("cutB", (0.4, 0.06, 0.15), (0, 0.48, 0.6), mat=cut, bevel=0.02)
    elif variant == "b":
        # bent chunk: two slabs at an angle, like a blade folded by the hit
        lib.box("lower", (0.48, 0.6, 0.15), (0, -0.22, 0.6), rot=(14, 0, 0), mat=body, bevel=0.05)
        lib.box("upper", (0.44, 0.6, 0.15), (0, 0.33, 0.72), rot=(-22, 0, 8), mat=body, bevel=0.05, taper=(0.75, 1.0))
        lib.box("cut", (0.46, 0.06, 0.14), (0, -0.52, 0.53), rot=(14, 0, 0), mat=cut, bevel=0.02)
    else:
        # tip: the pointed top of a blade, cut flat at the bottom
        # a slab narrowing to a point: taper the box's top, then lay it along Y
        lib.box("tip", (0.5, 0.16, 0.9), (0, 0.03, 0.6), rot=(-90, 0, 0), mat=body, bevel=0.03, taper=(0.12, 1.0))
        lib.box("cut", (0.5, 0.06, 0.15), (0, -0.42, 0.6), mat=cut, bevel=0.02)
