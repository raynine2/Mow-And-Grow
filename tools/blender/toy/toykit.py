"""Toy-model kit: sculpted, smooth "vinyl toy" characters baked into ONE textured mesh for Roblox.

Method by fwjelaa (FWJ STUDIOS): sculpt in Blender from smooth primitives (pushed quad spheres, fused metaballs,
tubes, leaves), paint crisp colour regions from signed-distance fields stored per vertex, then bake colour, normal
and roughness from that high-detail model onto a decimated mesh. This file is our own implementation of the method.

Conventions: 1 unit = 1 stud. Models are built at toy scale (about 4 studs tall; the game scales them up), stand on
z = 0 and face -Y while sculpting (the preview camera looks from -Y). export() turns the baked mesh round so the
face ends up on Blender +Y, which every other model in this repo uses and which becomes the Roblox LookVector.
Never put a dot in an object name: Blender merges metaballs whose names match up to the dot.
"""
import json
import math
import os

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector


# ---------------------------------------------------------------------------------------------------- scene & basics
def lin(color):
    """'#rrggbb' -> linear RGBA."""
    c = color.lstrip("#")
    out = []
    for i in (0, 2, 4):
        v = int(c[i:i + 2], 16) / 255
        out.append(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4)
    return (*out, 1.0)


