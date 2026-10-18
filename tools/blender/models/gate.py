"""Zone gate: a log palisade ~100 studs wide (X) and ~12 tall. Upright logs with pointed tops (slightly uneven
heights, two wood shades), two horizontal cross beams on the front (+Y), and a blank sign board hanging from the
upper beam in the middle (text is added in-game). Logs are custom 10-sided meshes with no hidden caps to stay cheap."""
import math, os, random, sys
import bmesh
sys.path.insert(0, os.path.dirname(__file__))
import _yardkit as kit  # noqa: E402

PREVIEW = dict(dist=52, height=14, target_z=6, yaw=18)


def stake(lib, name, x, y, r, h, tip, mat, segs=10):
    """Upright log with a pointed top: side ring + cone, no bottom cap (it sits in the ground)."""
    bm = bmesh.new()
    lo = [bm.verts.new((math.cos(2 * math.pi * i / segs) * r, math.sin(2 * math.pi * i / segs) * r, 0)) for i in range(segs)]
    hi = [bm.verts.new((v.co.x, v.co.y, h)) for v in lo]
    apex = bm.verts.new((0, 0, h + tip))
    for i in range(segs):
        j = (i + 1) % segs
        bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
        bm.faces.new((hi[i], hi[j], apex))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return lib._finish(lib._from_bmesh(name, bm), mat, (x, y, 0), (0, 0, 0), 0)


def build(lib):
    rnd = random.Random(11)
    wood_a = lib.material("Wood", (150, 98, 60))
    wood_b = lib.material("Wood", (132, 84, 52))
    beam = lib.material("Wood", (112, 72, 44))
    board = lib.material("WoodPlanks", (204, 150, 96))
    frame = lib.material("Wood", (90, 58, 38))
    rope = lib.material("Fabric", (196, 170, 120))
    W = 100.0
    r = 0.95
    n = int(W / (2 * r))
    step = W / n
    for i in range(n):
        x = -W / 2 + step * (i + 0.5)
        h = 10.2 + rnd.uniform(-0.5, 0.6)
        stake(lib, "stake%d" % i, x, rnd.uniform(-0.12, 0.12), r * rnd.uniform(0.95, 1.05), h, 1.5,
              wood_a if i % 2 else wood_b)
    # two cross beams on the front face
    for k, z in enumerate((3.2, 8.2)):
        kit.log(lib, "beam%d" % k, (-W / 2 - 0.3, r + 0.35, z), (W / 2 + 0.3, r + 0.35, z), 0.55, beam, verts=12)
    # hanging sign in the middle: two ropes from the top beam down to a plank board
    sz, sw, sh = 5.3, 16.0, 4.2
    sy = r + 1.15
    kit.plank_board(lib, "sign", sw, sh, 0.4, (0, sy, sz), (0, 0, 0), board, board, rows=3, bevel=0.06)
    for sx in (-1, 1):
        lib.box("frame_s%d" % sx, (0.45, 0.6, sh + 0.45), (sx * (sw / 2 + 0.2), sy, sz), mat=frame, bevel=0.06)
        lib.box("rope%d" % sx, (0.18, 0.18, 8.2 - sz - sh / 2 + 0.6), (sx * (sw / 2 - 1.5), sy - 0.1, (8.2 + sz + sh / 2) / 2), mat=rope)
    lib.box("frame_t", (sw + 0.85, 0.6, 0.45), (0, sy, sz + sh / 2 + 0.2), mat=frame, bevel=0.06)
    lib.box("frame_b", (sw + 0.85, 0.6, 0.45), (0, sy, sz - sh / 2 - 0.2), mat=frame, bevel=0.06)
