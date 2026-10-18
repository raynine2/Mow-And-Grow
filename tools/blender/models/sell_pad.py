"""The "drop bundles" sell pad, like Chop A Forest's "drop logs" pad: a low square plank platform (~12 x 12, ~1 tall)
framed by round logs on all four sides (ends crossing and sticking out at the corners, light cut ends), with a
black/yellow hazard stripe border inset along the inside of the log frame."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _yardkit as kit  # noqa: E402

PREVIEW = dict(dist=21, height=11, target_z=0.3, yaw=30)


def build(lib):
    wood = lib.material("Wood", (170, 112, 64))
    ends = lib.material("Wood", kit.LOG_END)
    plank_a = lib.material("WoodPlanks", (222, 150, 84))
    plank_b = lib.material("WoodPlanks", (206, 136, 74))
    yellow = lib.material("SmoothPlastic", kit.HAZ_YELLOW)
    black = lib.material("SmoothPlastic", kit.HAZ_BLACK)
    r, half, over = 0.55, 5.55, 0.95
    top = 0.82
    # plank floor: boards running along X, alternating shades
    lib.box("subfloor", (2 * half, 2 * half, top - 0.12), (0, 0, (top - 0.12) / 2), mat=wood)
    n = 6
    bw = (2 * half) / n
    for i in range(n):
        y = -half + bw * (i + 0.5)
        lib.box("board%d" % i, (2 * half - 0.1, bw - 0.1, 0.24), (0, y, top - 0.12), mat=plank_a if i % 2 else plank_b, bevel=0.05)
    # log frame: X logs low, Y logs a touch higher so the corners cross like a log crib
    for sy in (-1, 1):
        kit.log_ends(lib, "logx%d" % sy, (-half - over, sy * half, r), (half + over, sy * half, r), r, wood, ends, verts=10)
    for sx in (-1, 1):
        kit.log_ends(lib, "logy%d" % sx, (sx * half, -half - over, r + 0.18), (sx * half, half + over, r + 0.18), r, wood, ends, verts=10)
    # hazard border lying flat just inside the logs
    hw, inset = 0.85, half - r - 0.45
    L = 2 * inset + hw
    for sy in (-1, 1):
        kit.hazard(lib, "hazx%d" % sy, L, hw, 0.06, (0, sy * inset, top + 0.03), (90, 0, 0), yellow, black, stripe=0.42, slant=0.5, bevel=0)
    for sx in (-1, 1):
        kit.hazard(lib, "hazy%d" % sx, L - 2 * hw, hw, 0.06, (sx * inset, 0, top + 0.03), (90, 0, 90), yellow, black, stripe=0.42, slant=0.5, bevel=0)