def new_scene(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    coll = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(coll)
    return coll


def _link(obj, coll):
    coll.objects.link(obj)
    return obj


def smooth(obj):
    if obj.type == "MESH":
        for p in obj.data.polygons:
            p.use_smooth = True
    return obj


def set_mats(obj, *materials):
    obj.data.materials.clear()
    for m in materials:
        obj.data.materials.append(m)
    return obj


def subdivide(obj, levels=1):
    mod = obj.modifiers.new("Subsurf", "SUBSURF")
    mod.levels = mod.render_levels = levels
    return mod


def apply_modifiers(obj):
    """Bakes the modifier stack into the mesh (keeps custom attributes)."""
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(obj.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    old = obj.data
    obj.modifiers.clear()
    obj.data = me
    if old.users == 0:
        bpy.data.meshes.remove(old)
    return obj


def turn(objects, pivot, rot_deg):
    """Rotates a group of objects (a head with its eyes and petals) about a pivot."""
    bpy.context.view_layer.update()
    m = (Matrix.Translation(Vector(pivot)) @ Euler([math.radians(a) for a in rot_deg]).to_matrix().to_4x4()
         @ Matrix.Translation(-Vector(pivot)))
    for obj in objects:
        if obj.parent is None:
            obj.matrix_world = m @ obj.matrix_world


def by_prefix(coll, *prefixes):
    return [o for o in coll.all_objects if any(o.name.startswith(p) for p in prefixes)]


# ---------------------------------------------------------------------------------------------------- materials
def mat(name, color, rough=0.5, coat=0.0, sheen=0.0, emit=0.0, bump=None, bump_scale=40.0, bump_strength=0.2,
        **_ignored):
    """Principled material. bump: None, 'pores' (cell dimples) or 'fabric' (fine noise)."""
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    col = lin(color)
    b.inputs["Base Color"].default_value = col
    b.inputs["Roughness"].default_value = rough
    b.inputs["Coat Weight"].default_value = coat
    b.inputs["Sheen Weight"].default_value = sheen
    if emit:
        b.inputs["Emission Color"].default_value = col
        b.inputs["Emission Strength"].default_value = emit
    m.diffuse_color = col
    if bump:
        _bump(nt, b, bump, bump_scale, bump_strength)
    return m


def _bump(nt, b, bump, bump_scale, bump_strength):
    """Adds a procedural bump (fine noise, or 'pores' cell dimples) to a Principled material's normal."""
    if True:
        tc = nt.nodes.new("ShaderNodeTexCoord")
        if bump == "pores":
            tex = nt.nodes.new("ShaderNodeTexVoronoi")
            out = tex.outputs["Distance"]
        else:
            tex = nt.nodes.new("ShaderNodeTexNoise")
            tex.inputs["Detail"].default_value = 6.0
            out = tex.outputs["Fac"]
        tex.inputs["Scale"].default_value = bump_scale
        nt.links.new(tc.outputs["Object"], tex.inputs["Vector"])
        bn = nt.nodes.new("ShaderNodeBump")
        bn.inputs["Strength"].default_value = bump_strength
        nt.links.new(out, bn.inputs["Height"])
        nt.links.new(bn.outputs["Normal"], b.inputs["Normal"])


def sdf_attr(obj, name, fn):
    """Stores fn(local vertex position) per vertex; > 0 means inside the region. The shader thresholds the
    interpolated value at 0, so region edges stay crisp and smooth whatever the mesh density."""
    me = obj.data
    attr = me.attributes.get(name) or me.attributes.new(name, "FLOAT", "POINT")
    attr.data.foreach_set("value", [fn(v.co.copy()) for v in me.vertices])
    me.update()


def region_mat(name, color, layers, rough=0.5, coat=0.2, bump=None, bump_scale=40.0, bump_strength=0.2):
    """One material painting sdf_attr regions over a base colour. layers: [(attribute, '#color', roughness)],
    painted in order (later layers win)."""
    m = mat(name, color, rough=rough, coat=coat)
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    col_out = rough_out = None
    for attr, lcol, lrough in layers:
        a = nt.nodes.new("ShaderNodeAttribute")
        a.attribute_type = "GEOMETRY"
        a.attribute_name = attr
        gt = nt.nodes.new("ShaderNodeMath")
        gt.operation = "GREATER_THAN"
        gt.inputs[1].default_value = 0.0
        nt.links.new(a.outputs["Fac"], gt.inputs[0])
        mc = nt.nodes.new("ShaderNodeMix")
        mc.data_type = "RGBA"
        nt.links.new(gt.outputs[0], mc.inputs[0])
        if col_out is None:
            mc.inputs[6].default_value = lin(color)
        else:
            nt.links.new(col_out, mc.inputs[6])
        mc.inputs[7].default_value = lin(lcol)
        col_out = mc.outputs[2]
        mr = nt.nodes.new("ShaderNodeMix")
        mr.data_type = "FLOAT"
        nt.links.new(gt.outputs[0], mr.inputs[0])
        if rough_out is None:
            mr.inputs[2].default_value = rough
        else:
            nt.links.new(rough_out, mr.inputs[2])
        mr.inputs[3].default_value = lrough
        rough_out = mr.outputs[0]
    if col_out is not None:
        nt.links.new(col_out, b.inputs["Base Color"])
        nt.links.new(rough_out, b.inputs["Roughness"])
    if bump and not b.inputs["Normal"].is_linked:
        _bump(nt, b, bump, bump_scale, bump_strength)
    return m


# ---------------------------------------------------------------------------------------------------- primitives
def _mesh(name, coll, fill):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    fill(bm)
    bm.to_mesh(me)
    bm.free()
    return _link(bpy.data.objects.new(name, me), coll)


def sphere(name, coll, loc, radius, material=None, scale=(1, 1, 1), rot=(0, 0, 0), segs=40, rings=24):
    obj = _mesh(name, coll, lambda bm: bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings,
                                                                 radius=radius))
    obj.location = loc
    obj.scale = scale
    obj.rotation_euler = Euler([math.radians(a) for a in rot])
    if material:
        set_mats(obj, material)
    return smooth(obj)


def quadsphere(name, coll, center, radii, material=None, cuts=48):
    """Evenly spaced quad sphere (no pinched poles) with its radii baked in and its origin at the centre, ready to
    sculpt with push() in object space."""
    def fill(bm):
        bmesh.ops.create_cube(bm, size=2.0)
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
        for v in bm.verts:
            n = v.co.normalized()
            v.co = Vector((n.x * radii[0], n.y * radii[1], n.z * radii[2]))
        bm.normal_update()
    obj = _mesh(name, coll, fill)
    obj.location = center
    if material:
        set_mats(obj, material)
    return smooth(obj)


def push(obj, center, radius, amount, direction=None, power=2.0):
    """Sculpt move in object space: verts within radius of center move by amount (along their own normal, or along
    direction) with a smooth falloff. Negative amount dents."""
    me = obj.data
    c = Vector(center)
    d = Vector(direction).normalized() if direction else None
    normals = [v.normal.copy() for v in me.vertices]  # read all first: moving verts changes neighbours' normals
    for i, v in enumerate(me.vertices):
        dist = (v.co - c).length
        if dist < radius:
            v.co += (d if d else normals[i]) * amount * (1 - (dist / radius) ** 2) ** power
    me.update()


def trim(obj, plane_co, plane_no, cap=False):
    """Cuts the mesh with a plane, removing the side the normal points to."""
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=plane_co,
                           plane_no=plane_no, clear_outer=True)
    if cap:
        edges = [e for e in bm.edges if e.is_boundary]
        if edges:
            bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    bm.to_mesh(me)
    bm.free()
    me.update()


