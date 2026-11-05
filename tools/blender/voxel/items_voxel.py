"""The rest of the game's items in its voxel look (owner, 5 Nov: "remake every model like siccor etc to voxel if they are
already voxel keep it", "high qaulity vocel so pls"): the Garden Scissors (one half, server/Models puts two on the
bolt and client/ViewModel opens and shuts them), the Mega Scythe, the Leaf Vacuum, the four bags and the five
ride-on mowers. The sickle, the push mower, the weed whacker and the laser mower were voxel already
(tools/blender/voxel/tools_voxel.py) and stay as they are.

Each is sculpted in the frame of the model it replaces (measured in Studio, 5 Nov), so everything that places, holds,
seats or rides them keeps working:
  scissorhalf  the bolt at the origin, the blade along -Z, the loop out to -X, the half in y 0..+0.2 (the other half
               is this one turned half a turn about Z)
  scythe       the butt at z +2.6, the shaft along -Z at y 0, the head at z -5.25, the blade rising +Y to its tip at
               (0, 5.4, -1.4)
  vacuum       the grip on top at the origin, the motor under it, the tube forward along -Z at y -1.35, the bag under
  bag_*        the pivot at the bottom middle, the front toward -Z
  mower_*      the ground under the middle, forward -Z; the cushion's top at y 3.0 at z ~1.0, the steering wheel (or
               the zero-turn's lap bars) where shared/MowerSeats says
Written by tools_voxel.py into src/shared/VoxelToolShapes.luau with the rest.
"""
import math

import numpy as np

import tools_voxel as T
from sculptkit import A, Sculpt, box, cone, cyl, rot, sphere, torus, ellipsoid  # noqa: F401

PAL = T.PAL
SHADE = T.SHADE
inter, sub = T.inter, T.sub
STEEL, STEEL_D, EDGE, GOLD, BLACK, WHITE, RED, RED_D = T.STEEL, T.STEEL_D, T.EDGE, T.GOLD, T.BLACK, T.WHITE, T.RED, T.RED_D
LEATHER, WOOD, GREEN, LIME, ORANGE, YELLOW, NAVY, PANEL, CYAN, GLASS = (
    T.LEATHER, T.WOOD, T.GREEN, T.LIME, T.ORANGE, T.YELLOW, T.NAVY, T.PANEL, T.CYAN, T.GLASS)

# the new families
SC_RED = PAL.mat([(170, 30, 30), (200, 40, 38), (226, 52, 46), (240, 78, 64), (252, 116, 96)], noise=0.3, edge=0.7, top=0.7)
SC_CAP = PAL.mat([(30, 30, 36), (44, 44, 52), (60, 60, 70)], noise=0.3, edge=0.5)
VIOLET_D = PAL.mat([(28, 18, 42), (40, 26, 60), (56, 36, 82), (74, 50, 104)], noise=0.4, edge=0.5, top=0.5)
CRYSTAL = PAL.mat([(96, 30, 170), (122, 46, 206), (150, 70, 232), (178, 104, 248), (206, 150, 255), (232, 200, 255)],
                  noise=0.6, fine=0.4, edge=0.9, top=0.8)
CRYSTAL_GLOW = PAL.mat([(196, 120, 255)], "Neon", "glow")
SPIKE = PAL.mat([(20, 14, 28), (32, 22, 44), (48, 34, 64)], noise=0.3, edge=0.6)
GEM = PAL.mat([(236, 120, 255)], "Neon", "glow")
FABRIC = PAL.mat([(66, 70, 78), (80, 86, 94), (96, 102, 110), (112, 118, 126)], noise=0.6, fine=0.4, edge=0.3)
BURLAP = PAL.mat([(150, 118, 76), (172, 140, 96), (194, 164, 118), (214, 188, 142), (230, 208, 166)], noise=0.7, fine=0.5, edge=0.4, top=0.5)
ROPE = PAL.mat([(120, 82, 40), (148, 106, 56), (176, 132, 74), (200, 158, 96)], noise=0.6, fine=0.6, edge=0.4)
PACK = PAL.mat([(42, 110, 56), (54, 134, 66), (68, 158, 78), (88, 180, 92), (112, 200, 110)], noise=0.5, fine=0.3, edge=0.6, top=0.6)
PACK_D = PAL.mat([(30, 80, 42), (38, 98, 50)], noise=0.3)
NAVY_P = PAL.mat([(20, 34, 72), (28, 46, 94), (38, 60, 118), (50, 76, 140), (66, 96, 162)], noise=0.5, fine=0.3, edge=0.6, top=0.6)
MAGENTA = PAL.mat([(130, 26, 120), (162, 36, 150), (196, 50, 180), (224, 74, 206), (244, 112, 228)], noise=0.5, fine=0.3, edge=0.6, top=0.7)
PURPLE = PAL.mat([(76, 30, 128), (98, 42, 160), (122, 58, 192), (148, 82, 218), (176, 112, 236)], noise=0.45, edge=0.6, top=0.6)
STAR = PAL.mat([(120, 236, 255)], "Neon", "glow")
RUST = PAL.mat([(96, 50, 30), (124, 66, 38), (156, 84, 44), (186, 102, 50), (210, 124, 62), (226, 148, 84)], noise=0.9, fine=0.7, edge=0.5, top=0.4)
BLUE = PAL.mat([(22, 70, 160), (30, 92, 196), (38, 112, 222), (64, 140, 240), (100, 170, 250)], noise=0.4, edge=0.6, top=0.6)
GOLDY = PAL.mat([(206, 150, 20), (232, 178, 30), (252, 200, 40), (255, 222, 90)], noise=0.35, edge=0.6, top=0.6)
GREY = PAL.mat([(54, 58, 66), (70, 74, 84), (88, 92, 102), (108, 112, 122)], noise=0.4, edge=0.5)
CHROME = PAL.mat([(170, 176, 188), (196, 202, 212), (216, 220, 230), (238, 242, 248)], noise=0.3, edge=0.7, top=0.7)
TYRE = PAL.mat([(24, 24, 28), (32, 32, 36), (42, 42, 48), (54, 54, 60)], noise=0.3, edge=0.6)
SEAT = PAL.mat([(28, 28, 34), (38, 38, 46), (50, 50, 60)], noise=0.3, edge=0.6, top=0.5)
SEAT_BROWN = PAL.mat([(70, 44, 30), (92, 60, 40), (114, 76, 52)], noise=0.4, edge=0.5)
PLATE = PAL.mat([(110, 114, 122), (134, 138, 146), (150, 154, 160), (170, 174, 180)], noise=0.25, fine=0.8, edge=0.4)
LIGHT_W = PAL.mat([(255, 246, 200)], "Neon", "glow")
LIGHT_O = PAL.mat([(255, 160, 40)], "Neon", "glow")
FLAME = PAL.mat([(255, 120, 20)], "Neon", "glow")
FLAME_Y = PAL.mat([(255, 210, 80)], "Neon", "glow")
NOZZLE = PAL.mat([(54, 150, 64), (66, 178, 76), (80, 200, 90), (110, 220, 116)], noise=0.25, edge=0.7, top=0.6)
ROCKET_RED = PAL.mat([(196, 40, 24), (226, 56, 32), (255, 70, 40), (255, 104, 74)], noise=0.35, edge=0.6, top=0.6)

V_FINE = 0.0625  # the scissors: the smallest item, on half the held grain
V_HELD = 0.125   # held items and the bags (the vault's hero-detail grain)
V_RIDE = 0.15    # the ride-on mowers' bodies (big props); their wheels and steering wheels are on 0.1


