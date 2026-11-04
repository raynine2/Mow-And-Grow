"""Grass clumps, second look (owner, 4 Nov: "the grass needs to be more appealing in every zone").

The first clumps (models.stalk_clump) were a stalk with a dome on top and 44 arcs, each arc one flat colour picked at
random from two or three close shades: from a few studs away a flat-green ball on a stick, the same shape in every
area ("broccoli"). These keep what the game relies on (the 3 x 3 voxel stalk, STALK_H tall, at x = z = 0, the same
voxel size, so server/Field's collider, the hit tests and client/ClumpWound's carved cut still fit) and change the rest,
following the vault's voxel notes (ramps with hue shifting, baked darkness where it's covered, one accent per area):
  * every blade shades along its length: a dark, cooler foot, two mid steps, a light warm tip (a 5-step ramp per area,
    hue-shifted toward the light), so the clump reads as many blades catching the sun, not one blob;
  * a fountain of thinner blades (68 instead of 44), the inner ones nearly upright, the outer ones arching out and
    down, tips curling; the crown's core darker (baked occlusion);
  * the stalk in vertical stripes of the dark steps, fading up into the crown;
  * the area's own accent at the tips: dandelions (meadow), golden ears (wheat), five-petal flowers (blossom), fern
    leaflets (pine), cattails on taller reeds (swamp), frosted tips and ice shards (frost), glowing ember tips (ember),
    four-point stars (isles).
    clump2(seed, area) -> vox, pal, voxel_size     stubble2(area) -> the same, for the cut stump
"""
import colorsys
import math
import random

STALK_H = 6
STALK_VOXEL = 0.4

# per area: the blade's base colour (its mid tone), how far the hue shifts toward the tip (greens go toward yellow:
# a lower hue; the warm and cold areas their own way), the accent colours
AREA = {
    "meadow": dict(base=(70, 176, 62), shift=-0.04, accent=[(255, 214, 40), (255, 240, 120), (250, 250, 244)]),
    "wheat": dict(base=(222, 164, 52), shift=0.02, accent=[(255, 226, 132), (238, 186, 72), (196, 136, 40)]),
    "blossom": dict(base=(78, 172, 92), shift=-0.035, accent=[(255, 150, 200), (255, 228, 240), (255, 214, 90)]),
    "pine": dict(base=(44, 150, 112), shift=-0.03, accent=[(90, 196, 140), (150, 226, 170)]),
    "swamp": dict(base=(112, 150, 60), shift=-0.03, accent=[(118, 74, 46), (92, 56, 36), (230, 214, 160)]),
    "frost": dict(base=(150, 196, 236), shift=-0.02, accent=[(250, 253, 255), (120, 232, 255)]),
    "ember": dict(base=(78, 62, 68), shift=0.0, accent=[(255, 120, 36), (255, 196, 80)]),
    "isles": dict(base=(150, 112, 236), shift=-0.03, accent=[(120, 240, 255), (240, 250, 255)]),
}


def _hsv(c):
    return colorsys.rgb_to_hsv(*(v / 255 for v in c))


def _rgb(h, s, v):
    r, g, b = colorsys.hsv_to_rgb(h % 1.0, max(0, min(1, s)), max(0, min(1, v)))
    return (int(r * 255), int(g * 255), int(b * 255))


def ramp(area):
    """Five steps foot -> tip: darker, more saturated and hue-shifted away from the light at the foot; lighter, a
    little less saturated and shifted toward the light at the tip."""
    a = AREA[area]
    h, s, v = _hsv(a["base"])
    sh = a["shift"]
    steps = []
    for i, t in enumerate((0.0, 0.3, 0.55, 0.8, 1.0)):
        vv = v * (0.52 + 0.62 * t)
        ss = s * (1.12 - 0.3 * t)
        hh = h + sh * (t - 0.4) * 2
        if area == "frost":
            ss = s * (1.25 - 0.95 * t)  # icy: blue at the foot, nearly white at the tip
            vv = min(1, v * (0.7 + 0.42 * t))
        if area == "ember":
            vv = v * (0.6 + 0.5 * t)
            hh = h - 0.02 * t  # charcoal toward a warm ash
        steps.append(_rgb(hh, ss, vv))
    return steps