def torus(name, coll, loc, major, minor, material=None, rot=(0, 0, 0)):
    """Ring with a round tube; major is a radius or (rx, ry) for an oval ring (the tube stays round)."""
    rx, ry = (major, major) if isinstance(major, (int, float)) else major

    def fill(bm):
        nu, nv = 48, 12
        rings = []
        for i in range(nu):
            a = 2 * math.pi * i / nu
            cx, cy = rx * math.cos(a), ry * math.sin(a)
            nrm = Vector((math.cos(a) / rx, math.sin(a) / ry, 0)).normalized()
            rings.append([bm.verts.new((cx + nrm.x * minor * math.cos(2 * math.pi * j / nv),
                                        cy + nrm.y * minor * math.cos(2 * math.pi * j / nv),
                                        minor * math.sin(2 * math.pi * j / nv))) for j in range(nv)])
        for i in range(nu):
            for j in range(nv):
                bm.faces.new((rings[i][j], rings[(i + 1) % nu][j], rings[(i + 1) % nu][(j + 1) % nv],
                              rings[i][(j + 1) % nv]))
    obj = _mesh(name, coll, fill)
    obj.location = loc
    obj.rotation_euler = Euler([math.radians(a) for a in rot])
    if material:
        set_mats(obj, material)
    return smooth(obj)


def leaf(name, coll, base, direction, length, width, material, curl=0.2, fold=0.1, up=(0, 0, 1), thick=0.07):
    """Pointed leaf (or petal) from base along direction, folded along its midrib and curling towards `up`."""
    d = Vector(direction).normalized()
    side = d.cross(Vector(up))
    if side.length < 1e-4:
        side = d.cross(Vector((1, 0, 0)))
    side.normalize()
    n = side.cross(d).normalized()
    nu, nv = 20, 6

    def fill(bm):
        rows = []
        for i in range(nu + 1):
            u = i / nu
            w = width * math.sin(math.pi * min(u * 1.05, 1.0)) ** 0.8 * (1 - 0.2 * u) + 0.003
            rows.append([bm.verts.new(Vector(base) + d * (u * length) + side * ((-1 + 2 * j / nv) * w)
                                      + n * (curl * length * u * u + fold * abs(-1 + 2 * j / nv) * w))
                         for j in range(nv + 1)])
        for i in range(nu):
            for j in range(nv):
                bm.faces.new((rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]))
    obj = _mesh(name, coll, fill)
    sol = obj.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = width * thick
    sol.offset = 0.0
    subdivide(obj, 1)
    set_mats(obj, material)
    return smooth(obj)


