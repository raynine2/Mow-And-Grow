"""Gem pickup: the free gem a cut patch sometimes drops. A chunky faceted blue crystal (a stretched octahedron,
about 1.4 wide and 2 tall) with a glowing core showing through a gap round its middle. Origin at its centre,
since it floats and spins."""
import bmesh

PREVIEW = dict(dist=5, height=1.2, target_z=0.0, yaw=30, ground=False)


def _octa(lib, name, w, h, mat, z0=0.0):
    bm = bmesh.new()
    top = bm.verts.new((0, 0, z0 + h / 2))
    bot = bm.verts.new((0, 0, z0 - h / 2))
    ring = [bm.verts.new(p) for p in ((w / 2, 0, z0), (0, w / 2, z0), (-w / 2, 0, z0), (0, -w / 2, z0))]
    for i in range(4):
        bm.faces.new((ring[i], ring[(i + 1) % 4], top))
        bm.faces.new((ring[(i + 1) % 4], ring[i], bot))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return lib._finish(lib._from_bmesh(name, bm), mat, (0, 0, 0), (0, 0, 45), 0)


def build(lib):
    gem = lib.material("SmoothPlastic", (40, 140, 255))
    gem_light = lib.material("SmoothPlastic", (110, 200, 255))
    core = lib.material("Neon", (150, 230, 255))
    _octa(lib, "upper", 1.4, 2.0, gem, 0.0)
    _octa(lib, "facet", 1.0, 1.5, gem_light, 0.18)
    _octa(lib, "core", 0.7, 0.9, core, 0.0)
