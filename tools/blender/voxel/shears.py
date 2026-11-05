"""RAYAN'S SHEARS (client/Shears) as voxels, the game's voxel style (owner, 5 Nov: "voxel voor de schaar").

One half of a pair of giant gold scissors, drawn voxel by voxel on a grid in the half's own frame (client/Shears):
the pivot at the origin, the blade toward -Z, the handle and its finger ring toward +Z, the bolt along Y, the
cutting edge on the +X side; the blade's layer is y = 0 (the other half is this one turned 180 degrees about Z, so
its blade lies against this one's). Each colour's voxels are merged into as few boxes as possible (greedy, per
layer and across layers) and written to src/client/ShearsShape.luau:

    python3 tools/blender/voxel/shears.py luau      writes src/client/ShearsShape.luau
    python3 tools/blender/voxel/shears.py preview   writes a top view and a side view (PNG) for checking
"""
import math
import os
import sys

VOXEL = 0.24  # studs

# palette: name -> (r, g, b, neon)
PAL = {
    "gold": (255, 196, 64, False),
    "goldLight": (255, 226, 120, False),
    "goldDark": (196, 128, 32, False),
    "goldDeep": (150, 92, 22, False),
    "edge": (255, 248, 220, True),
    "grip": (34, 26, 38, False),
    "gripLight": (58, 44, 64, False),
    "gem": (70, 255, 150, True),
    "gemDark": (20, 150, 80, False),
}
ORDER = list(PAL.keys())

cells = {}  # (x, y, z) -> colour name


def put(x, y, z, c):
    cells[(x, y, z)] = c


# the blade: the cutting edge straight along x = +2, the spine stepping in toward it, the point at z = -19
WIDTH = {}  # z -> (xmin, xmax): the spine runs straight in a long diagonal from z = -7 to the point
for z in range(-19, 0):
    if z >= -7:
        WIDTH[z] = (-2, 2)
    else:
        WIDTH[z] = (min(2, -2 + round((-7 - z) * 4 / 12)), 2)
for z, (a, b) in WIDTH.items():
    for x in range(a, b + 1):
        if x == b:
            c = "edge"
        elif x == a and b - a >= 2:
            c = "goldDark"  # the spine
        elif x == b - 1:
            c = "goldLight"  # the bevel next to the edge
        else:
            c = "gold"
        # the fuller: a dark groove down the middle of the broad part
        if x == 0 and -12 <= z <= -3 and c == "gold":
            c = "goldDeep"
        put(x, 0, z, c)
    # the spine is a voxel thicker (outward) on the broad part: it reads as a heavy back
    if b - a >= 2:
        put(a, 1, z, "goldDark")

# the pivot plate: a round gold plate round the bolt, two layers, a green gem on top
for x in range(-3, 4):
    for z in range(-3, 4):
        d = math.hypot(x, z)
        if d <= 3.2:
            put(x, 0, z, "goldDark" if d > 2.4 else "gold")
            if d <= 2.4:
                put(x, 1, z, "gold" if d > 1.2 else "goldLight")
for (x, z) in [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)]:
    put(x, 2, z, "gem" if (x, z) == (0, 0) else "gemDark")
put(0, 3, 0, "gem")

# the neck to the ring: dark grip wrapped in gold bands, 3 wide, 2 thick
for z in range(4, 8):
    for x in range(-1, 2):
        for y in range(0, 2):
            band = z == 4
            put(x, y, z, "goldDark" if band else ("gripLight" if (z + x) % 2 == 0 and y == 1 else "grip"))

# the finger ring: a gold ring in the scissors' plane, two layers, a darker inner rim
RING_Z = 11.5
for x in range(-6, 7):
    for z in range(5, 19):
        d = math.hypot(x, (z + 0.5) - (RING_Z + 0.5))
        if 2.7 <= d <= 4.75:
            c = "goldDark" if d < 3.4 else ("goldLight" if d > 4.3 and z < RING_Z else "gold")
            put(x, 0, z, c)
            put(x, 1, z, c)

# (voxel (x, y, z) fills [x, x+1) x [y, y+1) x [z, z+1); the builder shifts every box by (-0.5, 0, -0.5) voxels so the
# pivot plate's middle voxel is centred on the bolt)
HANDLE = RING_Z * VOXEL  # the pivot to the ring's middle (where the hand holds it), studs
BLADE = 19.5 * VOXEL  # the pivot to the tip, studs
TIP_X = 2.0 * VOXEL  # the point sits this far toward the cutting edge