def tube(name, coll, points, radii, material=None, res=12):
    """Smooth tapered tube through points (one radius per point): stems, arms, vines, tails."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = 1.0
    cu.bevel_resolution = 5
    cu.resolution_u = res
    cu.use_fill_caps = True
    sp = cu.splines.new("NURBS")
    sp.points.add(len(points) - 1)
    for p, co, r in zip(sp.points, points, radii):
        p.co = (*co, 1.0)
        p.radius = r
    sp.use_endpoint_u = True
    sp.order_u = min(4, len(points))
    if material:
        cu.materials.append(material)
    return _link(bpy.data.objects.new(name, cu), coll)


# metaballs: a lone element (stiffness 2, threshold 0.6) surfaces at about 0.575 of its radius, so dividing by it
# makes the sizes below the real half extents of each element
_SURFACE = 0.575


def capsule(p0, p1, r):
    """A blob() capsule element running from p0 to p1 with radius r."""
    a, b = Vector(p0), Vector(p1)
    d = b - a
    if d.length < 1e-6:
        return dict(type="BALL", co=tuple(a), r=r)
    q = Vector((1, 0, 0)).rotation_difference(d.normalized())
    return dict(type="CAPSULE", co=tuple((a + b) / 2), r=r, size=(d.length / 2, 1, 1), quat=q)


def blob(name, coll, elements, material=None, resolution=0.03):
    """Fuses ellipsoids (size = half extents), balls (r) and capsules (see capsule()) into one smooth mesh."""
    mb = bpy.data.metaballs.new(name)
    mb.resolution = mb.render_resolution = resolution
    mb.threshold = 0.6
    meta = bpy.data.objects.new(name + "Meta", mb)
    bpy.context.scene.collection.objects.link(meta)
    for e in elements:
        kind = e.get("type", "ELLIPSOID")
        el = mb.elements.new(type=kind)
        el.co = e["co"]
        el.radius = (1.0 if kind == "ELLIPSOID" else e.get("r", 1.0)) / _SURFACE
        el.size_x, el.size_y, el.size_z = e.get("size", (1, 1, 1))
        el.stiffness = 2.0
        if "quat" in e:
            el.rotation = e["quat"]
        elif "rot" in e:
            el.rotation = Euler([math.radians(a) for a in e["rot"]]).to_quaternion()
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(meta.evaluated_get(dg), depsgraph=dg)
    me.name = name
    bpy.data.objects.remove(meta, do_unlink=True)
    bpy.data.metaballs.remove(mb)
    obj = _link(bpy.data.objects.new(name, me), coll)
    if material:
        set_mats(obj, material)
    return smooth(obj)


# ---------------------------------------------------------------------------------------------------- faces
def eye(prefix, coll, center, radius, look=(0, -1, 0), iris="#2f6b1f", iris_size=0.62, pupil_size=0.45,
        lid=None, lid_close=0.0, lid_tilt=0.0, side=1, white="#fbf7ec", glow=0.0):
    """Glossy cartoon eye: white ball, domed iris and pupil, catch-light and an optional upper lid.
    lid_close 0..1 is how far the lid comes down; lid_tilt in degrees, negative = inner corner lower (angry).
    side = +1 for the model's left eye (+X), -1 for the right one. glow > 0 makes the iris glow (no pupil)."""
    c = Vector(center)
    fwd = Vector(look).normalized()
    rot = fwd.to_track_quat("-Y", "Z")
    tag = "L" if side > 0 else "R"
    parts = []

    def place(obj):
        obj.rotation_mode = "QUATERNION"
        obj.rotation_quaternion = rot
        parts.append(obj)
        return obj
    place(sphere(f"{prefix}_Eye{tag}", coll, c, radius, mat(f"{prefix}_EyeWhite", white, rough=0.12, coat=0.6)))
    place(sphere(f"{prefix}_Iris{tag}", coll, c + fwd * radius * 0.86, radius * iris_size,
                 mat(f"{prefix}_Iris", iris, rough=0.15, coat=0.8, emit=glow), scale=(1, 0.32, 1)))
    if not glow:
        place(sphere(f"{prefix}_Pupil{tag}", coll, c + fwd * radius * 0.95, radius * iris_size * pupil_size,
                     mat(f"{prefix}_Pupil", "#08090b", rough=0.1, coat=1.0), scale=(1, 0.3, 1)))
    up, left = rot @ Vector((0, 0, 1)), rot @ Vector((1, 0, 0))
    place(sphere(f"{prefix}_Glint{tag}", coll, c + fwd * radius * 1.0 + up * radius * 0.3 + left * radius * 0.2,
                 radius * 0.14, mat(f"{prefix}_Glint", "#ffffff", rough=0.0, emit=2.0), scale=(1, 0.4, 0.8),
                 segs=16, rings=10))
    if lid is not None and lid_close > 0:
        r = radius * 1.08
        obj = sphere(f"{prefix}_Lid{tag}", coll, (0, 0, 0), r, lid, segs=48, rings=32)
        trim(obj, (0, 0, r * (1 - 2 * lid_close)), (0, 0, -1))
        sol = obj.modifiers.new("Solidify", "SOLIDIFY")
        sol.thickness = r * 0.12
        sol.offset = 1.0
        obj.location = c
        obj.rotation_mode = "QUATERNION"
        obj.rotation_quaternion = rot @ Euler((0, math.radians(-lid_tilt * side), 0)).to_quaternion()
        parts.append(obj)
    return parts