# ---------------------------------------------------------------------------------------------------------------
# the Garden Scissors: one half on its bolt (origin). The blade runs along -Z to its point at z -2.45, its straight
# cutting edge on +X (it meets the other half's when they shut), its back curving in; the shank goes back and out to
# -X into the red finger loop. This half lies in y 0..0.19; the other half is it turned half a turn about Z.
# ---------------------------------------------------------------------------------------------------------------
def scissorhalf():
    S = Sculpt(PAL, "scissorhalf", (-1.15, -0.02, -2.6), (0.4, 0.26, 2.05), V_FINE, seed=11, shade=SHADE)
    P = S.P
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    slab = np.maximum(y - 0.19, 0.0 - y)
    # the blade: from the bolt to the point; width tapers from 0.46 to a point, the edge straight at x +0.2 (so shut,
    # the two halves' blades lie over each other)
    E = 0.2
    t = np.clip(-z / 2.45, 0, 1)
    w = 0.46 * (1 - t ** 1.7) + 0.02
    across = np.maximum(x - E, (E - w) - x)
    blade = inter(across, z - 0.2, -z - 2.45, slab)
    S.add(blade, STEEL)
    S.paint((x > E - 2 * V_FINE) & (blade <= 0) & (z < 0.0), EDGE)  # the bright edge
    S.paint((np.abs(x - (E - w * 0.55)) < V_FINE) & (z < -0.35) & (z > -2.0) & (blade <= 0) & (y > 0.13), STEEL_D)  # a fuller
    # the shank: back and out to the loop
    S.add(inter(cone(P, (-0.02, 0.095, 0.15), (-0.42, 0.095, 0.95), 0.17, 0.14), slab), STEEL_D)
    # the finger loop: a thick red ring in XZ, a black cap on its far side
    ring = torus(P, (-0.6, 0.095, 1.42), 0.4, 0.13)
    ring = np.maximum(ring, np.abs(y - 0.095) - 0.13)
    S.add(ring, SC_RED)
    S.add(inter(box(P, (-0.92, 0.095, 1.72), (0.16, 0.13, 0.12), rr=0.04), np.abs(y - 0.095) - 0.13), SC_CAP)
    # the bolt: a gold disc (both halves have one; turned, they sit back to back)
    S.add(inter(cyl(P, (0, 0.0, 0), (0, 0.24, 0), 0.17), y + 0.0), GOLD)
    S.add(cyl(P, (0, 0.2, 0), (0, 0.26, 0), 0.08), STEEL)
    return S


# ---------------------------------------------------------------------------------------------------------------
# the Mega Scythe: a dark violet snath banded in silver, a side grip, a silver collar at the head and a purple
# crystal blade sweeping up from it and curling back over the shaft, black spikes along its back, a glowing gem at
# the butt
# ---------------------------------------------------------------------------------------------------------------
def scythe():
    S = Sculpt(PAL, "scythe", (-0.7, -1.6, -7.2), (0.7, 5.6, 2.8), V_HELD, seed=13, shade=SHADE)
    P = S.P
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    S.add(cyl(P, (0, 0, 2.45), (0, 0, -5.1), 0.19), VIOLET_D)
    for zb in (2.0, 0.4, -1.6, -3.2, -4.6):
        S.add(cyl(P, (0, 0, zb + 0.12), (0, 0, zb - 0.12), 0.25), CHROME)
    S.add(cyl(P, (0, 0, 1.6), (0, 0, 0.75), 0.24), LEATHER)  # the rear grip's wrap
    # the side grip: a short peg up from the shaft
    S.add(cyl(P, (0, 0.1, -2.5), (0, 0.95, -2.5), 0.13), VIOLET_D)
    S.add(cyl(P, (0, 0.85, -2.5), (0, 1.15, -2.5), 0.18), CHROME)
    # the butt: a silver cap and a gem
    S.add(cyl(P, (0, 0, 2.4), (0, 0, 2.62), 0.27), CHROME)
    S.add(ellipsoid(P, (0, 0, 2.72), (0.18, 0.18, 0.22)), GEM)
    # the head: a silver collar and a spiked socket
    S.add(box(P, (0, 0.1, -5.35), (0.3, 0.42, 0.45), rr=0.08), CHROME)
    S.add(box(P, (0, 0.1, -5.35), (0.34, 0.2, 0.2)), SPIKE)
    # the blade: a crescent in the YZ plane on a circle through the head (y 0.1, z -5.3) and the tip (y 5.4, z -1.4)
    # (centre y 1.02, z -1.0, radius 4.4): from the head it sweeps forward and up and curls back over the shaft. Its
    # spine is the outer side; it is widest at the head and comes to a point; the inner side is the glowing edge.
    cy, cz, R0 = 1.02, -1.0, 4.4
    dy, dz = y - cy, z - cz
    r = np.hypot(dy, dz)
    ang = np.degrees(np.arctan2(dy, -dz))  # 0 = forward (-z), 90 = up
    a0, a1 = -22.0, 86.0
    t = np.clip((ang - a0) / (a1 - a0), 0, 1)
    half = 0.66 * (1 - t ** 1.5) + 0.03
    mid = R0 - half  # the spine stays on the circle; the blade grows inward
    across = np.abs(r - mid) - half
    sweep = np.maximum(a0 - ang, ang - a1)
    thick = np.abs(x) - (0.2 - 0.11 * t)
    blade = inter(across, sweep, thick)
    blade = np.where(dz > 3.0, 1e9, blade)  # (only the front half of the circle)
    S.add(blade, CRYSTAL)
    S.paint((r < mid - half + 0.22) & (blade <= 0), CRYSTAL_GLOW)  # the edge
    S.paint((np.abs(x) < 0.07) & (np.abs(r - (R0 - 0.3)) < 0.07) & (blade <= 0) & (t < 0.85), CRYSTAL_GLOW)  # a vein
    for k in range(6):
        tk = 0.08 + k * 0.15
        th = math.radians(a0 + tk * (a1 - a0))
        out = A((0, math.sin(th), -math.cos(th)))
        base = A((0, cy, cz)) + out * (R0 - 0.08)
        back = A((0, -math.cos(th), -math.sin(th))) * -1  # (raked toward the tip)
        S.add(cone(P, base, base + out * (0.5 - 0.05 * k) + back * 0.2, 0.16, 0.02), SPIKE)
    # the blade's root wraps the collar
    S.add(box(P, (0, 0.15, -5.3), (0.26, 0.55, 0.3), rr=0.08), SPIKE)
    return S


