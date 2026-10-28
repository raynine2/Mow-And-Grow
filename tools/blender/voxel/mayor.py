"""MAYOR THISTLEWICK as a voxel sculpture for the films (client/MayorRig builds and animates him).

A round little Victorian mayor: a tall black top hat with a gold band and a sprig of grass, bushy white brows, a
monocle, a big rosy nose, a white handlebar moustache, a burgundy frock coat with velvet lapels, gold piping and
tails, an ivory waistcoat with gold buttons, a green bow tie, the gold chain of office with the valley's medal,
white gloves, pinstriped trousers, white spats and polished shoes.

Every moving part is its own group, sculpted with signed distance fields on its own voxel grid. Shapes are designed
in model space (studs, feet at y = 0, facing -Z, his right hand at +X) and each group stores its pivot (the joint)
relative to its parent's, the way client/MayorRig hangs them on Motor6Ds:

    LowerTorso (root, pelvis)  -> UpperTorso (waist) -> Head (neck) -> Jaw, Stache, BrowL/R, Eyes, Pupils, Lids, Hat
                                                     -> Left/RightUpperArm -> LowerArm -> Hand
                                                     -> Medal
                               -> Left/RightUpperLeg -> LowerLeg -> Foot
                               -> TailL/R (coat tails)

Eyes, Pupils and Lids share one grid so they line up exactly: the pupils sit one voxel in front of the whites (they
dart about), the lids fill the sockets and are hidden until he blinks. Tags (palette): "glass" (the monocle lens).

    python3 tools/blender/voxel/mayor.py luau      writes src/shared/MayorShape.luau (FULL and LITE)
    python3 tools/blender/voxel/mayor.py stats     box counts only
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sculptkit import (  # noqa: E402
    A, Palette, Sculpt, bez, box, cone, cyl, ellipsoid, greedy, noise, rot, sphere, torus, write_luau,
)

# ---------------------------------------------------------------------------------------------------------------
# joints (model space, rest pose: arms hanging straight down; client/MayorRig adds the slight A-pose)
# ---------------------------------------------------------------------------------------------------------------
ROOT = (0.0, 1.95, 0.05)  # pelvis (LowerTorso)
WAIST = (0.0, 2.42, 0.02)
NECK = (0.0, 4.30, 0.0)
SHOULDER = (1.12, 4.0, 0.06)  # right; the left is mirrored
ELBOW_DROP = 0.78
WRIST_DROP = 0.70
HIP = (0.42, 1.62, 0.05)
KNEE_DROP = 0.62
ANKLE_DROP = 0.58
JAW = (0.0, 4.98, -0.02)
STACHE = (0.0, 5.06, -0.96)
BROW = (0.32, 5.76, -0.86)
EYES = (0.0, 5.47, -0.9)
HAT = (0.0, 6.06, 0.0)
TAIL = (0.30, 2.30, 0.70)
MEDAL_TOP = (0.0, 3.34, None)  # z: just in front of the chest (found once the torso is sculpted)

FACE = (0.0, 5.3, -0.95)
EYE_C = {-1: (-0.31, 5.48, -0.78), 1: (0.31, 5.48, -0.78)}  # the whites' centres  # what close-ups aim at (between the eyes and the nose), model space

# ---------------------------------------------------------------------------------------------------------------
# palette
# ---------------------------------------------------------------------------------------------------------------
PAL = Palette()
SKIN = PAL.mat([(206, 140, 110), (224, 160, 126), (238, 178, 142), (248, 194, 158), (255, 210, 176)], noise=0.06, fine=0.0, edge=0.05, ao=1.3, top=0.35)
ROSY = PAL.mat([(214, 118, 104), (230, 136, 118), (242, 154, 134), (250, 172, 150)], noise=0.2, fine=0.08, edge=0.2, ao=1.1, top=0.4)
NOSE = PAL.mat([(212, 112, 98), (228, 130, 112), (240, 150, 128), (250, 170, 148), (255, 192, 170)], noise=0.12, edge=0.35, ao=1.2, top=0.7)
HAIR = PAL.mat([(176, 180, 190), (198, 202, 212), (218, 221, 230), (234, 236, 243), (248, 249, 252)], noise=0.3, fine=0.3, edge=0.3, ao=1.2, top=0.7)
WHITE_EYE = PAL.mat([(226, 228, 236), (244, 245, 250)], noise=0.1, edge=0.0, ao=0.6, top=0.3)
PUPIL = PAL.mat([(26, 20, 30)])
SHINE = PAL.mat([(255, 255, 255)])
LID = PAL.mat([(216, 150, 118), (232, 168, 132), (244, 186, 150)], noise=0.15, edge=0.1, ao=0.8, top=0.5)
LASH = PAL.mat([(70, 44, 44)])
MOUTH = PAL.mat([(64, 18, 26)])
LIP = PAL.mat([(196, 104, 100), (214, 122, 114)], noise=0.1, ao=0.6)
COAT = PAL.mat([(84, 16, 28), (102, 22, 36), (122, 28, 42), (140, 36, 50), (158, 46, 58), (176, 60, 68)], noise=0.15, fine=0.05, edge=0.1, ao=1.3, top=0.3)
VELVET = PAL.mat([(62, 10, 22), (76, 14, 28), (92, 20, 34), (108, 26, 40)], noise=0.25, fine=0.1, edge=0.35, ao=1.0, top=0.5)
GOLD = PAL.mat([(140, 92, 20), (176, 124, 28), (210, 160, 44), (238, 196, 80), (252, 226, 140), (255, 246, 200)], noise=0.45, fine=0.25, edge=0.9, ao=1.2, top=0.9)
VEST = PAL.mat([(186, 168, 132), (204, 188, 152), (220, 206, 172), (234, 222, 192), (244, 236, 212)], noise=0.12, fine=0.05, edge=0.1, ao=1.2, top=0.25)
VEST_PAT = PAL.mat([(176, 160, 124), (194, 178, 142), (208, 194, 160), (220, 208, 178)], noise=0.1, edge=0.1, ao=1.2, top=0.25)
SHIRT = PAL.mat([(214, 216, 222), (230, 232, 238), (244, 245, 249), (252, 252, 254)], noise=0.15, edge=0.3, ao=1.0, top=0.5)
BOW = PAL.mat([(18, 84, 42), (26, 106, 54), (36, 128, 66), (50, 150, 80)], noise=0.2, edge=0.4, ao=1.0, top=0.6)
TROUSER = PAL.mat([(38, 38, 48), (46, 46, 58), (54, 54, 68), (64, 64, 80), (76, 76, 94)], noise=0.15, fine=0.05, edge=0.1, ao=1.2, top=0.3)
STRIPE = PAL.mat([(84, 84, 102), (98, 98, 118)], noise=0.15, ao=0.6)
SPATS = PAL.mat([(206, 202, 190), (222, 218, 206), (236, 233, 224), (246, 244, 238)], noise=0.15, edge=0.3, ao=1.0, top=0.5)
SHOE = PAL.mat([(14, 12, 16), (22, 20, 26), (32, 30, 38), (46, 44, 54), (70, 68, 82), (112, 110, 128)], noise=0.15, fine=0.1, edge=0.7, ao=1.0, top=1.2)
SOLE = PAL.mat([(40, 28, 22), (54, 38, 30)], noise=0.1)
BUTTON_DARK = PAL.mat([(30, 26, 30)])
HATC = PAL.mat([(16, 14, 20), (22, 20, 28), (30, 28, 38), (40, 38, 50), (54, 52, 66), (76, 74, 92)], noise=0.08, fine=0.0, edge=0.2, ao=1.0, top=0.8)
GRASS = PAL.mat([(44, 120, 40), (62, 150, 50), (84, 178, 62), (110, 204, 80)], noise=0.3, edge=0.4, ao=0.8, top=0.8)
GLOVE = PAL.mat([(200, 202, 210), (218, 220, 228), (234, 236, 242), (246, 247, 251), (255, 255, 255)], noise=0.15, fine=0.08, edge=0.35, ao=1.25, top=0.6)
GOLD_D = PAL.mat([(112, 72, 16), (140, 96, 22), (170, 122, 30)], noise=0.3, edge=0.6, ao=1.0, top=0.6)
HAT_SHEEN = PAL.mat([(58, 56, 72), (78, 76, 96), (100, 98, 120)], noise=0.25, edge=0.4, ao=0.8, top=0.8)
ENAMEL = PAL.mat([(14, 92, 52), (22, 116, 64), (32, 138, 76)], noise=0.15, edge=0.3, ao=0.8, top=0.5)
GLASS = PAL.mat([(196, 226, 250)], "Glass", "glass")

SHADE = dict(noise=0.3, fine=0.12, edge=0.3, base=0.5, freq=2.2, ao=1.0, top=0.5, aor=2)


def mirror(p, side):
    return (p[0] * side, p[1], p[2])


def add3(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


# ---------------------------------------------------------------------------------------------------------------
# a group: a Sculpt whose shapes are written in model space (S.W: each voxel's model-space centre)
# ---------------------------------------------------------------------------------------------------------------
# Half-voxel grid phases: groups that overlap a neighbour (a joint, the moustache on the cheeks, the hat on the head)
# sit half a voxel off it, so their voxel faces never share a plane (no flicker). The jaw and the eyes instead sit
# exactly on the head's grid (their pivots snapped to it): they fill holes cut in the head.
PHASE = {
    "UpperTorso": 0.5, "Stache": 0.5, "BrowL": 0.5, "BrowR": 0.5, "Hat": 0.5, "Medal": 0.5, "TailL": 0.5, "TailR": 0.5,
    "LeftLowerArm": 0.5, "RightLowerArm": 0.5, "LeftUpperLeg": 0.5, "RightUpperLeg": 0.5, "LeftFoot": 0.5, "RightFoot": 0.5,
}
ON_HEAD_GRID = ("Jaw", "Eyes", "Pupils", "Lids")


class G(Sculpt):
    def __init__(self, name, pivot, lo, hi, v, parent=None, parent_pivot=(0, 0, 0), seed=1, shade=None, key=None):
        key = key or name
        pv = A(pivot)
        if key in ON_HEAD_GRID:
            pv = A(NECK) + np.round((pv - A(NECK)) / v) * v
        super().__init__(PAL, name, A(lo) - pv, A(hi) - pv, v, tuple(pv - A(parent_pivot)), parent, seed, dict(SHADE, **(shade or {})), PHASE.get(key, 0.0))
        self.model_pivot = pv
        self.W = self.P + pv

    def front_at(self, x, y):
        """Model-space z where this group's solid starts, coming from the front (-z), at model (x, y)."""
        z = self.front(x - self.model_pivot[0], y - self.model_pivot[1], -6, 6)
        return None if z is None else z + self.model_pivot[2]

    def nearest(self, p):
        """A mask with just the solid voxel nearest model point p."""
        d = np.linalg.norm(self.W - A(p), axis=1)
        d = np.where(self.D <= 0, d, 1e9)
        m = np.zeros(len(d), bool)
        m[int(np.argmin(d))] = True
        return m


