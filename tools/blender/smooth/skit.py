"""Smooth cartoon modelling kit (Blender bmesh): bevelled boxes, tapered cylinders, cones, soft blobs and hulls,
all written into one mesh per model, each face coloured through a shared palette texture (uv on the colour's tile).

Shapes are placed in GAME space: x right, y up, front = -z (the way the game's models face). The finished mesh is
turned into Blender space (x, -z, y), so the FBX comes into Studio like the voxel models do (server/VoxelModels).

Faces are lightly pre-shaded (down-facing faces a touch darker, blobs darker toward their bottom), which reads as
soft cartoon shading under Roblox's lighting.
"""
import math
import random

import bmesh
import bpy
from mathutils import Matrix, Vector


# ------------------------------------------------------------------------------------------------ transforms
def T(x=0.0, y=0.0, z=0.0):
    return Matrix.Translation((x, y, z))


def Ry(deg):
    return Matrix.Rotation(math.radians(deg), 4, "Y")


def Rx(deg):
    return Matrix.Rotation(math.radians(deg), 4, "X")


def Rz(deg):
    return Matrix.Rotation(math.radians(deg), 4, "Z")


def S(x, y=None, z=None):
    y = x if y is None else y
    z = x if z is None else z
    return Matrix.Diagonal((x, y, z, 1))


UPZ = Rx(-90)  # bmesh makes cones along local z; this stands them up along game y
TO_BLENDER = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def look(frm, to):
    """A matrix at `frm` whose local +y points at `to` (for logs, branches, ropes)."""
    a, b = Vector(frm), Vector(to)
    d = (b - a)
    up = Vector((0, 1, 0))
    q = up.rotation_difference(d.normalized())
    return Matrix.Translation(a) @ q.to_matrix().to_4x4()


# ------------------------------------------------------------------------------------------------ colour helpers
def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def dark(c, k):
    return tuple(v * (1 - k) for v in c)


def light(c, k):
    return tuple(v + (255 - v) * k for v in c)


def quant(c):
    return tuple(int(round(v / 4.0) * 4) for v in c)