# ---------------------------------------------------------------------------------------------------------------
# the Leaf Vacuum: the grip on top at the origin (along Z), the orange motor under it with a dark vent and a steel
# fan, a black suction tube forward to a flared green nozzle, a grey mesh bag hanging under the motor
# ---------------------------------------------------------------------------------------------------------------
def vacuum():
    S = Sculpt(PAL, "vacuum", (-1.0, -3.4, -6.5), (1.0, 0.4, 1.3), V_HELD, seed=17, shade=SHADE)
    P = S.P
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    S.add(box(P, (0, 0, 0), (0.25, 0.25, 0.8), rr=0.1), BLACK)  # the grip
    for zz in (-0.7, 0.7):
        S.add(box(P, (0, -0.45, zz), (0.2, 0.36, 0.15), rr=0.05), BLACK)
    S.add(box(P, (0, -0.32, -0.32), (0.12, 0.18, 0.12)), ORANGE)  # the trigger
    S.add(box(P, (0, -1.25, 0), (0.65, 0.62, 1.0), rr=0.28), ORANGE)  # the motor
    S.add(box(P, (0, -1.6, 0.4), (0.68, 0.24, 0.5), rr=0.08), RED_D)
    for k in range(4):
        S.carve(box(P, (0, -1.0 - k * 0.16, 0.45), (0.7, 0.04, 0.32)))
    S.add(cyl(P, (0.6, -1.25, -0.3), (0.72, -1.25, -0.3), 0.5), CHROME)
    S.add(cyl(P, (0.66, -1.25, -0.3), (0.78, -1.25, -0.3), 0.16), STEEL_D)
    for k in range(6):
        a = k * math.pi / 3
        S.add(box(P, (0.72, -1.25 + 0.3 * math.sin(a), -0.3 + 0.3 * math.cos(a)), (0.03, 0.05, 0.05)), STEEL_D)
    # the tube and its collar, the nozzle flaring out, its lip
    S.add(cyl(P, (0, -1.35, -0.85), (0, -1.35, -5.3), 0.32), BLACK)
    for zz in (-1.8, -2.8, -3.8, -4.8):
        S.add(cyl(P, (0, -1.35, zz + 0.06), (0, -1.35, zz - 0.06), 0.36), STEEL_D)
    S.add(cyl(P, (0, -1.35, -0.85), (0, -1.35, -1.2), 0.42), CHROME)
    noz = cone(P, (0, -1.35, -5.25), (0, -1.35, -6.2), 0.38, 0.72)
    S.add(noz, NOZZLE)
    S.carve(cone(P, (0, -1.35, -5.6), (0, -1.35, -6.6), 0.2, 0.6))
    S.add(torus(P, (0, -1.35, -6.25), 0.68, 0.1, rot(90, 0, 0)), ORANGE)
    # the bag: a fat mesh sack under the motor on a steel ring
    S.add(ellipsoid(P, (0, -2.55, 0.25), (0.82, 0.78, 0.9)), FABRIC)
    S.add(cyl(P, (0, -1.85, 0.2), (0, -1.75, 0.2), 0.55), CHROME)
    S.add(box(P, (0, -2.5, -0.62), (0.3, 0.3, 0.05)), LIME)  # a leaf badge
    return S


# ---------------------------------------------------------------------------------------------------------------
# the bags (pivot at the bottom middle, front -Z)
# ---------------------------------------------------------------------------------------------------------------
def bag_satchel():
    """Grass Satchel: a burlap sack tied with rope, its neck flaring, a clover sewn on the front."""
    S = Sculpt(PAL, "bag_satchel", (-1.25, 0, -1.0), (1.25, 2.8, 1.0), V_HELD, seed=21, shade=SHADE)
    P = S.P
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    S.add(ellipsoid(P, (0, 0.95, 0), (1.12, 0.98, 0.86)), BURLAP)
    S.add(cone(P, (0, 1.6, 0), (0, 2.05, 0), 0.62, 0.36), BURLAP, 0.15)
    # the flared neck: ruffled
    ruff = ellipsoid(P, (0, 2.42, 0), (0.75, 0.32, 0.62)) + 0.05 * np.sin(np.arctan2(z, x) * 9)
    S.add(ruff, BURLAP)
    S.carve(ellipsoid(P, (0, 2.62, 0), (0.48, 0.2, 0.38)), FABRIC)
    S.add(torus(P, (0, 2.08, 0), 0.4, 0.09), ROPE)
    S.add(cone(P, (0.28, 2.06, -0.35), (0.42, 1.55, -0.6), 0.07, 0.06), ROPE)
    S.add(sphere(P, (0.43, 1.5, -0.62), 0.09), ROPE)
    # the clover on the front
    fz = -0.8
    for cx_, cy_ in ((-0.16, 1.12), (0.16, 1.12), (0.0, 1.38)):
        S.add(inter(sphere(P, (cx_, cy_, fz), 0.2), -(z - fz + 0.02) - 0.1), GREEN)
    S.add(cone(P, (0.0, 1.05, fz), (0.08, 0.72, fz + 0.04), 0.05, 0.04), PACK_D)
    # a darker patch and stitches
    S.paint((np.abs(x + 0.6) < 0.2) & (np.abs(y - 0.55) < 0.2) & (z < -0.3), ROPE, depth=0.13)
    return S


def strap(S, a, b, w, d, m):
    """A flat strap from a to b, w wide (in x) and d deep."""
    P = S.P
    a, b = A(a), A(b)
    c = (a + b) / 2
    L = np.linalg.norm(b - a)
    u = (b - a) / L
    # a box along u, its width in x
    ex = A((1, 0, 0))
    ez = np.cross(ex, u)
    ez = ez / np.linalg.norm(ez)
    q = P - c
    loc = np.stack([q @ ex, q @ u, q @ ez], 1)
    S.add(np.max(np.abs(loc) - A((w / 2, L / 2, d / 2)), axis=1), m)


def bag_backpack():
    """Clipping Backpack: a rounded green pack, a front pocket with a flap and a gold buckle, side pockets, two
    leather straps down the back, a carry loop on top."""
    S = Sculpt(PAL, "bag_backpack", (-1.3, 0, -1.5), (1.3, 3.65, 1.5), V_HELD, seed=23, shade=SHADE)
    P = S.P
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    S.add(box(P, (0, 1.55, 0.15), (1.0, 1.5, 0.75), rr=0.45), PACK)
    S.add(ellipsoid(P, (0, 2.95, 0.15), (1.0, 0.55, 0.75)), PACK, 0.2)
    # the lid flap over the top front
    S.add(inter(ellipsoid(P, (0, 2.85, -0.05), (1.05, 0.62, 0.9)), -(y - 2.3)), PACK_D)
    # the front pocket with its flap and buckle
    S.add(box(P, (0, 1.1, -0.72), (0.75, 0.68, 0.3), rr=0.22), PACK)
    S.add(box(P, (0, 1.68, -0.78), (0.78, 0.16, 0.3), rr=0.1), PACK_D)
    S.add(box(P, (0, 1.5, -1.08), (0.13, 0.2, 0.05)), LEATHER)
    S.add(box(P, (0, 1.38, -1.1), (0.12, 0.08, 0.04)), GOLD)
    # side pockets
    for sx in (-1, 1):
        S.add(box(P, (sx * 1.02, 0.95, 0.1), (0.22, 0.55, 0.5), rr=0.16), PACK)
        S.add(box(P, (sx * 1.04, 1.42, 0.1), (0.24, 0.07, 0.52), rr=0.03), PACK_D)
    # the lid's straps down the front with buckles
    for sx in (-0.5, 0.5):
        strap(S, (sx, 3.45, -0.62), (sx, 2.2, -0.95), 0.22, 0.08, LEATHER)
        S.add(box(P, (sx, 2.25, -0.98), (0.14, 0.1, 0.05)), GOLD)
    # the back: two shoulder straps and the carry loop
    for sx in (-0.48, 0.48):
        strap(S, (sx, 3.0, 0.92), (sx * 1.15, 0.5, 0.98), 0.3, 0.12, LEATHER)
    S.add(np.maximum(torus(P, (0, 3.45, 0.15), 0.28, 0.07, rot(90, 0, 0)), -(y - 3.45)), LEATHER)
    # a zip line round the main body
    S.paint((np.abs(z - 0.15 + 0.0) > 0.0) & (np.abs(y - 2.42) < 0.06) & (np.abs(x) < 0.95), GOLD, depth=0.13)
    return S