def tcyl(P, c, y0, y1, r0, r1, sx=1.0, sz=1.0, rr=0.0):
    """A flat-ended cylinder along y from y0 to y1, radius r0 -> r1 (elliptical: x * sx, z * sz), edges rounded."""
    q = P - A(c)
    h = q[:, 1]
    t = np.clip((h - y0) / max(y1 - y0, 1e-9), 0, 1)
    r = r0 + (r1 - r0) * t
    rad = np.sqrt((q[:, 0] / sx) ** 2 + (q[:, 2] / sz) ** 2) - (r - rr)
    mid, half = (y0 + y1) / 2, (y1 - y0) / 2
    d = np.stack([rad, np.abs(h - mid) - (half - rr)], 1)
    return np.linalg.norm(np.maximum(d, 0), axis=1) + np.minimum(d.max(axis=1), 0) - rr


def shell_of(d, thick):
    """A skin of thickness `thick` just outside the surface of distance field d."""
    return np.maximum(d - thick, -d)


def tube_d(P, pts, r0, r1, n=14):
    """Distance to a tapering tube along a cubic bezier (4 points)."""
    out = np.full(len(P), 1e9)
    for i in range(n):
        t0, t1 = i / n, (i + 1) / n
        out = np.minimum(out, cone(P, bez(pts, t0), bez(pts, t1), r0 + (r1 - r0) * t0, r0 + (r1 - r0) * t1))
    return out


