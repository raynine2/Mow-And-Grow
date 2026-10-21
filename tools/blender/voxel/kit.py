"""Voxel model kit for Mow And Grow, in the Catch a Brainrot style.

A model is a dict {(x, y, z): colour_index} on a voxel grid (y up). build() turns it into one mesh with only the
outside faces, each face UV-mapped onto a tile of a small texture atlas: every tile is the colour with a lighter
bevelled rim and a soft darker centre, so every voxel shows its own little lit edge like the reference's blocks.
export_fbx() writes the model (mesh + embedded atlas) for Studio's Import 3D.

Run with Blender's Python module: python -m pip install bpy, then  python tools/blender/voxel/build_all.py
"""
import math
import os
import random

import bpy
import bmesh

TILE = 16  # pixels per atlas tile


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_atlas(name, colours, path):
    """One tile per colour: lighter rim (the lit bevel), the flat colour, a slightly darker centre."""
    n = len(colours)
    w, h = TILE * n, TILE
    img = bpy.data.images.new(name, width=w, height=h, alpha=False)
    px = [0.0] * (w * h * 4)
    for ci, c in enumerate(colours):
        r, g, b = [v / 255 for v in c]
        for y in range(TILE):
            for x in range(TILE):
                edge = min(x, y, TILE - 1 - x, TILE - 1 - y)
                if edge == 0:
                    k = 1.13  # lit rim (soft: no hologram look)
                elif edge == 1:
                    k = 1.05
                elif edge >= 5:
                    k = 0.98  # soft centre
                else:
                    k = 1.0
                i = ((y * w) + ci * TILE + x) * 4
                px[i] = min(1, r * k)
                px[i + 1] = min(1, g * k)
                px[i + 2] = min(1, b * k)
                px[i + 3] = 1
    img.pixels = px
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    return img


FACES = [
    ((1, 0, 0), [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)]),
    ((-1, 0, 0), [(0, 0, 1), (0, 1, 1), (0, 1, 0), (0, 0, 0)]),
    ((0, 1, 0), [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)]),
    ((0, -1, 0), [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)]),
    ((0, 0, 1), [(1, 0, 1), (1, 1, 1), (0, 1, 1), (0, 0, 1)]),
    ((0, 0, -1), [(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)]),
]


def build(name, vox, colours, voxel_size=1.0, origin=(0, 0, 0), atlas_dir="/tmp"):
    """Mesh from voxels: outside faces only, each mapped to its colour tile. y is up in `vox`; Blender is z-up,
    so (x, y, z) -> (x, -z, y). `origin` is subtracted (in voxels) so the model's pivot sits where we want."""
    atlas_path = os.path.join(atlas_dir, name + "_atlas.png")
    img = make_atlas(name + "_atlas", colours, atlas_path)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    n = len(colours)
    verts = {}

    def vert(p):
        v = verts.get(p)
        if v is None:
            x, y, z = p
            v = bm.verts.new(((x - origin[0]) * voxel_size, -(z - origin[2]) * voxel_size, (y - origin[1]) * voxel_size))
            verts[p] = v
        return v

    for (x, y, z), ci in vox.items():
        for normal, corners in FACES:
            nb = (x + normal[0], y + normal[1], z + normal[2])
            if nb in vox:
                continue
            vs = [vert((x + c[0], y + c[1], z + c[2])) for c in corners]
            try:
                f = bm.faces.new(vs)
            except ValueError:
                continue
            u0 = ci / n
            u1 = (ci + 1) / n
            tuv = [(u0, 0), (u0, 1), (u1, 1), (u1, 0)]
            for loop, t in zip(f.loops, tuv):
                loop[uv].uv = t
    bm.normal_update()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    # flip normals if they point inward (face winding from our table is consistent, but check one)
    me.validate()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    # recalc normals outward
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    mat = bpy.data.materials.new(name + "_mat")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.6
    me.materials.append(mat)
    return obj


def export_fbx(obj, path):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        apply_unit_scale=True,
        global_scale=1.0,
        axis_forward="-Z",
        axis_up="Y",
        path_mode="COPY",
        embed_textures=True,
        mesh_smooth_type="FACE",
    )


# ---------------------------------------------------------------------------------------------------------------
# shape helpers
# ---------------------------------------------------------------------------------------------------------------
def ball(vox, c, r, colour_fn):
    cx, cy, cz = c
    ir = int(math.ceil(r))
    for x in range(-ir, ir + 1):
        for y in range(-ir, ir + 1):
            for z in range(-ir, ir + 1):
                if x * x + y * y + z * z <= r * r + 0.3:
                    p = (cx + x, cy + y, cz + z)
                    vox[p] = colour_fn(p, (x, y, z), r)


def box(vox, a, b, ci):
    for x in range(min(a[0], b[0]), max(a[0], b[0]) + 1):
        for y in range(min(a[1], b[1]), max(a[1], b[1]) + 1):
            for z in range(min(a[2], b[2]), max(a[2], b[2]) + 1):
                vox[(x, y, z)] = ci if not callable(ci) else ci((x, y, z))


def cylinder(vox, c, r, y0, y1, ci):
    cx, cz = c
    ir = int(math.ceil(r))
    for x in range(-ir, ir + 1):
        for z in range(-ir, ir + 1):
            if x * x + z * z <= r * r + 0.3:
                for y in range(y0, y1 + 1):
                    vox[(cx + x, y, cz + z)] = ci if not callable(ci) else ci((cx + x, y, cz + z))