def bag_hiker():
    """Expedition Pack: a tall navy frame pack, a red bedroll strapped across the top, a front pocket, a water bottle
    on the side, a coiled rope, leather straps."""
    S = Sculpt(PAL, "bag_hiker", (-1.85, 0, -1.5), (1.85, 4.45, 1.5), V_HELD, seed=25, shade=SHADE)
    P = S.P
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    S.add(box(P, (0, 1.75, 0.2), (1.1, 1.7, 0.78), rr=0.42), NAVY_P)
    S.add(inter(ellipsoid(P, (0, 3.2, 0.05), (1.15, 0.5, 0.92)), -(y - 2.95)), NAVY_P)  # the lid
    S.add(box(P, (0, 1.15, -0.75), (0.82, 0.78, 0.32), rr=0.25), NAVY_P)  # the front pocket
    S.add(box(P, (0, 1.8, -0.8), (0.84, 0.12, 0.32), rr=0.08), STEEL_D)
    # the bedroll across the top
    S.add(cyl(P, (-1.7, 3.85, 0.15), (1.7, 3.85, 0.15), 0.52, 0.12), RED)
    for sx in (-1.7, 1.7):
        S.add(cyl(P, (sx - 0.02, 3.85, 0.15), (sx + 0.02, 3.85, 0.15), 0.3), RED_D)
    for sx in (-0.9, 0.9):
        S.add(cyl(P, (sx - 0.09, 3.85, 0.15), (sx + 0.09, 3.85, 0.15), 0.56), LEATHER)
    # front straps and buckles
    for sx in (-0.55, 0.55):
        strap(S, (sx, 3.1, -0.72), (sx, 0.6, -1.0), 0.22, 0.08, LEATHER)
        S.add(box(P, (sx, 1.9, -1.08), (0.14, 0.1, 0.05)), GOLD)
    # the bottle on the left, a coil of rope on the right
    S.add(cyl(P, (-1.25, 0.25, 0.25), (-1.25, 1.55, 0.25), 0.3, 0.08), CHROME)
    S.add(cyl(P, (-1.25, 1.5, 0.25), (-1.25, 1.75, 0.25), 0.16), BLACK)
    S.add(torus(P, (1.42, 1.1, 0.2), 0.42, 0.13, rot(0, 0, 90)), ROPE)
    # the back: shoulder straps and the frame's hip pads
    for sx in (-0.5, 0.5):
        strap(S, (sx, 3.0, 1.0), (sx * 1.2, 0.6, 1.02), 0.32, 0.12, LEATHER)
    S.add(box(P, (0, 0.55, 1.0), (1.0, 0.22, 0.14), rr=0.08), STEEL_D)
    return S


def bag_infinite():
    """Bottomless Sack: a fat magenta sack scattered with glowing stars, a purple ruffled top tied with gold rope."""
    S = Sculpt(PAL, "bag_infinite", (-1.65, 0, -1.6), (1.65, 4.1, 1.6), V_HELD, seed=27, shade=SHADE)
    P = S.P
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    S.add(ellipsoid(P, (0, 1.42, 0), (1.55, 1.42, 1.45)), MAGENTA)
    S.add(cone(P, (0, 2.5, 0), (0, 3.1, 0), 0.8, 0.45), MAGENTA, 0.2)
    ruff = ellipsoid(P, (0, 3.6, 0), (1.05, 0.42, 0.95)) + 0.06 * np.sin(np.arctan2(z, x) * 10)
    S.add(ruff, PURPLE)
    S.carve(ellipsoid(P, (0, 3.85, 0), (0.7, 0.28, 0.62)), PURPLE)
    S.add(torus(P, (0, 3.12, 0), 0.5, 0.1), GOLD)
    S.add(cone(P, (0.35, 3.1, -0.4), (0.55, 2.45, -0.75), 0.08, 0.07), GOLD)
    S.add(sphere(P, (0.56, 2.38, -0.78), 0.12), GOLD)
    # stars: little glowing plus-shapes pressed into the surface
    rng = np.random.default_rng(5)
    shell = ellipsoid(P, (0, 1.42, 0), (1.55, 1.42, 1.45))
    for _ in range(26):
        th = rng.uniform(0, 2 * math.pi)
        ph = rng.uniform(0.25, 2.6)
        c = A((1.55 * math.sin(ph) * math.cos(th), 1.42 + 1.42 * math.cos(ph), 1.45 * math.sin(ph) * math.sin(th)))
        s = rng.uniform(0.09, 0.17)
        near = np.linalg.norm(P - c, axis=1)
        plus = (np.minimum(np.abs(P[:, 0] - c[0]) + np.abs(P[:, 1] - c[1]) * 2.2, np.abs(P[:, 0] - c[0]) * 2.2 + np.abs(P[:, 1] - c[1])) < s) | (
            np.minimum(np.abs(P[:, 2] - c[2]) + np.abs(P[:, 1] - c[1]) * 2.2, np.abs(P[:, 2] - c[2]) * 2.2 + np.abs(P[:, 1] - c[1])) < s)
        S.paint(plus & (near < s * 2.2) & (shell > -0.14), STAR)
    return S


# ---------------------------------------------------------------------------------------------------------------
# ride-on mowers. Each is several groups: the body (frame, hood, seat, deck, the steering column), each tyre on its
# own group pivoting on its axle ("<mower>.WheelFL" etc.: server/Models names its parts so server/Mowers' `rig` hangs
# them on a "Spin" motor and client/MowerFx rolls them) and the steering wheel ("<mower>.Steer": its parts join the
# "SteerHub" server/Mowers makes, so client/RiderPose turns it). The wheels' grain is finer, so they stay round.
# ---------------------------------------------------------------------------------------------------------------
V_WHEEL = 0.125


def wheel(owner, tag, c, R, w, tyre, hub, lugs=8, seed=0):
    """A tyre on its own group: axle along X through the pivot `c`, tread blocks round it, a hub and lug nuts on the
    outer face (+X on the right side, -X on the left)."""
    side = 1 if c[0] >= 0 else -1
    S = Sculpt(PAL, "%s.Wheel%s" % (owner, tag), (-w / 2 - 0.3, -R - 0.05, -R - 0.05), (w / 2 + 0.3, R + 0.05, R + 0.05),
               V_WHEEL, pivot=c, parent=owner, seed=50 + seed, shade=SHADE)
    P = S.P
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    S.add(cyl(P, (-w / 2, 0, 0), (w / 2, 0, 0), R, min(0.18, R * 0.22)), tyre)
    r = np.hypot(y, z)
    a = np.arctan2(y, z)
    n = max(10, int(round(R * 14)))
    groove = ((np.mod(a * n / math.pi, 1.0) < 0.4) & (r > R - 0.13) & (np.abs(x) < w / 2 - 0.06))
    S.D = np.where(groove, np.maximum(S.D, 0.01), S.D)
    hr = R * 0.56
    o = side * w / 2
    S.carve(cyl(P, (o - side * 0.12, 0, 0), (o + side * 0.2, 0, 0), hr + 0.06))  # the rim's dish
    S.add(cyl(P, (o - side * 0.14, 0, 0), (o - side * 0.02, 0, 0), hr), hub)
    S.add(cyl(P, (o - side * 0.1, 0, 0), (o + side * 0.06, 0, 0), hr * 0.42), CHROME)
    for k in range(lugs):
        an = 2 * math.pi * k / lugs
        yy, zz = hr * 0.7 * math.sin(an), hr * 0.7 * math.cos(an)
        S.add(cyl(P, (o - side * 0.05, yy, zz), (o + side * 0.04, yy, zz), 0.06), CHROME)
    S.add(cyl(P, (-o - side * 0.02, 0, 0), (-o + side * 0.08, 0, 0), hr * 0.5), GREY)  # the inner face
    return S