def tube_t(P, pts, n=24):
    """For each point, the bezier parameter (0..1) of the nearest point on the curve (for painting along it)."""
    best = np.full(len(P), 1e9)
    tt = np.zeros(len(P))
    for i in range(n + 1):
        t = i / n
        d = np.linalg.norm(P - bez(pts, t), axis=1)
        sel = d < best
        best = np.where(sel, d, best)
        tt = np.where(sel, t, tt)
    return tt


# ---------------------------------------------------------------------------------------------------------------
# the body
# ---------------------------------------------------------------------------------------------------------------
def opening_halfwidth(y):
    """Half the width of the coat's front opening (the waistcoat shows through) at height y."""
    return 0.15 + np.clip(4.06 - y, 0, None) * 0.31


def upper_torso(v):
    S = G("UpperTorso", WAIST, (-1.45, 1.85, -1.35), (1.45, 4.55, 1.25), v, "LowerTorso", ROOT, seed=11)
    W = S.W
    belly = ellipsoid(W, (0, 2.98, -0.12), (1.07, 0.98, 1.0))
    chest = ellipsoid(W, (0, 3.72, 0.0), (0.97, 0.72, 0.78))
    back = ellipsoid(W, (0, 3.6, 0.22), (0.92, 0.85, 0.66))
    S.add(belly, COAT)
    S.add(chest, COAT, 0.3)
    S.add(back, COAT, 0.25)
    for side in (-1, 1):
        S.add(sphere(W, (side * 0.86, 3.98, 0.05), 0.36), COAT, 0.22)
    S.add(cyl(W, (0, 3.95, 0.02), (0, 4.42, 0.02), 0.34), SKIN, 0.05)  # (the neck, mostly under the collar)
    # front opening: the waistcoat below, the shirt at the top; velvet lapels and gold piping along the edges
    x, y, z = W[:, 0], W[:, 1], W[:, 2]
    hw = opening_halfwidth(y)
    front = z < -0.15
    inside = front & (np.abs(x) < hw) & (y < 4.12) & (y > 2.0)
    S.paint(inside & (y < 3.9), VEST)
    S.paint(inside & (y >= 3.9), SHIRT)
    # velvet lapels: raised plates beside the opening, chest height
    body = S.D.copy()
    lap_region = np.maximum.reduce([hw - np.abs(x), np.abs(x) - (hw + 0.24), 3.3 - y, y - 4.16, z + 0.12])
    S.add(np.maximum(body - 0.11, lap_region), VELVET)
    # waistcoat buttons
    for by in (2.55, 2.86, 3.17, 3.48):
        zf = S.front_at(0.0, by)
        if zf is not None:
            S.add(sphere(W, (0, by, zf + 0.02), 0.075), GOLD)
    # a pocket watch chain across the waistcoat, from the third button to the left pocket
    watch = [(0.0, 3.17, None), (-0.12, 2.96, None), (-0.28, 2.88, None), (-0.44, 2.95, None)]
    watch = [(px, py, (S.front_at(px, py) or -1.0)) for (px, py, _) in watch]
    S.paint(tube_d(W, watch, 0.075, 0.075, 12) < 0, GOLD, depth=v * 1.5)
    # the waistcoat's two points below the belly
    for side in (-1, 1):
        S.add(box(W, (side * 0.17, 2.03, -0.66), (0.17, 0.11, 0.07), rot(-18, 0, side * 30)), VEST, 0.03)
    # the shirt collar's wing tips and the green bow tie
    zn = -0.36
    for side in (-1, 1):
        S.add(box(W, (side * 0.12, 4.3, zn - 0.04), (0.1, 0.06, 0.04), rot(0, 0, side * -35)), SHIRT)
        S.add(box(W, (side * 0.17, 4.14, zn - 0.1), (0.13, 0.09, 0.05), rot(0, 0, side * 14)), BOW)
    S.add(sphere(W, (0, 4.15, zn - 0.14), 0.07), BOW)
    # the gold chain of office: shoulders down to the medal, a link pattern painted along it
    pts_l = [(-0.66, 4.24, -0.22), (-0.72, 3.9, -0.62), (-0.42, 3.42, None), (0.0, 3.32, None)]

    def on_surface(pts):
        out = []
        for (px, py, pz) in pts:
            if pz is None:
                zf = S.front_at(px, py)
                pz = (zf if zf is not None else -0.9) - 0.03
            out.append((px, py, pz))
        return out

    for side in (-1, 1):
        pts = on_surface([(px * side, py, pz) for (px, py, pz) in pts_l])
        d = tube_d(W, pts, 0.085, 0.08, 18)
        S.add(d, GOLD)
        t = tube_t(W, pts, 40)
        links = (np.floor(t * 12) % 2 == 0) & (d < 0.03)
        S.paint(links, GOLD_D)
    # the coat's back seam and the buttons above the tails
    for side in (-1, 1):
        S.add(sphere(W, (side * 0.22, 2.42, 0.98), 0.07), GOLD)
    return S