# ---------------------------------------------------------------------------------------------------------------
# one shared atlas for every model (one texture to upload, one material)
# ---------------------------------------------------------------------------------------------------------------
class Atlas:
    """A 16 x 16 grid of colour tiles (256 colours). Tiles are 32 px so Roblox's filtering keeps the soft rim."""

    GRID = 16
    PX = 32

    def __init__(self):
        self.index = {}

    def tile(self, rgb):
        rgb = tuple(int(max(0, min(255, c))) for c in rgb)
        i = self.index.get(rgb)
        if i is None:
            i = len(self.index)
            if i >= self.GRID * self.GRID:
                raise RuntimeError("atlas full")
            self.index[rgb] = i
        g = self.GRID
        u0, v0 = (i % g) / g, (i // g) / g
        inset = 1.5 / (g * self.PX)  # keep the uv off the tile border
        return u0 + inset, v0 + inset, u0 + 1 / g - inset, v0 + 1 / g - inset

    def image(self, name, path):
        g, P = self.GRID, self.PX
        w = g * P
        img = bpy.data.images.new(name, width=w, height=w, alpha=False)
        px = [0.0] * (w * w * 4)
        for rgb, i in self.index.items():
            r, gg, b = [v / 255 for v in rgb]
            tx, ty = (i % g) * P, (i // g) * P
            for y in range(P):
                for x in range(P):
                    edge = min(x, y, P - 1 - x, P - 1 - y)
                    k = 1.13 if edge < 2 else (1.05 if edge < 4 else (0.98 if edge > 9 else 1.0))
                    j = ((ty + y) * w + tx + x) * 4
                    px[j], px[j + 1], px[j + 2], px[j + 3] = min(1, r * k), min(1, gg * k), min(1, b * k), 1
        img.pixels = px
        img.filepath_raw = path
        img.file_format = "PNG"
        img.save()
        return img


def build_shared(name, vox, pal, atlas, voxel_size=1.0, centre=True):
    """Mesh from voxels with uvs into the shared atlas. The pivot is the middle of the footprint at ground level."""
    xs = [p[0] for p in vox]
    zs = [p[2] for p in vox]
    ys = [p[1] for p in vox]
    ox = (min(xs) + max(xs) + 1) / 2 if centre else 0
    oz = (min(zs) + max(zs) + 1) / 2 if centre else 0
    oy = min(ys)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    verts = {}

    def vert(p):
        v = verts.get(p)
        if v is None:
            x, y, z = p
            v = bm.verts.new(((x - ox) * voxel_size, -(z - oz) * voxel_size, (y - oy) * voxel_size))
            verts[p] = v
        return v

    tiles = [atlas.tile(c) for c in pal]
    for (x, y, z), ci in vox.items():
        u0, v0, u1, v1 = tiles[ci]
        for normal, corners in FACES:
            if (x + normal[0], y + normal[1], z + normal[2]) in vox:
                continue
            try:
                f = bm.faces.new([vert((x + c[0], y + c[1], z + c[2])) for c in corners])
            except ValueError:
                continue
            for loop, t in zip(f.loops, [(u0, v0), (u0, v1), (u1, v1), (u1, v0)]):
                loop[uv].uv = t
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.validate()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    size = ((max(xs) - min(xs) + 1) * voxel_size, (max(ys) - min(ys) + 1) * voxel_size, (max(zs) - min(zs) + 1) * voxel_size)
    return obj, size


def shared_material(img):
    mat = bpy.data.materials.new("MowAtlas")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.6
    return mat


def build_columns(name, vox, pal, atlas, voxel_size=1.0):
    """Like build_shared, but each vertical run of one colour becomes a single box. For grass, where blades are
    thin columns: about a tenth of the triangles, and every brick-run still gets its lit outline."""
    xs = [p[0] for p in vox]
    zs = [p[2] for p in vox]
    ys = [p[1] for p in vox]
    ox, oz, oy = (min(xs) + max(xs) + 1) / 2, (min(zs) + max(zs) + 1) / 2, min(ys)
    runs = []
    cols = {}
    for (x, y, z), ci in vox.items():
        cols.setdefault((x, z), []).append((y, ci))
    for (x, z), items in cols.items():
        items.sort()
        start, prev, pci = items[0][0], items[0][0], items[0][1]
        for y, ci in items[1:] + [(None, None)]:
            if y is not None and y == prev + 1 and ci == pci:
                prev = y
                continue
            runs.append((x, start, z, prev + 1, pci))
            if y is not None:
                start, prev, pci = y, y, ci
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    tiles = [atlas.tile(c) for c in pal]
    for (x, y0, z, y1, ci) in runs:
        u0, v0, u1, v1 = tiles[ci]
        for normal, corners in FACES:
            if normal == (0, -1, 0) and ((x, y0 - 1, z) in vox or y0 == oy):
                continue
            if normal == (0, 1, 0) and (x, y1, z) in vox:
                continue
            if normal[1] == 0 and all((x + normal[0], y, z + normal[2]) in vox for y in range(y0, y1)):
                continue
            pts = []
            for c in corners:
                yy = y0 + c[1] * (y1 - y0)
                pts.append(bm.verts.new(((x + c[0] - ox) * voxel_size, -(z + c[2] - oz) * voxel_size, (yy - oy) * voxel_size)))
            f = bm.faces.new(pts)
            for loop, t in zip(f.loops, [(u0, v0), (u0, v1), (u1, v1), (u1, v0)]):
                loop[uv].uv = t
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    size = ((max(xs) - min(xs) + 1) * voxel_size, (max(ys) - min(ys) + 1) * voxel_size, (max(zs) - min(zs) + 1) * voxel_size)
    return obj, size