def steer(owner, c, r, u, rim):
    """The steering wheel on its own group (pivot `c`, the rim's centre), its face square to `u`'s normal like
    shared/MowerSeats says: a thick rim, three spokes, a chrome cap."""
    S = Sculpt(PAL, owner + ".Steer", (-r - 0.25,) * 3, (r + 0.25,) * 3, V_WHEEL, pivot=c, parent=owner, seed=61, shade=SHADE)
    P = S.P
    u = A(u) / np.linalg.norm(u)
    n = np.cross(A((1, 0, 0)), u)
    n = n / np.linalg.norm(n)
    a = P @ n
    inplane = P - a[:, None] * n
    S.add(np.sqrt((np.linalg.norm(inplane, axis=1) - r) ** 2 + a ** 2) - 0.11, rim)
    for k in range(3):
        an = -math.pi / 2 + 2 * math.pi * k / 3
        d = math.cos(an) * A((1, 0, 0)) + math.sin(an) * u
        S.add(cone(P, (0, 0, 0), d * r, 0.07, 0.06), GREY)
    S.add(cyl(P, -n * 0.08, n * 0.1, 0.17), CHROME)
    return S


def column(S, c, u, length=1.3):
    """The steering column from under the wheel down and forward into the dash (part of the body)."""
    u = A(u) / np.linalg.norm(u)
    n = np.cross(A((1, 0, 0)), u)
    n = n / np.linalg.norm(n)
    c = A(c)
    S.add(cyl(S.P, c - n * 0.12, c - n * length, 0.11), GREY)
    S.add(cyl(S.P, c - n * (length - 0.25), c - n * (length + 0.1), 0.2), BLACK)


def seat(S, z, mat, w=1.05, top=3.0, backTop=4.5, lean=12, pipe=None):
    """The seat: the cushion's top at `top` (shared/MowerSeats: 3.0), centred at `z`; a back leaning `lean` degrees
    back; a grey post under it."""
    P = S.P
    S.add(box(P, (0, top - 0.25, z), (w, 0.25, 0.85), rr=0.16), mat)
    if pipe is not None:
        S.paint((np.abs(np.abs(P[:, 0]) - (w - 0.12)) < 0.08) & (P[:, 1] > top - 0.15), pipe, depth=0.2)
    S.add(box(P, (0, (top + backTop) / 2 - 0.05, z + 0.95), (w * 0.95, (backTop - top) / 2 + 0.1, 0.22), rot(lean, 0, 0), rr=0.16), mat)
    S.add(box(P, (0, top - 0.75, z + 0.1), (w * 0.6, 0.3, 0.55)), GREY)


def deck(S, z, half_w, mat, rim, y=0.55, half_d=1.15):
    """The mowing deck slung under the middle, its skirt and the spindle housing on top."""
    P = S.P
    S.add(box(P, (0, y, z), (half_w, 0.22, half_d), rr=0.14), mat)
    S.add(box(P, (0, y - 0.25, z), (half_w + 0.05, 0.07, half_d + 0.05)), rim)
    S.add(cyl(P, (0, y + 0.18, z), (0, y + 0.45, z), 0.35), GREY)
    S.add(cyl(P, (half_w - 0.4, y + 0.1, z - half_d + 0.3), (half_w + 0.15, y + 0.1, z - half_d + 0.3), 0.18), rim)  # the chute


def light(S, c, half, glow, rim=CHROME):
    S.add(box(S.P, c, (half[0] + 0.06, half[1] + 0.06, half[2]), rr=0.04), rim)
    S.add(box(S.P, (c[0], c[1], c[2] - 0.05), half), glow)


# ---------------------------------------------------------------------------------------------------------------
# the Rusty Rider: an old rusted rider mower, bare metal patches, a torn brown seat, one headlight out, a dented hood
# ---------------------------------------------------------------------------------------------------------------
def mower_rusty():
    o = "mower_rusty"
    S = Sculpt(PAL, o, (-2.9, 0, -4.0), (2.9, 4.7, 3.9), V_RIDE, seed=31, shade=SHADE)
    P = S.P
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    S.add(box(P, (0, 1.15, -0.3), (1.5, 0.28, 3.1), rr=0.1), GREY)  # the frame
    for sx in (-1, 1):
        S.add(cyl(P, (sx * 1.4, 0.95, 2.1), (sx * 1.9, 0.95, 2.1), 0.2), STEEL_D)  # axle stubs
        S.add(cyl(P, (sx * 1.4, 0.62, -2.55), (sx * 1.8, 0.62, -2.55), 0.16), STEEL_D)
    S.add(box(P, (0, 2.0, -2.05), (1.35, 0.72, 1.45), rr=0.42), RUST)  # the hood
    S.add(box(P, (0, 2.7, -1.0), (1.1, 0.12, 0.4), rr=0.08), RUST)  # the dash
    S.carve(sphere(P, (-0.7, 2.95, -2.3), 0.35))  # a dent
    S.add(box(P, (0, 1.95, -3.48), (1.08, 0.58, 0.12)), GREY)  # the grille
    for k in range(5):
        S.add(box(P, (0, 1.55 + k * 0.2, -3.6), (0.98, 0.05, 0.05)), CHROME)
    light(S, (-0.74, 2.62, -3.5), (0.22, 0.16, 0.06), LIGHT_W)
    light(S, (0.74, 2.62, -3.5), (0.22, 0.16, 0.06), STEEL_D)  # (the other one is out)
    S.add(box(P, (0, 1.95, 1.55), (1.6, 0.45, 1.35), rr=0.25), RUST)  # the rear body under the seat
    for sx in (-1, 1):
        S.add(box(P, (sx * 2.3, 2.12, 2.1), (0.52, 0.12, 1.1), rr=0.06), RUST)  # mudguards over the rear tyres
        S.add(box(P, (sx * 1.85, 1.7, 2.1), (0.08, 0.45, 0.6)), RUST)
    S.add(box(P, (0, 1.48, -0.3), (1.05, 0.06, 0.9)), PLATE)  # the footboard
    deck(S, -0.35, 2.05, GREY, RUST, y=0.42, half_d=1.0)
    seat(S, 1.05, SEAT_BROWN, top=3.0, backTop=4.2, lean=14)
    S.paint((np.abs(x - 0.45) < 0.25) & (np.abs(z - 1.2) < 0.3) & (y > 2.7), FABRIC, depth=0.2)  # the tear
    column(S, (0, 3.85, 0.15), (0, 0.86, -0.6))
    S.paint((np.abs(x + 0.9) < 0.3) & (np.abs(z + 1.6) < 0.35) & (y > 2.5), STEEL_D, depth=0.2)  # rust holes, bare metal
    S.paint((np.abs(x - 1.0) < 0.25) & (np.abs(y - 2.0) < 0.25) & (z > 1.0), STEEL, depth=0.2)
    S.add(cyl(P, (1.0, 2.6, -1.25), (1.0, 3.45, -1.25), 0.14), GREY)  # the exhaust
    S.add(cyl(P, (1.0, 3.35, -1.25), (1.0, 3.6, -1.25), 0.18), BLACK)
    return [S,
            wheel(o, "RL", (-2.3, 0.95, 2.1), 0.95, 0.9, TYRE, GREY, 6, 1), wheel(o, "RR", (2.3, 0.95, 2.1), 0.95, 0.9, TYRE, GREY, 6, 2),
            wheel(o, "FL", (-2.05, 0.62, -2.55), 0.62, 0.62, TYRE, GREY, 5, 3), wheel(o, "FR", (2.05, 0.62, -2.55), 0.62, 0.62, TYRE, GREY, 5, 4),
            steer(o, (0, 3.85, 0.15), 0.52, (0, 0.86, -0.6), TYRE)]