def lower_torso(v):
    S = G("LowerTorso", ROOT, (-1.2, 1.2, -1.05), (1.2, 2.6, 1.1), v, None, (0, 0, 0), seed=12)
    W = S.W
    x, y, z = W[:, 0], W[:, 1], W[:, 2]
    S.add(ellipsoid(W, (0, 1.95, 0.04), (0.84, 0.56, 0.68)), TROUSER)
    # pinstripes
    S.paint((np.abs((x * 9.0) % 1.0 - 0.5) < 0.07), STRIPE, depth=v * 1.5)
    # the frock coat's skirt: sides and back only (cut away at the front)
    outer = ellipsoid(W, (0, 2.06, 0.08), (1.0, 0.58, 0.84))
    cut = np.maximum(np.abs(x) - (0.42 + (2.45 - y) * 0.55), z + 0.12)  # the cutaway front
    skirt = np.maximum.reduce([outer, 1.52 - y, -cut])
    S.add(skirt, COAT)
    S.paint((np.abs(skirt) < 0.12) & (y < 1.62), VELVET)  # (a darker hem)
    return S


def coat_tail(v, side):
    pv = mirror(TAIL, side)
    S = G("TailL" if side < 0 else "TailR", pv, (pv[0] - 0.45, 0.85, 0.45), (pv[0] + 0.45, 2.45, 1.25), v, "LowerTorso", ROOT, seed=13 + side)
    W = S.W
    for i, (y0, y1, ang) in enumerate([(2.38, 1.9, 6), (1.95, 1.45, 11), (1.5, 1.05, 16)]):
        cy = (y0 + y1) / 2
        w = 0.27 - i * 0.03
        S.add(box(W, (pv[0] + side * 0.02 * i, cy, 0.78 + i * 0.09), (w, (y0 - y1) / 2 + 0.04, 0.07), rot(-ang, 0, side * (3 + i * 2)), 0.03), COAT, 0.05)
    S.paint(W[:, 1] < 1.14, VELVET)  # (the lining shows at the tip)
    return S


def medal(v, chest_z):
    top = (0.0, 3.32, chest_z - 0.06)
    S = G("Medal", top, (-0.42, 2.7, top[2] - 0.25), (0.42, 3.45, top[2] + 0.2), v, "UpperTorso", WAIST, seed=14)
    W = S.W
    c = (0.0, 3.06, top[2] - 0.04)
    R = rot(90, 0, 0)  # disc facing forward
    S.add(torus(W, (0, 3.33, top[2]), 0.06, 0.025, R), GOLD)  # the ring it hangs from
    disc = tcyl((W - A(c)) @ R + A(c), c, -0.05, 0.05, 0.27, 0.27, rr=0.02)
    S.add(disc, GOLD)
    S.add(torus(W, (c[0], c[1], c[2] - 0.05), 0.24, 0.035, R), GOLD)  # the raised rim
    enamel = sphere(W, (c[0], c[1], c[2] - 0.05), 0.19)
    S.paint(enamel < 0, ENAMEL, depth=v * 1.6)
    # the valley's emblem: a gold clover
    for k in range(3):
        a = math.radians(90 + k * 120)
        S.add(sphere(W, (c[0] + math.cos(a) * 0.065, c[1] + 0.02 + math.sin(a) * 0.065, c[2] - 0.07), 0.058), GOLD)
    S.add(cone(W, (c[0], c[1] - 0.02, c[2] - 0.07), (c[0] + 0.05, c[1] - 0.15, c[2] - 0.07), 0.022, 0.016), GOLD)
    return S


# ---------------------------------------------------------------------------------------------------------------
# the head
# ---------------------------------------------------------------------------------------------------------------
HV = None  # head voxel size (set per level of detail)


def face_volume(W):
    skull = ellipsoid(W, (0, 5.3, 0.0), (0.92, 0.98, 0.9))
    face = ellipsoid(W, (0, 5.06, -0.34), (0.8, 0.72, 0.62))
    d = np.minimum(skull, face)
    h = np.clip(0.5 + 0.5 * (skull - face) / 0.2, 0, 1)
    d = face * h + skull * (1 - h) - 0.2 * h * (1 - h)
    for side in (-1, 1):
        ch = sphere(W, (side * 0.47, 4.92, -0.55), 0.36)
        h = np.clip(0.5 + 0.5 * (d - ch) / 0.15, 0, 1)
        d = ch * h + d * (1 - h) - 0.15 * h * (1 - h)
    return d