def greedy():
    """Merge voxels of one colour into boxes: grow along x, then z, then y."""
    left = dict(cells)
    boxes = []
    for key in sorted(left.keys(), key=lambda k: (k[1], k[2], k[0])):
        if key not in left:
            continue
        c = left[key]
        x0, y0, z0 = key
        x1 = x0
        while (x1 + 1, y0, z0) in left and left[(x1 + 1, y0, z0)] == c:
            x1 += 1
        z1 = z0
        while all((x, y0, z1 + 1) in left and left[(x, y0, z1 + 1)] == c for x in range(x0, x1 + 1)):
            z1 += 1
        y1 = y0
        while all((x, y1 + 1, z) in left and left[(x, y1 + 1, z)] == c for x in range(x0, x1 + 1) for z in range(z0, z1 + 1)):
            y1 += 1
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                for z in range(z0, z1 + 1):
                    del left[(x, y, z)]
        boxes.append((x0, y0, z0, x1 - x0 + 1, y1 - y0 + 1, z1 - z0 + 1, c))
    return boxes


def luau(boxes):
    lines = [
        "-- RAYAN'S SHEARS as voxels: written by tools/blender/voxel/shears.py (don't edit by hand; edit the script and",
        "-- run it). One half of the pair in its own frame (client/Shears): the pivot at the origin, the blade toward -Z,",
        "-- the finger ring toward +Z, the bolt along Y (the blade's layer at y = 0), the cutting edge on +X. Each box:",
        "-- { x, y, z, sx, sy, sz, colour } in voxels (x, y, z = its lowest corner); VOXEL studs a voxel.",
        "local ShearsShape = {}",
        f"ShearsShape.VOXEL = {VOXEL}",
        f"ShearsShape.HANDLE = {HANDLE:.4f} -- the pivot to the ring's middle (the hand), studs",
        f"ShearsShape.BLADE = {BLADE:.4f} -- the pivot to the tip, studs",
        f"ShearsShape.TIP_X = {TIP_X:.4f} -- the point's offset toward the cutting edge, studs",
        "ShearsShape.SHIFT = Vector3.new(-0.5, 0, -0.5) -- (voxels) every box is moved by this: the bolt through the middle voxel",
        "-- name -> { r, g, b, neon }",
        "ShearsShape.PALETTE = {",
    ]
    for name in ORDER:
        r, g, b, n = PAL[name]
        lines.append(f"\t{name} = {{ {r}, {g}, {b}, {'true' if n else 'false'} }},")
    lines.append("}")
    lines.append("ShearsShape.BOXES = {")
    for (x, y, z, sx, sy, sz, c) in boxes:
        lines.append(f'\t{{ {x}, {y}, {z}, {sx}, {sy}, {sz}, "{c}" }},')
    lines.append("}")
    lines.append("return ShearsShape")
    return "\n".join(lines) + "\n"


def preview(path):
    from PIL import Image, ImageDraw
    s = 18
    xs = [k[0] for k in cells]
    zs = [k[2] for k in cells]
    ys = [k[1] for k in cells]
    w = (max(zs) - min(zs) + 1) * s + 40
    h = (max(xs) - min(xs) + 1) * s + (max(ys) - min(ys) + 1) * s + 80
    img = Image.new("RGB", (w, h), (40, 44, 60))
    d = ImageDraw.Draw(img)
    # top view (looking down the bolt, y up toward the viewer): z across, x down; the highest voxel wins
    top = {}
    for (x, y, z), c in cells.items():
        if (x, z) not in top or y > top[(x, z)][0]:
            top[(x, z)] = (y, c)
    for (x, z), (y, c) in top.items():
        px = 20 + (z - min(zs)) * s
        py = 20 + (max(xs) - x) * s
        r, g, b, n = PAL[c]
        shade = 1.0 if y >= 1 else 0.85
        d.rectangle([px, py, px + s - 1, py + s - 1], fill=(int(r * shade), int(g * shade), int(b * shade)))
    # side view (looking along x): z across, y up
    oy = 40 + (max(xs) - min(xs) + 1) * s
    side = {}
    for (x, y, z), c in cells.items():
        if (y, z) not in side or x > side[(y, z)][0]:
            side[(y, z)] = (x, c)
    for (y, z), (x, c) in side.items():
        px = 20 + (z - min(zs)) * s
        py = oy + (max(ys) - y) * s
        r, g, b, n = PAL[c]
        d.rectangle([px, py, px + s - 1, py + s - 1], fill=(r, g, b))
    img.save(path)


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "luau"
    boxes = greedy()
    if what == "luau":
        out = os.path.join(os.path.dirname(__file__), "..", "..", "..", "src", "client", "ShearsShape.luau")
        with open(out, "w") as f:
            f.write(luau(boxes))
        print(f"{len(cells)} voxels, {len(boxes)} boxes -> {os.path.normpath(out)}")
    else:
        preview(sys.argv[2] if len(sys.argv) > 2 else "shears_preview.png")
        print(f"{len(cells)} voxels, {len(boxes)} boxes")