# ---------------------------------------------------------------------------------------------------------------
# the Turbo Tractor: a blue garden tractor on yellow hubs, big rear tyres, a long hood with a light bar and yellow
# stripes, a tall chrome exhaust stack, the deck slung under the middle, a diamond-plate floor
# ---------------------------------------------------------------------------------------------------------------
def mower_tractor():
    o = "mower_tractor"
    S = Sculpt(PAL, o, (-3.4, 0, -4.9), (3.4, 6.3, 4.5), V_RIDE, seed=33, shade=SHADE)
    P = S.P
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    S.add(box(P, (0, 1.3, -0.4), (1.45, 0.32, 3.6), rr=0.1), GREY)
    for sx in (-1, 1):
        S.add(cyl(P, (sx * 1.4, 1.5, 2.15), (sx * 2.0, 1.5, 2.15), 0.22), STEEL_D)
        S.add(cyl(P, (sx * 1.4, 0.85, -3.0), (sx * 1.85, 0.85, -3.0), 0.18), STEEL_D)
    S.add(box(P, (0, 2.45, -2.6), (1.45, 1.0, 1.7), rr=0.45), BLUE)  # the hood
    S.add(box(P, (0, 3.45, -2.5), (1.2, 0.14, 1.45), rr=0.08), BLUE)
    S.add(box(P, (0, 3.35, -1.0), (1.25, 0.14, 0.35), rr=0.08), SEAT)  # the dash
    for sx in (-1, 1):
        S.paint((np.abs(x - sx * 1.45) < 0.12) & (np.abs(y - 2.55) < 0.14) & (np.abs(z + 2.6) < 1.4), GOLDY, depth=0.25)
        S.paint((np.abs(x - sx * 1.45) < 0.12) & (np.abs(y - 2.2) < 0.07) & (np.abs(z + 2.6) < 1.4), GOLDY, depth=0.25)
        for k in range(3):
            S.carve(box(P, (sx * 1.5, 2.1 + k * 0.28, -3.3), (0.12, 0.06, 0.45)))  # side vents
    S.add(box(P, (0, 2.35, -4.3), (1.2, 0.85, 0.12)), GREY)  # the grille
    for k in range(5):
        S.add(box(P, (0, 1.8 + k * 0.25, -4.42), (1.05, 0.05, 0.05)), CHROME)
    S.add(box(P, (0, 3.05, -4.41), (1.14, 0.13, 0.06)), LIGHT_W)  # the light bar
    for sx in (-1, 1):
        light(S, (sx * 0.85, 1.55, -4.45), (0.16, 0.12, 0.05), LIGHT_W)
        S.add(box(P, (sx * 2.6, 3.12, 2.15), (0.78, 0.14, 1.7), rr=0.08), BLUE)  # mudguards
        S.add(box(P, (sx * 1.9, 2.4, 2.15), (0.08, 0.72, 1.3)), BLUE)
        S.add(box(P, (sx * 2.6, 3.0, 3.85), (0.7, 0.12, 0.12)), GOLDY)
    S.add(box(P, (0, 2.2, 1.6), (1.75, 0.62, 1.6), rr=0.3), BLUE)  # the rear body
    S.add(box(P, (0, 1.65, -0.1), (1.2, 0.06, 1.1)), PLATE)  # the floor
    deck(S, -0.7, 2.55, GREY, GOLDY, y=0.45, half_d=1.25)
    seat(S, 1.05, SEAT, top=3.0, backTop=4.55, lean=10, pipe=GOLDY)
    column(S, (0, 4.25, 0.35), (0, 1.02, -0.72))
    S.add(cyl(P, (1.05, 3.5, -1.6), (1.05, 6.0, -1.6), 0.16), CHROME)  # the exhaust stack
    S.add(cyl(P, (1.05, 5.85, -1.6), (1.05, 6.25, -1.6), 0.22), BLACK)
    S.add(cyl(P, (1.05, 4.2, -1.6), (1.05, 4.7, -1.6), 0.21), STEEL_D)
    S.add(box(P, (0, 1.9, 3.35), (0.35, 0.2, 0.3)), GOLDY)  # the hitch
    return [S,
            wheel(o, "RL", (-2.6, 1.5, 2.15), 1.5, 1.3, TYRE, GOLDY, 10, 1), wheel(o, "RR", (2.6, 1.5, 2.15), 1.5, 1.3, TYRE, GOLDY, 10, 2),
            wheel(o, "FL", (-2.25, 0.85, -3.0), 0.85, 0.8, TYRE, GOLDY, 6, 3), wheel(o, "FR", (2.25, 0.85, -3.0), 0.85, 0.8, TYRE, GOLDY, 6, 4),
            steer(o, (0, 4.25, 0.35), 0.62, (0, 1.02, -0.72), TYRE)]