def jaw_volume(W):
    lower = np.maximum.reduce([face_volume(W), W[:, 1] - 4.86, W[:, 2] + 0.3, np.abs(W[:, 0]) - 0.42])
    chin = ellipsoid(W, (0, 4.62, -0.55), (0.4, 0.24, 0.36))
    return np.minimum(lower, chin)


def head(v):
    S = G("Head", NECK, (-1.1, 4.25, -1.3), (1.1, 6.35, 1.05), v, "UpperTorso", WAIST, seed=21)
    W = S.W
    S.add(face_volume(W), SKIN)
    # ears
    for side in (-1, 1):
        S.add(ellipsoid(W, (side * 0.9, 5.25, 0.06), (0.12, 0.22, 0.16)), SKIN, 0.05)
        S.carve(ellipsoid(W, (side * 0.97, 5.25, 0.03), (0.05, 0.12, 0.08)), ROSY)
    # a soft blush on the apples of the cheeks
    for side in (-1, 1):
        S.paint(sphere(W, (side * 0.6, 4.96, -0.8), 0.15) < 0, ROSY, depth=v * 2.5)
    # the nose: big, round and rosy, well clear of the cheeks
    S.add(sphere(W, (0, 5.2, -1.08), 0.25), NOSE, 0.03)
    S.add(ellipsoid(W, (0, 5.36, -0.96), (0.12, 0.18, 0.14)), NOSE, 0.04)
    # eye sockets (the whites sit in them)
    for side in (-1, 1):
        S.carve(ellipsoid(W, EYE_C[side], (0.22, 0.245, 0.14)), SKIN)
    # the mouth: a recess where the jaw sits, dark inside
    jv = jaw_volume(W)
    S.carve(jv)
    inner = (jv > 0) & (jv < 1.6 * v) & (S.D <= 0) & (np.abs(W[:, 0]) < 0.36) & (W[:, 1] > 4.4) & (W[:, 1] < 4.93)
    S.paint(inner, MOUTH)
    S.add(box(W, (0, 4.74, -0.42), (0.34, 0.12, 0.14)), MOUTH)
    # white hair round the back of the head (bald on top, under the hat)
    for side in (-1, 1):
        S.add(ellipsoid(W, (side * 0.78, 5.22, 0.42), (0.17, 0.28, 0.32)) + noise(W, 9, 3 + side) * 0.03, HAIR, 0.05)
    S.add(ellipsoid(W, (0, 5.2, 0.68), (0.66, 0.32, 0.24)) + noise(W, 9, 5) * 0.03, HAIR, 0.05)
    for side in (-1, 1):
        S.add(ellipsoid(W, (side * 0.86, 5.5, 0.1), (0.14, 0.2, 0.3)) + noise(W, 11, 6 + side) * 0.03, HAIR, 0.06)
    # the monocle on his right eye: a gold ring and the lens, and its fine chain down to the collar
    R = rot(90, 0, 0)
    ex, ey, ez = EYE_C[1]
    S.add(torus(W, (ex, ey, -1.02), 0.25, 0.038, R), GOLD)
    S.add(np.maximum(sphere(W, (ex, ey, -1.02), 0.225), np.abs(W[:, 2] + 1.02) - v * 0.5), GLASS)
    S.add(tube_d(W, [(ex + 0.2, ey - 0.08, -1.0), (ex + 0.32, ey - 0.3, -0.88), (ex + 0.36, ey - 0.56, -0.72), (ex + 0.3, ey - 0.86, -0.52)], 0.024, 0.024, 10), GOLD)
    return S


def jaw(v):
    S = G("Jaw", JAW, (-0.65, 4.3, -1.05), (0.65, 4.95, 0.1), v, "Head", NECK, seed=22)
    W = S.W
    S.add(jaw_volume(W) + 0.0, SKIN)
    S.paint((W[:, 1] > 4.74) & (W[:, 2] < -0.6), LIP, depth=v * 2)
    for side in (-1, 1):
        S.paint(sphere(W, (side * 0.5, 4.86, -0.84), 0.2) < 0, ROSY, depth=v * 2)
    return S


def stache(v):
    S = G("Stache", STACHE, (-1.15, 4.6, -1.35), (1.15, 5.6, -0.4), v, "Head", NECK, seed=23)
    W = S.W
    for side in (-1, 1):
        lobe = [(side * 0.03, 5.0, -1.1), (side * 0.3, 4.86, -1.08), (side * 0.6, 4.88, -0.9), (side * 0.8, 5.08, -0.7)]
        curl = [(side * 0.8, 5.08, -0.7), (side * 0.98, 5.3, -0.62), (side * 0.88, 5.42, -0.66), (side * 0.78, 5.3, -0.7)]
        d = np.minimum(tube_d(W, lobe, 0.16, 0.06, 16), tube_d(W, curl, 0.06, 0.03, 12))
        d = np.minimum(d, ellipsoid(W, (side * 0.2, 4.97, -1.07), (0.25, 0.13, 0.13)))
        S.add(d + noise(W, 16, 7) * 0.012, HAIR, 0.06)
    return S