def clump2(seed=1, area="meadow"):
    R = random.Random(seed * 7919 + 13)
    steps = ramp(area)
    acc = AREA[area]["accent"]
    pal = steps + list(acc)
    A = len(steps)  # first accent index
    vox = {}
    # roots: a flare round the foot, in the darkest step
    for x in range(-2, 3):
        for z in range(-2, 3):
            if abs(x) == 2 and abs(z) == 2:
                continue
            vox[(x, 0, z)] = 0
    for (dx, dz) in ((3, 0), (-3, 0), (0, 3), (0, -3), (2, 2), (-2, -2), (2, -2)):
        if R.random() < 0.65:
            vox[(dx, 0, dz)] = 0
    # the stalk: stripes of the two dark steps, the top layer a step lighter (fading into the crown)
    H = STALK_H
    for y in range(1, H):
        for x in (-1, 0, 1):
            for z in (-1, 0, 1):
                vox[(x, y, z)] = 0 if (x + z + (y // 2)) % 2 == 0 else 1
    for x in (-1, 0, 1):
        for z in (-1, 0, 1):
            vox[(x, H - 1, z)] = 1
    # the collar: a short dense ring of upright blades (the crown's dark core)
    for x in range(-2, 3):
        for z in range(-2, 3):
            if abs(x) == 2 and abs(z) == 2:
                continue
            for y in range(0, 3):
                vox[(x, H + y, z)] = 1 if y < 2 else 2
    tall = {"swamp": 1.0, "wheat": 0.95}.get(area, 1.0)
    lean_k = {"swamp": 0.55, "wheat": 0.6, "frost": 0.85}.get(area, 1.0)
    tips = []

    def blade(a, r0, y0, L, lean, outer):
        sx, sz = math.cos(a) * r0, math.sin(a) * r0
        last = None
        for y in range(1, L + 1):
            t = y / L
            bend = lean * y * (0.3 + 0.7 * t) ** 1.5
            droop = int(round(max(0.0, t - 0.72) * 7 * outer)) if outer > 0.55 else 0
            px = int(round(sx + math.cos(a) * bend))
            pz = int(round(sz + math.sin(a) * bend))
            p = (px, y0 + y - droop, pz)
            si = min(4, int(t * 4.6))
            if math.hypot(px, pz) < r0 + 0.8 and t < 0.3:
                si = 0  # the base, deep in the tuft: the darkest step (baked occlusion)
            if p not in vox or vox[p] < si:
                vox[p] = si
            last = p
        if last:
            vox[last] = 4
            tips.append((last, a, outer))

    # (the silhouette: a fountain of blades rising from the ground all round the stalk, so it reads as a big tuft of
    # grass, wide at the foot and flaring out, not a ball on a stick; the stalk is still inside for the chopping)
    for i in range(56):
        a = i / 56 * math.pi * 2 + R.uniform(-0.25, 0.25)
        r0 = R.uniform(1.3, 2.5)
        outer = (r0 - 1.3) / 1.2
        L = int(R.uniform(11, 16) * (1.05 - outer * 0.3) * tall)
        lean = (0.14 + outer * 0.34 + R.uniform(0, 0.1)) * lean_k
        blade(a, r0, R.randint(0, 1), L, lean, 0.35 + outer * 0.65)
    # the inner blades out of the collar: the tall upright middle
    for i in range(26):
        a = i / 26 * math.pi * 2 + R.uniform(-0.3, 0.3)
        L = int(R.uniform(7, 11) * tall)
        blade(a, R.uniform(0.2, 1.1), H + 1, L, R.uniform(0.04, 0.2) * lean_k, 0.1)
    _accents(vox, tips, area, A, R)
    return vox, pal, STALK_VOXEL


def _accents(vox, tips, area, A, R):
    def put(p, ci):
        vox[p] = ci

    if area == "meadow":
        # three or four dandelions on their own stems standing out of the crown, one gone to seed
        for k in range(R.randint(3, 4)):
            (x, y, z), a, _ = tips[R.randrange(len(tips))]
            top = y + 2
            for yy in range(y + 1, top):
                put((x, yy, z), 3)
            col = A + 2 if k == 0 else A
            for dx in (0, 1):
                for dz in (0, 1):
                    put((x + dx, top, z + dz), col)
            put((x, top + 1, z), A + 1 if col == A else A + 2)
    elif area == "wheat":
        for (x, y, z), a, outer in tips:
            if R.random() < 0.55:
                for k in range(3):
                    put((x, y + 1 + k, z), A + (k % 2))
                if R.random() < 0.5:  # whiskers
                    put((x + (1 if math.cos(a) > 0 else -1), y + 3, z), A + 2)
    elif area == "blossom":
        for (x, y, z), a, outer in tips:
            if R.random() < 0.3:
                put((x, y + 1, z), A + 2)  # the flower's heart
                for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    put((x + dx, y + 1, z + dz), A if R.random() < 0.7 else A + 1)
    elif area == "pine":
        # fern leaflets: short side shoots along the outer blades
        for (x, y, z), a, outer in tips:
            if outer > 0.4 and R.random() < 0.7:
                ox, oz = -math.sin(a), math.cos(a)
                for s in (-1, 1):
                    put((x + int(round(ox * s)), y - 1, z + int(round(oz * s))), A + (0 if s < 0 else 1))
    elif area == "swamp":
        for (x, y, z), a, outer in tips:
            if outer < 0.5 and R.random() < 0.45:
                for k in range(3):
                    put((x, y + 1 + k, z), A if k < 2 else A + 1)
                put((x, y + 4, z), 3)  # the spike on top
            elif R.random() < 0.08:
                put((x, y + 1, z), A + 2)  # a little white flower
    elif area == "frost":
        for (x, y, z), a, outer in tips:
            put((x, y, z), A)  # frosted tip
            if R.random() < 0.12:  # an ice shard
                for k in range(3):
                    put((x, y + 1 + k, z), A + 1)
    elif area == "ember":
        for (x, y, z), a, outer in tips:
            put((x, y, z), A if R.random() < 0.7 else A + 1)  # glowing tips
            if R.random() < 0.3:
                put((x, y - 1, z), A)
    elif area == "isles":
        for (x, y, z), a, outer in tips:
            if R.random() < 0.25:
                put((x, y + 1, z), A + 1)
                for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    put((x + dx, y + 1, z + dz), A)
            else:
                put((x, y, z), A)


def stubble2(area="meadow"):
    """The cut stump: two layers of striped stalk, a pale cut face, the root flare."""
    steps = ramp(area)
    cut = _rgb(*[_hsv(steps[4])[0], _hsv(steps[4])[1] * 0.45, min(1, _hsv(steps[4])[2] * 1.12)])
    pal = steps + [cut]
    vox = {}
    for x in range(-2, 3):
        for z in range(-2, 3):
            if abs(x) == 2 and abs(z) == 2:
                continue
            vox[(x, 0, z)] = 0
    for x in (-1, 0, 1):
        for z in (-1, 0, 1):
            vox[(x, 1, z)] = 0 if (x + z) % 2 == 0 else 1
            vox[(x, 2, z)] = 5
    return vox, pal, STALK_VOXEL


AREAS = ["meadow", "wheat", "blossom", "pine", "swamp", "frost", "ember", "isles"]