class Palette:
    """A grid of flat colour tiles. Every face's loops get the middle of its colour's tile."""

    def __init__(self, grid=32, px=16):
        self.grid, self.px, self.index = grid, px, {}

    def uv(self, rgb):
        rgb = tuple(int(max(0, min(255, v))) for v in rgb)
        i = self.index.get(rgb)
        if i is None:
            i = len(self.index)
            if i >= self.grid * self.grid:
                raise RuntimeError("palette full")
            self.index[rgb] = i
        g = self.grid
        return ((i % g) + 0.5) / g, ((i // g) + 0.5) / g

    def image(self, name, path):
        g, P = self.grid, self.px
        w = g * P
        img = bpy.data.images.new(name, width=w, height=w, alpha=False)
        px = [0.0] * (w * w * 4)
        for rgb, i in self.index.items():
            r, gg, b = [v / 255 for v in rgb]
            tx, ty = (i % g) * P, (i // g) * P
            for y in range(P):
                row = ((ty + y) * w + tx) * 4
                for x in range(P):
                    j = row + x * 4
                    px[j], px[j + 1], px[j + 2], px[j + 3] = r, gg, b, 1
        img.pixels = px
        img.filepath_raw = path
        img.file_format = "PNG"
        img.save()
        return img


# ------------------------------------------------------------------------------------------------ the mesh
class Model:
    def __init__(self, name, palette, seed=1):
        self.name = name
        self.pal = palette
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.rng = random.Random(seed)

    # copy a finished temporary bmesh (already in game space) in, colouring each face
    def _take(self, tmp, colour, smooth, shade):
        tmp.normal_update()
        vmap = {}
        for v in tmp.verts:
            vmap[v] = self.bm.verts.new(v.co)
        ys = [v.co.y for v in tmp.verts] or [0]
        y0, y1 = min(ys), max(ys)
        for f in tmp.faces:
            try:
                nf = self.bm.faces.new([vmap[v] for v in f.verts])
            except ValueError:
                continue
            nf.smooth = smooth(f) if callable(smooth) else smooth
            c = colour
            if callable(shade):
                c = shade(f, y0, y1)
            elif shade:
                # soft baked light: faces looking down a little darker
                ny = f.normal.y
                c = dark(colour, 0.12) if ny < -0.5 else colour
            c = quant(c)
            u, v = self.pal.uv(c)
            for lp in nf.loops:
                lp[self.uv].uv = (u, v)
        tmp.free()

    # ---------------------------------------------------------------------------------------- primitives
    def box(self, size, cf, colour, bevel=0.0, shade=True, seg=1):
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        bmesh.ops.scale(tmp, vec=Vector(size), verts=tmp.verts)
        if bevel > 0:
            b = min(bevel, min(size) * 0.45)
            bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=b, offset_type="OFFSET", segments=seg, profile=0.5, affect="EDGES")
        bmesh.ops.transform(tmp, matrix=cf, verts=tmp.verts)
        self._take(tmp, colour, False, shade)

    def cyl(self, r, h, cf, colour, seg=12, r2=None, smooth=True, bevel=0.0, shade=True, cap=None):
        """Cylinder (or tapered: r at the bottom, r2 at the top) standing on cf's origin, axis along local y."""
        tmp = bmesh.new()
        bmesh.ops.create_cone(tmp, cap_ends=True, cap_tris=False, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=h)
        if bevel > 0:
            rim = [e for e in tmp.edges if len(e.link_faces) == 2 and abs(e.link_faces[0].normal.dot(e.link_faces[1].normal)) < 0.5]
            bmesh.ops.bevel(tmp, geom=rim, offset=min(bevel, h * 0.4), offset_type="OFFSET", segments=2, profile=0.5, affect="EDGES")
        full = cf @ T(0, h / 2, 0) @ UPZ
        bmesh.ops.transform(tmp, matrix=full, verts=tmp.verts)
        ax = (full.to_3x3() @ Vector((0, 0, 1))).normalized()
        # the end caps stay flat (smoothing them into the sides shades them dark)
        sm = (lambda f: abs(f.normal.dot(ax)) < 0.9) if smooth else False
        if cap:
            base = shade

            def shade(f, y0, y1):
                if abs(f.normal.dot(ax)) > 0.9:
                    return cap
                return dark(colour, 0.12) if base and f.normal.y < -0.5 else colour

        self._take(tmp, colour, sm, shade)

    def log(self, a, b, r, colour, end_colour=None, seg=8):
        """A round log from point a to b with lighter cut ends."""
        a, b = Vector(a), Vector(b)
        h = (b - a).length
        self.cyl(r, h, look(a, b), colour, seg=seg, smooth=True, cap=end_colour)

    def cone(self, r, h, cf, colour, seg=10, tip=0.0, smooth=False, shade=True):
        self.cyl(r, h, cf, colour, seg=seg, r2=tip, smooth=smooth, shade=shade)

    def blob(self, r, cf, colour, sub=2, squash=(1, 1, 1), noise=0.12, smooth=True, grad=0.28):
        """A soft round lump (leaves, bushes, clouds of flowers): a noisy icosphere, darker toward its bottom."""
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=sub, radius=r)
        for v in tmp.verts:
            n = v.co.normalized()
            k = 1 + (self.rng.random() - 0.5) * 2 * noise
            v.co = Vector((n.x * r * k * squash[0], n.y * r * k * squash[1], n.z * r * k * squash[2]))
        bmesh.ops.transform(tmp, matrix=cf, verts=tmp.verts)

        def shade(f, y0, y1):
            t = (f.calc_center_median().y - y0) / max(y1 - y0, 1e-3)
            k = 3 if t > 0.62 else (2 if t > 0.35 else (1 if t > 0.15 else 0))
            return [dark(colour, grad), dark(colour, grad * 0.55), colour, light(colour, 0.1)][k]

        self._take(tmp, colour, smooth, shade if grad else False)

    def rock(self, r, cf, colour, squash=(1, 0.7, 1), noise=0.22):
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=1, radius=r)
        for v in tmp.verts:
            n = v.co.normalized()
            k = 1 + (self.rng.random() - 0.5) * 2 * noise
            v.co = Vector((n.x * r * k * squash[0], max(n.y, -0.3) * r * k * squash[1], n.z * r * k * squash[2]))
        bmesh.ops.transform(tmp, matrix=cf, verts=tmp.verts)
        self._take(tmp, colour, False, True)

    def hull(self, points, cf, colour, smooth=False, shade=True):
        tmp = bmesh.new()
        vs = [tmp.verts.new(p) for p in points]
        bmesh.ops.convex_hull(tmp, input=vs)
        bmesh.ops.transform(tmp, matrix=cf, verts=tmp.verts)
        self._take(tmp, colour, smooth, shade)

    def prism(self, w, h, d, cf, colour, overhang=0.0):
        """A gable roof shape: width w along x, height h, depth d along z; ridge along x."""
        x, z = w / 2, d / 2
        self.hull([(-x, 0, -z), (x, 0, -z), (-x, 0, z), (x, 0, z), (-x, h, 0), (x, h, 0)], cf, colour)

    def roof(self, w, d, h, cf, colour, thick=0.45, edge=None):
        """A pitched roof of two thick slabs meeting at a ridge along x (w long), eaves at y 0, ridge at y h, slabs
        reaching d/2 to either side, with a ridge cap."""
        half = d / 2
        ang = math.degrees(math.atan2(h, half))
        ln = math.hypot(h, half) + 0.3
        for s in (-1, 1):
            m = cf @ T(0, h / 2, s * half / 2) @ Rx(s * ang)
            self.box((w, thick, ln), m, colour, bevel=0.08)
            if edge:
                # a trim board along the eave
                self.box((w + 0.1, 0.3, 0.3), cf @ T(0, -0.1, s * (half + 0.05)), edge, bevel=0.05)
        self.cyl(thick * 0.7, w + 0.4, cf @ T(-(w + 0.4) / 2, h + 0.1, 0) @ Rz(-90), dark(colour, 0.2), seg=8)

    # ---------------------------------------------------------------------------------------- output
    def finish(self):
        """Centre the footprint on x/z, put the lowest point at y 0, turn into Blender space, make the object.
        Returns (object, size in studs (x, y, z), origin in design space (where the footprint middle at the
        lowest point sits relative to the design's own origin))."""
        bm = self.bm
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
        xs = [v.co.x for v in bm.verts]
        ys = [v.co.y for v in bm.verts]
        zs = [v.co.z for v in bm.verts]
        cx, cz, y0 = (min(xs) + max(xs)) / 2, (min(zs) + max(zs)) / 2, min(ys)
        size = (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))
        bmesh.ops.transform(bm, matrix=TO_BLENDER @ T(-cx, -y0, -cz), verts=bm.verts)
        me = bpy.data.meshes.new(self.name)
        bm.to_mesh(me)
        bm.free()
        me.validate()
        obj = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(obj)
        return obj, size, (cx, y0, cz)


def material(img, name):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.7
    return mat