def brow(v, side):
    pv = mirror(BROW, side)
    S = G("BrowL" if side < 0 else "BrowR", pv, (pv[0] - 0.45, 5.5, -1.15), (pv[0] + 0.45, 6.05, -0.4), v, "Head", NECK, seed=24 + side)
    W = S.W
    pts = [(side * 0.12, 5.72, -0.94), (side * 0.27, 5.81, -0.92), (side * 0.45, 5.8, -0.82), (side * 0.58, 5.69, -0.68)]
    d = tube_d(W, pts, 0.095, 0.06, 12) + noise(W, 14, 9 + side) * 0.02
    S.add(d, HAIR)
    S.add(cone(W, (side * 0.16, 5.77, -0.95), (side * 0.1, 5.9, -0.96), 0.045, 0.02), HAIR, 0.03)
    return S


def eyes_group(v, which):
    """The whites, the pupils and the lids, all on one grid (lo / hi / v alike) so they line up voxel for voxel."""
    lo, hi = (-0.62, 5.15, -1.2), (0.62, 5.85, -0.55)
    name = {"whites": "Eyes", "pupils": "Pupils", "lids": "Lids"}[which]
    S = G(name, EYES, lo, hi, v, "Head", NECK, seed=27)
    W = S.W
    whites = np.full(len(W), 1e9)
    for side in (-1, 1):
        whites = np.minimum(whites, ellipsoid(W, EYE_C[side], (0.19, 0.22, 0.12)))
    if which == "whites":
        S.add(whites, WHITE_EYE)
        return S
    if which == "lids":
        # a closed eye: the socket filled with skin, a lash line curving down (a contented squint)
        S.add(whites, LID)
        for side in (-1, 1):
            cx, cy = EYE_C[side][0], EYE_C[side][1]
            line = np.abs(W[:, 1] - (cy - 0.03 - ((W[:, 0] - cx) / 0.19) ** 2 * 0.08)) < v * 0.6
            S.paint(line & (np.abs(W[:, 0] - cx) < 0.19), LASH, depth=v * 1.2)
        return S
    # pupils: one voxel in front of each white, with a catchlight
    T = G("tmp", EYES, lo, hi, v, "Head", NECK, key="Eyes")
    T.add(whites, WHITE_EYE)
    occ = np.zeros(tuple(T.n), bool)
    solid = T.D <= 0
    occ[tuple(T.idx[solid].T)] = True
    D = np.full(len(W), 1e9)
    nx, ny, nz = T.n
    for side in (-1, 1):
        c = (EYE_C[side][0], EYE_C[side][1] - 0.02)
        for ix in range(nx):
            for iy in range(ny):
                px = T.lo[0] + (ix + 0.5) * v + EYES[0]
                py = T.lo[1] + (iy + 0.5) * v + EYES[1]
                if ((px - c[0]) / 0.1) ** 2 + ((py - c[1]) / 0.125) ** 2 > 1.0:
                    continue
                col = occ[ix, iy, :]
                if not col.any():
                    continue
                k = int(np.argmax(col)) - 1  # one cell in front of the white
                if k < 0:
                    continue
                D[(ix * ny + iy) * nz + k] = -1.0
    S.add(D, PUPIL)
    for side in (-1, 1):
        S.paint(S.nearest((EYE_C[side][0] - 0.04, EYE_C[side][1] + 0.03, -1.0)), SHINE)
    return S


def hat(v):
    S = G("Hat", HAT, (-1.25, 5.9, -1.2), (1.25, 7.8, 1.2), v, "Head", NECK, seed=31)
    W = S.W
    # the brim, curling up at the sides
    q = W.copy()
    q[:, 1] = q[:, 1] - 0.13 * (q[:, 0] / 1.08) ** 2
    S.add(ellipsoid(q, (0, 6.06, 0.0), (1.08, 0.065, 0.98)), HATC)
    # the crown: tall, flaring a touch toward the top
    S.add(tcyl(W, (0, 0, 0), 6.06, 7.62, 0.68, 0.75, 1.0, 0.92, rr=0.05), HATC, 0.04)
    # the gold band and a sprig of grass tucked into it
    band = np.maximum(tcyl(W, (0, 0, 0), 6.12, 6.38, 0.75, 0.765, 1.0, 0.92), -tcyl(W, (0, 0, 0), 6.0, 6.5, 0.62, 0.62, 1.0, 0.92))
    S.add(band, GOLD)
    for i, (dx, h, lean) in enumerate([(-0.05, 0.62, -0.18), (0.05, 0.78, 0.0), (0.14, 0.58, 0.2)]):
        base = (0.6 + dx, 6.24, -0.38)
        tip = (0.78 + dx + lean, 6.24 + h, -0.46 - abs(lean) * 0.4)
        mid = ((base[0] + tip[0]) / 2 + 0.06, (base[1] + tip[1]) / 2, (base[2] + tip[2]) / 2 - 0.05)
        S.add(tube_d(W, [base, mid, mid, tip], 0.07, 0.03, 8), GRASS)
    for k in range(3):
        a = k * 2.094
        S.add(sphere(W, (0.62 + math.cos(a) * 0.07, 6.32 + math.sin(a) * 0.07, -0.47), 0.065), GRASS)
    # a sheen down the crown (the light catching the silk)
    S.paint((np.abs(W[:, 0] + 0.3) < 0.08) & (W[:, 2] < -0.3) & (W[:, 1] > 6.44) & (W[:, 1] < 7.5), HAT_SHEEN, depth=v * 1.5)
    return S