# ---------------------------------------------------------------------------------------------------------------
# the Golden Zero-Turn: a low gold-and-black zero-turn, a chrome roll bar, two lap bars (the rider's hands), a wide
# front deck, little caster wheels in front, a light strip
# ---------------------------------------------------------------------------------------------------------------
def mower_zeroturn():
    o = "mower_zeroturn"
    S = Sculpt(PAL, o, (-3.5, 0, -4.8), (3.5, 5.2, 4.4), V_RIDE, seed=35, shade=SHADE)
    P = S.P
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    for sx in (-1, 1):
        S.add(cyl(P, (sx * 2.6, 0.9, -3.7), (sx * 2.6, 1.55, -3.45), 0.11), CHROME)  # caster forks
        S.add(box(P, (sx * 2.6, 0.8, -3.7), (0.32, 0.1, 0.12)), CHROME)
        S.add(cyl(P, (sx * 1.3, 1.2, 2.3), (sx * 1.9, 1.2, 2.3), 0.22), STEEL_D)
    S.add(box(P, (0, 1.3, -0.6), (1.4, 0.3, 3.3), rr=0.1), SEAT)  # the frame
    S.add(box(P, (0, 2.0, 2.2), (1.85, 0.72, 1.45), rr=0.35), GOLDY)  # the engine body
    S.add(box(P, (0, 2.78, 2.65), (1.35, 0.1, 0.85), rr=0.06), SEAT)
    for k in range(4):
        S.add(box(P, (0, 2.0 + k * 0.2 - 0.3, 3.62), (1.2, 0.05, 0.06)), SEAT)  # the engine's grille at the back
    for sx in (-1, 1):
        S.add(box(P, (sx * 2.55, 2.55, 2.3), (0.72, 0.13, 1.35), rr=0.08), GOLDY)  # fenders
        S.add(box(P, (sx * 1.5, 1.95, -0.45), (0.2, 0.45, 1.45), rr=0.1), GOLDY)  # side pods
        S.paint((np.abs(x - sx * 1.7) < 0.1) & (np.abs(y - 1.95) < 0.08) & (np.abs(z + 0.45) < 1.2), SEAT, depth=0.2)
    S.add(box(P, (0, 1.65, -0.55), (1.25, 0.06, 0.95)), PLATE)  # the floor
    S.add(box(P, (0, 0.6, -2.45), (3.0, 0.28, 1.25), rr=0.2), GOLDY)  # the wide front deck
    S.add(box(P, (0, 0.32, -2.45), (3.05, 0.06, 1.3)), SEAT)
    S.add(cyl(P, (-1.5, 0.9, -2.45), (-1.5, 1.05, -2.45), 0.34), SEAT)
    S.add(cyl(P, (1.5, 0.9, -2.45), (1.5, 1.05, -2.45), 0.34), SEAT)
    S.add(box(P, (0, 1.6, -2.15), (1.3, 0.32, 0.22), rr=0.08), SEAT)
    S.add(box(P, (0, 1.85, -2.38), (1.15, 0.1, 0.05)), LIGHT_W)  # the light strip
    seat(S, 1.0, SEAT, top=3.0, backTop=4.65, lean=14, w=1.0, pipe=GOLDY)
    for sx in (-1, 1):  # the roll bar behind the seat
        S.add(cyl(P, (sx * 1.45, 2.6, 3.3), (sx * 1.45, 5.0, 3.55), 0.13), CHROME)
    S.add(cyl(P, (-1.45, 5.0, 3.55), (1.45, 5.0, 3.55), 0.13), CHROME)
    for sx in (-1, 1):  # the lap bars, from the side pods up and in to the grips
        g = A((sx * 0.72, 4.15, -0.52))
        S.add(cyl(P, (sx * 1.5, 2.3, 0.3), (sx * 1.5, 3.65, 0.0), 0.11), CHROME)
        S.add(cyl(P, (sx * 1.5, 3.65, 0.0), g + A((sx * 0.25, 0, 0.02)), 0.11), CHROME)
        S.add(cyl(P, g + A((sx * 0.3, 0, 0)), g - A((sx * 0.32, 0, 0)), 0.13), TYRE)
    S.add(cyl(P, (-0.9, 2.9, 3.3), (-0.9, 3.4, 3.3), 0.13), CHROME)  # the exhaust
    return [S,
            wheel(o, "RL", (-2.55, 1.2, 2.3), 1.2, 1.2, TYRE, GOLDY, 10, 1), wheel(o, "RR", (2.55, 1.2, 2.3), 1.2, 1.2, TYRE, GOLDY, 10, 2),
            wheel(o, "FL", (-2.6, 0.42, -3.7), 0.42, 0.45, TYRE, GOLDY, 4, 3), wheel(o, "FR", (2.6, 0.42, -3.7), 0.42, 0.45, TYRE, GOLDY, 4, 4)]


# ---------------------------------------------------------------------------------------------------------------
# the Monster Mulcher: a purple monster machine on huge gold-hubbed tyres, a grinding drum up front with teeth, a cab
# roof on four posts with an orange light bar, built high enough for a rider (shared/MowerSeats lifts nothing on it)
# ---------------------------------------------------------------------------------------------------------------
def mower_mulcher():
    o = "mower_mulcher"
    S = Sculpt(PAL, o, (-3.4, 0, -5.0), (3.4, 8.3, 4.6), V_RIDE, seed=37, shade=SHADE)
    P = S.P
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    S.add(box(P, (0, 1.65, 0.3), (1.5, 0.38, 3.0), rr=0.12), GREY)
    for sx in (-1, 1):
        S.add(cyl(P, (sx * 1.4, 1.75, 2.3), (sx * 2.1, 1.75, 2.3), 0.25), STEEL_D)
        S.add(cyl(P, (sx * 1.4, 1.45, -1.6), (sx * 2.1, 1.45, -1.6), 0.22), STEEL_D)
    S.add(box(P, (0, 2.35, 2.35), (1.8, 0.78, 1.55), rr=0.35), PURPLE)  # the engine body behind
    for k in range(4):
        S.carve(box(P, (0, 2.0 + k * 0.25, 3.9), (1.2, 0.06, 0.1)))
    for sx in (-1, 1):
        S.add(box(P, (sx * 2.65, 3.7, 2.3), (0.7, 0.16, 1.85), rr=0.08), PURPLE)
        S.add(box(P, (sx * 2.65, 3.15, -1.6), (0.62, 0.16, 1.55), rr=0.08), PURPLE)
        S.add(box(P, (sx * 1.95, 3.0, 2.3), (0.08, 0.7, 1.2)), PURPLE)
    S.add(box(P, (0, 2.05, -3.65), (2.1, 1.05, 0.95), rr=0.25), GREY)  # the drum box
    S.add(box(P, (0, 3.1, -3.65), (2.15, 0.12, 1.0), rr=0.05), GOLDY)
    for k in range(4):
        S.paint((np.abs(x - (-1.5 + k)) < 0.25) & (np.abs(y - 2.1) < 0.6) & (z < -4.4), GOLDY if k % 2 else STEEL_D, depth=0.2)
    S.carve(box(P, (0, 0.75, -3.65), (1.95, 0.6, 0.75)))  # the drum's cave under it
    S.add(cyl(P, (-1.9, 0.75, -3.65), (1.9, 0.75, -3.65), 0.58), STEEL_D)
    for k in range(10):
        xx = -1.7 + k * 0.38
        an = k * 1.3
        S.add(box(P, (xx, 0.75 + 0.62 * math.sin(an), -3.65 + 0.62 * math.cos(an)), (0.09, 0.12, 0.12)), CHROME)
    light(S, (-1.3, 2.75, -4.62), (0.22, 0.14, 0.05), LIGHT_O)
    light(S, (1.3, 2.75, -4.62), (0.22, 0.14, 0.05), LIGHT_O)
    S.add(box(P, (0, 1.4, 0.2), (1.2, 0.06, 0.7)), PLATE)  # the floor
    S.add(box(P, (0, 3.6, -1.15), (1.2, 0.16, 0.35), rr=0.08), SEAT)  # the dash
    seat(S, 1.0, SEAT, top=3.0, backTop=4.7, lean=8, w=1.1, pipe=GOLDY)
    column(S, (0, 4.45, 0.25), (0, 0.96, -0.68), 1.25)
    for sx in (-1, 1):  # the cab: four posts and the roof
        for zz in (-1.15, 2.65):
            S.add(box(P, (sx * 1.6, 5.15, zz), (0.13, 2.6, 0.13)), PURPLE)
    S.add(box(P, (0, 7.85, 0.75), (1.9, 0.18, 2.2), rr=0.1), PURPLE)
    S.add(box(P, (0, 8.06, 0.75), (1.6, 0.06, 1.9)), SEAT)
    S.add(box(P, (0, 8.14, -1.05), (1.35, 0.1, 0.14)), SEAT)
    for sx in (-0.9, 0.0, 0.9):
        S.add(box(P, (sx, 8.2, -1.05), (0.25, 0.1, 0.16)), LIGHT_O)
    for sx in (-1, 1):  # twin exhausts behind
        S.add(cyl(P, (sx * 1.2, 3.0, 3.35), (sx * 1.2, 5.5, 3.35), 0.15), CHROME)
        S.add(cyl(P, (sx * 1.2, 5.35, 3.35), (sx * 1.2, 5.75, 3.35), 0.21), BLACK)
    return [S,
            wheel(o, "RL", (-2.65, 1.75, 2.3), 1.75, 1.2, TYRE, GOLDY, 10, 1), wheel(o, "RR", (2.65, 1.75, 2.3), 1.75, 1.2, TYRE, GOLDY, 10, 2),
            wheel(o, "FL", (-2.65, 1.45, -1.6), 1.45, 1.05, TYRE, GOLDY, 8, 3), wheel(o, "FR", (2.65, 1.45, -1.6), 1.45, 1.05, TYRE, GOLDY, 8, 4),
            steer(o, (0, 4.45, 0.25), 0.59, (0, 0.96, -0.68), TYRE)]


