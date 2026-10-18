"""Private helper for the first-person hands (hand_right, hand_left): a chunky orange gardening glove gripping a tool
handle, with a green elastic cuff and a blue-grey shirt sleeve.

build.py skips files that start with "_", so this is never built as a model. Load it from a hand model with:

    import os, sys; sys.path.insert(0, os.path.dirname(__file__)); import _handkit as hk

Layout (right hand; the left hand is its mirror image, x -> -x):
- ORIGIN (0, 0, 0) = the centre of the grip: the tool handle runs straight forward along +Y through the fist.
- Fist: a bevelled block ~1.3 x 1.3 x 1.3 centred at FIST_CENTRE. The four fingers are stacked along the handle
  (index at the front, pinky at the back); each wraps over the top (a darker padded knuckle, together forming the
  knuckle ridge), down the outer side (+X) and tucks its tip under the handle. The thumb sits on the inner side
  (-X) and wraps over the top at the front, across the index knuckle.
- Cuff: green elastic glove cuff with a cream stripe, y = -0.7 .. -1.1 (CUFF).
- Sleeve: blue-grey shirt sleeve 1.05 x 1.05, y = -1.0 .. -3.6 (SLEEVE), towards the camera.
"""
import bpy

GLOVE, PAD, CUFF_C, STRIPE, SHIRT = (240, 130, 40), (200, 88, 26), (60, 120, 60), (246, 226, 160), (70, 90, 140)

FIST_CENTRE = (0.05, 0.0, 0.02)      # right hand; x is mirrored for the left
CUFF = dict(y0=-0.7, y1=-1.1, size=(1.32, 1.32), centre=(0.03, -0.9, 0.0))
SLEEVE = dict(y0=-1.0, y1=-3.6, size=(1.05, 1.05), centre=(0.03, -2.3, 0.0))


def build_hand(lib, side):
    """side = "right" (thumb on -X) or "left" (thumb on +X)."""
    m = 1 if side == "right" else -1
    glove = lib.material("SmoothPlastic", GLOVE)
    pad = lib.material("SmoothPlastic", PAD)
    cuff = lib.material("Fabric", CUFF_C)
    stripe = lib.material("SmoothPlastic", STRIPE)
    shirt = lib.material("Fabric", SHIRT)

    def box(name, size, loc, mat, bevel):
        return lib.box(name, size, (loc[0] * m, loc[1], loc[2]), mat=mat, bevel=bevel)

    # main fist mass (palm + back of the hand)
    fx, fy, fz = FIST_CENTRE
    box("fist", (1.2, 1.3, 1.22), (fx - 0.04, fy - 0.02, fz), glove, 0.18)
    # four fingers stacked along the handle: padded knuckle on top, a phalanx down the outer side
    for i, (y, s) in enumerate(((0.45, 1.0), (0.15, 1.02), (-0.15, 1.0), (-0.44, 0.9))):
        box("knuckle%d" % i, (0.56, 0.28, 0.3 * s), (0.36, y, 0.6 + 0.04 * s), pad, 0.07)
        box("finger%d" % i, (0.3, 0.28, 0.98 * s), (0.66, y, 0.06), glove, 0.07)
    # fingertips tucked under the handle (one block with the four tips)
    box("tips", (0.8, 1.12, 0.3), (0.22, 0.0, -0.64), glove, 0.1)
    # thumb: a fat base on the inner side, the tip lying over the top at the front
    box("thumb", (0.36, 0.72, 0.78), (-0.66, 0.2, 0.06), glove, 0.12)
    box("thumbtip", (0.62, 0.36, 0.34), (-0.4, 0.42, 0.66), glove, 0.1)
    # elastic cuff with a cream stripe
    cx, cy, cz = CUFF["centre"]
    box("cuff", (CUFF["size"][0], CUFF["y0"] - CUFF["y1"], CUFF["size"][1]), (cx, cy, cz), cuff, 0.06)
    box("stripe", (CUFF["size"][0] + 0.05, 0.1, CUFF["size"][1] + 0.05), (cx, cy - 0.02, cz), stripe, 0.02)
    # shirt sleeve, running back toward the camera
    sx, sy, sz = SLEEVE["centre"]
    box("sleeve", (SLEEVE["size"][0], SLEEVE["y0"] - SLEEVE["y1"], SLEEVE["size"][1]), (sx, sy, sz), shirt, 0.1)
    _lift_preview(lib)


def _lift_preview(lib, dz=1.6):
    """The hand's origin is the grip centre, so half of it is below z = 0 and the preview's ground would cut it.
    Wrap lib.preview once so the render lifts the meshes by dz and puts them back before export."""
    orig = lib.preview

    def lifted(path, **kw):
        lib.preview = orig
        objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
        for o in objs:
            o.location.z += dz
        try:
            orig(path, **kw)
        finally:
            for o in objs:
                o.location.z -= dz
    lib.preview = lifted
