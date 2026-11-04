"""The hand tools as voxel sculptures, in the game's voxel look (owner, 4 Nov: the AI-made smooth tools "don't fit our
voxel look"; judged against the LihFolk vault's voxel notes: one grain per model, a held item on the 0.125-stud
"hero detail" grain (half the props' 0.25), colours from the props' families (tools/blender/voxel/props.py) in
dark-to-light shades picked per voxel by noise, lit edges and baked occlusion, no smooth shapes slipped in).

Each tool is one group sculpted straight in its template's frame (server/Models FORGE_TOOLS): studs, y up, the
working end toward -Z, the pivot at the template's origin (a hand tool's grip; a mower's ground under its middle).
Writes src/shared/VoxelToolShapes.luau (shared/SculptKit's shape format; server/Models builds the templates from it).

    python3 tools/blender/voxel/tools_voxel.py [preview_dir]

numpy only (no Blender). With a preview_dir it also draws each tool from three sides (PIL) to check the shapes.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sculptkit import A, Palette, Sculpt, box, cone, cyl, rot, sphere, torus, voxels_of, corner_of, write_luau  # noqa: E402

V = 0.125  # the held-item grain

# ---------------------------------------------------------------------------------------------------------------
# palette: the props' colour families (props.py), dark to light
# ---------------------------------------------------------------------------------------------------------------
PAL = Palette()
SHADE = dict(noise=0.55, fine=0.25, edge=0.55, base=0.45, freq=1.6, ao=0.8, top=0.5, aor=1)

WOOD = PAL.mat([(122, 76, 46), (146, 94, 58), (170, 116, 74), (198, 142, 88), (216, 164, 108)])
LEATHER = PAL.mat([(58, 30, 24), (78, 42, 30), (100, 56, 38), (122, 72, 48)], edge=0.4)
GOLD = PAL.mat([(160, 108, 28), (196, 140, 36), (232, 178, 52), (255, 210, 80), (255, 236, 150)], noise=0.4, edge=0.9, top=0.8)
STEEL = PAL.mat([(112, 120, 136), (140, 148, 164), (168, 176, 190), (196, 202, 214), (222, 228, 236)], noise=0.45, edge=0.6, top=0.7)
STEEL_D = PAL.mat([(70, 74, 88), (88, 92, 108), (108, 114, 130)], noise=0.3, edge=0.4)
EDGE = PAL.mat([(214, 222, 234), (236, 242, 250), (255, 255, 255)], noise=0.4, edge=0.5, top=0.6)
RED = PAL.mat([(150, 40, 36), (184, 54, 44), (212, 72, 54), (232, 96, 66), (246, 124, 84)], noise=0.4, edge=0.6, top=0.7)
RED_D = PAL.mat([(104, 28, 28), (128, 36, 32)], noise=0.3)
WHITE = PAL.mat([(206, 206, 200), (226, 226, 220), (242, 240, 234), (252, 250, 246)], noise=0.3, edge=0.4)
BLACK = PAL.mat([(26, 24, 30), (36, 34, 42), (48, 46, 56), (64, 62, 74)], noise=0.35, edge=0.5)
GREEN = PAL.mat([(44, 112, 44), (58, 136, 52), (76, 160, 62), (98, 184, 74), (124, 204, 90)], noise=0.45, edge=0.5, top=0.6)
LIME = PAL.mat([(98, 164, 40), (122, 190, 48), (148, 212, 60), (176, 230, 84)], noise=0.4, edge=0.6, top=0.7)
ORANGE = PAL.mat([(200, 92, 26), (224, 112, 32), (248, 140, 40), (255, 172, 70)], noise=0.35, edge=0.6, top=0.6)
YELLOW = PAL.mat([(214, 160, 34), (238, 190, 46), (255, 214, 64)], noise=0.3, edge=0.6)
NAVY = PAL.mat([(18, 30, 64), (26, 42, 86), (36, 56, 110), (48, 72, 134)], noise=0.35, edge=0.6, top=0.6)
PANEL = PAL.mat([(186, 196, 212), (210, 218, 230), (230, 236, 244), (246, 248, 252)], noise=0.3, edge=0.5, top=0.5)
CYAN = PAL.mat([(40, 220, 255)], "Neon", "glow")
GLASS = PAL.mat([(170, 230, 255)], "Glass", "glass")


def inter(*ds):
    return np.maximum.reduce(ds)


def sub(a, b):
    return np.maximum(a, -b)


# ---------------------------------------------------------------------------------------------------------------
# the sickle: the fist on the leather wrap (origin), the handle straight ahead along -Z, the blade flat in XZ: out
# of the brass collar forward, round to the left and back, its tip pointing back at you on the left, edge inward
# ---------------------------------------------------------------------------------------------------------------
def sickle():
    S = Sculpt(PAL, "sickle", (-2.6, -0.4, -3.4), (0.6, 0.4, 1.0), V, seed=3, shade=SHADE)
    P = S.P
    S.add(cyl(P, (0, 0, 0.62), (0, 0, -1.5), 0.17), WOOD)
    S.add(cyl(P, (0, 0, 0.4), (0, 0, -0.5), 0.2), LEATHER)
    S.add(sphere(P, (0, 0, 0.7), 0.22), GOLD)
    S.add(cyl(P, (0, 0, -1.38), (0, 0, -1.66), 0.22), GOLD)
    # the blade: an arc round (-1, -2) in XZ, radius 1, from the collar (-25 deg) forward (90) and round to its tip
    # out at the left (200), tapering from 0.6 wide to a point; 2 cells thick
    c, rc = A((-1.0, -2.0)), 1.0
    dx, dz = P[:, 0] - c[0], P[:, 2] - c[1]
    r = np.hypot(dx, dz)
    th = np.degrees(np.arctan2(-dz, dx))
    th = np.where(th < -90, th + 360, th)
    t = np.clip((th + 25) / 225, 0, 1)
    half = 0.3 - 0.25 * t
    off = 0.08 * t  # the edge side thins faster: the tip curls inward
    across = np.abs(r - rc + off) - half
    arc = np.maximum(-(th + 25), th - 200)
    flat = np.abs(P[:, 1]) - 0.07
    blade = inter(across, arc, flat)
    S.add(blade, STEEL)
    S.add(cyl(P, (0, 0, -1.5), (-0.08, 0, -1.62), 0.13), STEEL_D)
    # the edge: the inner rim, light; the spine: the outer rim, darker
    S.paint((r - rc + off < -half + 0.15) & (blade <= 0), EDGE)
    S.paint((r - rc + off > half - 0.12) & (blade <= 0), STEEL_D)
    return S


# ---------------------------------------------------------------------------------------------------------------
# the push mower: on its wheels (y 0), the handle rising to the back (+Z) to its grip bar at (0, 3.42, 3.58)
# ---------------------------------------------------------------------------------------------------------------
def mower_wheels(S, tyre, hub, rim=None):
    P = S.P
    for x in (-1, 1):
        for z in (-1.3, 0.62):
            S.add(cyl(P, (x * 0.88, 0.42, z), (x * 1.2, 0.42, z), 0.42, 0.06), tyre)
            S.add(cyl(P, (x * 1.12, 0.42, z), (x * 1.26, 0.42, z), 0.2), hub)
            if rim is not None:
                ring = inter(np.abs(np.linalg.norm(P[:, [1, 2]] - A((0.42, z)), axis=1) - 0.3) - 0.06,
                             np.abs(P[:, 0] - x * 1.22) - 0.06)
                S.add(ring, rim)


def mower_handle(S, bar, grip):
    P = S.P
    for x in (-0.68, 0.68):
        S.add(cone(P, (x, 0.85, 0.7), (x, 3.42, 3.58), 0.11, 0.11), bar)
    S.add(cyl(P, (-0.68, 3.42, 3.58), (0.68, 3.42, 3.58), 0.11), bar)
    S.add(cyl(P, (-0.5, 3.42, 3.58), (0.5, 3.42, 3.58), 0.16), grip)
    S.add(cyl(P, (-0.68, 2.1, 2.15), (0.68, 2.1, 2.15), 0.09), bar)


def pushmower():
    S = Sculpt(PAL, "pushmower", (-1.4, -0.1, -2.0), (1.4, 3.7, 3.9), V, seed=5, shade=SHADE)
    P = S.P
    mower_wheels(S, BLACK, YELLOW)
    S.add(box(P, (0, 0.66, -0.35), (1.0, 0.3, 1.3), rr=0.18), RED)
    S.add(box(P, (0, 0.42, -0.35), (1.04, 0.1, 1.34), rr=0.05), RED_D)
    S.paint((np.abs(P[:, 0]) < 0.2) & (P[:, 1] > 0.85) & (P[:, 2] < 0.7), WHITE, depth=0.13)
    # the engine: a black block with a steel top, the yellow fuel cap and the orange pull-start
    S.add(box(P, (0, 1.2, -0.6), (0.44, 0.3, 0.44), rr=0.08), BLACK)
    S.add(box(P, (0, 1.55, -0.6), (0.38, 0.08, 0.38), rr=0.04), STEEL)
    S.add(cyl(P, (0.2, 1.6, -0.82), (0.2, 1.78, -0.82), 0.11), YELLOW)
    S.add(box(P, (-0.32, 1.42, -0.25), (0.14, 0.06, 0.06)), ORANGE)
    # the grass bag behind, under the handle, with a dark frame on top
    S.add(box(P, (0, 1.05, 1.42), (0.62, 0.5, 0.6), rr=0.16), GREEN)
    S.add(box(P, (0, 1.56, 1.42), (0.66, 0.06, 0.64)), BLACK)
    mower_handle(S, STEEL_D, BLACK)
    return S


# ---------------------------------------------------------------------------------------------------------------
# the laser mower: the same frame, a sleek navy deck with white side panels, cyan light strips and wheel rims, a
# glass dome with a glowing core, a glowing blade slot at the front
# ---------------------------------------------------------------------------------------------------------------
def lasermower():
    S = Sculpt(PAL, "lasermower", (-1.45, -0.1, -2.3), (1.45, 3.7, 3.9), V, seed=7, shade=SHADE)
    P = S.P
    mower_wheels(S, BLACK, STEEL_D, CYAN)
    S.add(box(P, (0, 0.7, -0.45), (1.0, 0.32, 1.55), rr=0.22), NAVY)
    for x in (-1, 1):
        S.add(box(P, (x * 0.93, 0.66, -0.45), (0.1, 0.2, 1.3), rr=0.05), PANEL)
        S.add(box(P, (x * 1.0, 0.62, -0.45), (0.06, 0.05, 1.1)), CYAN)
    S.add(box(P, (0, 0.5, -2.0), (0.8, 0.06, 0.06)), CYAN)  # the laser slot
    S.add(box(P, (0, 1.06, 0.1), (0.62, 0.12, 0.6), rr=0.08), PANEL)
    S.add(sphere(P, (0, 1.22, -0.55), 0.42), GLASS)
    S.add(sphere(P, (0, 1.2, -0.55), 0.2), CYAN)
    S.add(box(P, (0, 1.0, -0.55), (0.48, 0.08, 0.48), rr=0.04), STEEL_D)
    # vents on the back deck
    for k in range(3):
        S.carve(box(P, (0, 1.16, -0.05 + k * 0.25), (0.42, 0.04, 0.05)), BLACK)
    S.add(box(P, (0, 1.0, 1.32), (0.55, 0.32, 0.34), rr=0.12), NAVY)  # the battery pack behind
    S.add(box(P, (0, 1.0, 1.68), (0.4, 0.2, 0.04)), CYAN)
    mower_handle(S, NAVY, BLACK)
    S.add(box(P, (0, 3.3, 3.42), (0.18, 0.1, 0.05)), CYAN)  # a little screen on the grip bar
    return S


# ---------------------------------------------------------------------------------------------------------------
# the weed whacker: the right fist on the rear grip (origin), the motor behind it, the shaft straight ahead along -Z,
# the loop handle's top bar where the left fist goes (0, 0.82, -1.55), and the head at the far end, its spool's
# middle at the hub (0, -0.3, -5.17), turned to client/ViewModel's WHACK_AXIS so the line spins flat over the grass
# ---------------------------------------------------------------------------------------------------------------
HUB = A((0, -0.3, -5.17))
AXIS = A((0, 0.81, 0.59)) / np.linalg.norm((0, 0.81, 0.59))


def whacker():
    S = Sculpt(PAL, "whacker", (-1.0, -0.9, -6.1), (1.0, 1.1, 2.1), V, seed=9, shade=SHADE)
    P = S.P
    # the motor: a lime housing with a black cap and an orange pull-start
    S.add(box(P, (0, 0.08, 1.18), (0.36, 0.38, 0.6), rr=0.16), LIME)
    S.add(box(P, (0, 0.08, 1.74), (0.3, 0.32, 0.1), rr=0.06), BLACK)
    S.add(box(P, (0.4, 0.12, 1.2), (0.06, 0.12, 0.16)), ORANGE)
    S.paint((np.abs(P[:, 1] - 0.08) < 0.07) & (P[:, 2] > 0.6), WHITE, depth=0.13)
    # the rear grip and the shaft
    S.add(cyl(P, (0, 0, 0.55), (0, 0, -0.42), 0.17), BLACK)
    S.add(cyl(P, (0, 0, 0.5), (0, 0, -4.85), 0.13), STEEL)
    # the loop handle: a black arch over the shaft, its top bar at y 0.82
    ring = torus(P, (0, 0.4, -1.55), 0.42, 0.08, rot(90, 0, 0))
    S.add(np.maximum(ring, -(P[:, 1] - 0.0)), BLACK)
    S.add(cyl(P, (0, 0, -1.47), (0, 0, -1.63), 0.15), BLACK)
    # the head: a gearbox down from the shaft's end to the spool, the spool, and the guard over the line
    S.add(cone(P, (0, 0, -4.8), HUB + 0.28 * AXIS, 0.13, 0.15), STEEL_D)
    S.add(cyl(P, HUB - 0.2 * AXIS, HUB + 0.12 * AXIS, 0.24, 0.04), GREEN)
    S.add(cyl(P, HUB - 0.26 * AXIS, HUB - 0.18 * AXIS, 0.14), BLACK)
    q = P - HUB
    disc = cyl(P, HUB + 0.14 * AXIS, HUB + 0.24 * AXIS, 0.82)
    toward = q @ A((0, -0.59, 0.81))  # the guard covers the operator's half
    S.add(np.maximum(disc, -(toward + 0.18)), ORANGE)
    return S


TOOLS = [sickle, pushmower, lasermower, whacker]


# ---------------------------------------------------------------------------------------------------------------
# previews: each voxel as a cube, drawn back to front in a simple projection
# ---------------------------------------------------------------------------------------------------------------
def preview(S, path):
    from PIL import Image, ImageDraw

    vox = voxels_of(S)
    lo = corner_of(S)
    cols = {i: e for i, e in enumerate(PAL.entries) if e}
    views = {"three": rot(-30, 35, 0), "side": rot(0, 90, 0), "top": rot(-90, 0, 0)}
    imgs = []
    for vname, R in views.items():
        W = 520
        img = Image.new("RGB", (W, W), (118, 170, 220))
        d = ImageDraw.Draw(img)
        pts = []
        for (i, j, k), c in vox.items():
            centre = lo + (A((i, j, k)) + 0.5) * S.v
            pts.append((centre, c))
        allc = np.array([p for p, _ in pts])
        cam = allc @ R  # camera space (x right, y up, z toward the viewer is -z)
        span = max(np.ptp(cam[:, 0]), np.ptp(cam[:, 1])) + 0.5
        sc = (W - 40) / span
        mid = (cam.min(0) + cam.max(0)) / 2
        order = np.argsort(cam[:, 2])[::-1]
        corners = np.array([[x, y, z] for x in (-.5, .5) for y in (-.5, .5) for z in (-.5, .5)]) * S.v
        faces = [(0, 1, 3, 2), (4, 5, 7, 6), (0, 1, 5, 4), (2, 3, 7, 6), (0, 2, 6, 4), (1, 3, 7, 5)]
        light = A((0.4, 0.8, -0.45))
        for idx in order:
            centre, c = pts[idx]
            r, g, b, mat, tag = cols[c]
            cc = (centre + corners) @ R
            for f in faces:
                poly = cc[list(f)]
                n = np.cross(poly[1] - poly[0], poly[2] - poly[0])
                if np.linalg.norm(n) < 1e-9:
                    continue
                n = n / np.linalg.norm(n)
                if n[2] > 0:
                    n = -n
                facing = (poly.mean(0)[2] - (centre @ R)[2])
                if facing > 0:
                    continue
                k = 0.62 + 0.38 * max(0, -(n @ (light @ R)))
                if mat == "Neon":
                    k = 1.15
                xy = [((p[0] - mid[0]) * sc + W / 2, (mid[1] - p[1]) * sc + W / 2) for p in poly]
                d.polygon(xy, fill=(min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k))))
        d.text((8, 8), "%s %s" % (S.name, vname), fill=(0, 0, 0))
        imgs.append(img)
    out = Image.new("RGB", (W * 3, W))
    for i, im in enumerate(imgs):
        out.paste(im, (i * W, 0))
    out.save(path)


def main():
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
    sculpts = [f() for f in TOOLS]
    write_luau(os.path.join(root, "src", "shared", "VoxelToolShapes.luau"), "tools_voxel.py", PAL, sculpts)
    if len(sys.argv) > 1:
        os.makedirs(sys.argv[1], exist_ok=True)
        for S in sculpts:
            preview(S, os.path.join(sys.argv[1], S.name + ".png"))


if __name__ == "__main__":
    main()