# ---------------------------------------------------------------------------------------------------------------
# arms and legs (hanging straight down in the rest pose)
# ---------------------------------------------------------------------------------------------------------------
def upper_arm(v, side):
    sh = mirror(SHOULDER, side)
    el = add3(sh, (0, -ELBOW_DROP, 0))
    S = G(("Left" if side < 0 else "Right") + "UpperArm", sh, (sh[0] - 0.45, el[1] - 0.15, -0.45), (sh[0] + 0.45, sh[1] + 0.45, 0.55), v, "UpperTorso", WAIST, seed=41 + side)
    W = S.W
    S.add(sphere(W, sh, 0.33), COAT)
    S.add(cone(W, sh, el, 0.31, 0.275), COAT, 0.08)
    return S


def lower_arm(v, side):
    sh = mirror(SHOULDER, side)
    el = add3(sh, (0, -ELBOW_DROP, 0))
    wr = add3(el, (0, -WRIST_DROP, -0.02))
    S = G(("Left" if side < 0 else "Right") + "LowerArm", el, (el[0] - 0.45, wr[1] - 0.12, -0.45), (el[0] + 0.45, el[1] + 0.32, 0.5), v, ("Left" if side < 0 else "Right") + "UpperArm", sh, seed=43 + side)
    W = S.W
    S.add(sphere(W, el, 0.27), COAT)
    S.add(cyl(W, el, add3(wr, (0, 0.1, 0)), 0.265), COAT, 0.06)
    # the turned-back velvet cuff with gold piping and two buttons, the shirt cuff peeking out
    cuff = tcyl(W, (el[0], 0, el[2] - 0.01), wr[1] + 0.06, wr[1] + 0.32, 0.33, 0.31, rr=0.03)
    S.add(cuff, VELVET)
    S.paint((np.abs(W[:, 1] - (wr[1] + 0.31)) < 0.04) & (cuff < 0.02), GOLD, depth=v * 2)
    for k in range(2):
        S.add(sphere(W, (el[0] + side * 0.31, wr[1] + 0.13 + k * 0.11, el[2]), 0.045), GOLD)
    S.add(tcyl(W, (wr[0], 0, wr[2]), wr[1] - 0.02, wr[1] + 0.08, 0.235, 0.235, rr=0.02), SHIRT)
    return S


def hand(v, side):
    sh = mirror(SHOULDER, side)
    wr = add3(add3(sh, (0, -ELBOW_DROP, 0)), (0, -WRIST_DROP, -0.02))
    S = G(("Left" if side < 0 else "Right") + "Hand", wr, (wr[0] - 0.35, wr[1] - 0.62, wr[2] - 0.42), (wr[0] + 0.35, wr[1] + 0.1, wr[2] + 0.35), v, ("Left" if side < 0 else "Right") + "LowerArm", add3(sh, (0, -ELBOW_DROP, 0)), seed=45 + side)
    W = S.W
    cx, cy, cz = wr
    # the glove's puffy cuff
    S.add(tcyl(W, (cx, 0, cz), cy - 0.1, cy + 0.04, 0.22, 0.2, rr=0.04), GLOVE)
    # palm (flat side toward the body), three plump fingers and a thumb in front
    S.add(ellipsoid(W, (cx, cy - 0.25, cz), (0.14, 0.17, 0.2)), GLOVE, 0.05)
    for k, dz in enumerate((-0.11, 0.0, 0.11)):
        S.add(cone(W, (cx, cy - 0.32, cz + dz), (cx - side * 0.02, cy - 0.5 + abs(dz) * 0.4, cz + dz * 1.1), 0.07, 0.06), GLOVE, 0.03)
    S.add(cone(W, (cx - side * 0.04, cy - 0.2, cz - 0.16), (cx - side * 0.1, cy - 0.34, cz - 0.27), 0.065, 0.055), GLOVE, 0.03)
    # the three stitched lines on the back of the glove
    S.paint((np.abs(W[:, 2] - cz) < 0.11) & (np.abs(((W[:, 2] - cz) / 0.055) % 2 - 1) < 0.25) & (W[:, 1] > cy - 0.3) & (W[:, 1] < cy - 0.12) & ((W[:, 0] - cx) * side > 0.08), GLOVE)
    return S


def upper_leg(v, side):
    hp = mirror(HIP, side)
    kn = add3(hp, (side * 0.01, -KNEE_DROP, -0.01))
    S = G(("Left" if side < 0 else "Right") + "UpperLeg", hp, (hp[0] - 0.45, kn[1] - 0.12, -0.45), (hp[0] + 0.45, hp[1] + 0.25, 0.5), v, "LowerTorso", ROOT, seed=51 + side)
    W = S.W
    S.add(cone(W, hp, kn, 0.33, 0.28), TROUSER)
    S.paint((np.abs((W[:, 0] * 9.0) % 1.0 - 0.5) < 0.07), STRIPE, depth=v * 1.5)
    return S


