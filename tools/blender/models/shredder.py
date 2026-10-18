"""Giant Grass Shredder: the selling machine, styled like Chop A Forest's orange drum chipper.

Orange upright cabinet on a little 2-wheel trailer. A big round drum on the +X side (orange disc, dark bolts, dark
hub ring, grey centre), a hopper at the back (-Y) where bundles are tossed in, a curved segmented discharge chute on
top, a control panel (black box, red button, white gauge, three knobs) and a DANGER plate on the front, tall
black/yellow hazard stripe panels, a front box with a label plate, a grey tank, a hazard bumper, a hitch with a jack
leg, and a metal output tray at the front (+Y) where the coins come out. About 14 long (Y) and 9 tall.
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _yardkit as kit  # noqa: E402

PREVIEW = dict(dist=24, height=10, target_z=4.2, yaw=40)


def build(lib):
    orange = lib.material("SmoothPlastic", (255, 112, 10))
    dark = lib.material("SmoothPlastic", (38, 38, 42))
    yellow = lib.material("SmoothPlastic", kit.HAZ_YELLOW)
    grey = lib.material("Metal", (150, 152, 158))
    red = lib.material("SmoothPlastic", (220, 34, 30))
    white = lib.material("SmoothPlastic", (236, 236, 230))

    # ---- trailer chassis -------------------------------------------------------------------------------------
    for sx in (-1, 1):
        lib.box("rail%d" % sx, (0.6, 10.6, 0.7), (sx * 2.0, -0.4, 2.0), mat=dark, bevel=0.08)
    lib.box("deck", (4.8, 9.0, 0.35), (0, -0.6, 2.45), mat=dark, bevel=0.06)
    lib.cyl("axle", 0.28, 7.0, (0, -0.6, 1.5), rot=(0, 90, 0), mat=dark, verts=8)
    for sx in (-1, 1):
        x = sx * 3.15
        lib.cyl("tyre%d" % sx, 1.5, 1.1, (x, -0.6, 1.5), rot=(0, 90, 0), mat=dark, verts=14, bevel=0.1)
        lib.cyl("hub%d" % sx, 0.75, 1.2, (x, -0.6, 1.5), rot=(0, 90, 0), mat=grey, verts=12)
        lib.cyl("cap%d" % sx, 0.3, 1.32, (x, -0.6, 1.5), rot=(0, 90, 0), mat=dark, verts=8)
        # fender over the wheel
        lib.box("fender%d" % sx, (1.5, 3.8, 0.3), (x, -0.6, 3.25), mat=dark, bevel=0.08)
        lib.box("fender_f%d" % sx, (1.5, 0.3, 1.0), (x, 1.15, 2.85), rot=(-20, 0, 0), mat=dark, bevel=0.06)
        lib.box("fender_b%d" % sx, (1.5, 0.3, 1.0), (x, -2.35, 2.85), rot=(20, 0, 0), mat=dark, bevel=0.06)
    # stand legs at the back so it sits level
    for sx in (-1, 1):
        lib.box("leg%d" % sx, (0.45, 0.45, 1.7), (sx * 2.0, -5.0, 0.85), mat=dark)
        lib.box("foot%d" % sx, (1.0, 1.0, 0.2), (sx * 2.0, -5.0, 0.1), mat=dark)

    # ---- hitch at the front (+Y) -----------------------------------------------------------------------------
    for sx in (-1, 1):
        lib.box("tongue%d" % sx, (0.45, 3.4, 0.45), (sx * 1.0, 6.0, 1.95), rot=(0, 0, sx * 20), mat=dark, bevel=0.06)
    lib.box("coupler", (0.8, 1.2, 0.7), (0, 7.3, 1.95), mat=dark, bevel=0.1)
    lib.cyl("ball", 0.38, 0.4, (0, 7.6, 1.5), mat=grey, verts=10)
    lib.cyl("jack", 0.22, 1.9, (0.8, 6.0, 1.0), mat=grey, verts=8)
    lib.cyl("jackfoot", 0.5, 0.2, (0.8, 6.0, 0.1), mat=dark, verts=10)

    # ---- front bumper with hazard stripes + label box + tank ------------------------------------------------
    kit.hazard(lib, "bumper", 5.8, 0.9, 0.35, (0, 5.05, 1.75), (0, 0, 0), yellow, dark, stripe=0.38, slant=0.55)
    lib.box("frontbox", (4.4, 1.6, 1.3), (0, 4.0, 3.1), mat=orange, bevel=0.12)
    lib.box("label", (3.0, 0.12, 0.8), (0, 4.84, 3.1), mat=yellow, bevel=0.03)
    lib.box("label_frame", (3.2, 0.08, 0.96), (0, 4.81, 3.1), mat=dark, bevel=0.02)
    lib.box("label_txt1", (2.3, 0.16, 0.18), (0, 4.87, 3.22), mat=dark)
    lib.box("label_txt2", (1.7, 0.16, 0.09), (0, 4.87, 2.92), mat=dark)
    lib.cyl("tank", 0.62, 3.8, (0, 2.35, 3.25), rot=(0, 90, 0), mat=grey, verts=12, bevel=0.1)
    for sx in (-1, 1):
        lib.cyl("strap%d" % sx, 0.67, 0.18, (sx * 1.1, 2.35, 3.25), rot=(0, 90, 0), mat=dark, verts=12)

    # ---- main cabinet ---------------------------------------------------------------------------------------
    cab_y, cab_d = -0.9, 4.6
    lib.box("cabinet", (4.4, cab_d, 5.6), (-0.3, cab_y, 5.4), mat=orange, bevel=0.18)
    lib.box("cab_top", (4.7, cab_d + 0.3, 0.35), (-0.3, cab_y, 8.3), mat=dark, bevel=0.08)
    lib.box("cab_skirt", (4.7, cab_d + 0.3, 0.4), (-0.3, cab_y, 2.75), mat=dark, bevel=0.08)
    front = cab_y + cab_d / 2
    # tall hazard panel down the front-left edge (like the reference's side edge)
    kit.hazard(lib, "edge_haz", 5.2, 1.1, 0.3, (-2.3, front + 0.02, 5.4), (0, 90, 0), yellow, dark, stripe=0.42, slant=0.75)
    kit.hazard(lib, "edge_haz_s", 5.2, 1.0, 0.3, (-2.62, cab_y - 1.0, 5.4), (0, 90, 90), yellow, dark, stripe=0.42, slant=0.75)
    # control panel: black box with a red button and a white gauge, three knobs on stalks above
    py = front + 0.2
    lib.box("panel", (2.2, 0.4, 1.5), (0.35, py, 6.6), mat=dark, bevel=0.08)
    lib.cyl("button", 0.32, 0.3, (-0.15, py + 0.25, 6.45), rot=(90, 0, 0), mat=red, verts=12)
    lib.cyl("button_ring", 0.42, 0.2, (-0.15, py + 0.18, 6.45), rot=(90, 0, 0), mat=yellow, verts=12)
    lib.cyl("gauge", 0.42, 0.24, (0.85, py + 0.22, 6.75), rot=(90, 0, 0), mat=white, verts=14)
    lib.box("needle", (0.5, 0.06, 0.07), (0.92, py + 0.36, 6.8), rot=(0, 35, 0), mat=red)
    for i, (x, m) in enumerate(((-0.3, red), (0.35, yellow), (1.0, red))):
        lib.cyl("stalk%d" % i, 0.07, 0.9, (x, py - 0.05, 7.7), rot=(-12, 0, 0), mat=grey, verts=6)
        lib.cyl("knob%d" % i, 0.2, 0.32, (x, py + 0.05, 8.15), mat=m, verts=8)
    # DANGER plate under the panel
    lib.box("danger", (2.1, 0.12, 1.2), (0.35, front + 0.04, 5.05), mat=yellow, bevel=0.03)
    lib.box("danger_frame", (2.25, 0.08, 1.35), (0.35, front + 0.0, 5.05), mat=dark, bevel=0.02)
    lib.box("danger_txt", (1.5, 0.16, 0.28), (0.35, front + 0.08, 5.3), mat=dark)
    lib.box("danger_txt2", (1.2, 0.16, 0.08), (0.35, front + 0.08, 4.9), mat=dark)
    lib.box("danger_txt3", (1.0, 0.16, 0.08), (0.35, front + 0.08, 4.73), mat=dark)

    # ---- big drum on the +X side --------------------------------------------------------------------------
    dx, dy, dz, dr = 2.6, -1.0, 5.95, 2.5
    lib.cyl("drum", dr, 1.6, (dx, dy, dz), rot=(0, 90, 0), mat=orange, verts=20, bevel=0.16)
    lib.cyl("drum_rim", dr + 0.12, 0.35, (dx - 0.55, dy, dz), rot=(0, 90, 0), mat=dark, verts=20)
    lib.cyl("drum_hubring", 1.15, 0.3, (dx + 0.85, dy, dz), rot=(0, 90, 0), mat=dark, verts=16)
    lib.cyl("drum_hub", 0.72, 0.42, (dx + 0.9, dy, dz), rot=(0, 90, 0), mat=grey, verts=14, bevel=0.06)
    for i in range(8):
        a = math.radians(i * 45 + 22.5)
        lib.cyl("bolt%d" % i, 0.18, 0.2, (dx + 0.82, dy + math.cos(a) * (dr - 0.45), dz + math.sin(a) * (dr - 0.45)),
                rot=(0, 90, 0), mat=dark, verts=6)
    lib.box("drum_tab", (0.3, 0.6, 0.3), (dx + 0.8, dy + 0.0, dz - dr + 0.05), mat=yellow, bevel=0.05)

    # ---- hopper at the back (-Y): flared funnel with a dark mouth and a hazard rim ---------------------------
    hy = cab_y - cab_d / 2 - 1.35
    lib.box("hopper", (3.6, 2.8, 3.0), (-0.3, hy, 6.4), mat=orange, bevel=0.12, taper=(1.35, 1.35))
    lib.box("hopper_mouth", (4.2, 3.2, 0.3), (-0.3, hy, 7.82), mat=dark, bevel=0.03)
    for sx in (-1, 1):
        lib.box("hop_lip%d" % sx, (0.35, 4.0, 0.45), (-0.3 + sx * 2.45, hy, 8.0), mat=yellow, bevel=0.06)
    kit.hazard(lib, "hop_lip_b", 5.25, 0.45, 0.35, (-0.3, hy - 1.85, 8.0), (0, 0, 0), yellow, dark, stripe=0.3, slant=0.3)
    lib.box("hop_lip_f", (5.25, 0.35, 0.45), (-0.3, hy + 1.85, 8.0), mat=yellow, bevel=0.06)
    lib.box("hop_brace", (3.0, 1.2, 1.6), (-0.3, hy + 0.4, 4.1), mat=dark, bevel=0.08)

    # ---- curved discharge chute on top: orange segments with dark rings, arching toward the front -------------
    cx = -1.0
    pts = [(cx, cab_y - 0.2, 8.4), (cx, cab_y - 0.2, 9.2), (cx, cab_y + 0.3, 10.0), (cx, cab_y + 1.2, 10.5),
           (cx, cab_y + 2.2, 10.55), (cx, cab_y + 3.0, 10.05)]
    for i in range(len(pts) - 1):
        kit.log(lib, "chute%d" % i, pts[i], pts[i + 1], 0.62, orange, verts=10)
    for i in range(1, len(pts) - 1):
        a, b = pts[i - 1], pts[i + 1]
        d = [(b[k] - a[k]) for k in range(3)]
        n = math.sqrt(sum(c * c for c in d))
        e = [pts[i][k] + d[k] / n * 0.12 for k in range(3)]
        s = [pts[i][k] - d[k] / n * 0.12 for k in range(3)]
        kit.log(lib, "joint%d" % i, s, e, 0.72, dark, verts=10)
    # nozzle: boxy deflector at the end
    lib.box("nozzle", (1.5, 1.2, 0.9), (cx, cab_y + 3.25, 9.7), rot=(-40, 0, 0), mat=grey, bevel=0.1)
    lib.box("chute_base", (2.0, 2.0, 0.45), (cx, cab_y - 0.2, 8.6), mat=dark, bevel=0.08)

    # ---- output tray at the front where the coins come out --------------------------------------------------
    lib.box("out_slot", (2.8, 0.3, 0.8), (0.35, front + 0.05, 4.05), mat=dark, bevel=0.04)
    lib.box("tray", (2.6, 3.6, 0.16), (0.35, front + 1.8, 3.92), rot=(-4, 0, 0), mat=grey, bevel=0.04)
    for sx in (-1, 1):
        lib.box("tray_side%d" % sx, (0.14, 3.6, 0.45), (0.35 + sx * 1.3, front + 1.8, 4.1), rot=(-4, 0, 0), mat=grey)