# ---------------------------------------------------------------------------------------------------------------
# the Rocket Mower: a low red-and-white racer, a glass windscreen, side rocket boosters with flames out the back, cyan
# underglow and rims, a spoiler
# ---------------------------------------------------------------------------------------------------------------
def mower_rocket():
    o = "mower_rocket"
    S = Sculpt(PAL, o, (-3.1, 0, -5.3), (3.1, 5.3, 5.3), V_RIDE, seed=39, shade=SHADE)
    P = S.P
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    S.add(box(P, (0, 1.2, -0.3), (1.45, 0.28, 3.6), rr=0.1), GREY)
    for sx in (-1, 1):
        S.add(cyl(P, (sx * 1.4, 1.0, 2.3), (sx * 2.0, 1.0, 2.3), 0.2), STEEL_D)
        S.add(cyl(P, (sx * 1.4, 0.75, -3.0), (sx * 1.95, 0.75, -3.0), 0.18), STEEL_D)
    nose = box(P, (0, 1.7, -2.5), (1.35, 0.55, 1.9), rr=0.42)  # the nose: red over white
    S.add(nose, ROCKET_RED)
    S.paint((y < 1.5) & (nose <= 0), WHITE)
    S.paint((np.abs(x) < 0.22) & (y > 2.0) & (nose <= 0), WHITE, depth=0.2)  # a racing stripe
    S.add(box(P, (0, 1.35, -4.5), (1.55, 0.1, 0.45), rr=0.05), ROCKET_RED)  # the front wing
    for sx in (-1, 1):
        S.add(box(P, (sx * 1.55, 1.6, -4.5), (0.06, 0.3, 0.45)), WHITE)
        light(S, (sx * 0.85, 1.85, -4.35), (0.2, 0.1, 0.05), LIGHT_W)
    S.add(box(P, (0, 2.35, -1.0), (1.2, 0.26, 0.9), rr=0.2), WHITE)
    S.add(box(P, (0, 2.95, -0.64), (1.0, 0.38, 0.06), rot(-30, 0, 0)), GLASS)  # the windscreen
    S.add(box(P, (0, 2.1, 2.0), (1.7, 0.6, 1.4), rr=0.35), ROCKET_RED)  # the rear body
    S.add(box(P, (0, 2.72, 2.6), (1.4, 0.08, 0.8)), WHITE)
    seat(S, 1.0, SEAT, top=3.0, backTop=4.35, lean=18, w=0.95, pipe=ROCKET_RED)
    column(S, (0, 3.35, 0.3), (0, 0.82, -0.48), 1.0)
    for sx in (-1, 1):  # the boosters, flames out the back
        S.add(cyl(P, (sx * 2.0, 2.65, -0.2), (sx * 2.0, 2.65, 3.9), 0.42, 0.15), WHITE)
        S.add(cone(P, (sx * 2.0, 2.65, -0.2), (sx * 2.0, 2.65, -1.25), 0.42, 0.06), ROCKET_RED)
        for zz in (0.9, 2.6):
            S.add(cyl(P, (sx * 2.0, 2.65, zz - 0.1), (sx * 2.0, 2.65, zz + 0.1), 0.47), ROCKET_RED)
        for k in range(3):
            an = math.radians(90 + k * 120)
            S.add(box(P, (sx * 2.0 + 0.5 * math.cos(an) * sx, 2.65 + 0.5 * math.sin(an), 3.5), (0.05, 0.22, 0.3)), ROCKET_RED)
        S.add(cyl(P, (sx * 2.0, 2.65, 3.85), (sx * 2.0, 2.65, 4.15), 0.34), STEEL_D)
        S.add(cone(P, (sx * 2.0, 2.65, 4.1), (sx * 2.0, 2.65, 5.15), 0.3, 0.05), FLAME)
        S.add(cone(P, (sx * 2.0, 2.65, 4.1), (sx * 2.0, 2.65, 4.65), 0.19, 0.05), FLAME_Y)
        S.add(box(P, (sx * 1.6, 2.15, 0.6), (0.3, 0.12, 0.7)), STEEL_D)  # the mounts
        S.add(box(P, (sx * 1.5, 0.9, -0.5), (0.06, 0.06, 2.8)), CYAN)  # underglow
        S.add(box(P, (sx * 1.3, 3.0, 3.55), (0.08, 0.32, 0.2)), STEEL_D)  # the spoiler's legs
    S.add(box(P, (0, 3.35, 3.6), (1.65, 0.08, 0.34), rr=0.04), ROCKET_RED)  # the spoiler
    return [S,
            wheel(o, "RL", (-2.45, 1.0, 2.3), 1.0, 1.0, TYRE, CYAN, 6, 1), wheel(o, "RR", (2.45, 1.0, 2.3), 1.0, 1.0, TYRE, CYAN, 6, 2),
            wheel(o, "FL", (-2.35, 0.75, -3.0), 0.75, 0.8, TYRE, CYAN, 6, 3), wheel(o, "FR", (2.35, 0.75, -3.0), 0.75, 0.8, TYRE, CYAN, 6, 4),
            steer(o, (0, 3.35, 0.3), 0.475, (0, 0.82, -0.48), TYRE)]


# where exhaust smoke comes out of each (client/MowerFx: parts named "ExhaustTip"); server/Models adds them
EXHAUST = {
    "mower_rusty": [(1.0, 3.62, -1.25)],
    "mower_tractor": [(1.05, 6.27, -1.6)],
    "mower_zeroturn": [(-0.9, 3.42, 3.3)],
    "mower_mulcher": [(-1.2, 5.77, 3.35), (1.2, 5.77, 3.35)],
    "mower_rocket": [(-2.0, 2.65, 4.2), (2.0, 2.65, 4.2)],
}

ITEMS = [scissorhalf, scythe, vacuum, bag_satchel, bag_backpack, bag_hiker, bag_infinite,
         mower_rusty, mower_tractor, mower_zeroturn, mower_mulcher, mower_rocket]


def sculpts():
    """Every group, the multi-group mowers flattened."""
    out = []
    for f in ITEMS:
        r = f()
        out.extend(r if isinstance(r, list) else [r])
    return out


def main():
    """Writes src/server/VoxelItemShapes.luau (server/Models builds the templates from it; the client gets the
    scissor half as the template MowALawnModels.voxel_scissorhalf). Previews: pass a folder."""
    import os
    import sys

    from sculptkit import write_luau

    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
    groups = sculpts()
    exhaust = "{ %s }" % ", ".join('%s = { %s }' % (k, ", ".join("Vector3.new(%g, %g, %g)" % p for p in v)) for k, v in EXHAUST.items())
    write_luau(os.path.join(root, "src", "server", "VoxelItemShapes.luau"), "items_voxel.py", PAL, groups, {"EXHAUST": exhaust})
    if len(sys.argv) > 1:
        os.makedirs(sys.argv[1], exist_ok=True)
        for S in groups:
            if not S.parent:
                T.preview(S, os.path.join(sys.argv[1], S.name + ".png"))


if __name__ == "__main__":
    main()