def lower_leg(v, side):
    hp = mirror(HIP, side)
    kn = add3(hp, (side * 0.01, -KNEE_DROP, -0.01))
    an = add3(kn, (side * 0.01, -ANKLE_DROP, 0.0))
    S = G(("Left" if side < 0 else "Right") + "LowerLeg", kn, (kn[0] - 0.42, an[1] - 0.2, -0.45), (kn[0] + 0.42, kn[1] + 0.25, 0.45), v, ("Left" if side < 0 else "Right") + "UpperLeg", hp, seed=53 + side)
    W = S.W
    S.add(sphere(W, kn, 0.28), TROUSER)
    S.add(cone(W, kn, add3(an, (0, 0.35, 0)), 0.28, 0.25), TROUSER, 0.05)
    S.add(cyl(W, add3(an, (0, 0.35, 0)), add3(an, (0, 0.05, 0)), 0.25), TROUSER, 0.04)
    S.paint((np.abs((W[:, 0] * 9.0) % 1.0 - 0.5) < 0.07), STRIPE, depth=v * 1.5)
    # white spats over the ankle, buttoned on the outside
    sp = tcyl(W, (an[0], 0, an[2] - 0.02), an[1] - 0.16, an[1] + 0.18, 0.265, 0.245, rr=0.03)
    S.add(sp, SPATS)
    for k in range(3):
        S.add(sphere(W, (an[0] + side * 0.26, an[1] - 0.08 + k * 0.1, an[2] - 0.02), 0.035), BUTTON_DARK)
    return S


def foot(v, side):
    hp = mirror(HIP, side)
    an = add3(add3(hp, (side * 0.01, -KNEE_DROP, -0.01)), (side * 0.01, -ANKLE_DROP, 0.0))
    S = G(("Left" if side < 0 else "Right") + "Foot", an, (an[0] - 0.4, -0.05, -0.9), (an[0] + 0.4, an[1] + 0.12, 0.5), v, ("Left" if side < 0 else "Right") + "LowerLeg", add3(hp, (side * 0.01, -KNEE_DROP, -0.01)), seed=55 + side)
    W = S.W
    x0, z0 = an[0], an[2]
    # the shoe: a rounded body from heel to a round toe, a polished cap, the sole and heel
    S.add(box(W, (x0, 0.19, z0 - 0.12), (0.25, 0.15, 0.38), None, 0.12), SHOE)
    S.add(ellipsoid(W, (x0 + side * 0.01, 0.16, z0 - 0.5), (0.27, 0.16, 0.24)), SHOE, 0.08)
    S.add(box(W, (x0, 0.04, z0 - 0.14), (0.27, 0.045, 0.52), None, 0.04), SOLE, 0.02)
    S.add(box(W, (x0, 0.09, z0 + 0.2), (0.22, 0.09, 0.13), None, 0.03), SOLE)
    S.add(cyl(W, (x0, an[1] - 0.25, z0), (x0, an[1] + 0.05, z0), 0.23), SPATS, 0.04)
    return S


# ---------------------------------------------------------------------------------------------------------------
# the whole figure
# ---------------------------------------------------------------------------------------------------------------
def sculpts(body_v=0.1, head_v=0.075, limb_v=0.09, fine_v=0.05):
    ut = upper_torso(body_v)
    chest_z = ut.front_at(0.0, 3.32) or -0.95
    out = [
        lower_torso(body_v),
        ut,
        medal(fine_v, chest_z),
        coat_tail(body_v, -1),
        coat_tail(body_v, 1),
        head(head_v),
        jaw(head_v),
        stache(head_v),
        brow(head_v, -1),
        brow(head_v, 1),
        eyes_group(head_v, "whites"),
        eyes_group(head_v, "pupils"),
        eyes_group(head_v, "lids"),
        hat(limb_v),
    ]
    for side in (-1, 1):
        out += [upper_arm(limb_v, side), lower_arm(limb_v, side), hand(limb_v * 0.8, side)]
    for side in (-1, 1):
        out += [upper_leg(limb_v, side), lower_leg(limb_v, side), foot(limb_v, side)]
    return out


LEVELS = {
    "FULL": dict(body_v=0.1, head_v=0.065, limb_v=0.09, fine_v=0.05),
    "LITE": dict(body_v=0.15, head_v=0.1, limb_v=0.13, fine_v=0.08),
}


def extra_lines():
    return {
        "FACE": "Vector3.new(%s, %s, %s)" % FACE,
        "HEIGHT": "7.62",
    }


def luau(path):
    """Writes both levels of detail into one module: { FULL = {...}, LITE = {...} } sharing one palette."""
    tmp = []
    totals = {}
    for lvl, kw in LEVELS.items():
        p = path + "." + lvl
        totals[lvl] = write_luau(p, "mayor.py", PAL, sculpts(**kw), extra_lines())
        tmp.append((lvl, open(p).read()))
        os.remove(p)
    # merge: keep the header and palette once, then FULL / LITE group lists
    head_lines = tmp[0][1].split("\n")
    pal_end = head_lines.index("\t},")  # end of PALETTE
    header = head_lines[: pal_end + 1]
    lines = header + ["\tFACE = %s," % extra_lines()["FACE"], "\tHEIGHT = %s," % extra_lines()["HEIGHT"]]
    for lvl, text in tmp:
        L = text.split("\n")
        g0 = L.index("\tGROUPS = {")
        g1 = len(L) - 1 - L[::-1].index("\t},")
        lines.append("\t%s = {" % lvl)
        lines += ["\t" + s for s in L[g0 + 1 : g1]]
        lines.append("\t},")
    lines.append("}")
    open(path, "w").write("\n".join(lines) + "\n")
    print("wrote", path, totals, os.path.getsize(path), "bytes")


def stats():
    for lvl, kw in LEVELS.items():
        total = 0
        for S in sculpts(**kw):
            cg, exposed = S.grid()
            b = greedy(cg, exposed)
            total += len(b)
            print("  %-14s v=%.3f vox %6d boxes %5d" % (S.name, S.v, int((cg > 0).sum()), len(b)))
        print(lvl, total)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "stats"
    if cmd == "luau":
        luau(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "src", "shared", "MayorShape.luau"))
    else:
        stats()