# ---------------------------------------------------------------------------------------------------- preview
def studio(height=4.2, size=800):
    """Soft three-light studio and a front three-quarter camera (from -Y, a little to the model's right)."""
    sc = bpy.context.scene
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            sc.render.engine = engine
            break
        except TypeError:
            continue
    sc.render.resolution_x = sc.render.resolution_y = size
    sc.view_settings.view_transform = "Standard"  # Roblox shows colours without a filmic curve
    sc.view_settings.look = "None"
    world = sc.world or bpy.data.worlds.new("World")
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = lin("#c9d3e0")
    bg.inputs["Strength"].default_value = 0.45
    coll = bpy.data.collections.new("Studio")
    sc.collection.children.link(coll)
    target = Vector((0, 0, height * 0.5))

    def light(name, loc, energy, size_, color):
        ld = bpy.data.lights.new(name, "AREA")
        ld.energy = energy
        ld.size = size_
        ld.color = lin(color)[:3]
        o = _link(bpy.data.objects.new(name, ld), coll)
        o.location = loc
        o.rotation_euler = (target - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    light("Key", (-4.5, -6, height * 1.6), 1500, 4, "#fff6ea")
    light("Fill", (6, -4, height * 0.8), 400, 5, "#eef3ff")
    light("Rim", (2, 6, height * 1.4), 900, 3, "#ffffff")
    cd = bpy.data.cameras.new("Cam")
    cd.lens = 50
    cam = _link(bpy.data.objects.new("Cam", cd), coll)
    sc.camera = cam
    view(cam, height, (-0.42, -1, 0.2))
    return cam


def view(cam, height, direction, dist_mult=2.3):
    target = Vector((0, 0, height * 0.5))
    cam.location = target + Vector(direction).normalized() * height * dist_mult
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()


def render(path):
    sc = bpy.context.scene
    sc.render.filepath = path
    sc.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)
    return path


def compare(paths, out):
    """Puts images side by side (e.g. reference | front | back) in one PNG."""
    import numpy as np
    arrs = []
    for p in paths:
        if not os.path.exists(p):
            continue
        img = bpy.data.images.load(p)
        w, h = img.size
        a = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, img.channels)
        if img.channels == 3:
            a = np.concatenate([a, np.ones((h, w, 1), np.float32)], axis=2)
        arrs.append(a)
        bpy.data.images.remove(img)
    H = max(a.shape[0] for a in arrs)
    W = sum(a.shape[1] for a in arrs)
    canvas = np.ones((H, W, 4), np.float32)
    x = 0
    for a in arrs:
        h, w = a.shape[:2]
        canvas[H - h:H, x:x + w] = a
        x += w
    img = bpy.data.images.new("compare", W, H, alpha=True)
    img.pixels.foreach_set(canvas.ravel())
    img.filepath_raw = out
    img.file_format = "PNG"
    img.save()


# ---------------------------------------------------------------------------------------------------- export
def _tris(me):
    return sum(len(p.vertices) - 2 for p in me.polygons)


def _join(objs, name):
    keep = objs[0]
    if len(objs) > 1:
        with bpy.context.temp_override(active_object=keep, object=keep, selected_objects=objs,
                                       selected_editable_objects=objs):
            bpy.ops.object.join()
    keep.name = keep.data.name = name
    return keep


