"""Far-off mountain: a faceted low-poly peak (about 60 across, 62 high) with slate-grey rock slopes, a few ledges,
and a snow cap whose ragged lower edge follows the rock below. Background scenery, no collisions needed."""
import math, random
import bmesh

PREVIEW = dict(dist=150, height=40, target_z=26, yaw=25)

RINGS = [(30.0, 0.0), (26.5, 9.0), (22.0, 19.0), (17.5, 29.0), (13.0, 38.0), (8.5, 47.0), (4.5, 55.0)]
SNOW_FROM = 3  # rings from here up are snow
SEG = 11


def build(lib):
    rnd = random.Random(12)
    rock = lib.material("Slate", (120, 130, 145))
    rock_dark = lib.material("Slate", (98, 106, 120))
    snow = lib.material("Snow", (240, 245, 250))
    # jittered rings, shared by the rock and the snow meshes so they meet without gaps
    rings = []
    for j, (r, z) in enumerate(RINGS):
        twist = j * 0.21
        ring = []
        for i in range(SEG):
            a = 2 * math.pi * i / SEG + twist + rnd.uniform(-0.12, 0.12)
            rr = r * (rnd.uniform(0.82, 1.12) if j else rnd.uniform(0.9, 1.1))
            zz = z + (rnd.uniform(-2.5, 2.5) if j else 0)
            ring.append((math.cos(a) * rr, math.sin(a) * rr, zz))
        rings.append(ring)
    peak = (rnd.uniform(-1.5, 1.5), rnd.uniform(-1.5, 1.5), 62.0)

    def band(name, j0, j1, mat_a, mat_b, cap=False):
        # faces alternate between two shades so the facets read
        for mat, parity in ((mat_a, 0), (mat_b, 1)):
            bm = bmesh.new()
            vs = [[bm.verts.new(p) for p in ring] for ring in rings[j0:j1 + 1]]
            top = bm.verts.new(peak) if cap else None
            for j in range(len(vs) - 1):
                for i in range(SEG):
                    if (i + j) % 2 != parity:
                        continue
                    a, b = vs[j], vs[j + 1]
                    bm.faces.new((a[i], a[(i + 1) % SEG], b[(i + 1) % SEG]))
                    bm.faces.new((a[i], b[(i + 1) % SEG], b[i]))
            if cap:
                for i in range(SEG):
                    if i % 2 == parity:
                        bm.faces.new((vs[-1][i], vs[-1][(i + 1) % SEG], top))
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            if len(bm.faces):
                lib._finish(lib._from_bmesh("%s%d" % (name, parity), bm), mat, (0, 0, 0), (0, 0, 0), 0)
            else:
                bm.free()

    band("rock", 0, SNOW_FROM, rock, rock_dark)
    band("snow", SNOW_FROM, len(RINGS) - 1, snow, snow, cap=True)
    # rocky ledges sticking out of the slopes
    for i in range(4):
        a = i * 90 + rnd.uniform(-30, 30)
        z = 5 + i * 4
        # sunk into the slope: the cone's radius at height z, minus a bit
        lib.box("ledge%d" % i, (8, 5, 3.4), lib.rotated((0, 27.5 - z * 0.48, z), a), rot=(rnd.uniform(-8, 8), 0, a), mat=rock_dark, bevel=0.6)