def export(coll, name, out_dir, tri_budget=16000, tex_size=1024, preview_path=None, height=4.2):
    """Bakes the sculpt into one game mesh: <out_dir>/<name>.fbx (textures embedded) plus
    <name>_Color/_Normal/_Rough.png and <name>_export.json. HIGH = every part with modifiers applied; LOW = each
    part decimated to its share of tri_budget, joined and unwrapped; the maps are baked from HIGH onto LOW."""
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    high_parts = []
    for obj in coll.all_objects:
        if obj.type not in ("MESH", "CURVE") or obj.hide_render:
            continue
        me = bpy.data.meshes.new_from_object(obj.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
        me.transform(obj.matrix_world)
        if not me.polygons:
            bpy.data.meshes.remove(me)
            continue
        part = bpy.data.objects.new(f"{name}Hi{len(high_parts)}", me)
        sc.collection.objects.link(part)
        high_parts.append(part)
    coll.hide_render = True
    high_total = sum(_tris(p.data) for p in high_parts)
    ratio = min(1.0, tri_budget / max(high_total, 1))
    low_parts = []
    for part in high_parts:
        lo = part.copy()
        lo.data = part.data.copy()
        lo.name = part.name.replace("Hi", "Lo")
        sc.collection.objects.link(lo)
        n = _tris(lo.data)
        r = min(1.0, max(ratio, 60 / max(n, 1)))
        if r < 1.0:
            dec = lo.modifiers.new("Decimate", "DECIMATE")
            dec.ratio = r
            dec.use_collapse_triangulate = True
            apply_modifiers(lo)
        low_parts.append(lo)
    high = _join(high_parts, f"{name}_High")
    low = _join(low_parts, name)
    if _tris(low.data) > tri_budget * 1.15:  # the per-part minimums pushed it over: trim the whole mesh
        dec = low.modifiers.new("Decimate", "DECIMATE")
        dec.ratio = tri_budget / _tris(low.data)
        dec.use_collapse_triangulate = True
        apply_modifiers(low)
    for p in low.data.polygons:
        p.use_smooth = True
    low.data.materials.clear()
    while low.data.uv_layers:
        low.data.uv_layers.remove(low.data.uv_layers[0])
    low.data.uv_layers.new(name="UVMap")
    for o in sc.objects:
        o.select_set(False)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    with bpy.context.temp_override(active_object=low, object=low, selected_objects=[low],
                                   selected_editable_objects=[low]):
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004)
        try:
            bpy.ops.uv.pack_islands(margin=0.004, rotate=True)
        except RuntimeError:
            pass
        bpy.ops.object.mode_set(mode="OBJECT")

    # no metalness map in Roblox: bake metals as their base colour
    for m in high.data.materials:
        if m and m.use_nodes:
            for nd in m.node_tree.nodes:
                if nd.type == "BSDF_PRINCIPLED":
                    nd.inputs["Metallic"].default_value = 0.0

    images = {}
    for kind, space in (("Color", "sRGB"), ("Normal", "Non-Color"), ("Rough", "Non-Color")):
        img = bpy.data.images.new(f"{name}_{kind}", tex_size, tex_size, alpha=False)
        img.colorspace_settings.name = space
        if kind == "Normal":
            img.generated_color = (0.5, 0.5, 1.0, 1.0)
        images[kind] = img
    baked = bpy.data.materials.new(f"{name}_Baked")
    baked.use_nodes = True
    nt = baked.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    nodes = {}
    for kind, img in images.items():
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = img
        nodes[kind] = t
    low.data.materials.append(baked)

    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 8
    sc.cycles.use_denoising = False
    sc.render.bake.margin = 8
    high.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    for kind, btype in (("Color", "DIFFUSE"), ("Normal", "NORMAL"), ("Rough", "ROUGHNESS")):
        for nd in nt.nodes:
            nd.select = False
        nodes[kind].select = True
        nt.nodes.active = nodes[kind]
        kw = dict(type=btype, use_selected_to_active=True, cage_extrusion=0.04, max_ray_distance=0.12, margin=8)
        if btype == "DIFFUSE":
            kw["pass_filter"] = {"COLOR"}
        if btype == "NORMAL":
            kw["normal_space"] = "TANGENT"
        with bpy.context.temp_override(active_object=low, object=low, selected_objects=[high, low],
                                       selected_editable_objects=[high, low]):
            bpy.ops.object.bake(**kw)
        img = images[kind]
        img.filepath_raw = os.path.join(out_dir, f"{name}_{kind}.png")
        img.file_format = "PNG"
        img.save()

    nt.links.new(nodes["Color"].outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(nodes["Rough"].outputs["Color"], bsdf.inputs["Roughness"])
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(nodes["Normal"].outputs["Color"], nmap.inputs["Color"])
    nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    high.hide_render = True
    high.hide_set(True)

    if preview_path:  # what Roblox gets, from the same camera as the sculpt preview
        render(preview_path)

    # turn round so the face is on +Y like every other model here (-> the Roblox LookVector)
    low.data.transform(Matrix.Rotation(math.pi, 4, "Z"))
    for o in sc.objects:
        o.select_set(False)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    with bpy.context.temp_override(active_object=low, object=low, selected_objects=[low],
                                   selected_editable_objects=[low]):
        bpy.ops.export_scene.fbx(filepath=os.path.join(out_dir, f"{name}.fbx"), use_selection=True,
                                 object_types={"MESH"}, apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
                                 axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE", path_mode="COPY",
                                 embed_textures=True, bake_space_transform=True)
    xs, ys, zs = zip(*[tuple(v.co) for v in low.data.vertices])
    stats = dict(name=name, high_tris=high_total, low_tris=_tris(low.data),
                 bbox_min=[round(min(xs), 4), round(min(ys), 4), round(min(zs), 4)],
                 bbox_max=[round(max(xs), 4), round(max(ys), 4), round(max(zs), 4)])
    with open(os.path.join(out_dir, f"{name}_export.json"), "w", encoding="utf-8") as f:
        json.dump(stats, f, indent=1)
    return stats
