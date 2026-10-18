"""Shared helpers for the Blender model scripts in tools/blender/models/.

Conventions (so models drop straight into Roblox):
- 1 Blender unit = 1 Roblox stud. Models stand on the ground at z = 0, centred on x = y = 0.
- The model's FRONT faces Blender +Y (it becomes Roblox -Z, the LookVector, after glTF export).
- Every part gets a material named "<RobloxMaterial>__<RRGGBB>", e.g. "Wood__7A4A30". On export, all parts with the
  same material are joined into one mesh with that name; the uploader turns each mesh into a MeshPart and sets its
  Roblox Material + Color from the name. So models keep Roblox's own textures (grass, wood grain ...).
"""
import math
import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

ROBLOX_MATERIALS = {"Plastic", "SmoothPlastic", "Wood", "WoodPlanks", "Grass", "Ground", "Mud", "Pebble", "Slate",
                    "Metal", "DiamondPlate", "Neon", "Glass", "Fabric", "Sand", "Snow", "Brick", "Concrete",
                    "Cobblestone", "Marble", "Granite", "Foil", "CorrodedMetal", "LeafyGrass", "Cardboard"}

def hexcol(rgb):
    return "%02X%02X%02X" % tuple(int(round(c)) for c in rgb)

def lin(c):
    c = c / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m)

# ---------------------------------------------------------------------------------------------------------------
# materials
# ---------------------------------------------------------------------------------------------------------------
def material(kind, rgb):
    """A Roblox material slot. kind = Roblox material name, rgb = (r, g, b) in 0..255."""
    assert kind in ROBLOX_MATERIALS, kind
    name = "%s__%s" % (kind, hexcol(rgb))
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree; n = nt.nodes; l = nt.links
    bsdf = n["Principled BSDF"]
    base = (lin(rgb[0]), lin(rgb[1]), lin(rgb[2]), 1)
    bsdf.inputs["Base Color"].default_value = base
    bsdf.inputs["Roughness"].default_value = 0.7
    mat.diffuse_color = base
    # preview-only texture so renders read like Roblox's materials (export keeps just the base colour)
    def tint(fac_out, lo, hi):
        mr = n.new("ShaderNodeMapRange"); mr.inputs["To Min"].default_value = lo; mr.inputs["To Max"].default_value = hi
        l.new(fac_out, mr.inputs["Value"])
        mix = n.new("ShaderNodeMix"); mix.data_type = "RGBA"; mix.blend_type = "MULTIPLY"; mix.inputs["Factor"].default_value = 1
        mix.inputs[6].default_value = base
        l.new(mr.outputs["Result"], mix.inputs[7])
        l.new(mix.outputs[2], bsdf.inputs["Base Color"])
    tc = n.new("ShaderNodeTexCoord")
    if kind in ("Grass", "LeafyGrass", "Ground", "Mud", "Pebble", "Sand", "Fabric", "Slate", "Snow", "Cobblestone"):
        nz = n.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = {"Grass": 9, "LeafyGrass": 9, "Pebble": 14, "Fabric": 20}.get(kind, 6)
        nz.inputs["Detail"].default_value = 10; l.new(tc.outputs["Object"], nz.inputs["Vector"])
        tint(nz.outputs["Fac"], 0.55, 1.25)
        bsdf.inputs["Roughness"].default_value = 0.95
    elif kind in ("Wood", "WoodPlanks"):
        # vertical grain: stretch the texture space along Z so bands run up the trunk
        mp = n.new("ShaderNodeMapping"); mp.inputs["Scale"].default_value = (1, 1, 0.08)
        l.new(tc.outputs["Object"], mp.inputs["Vector"])
        wv = n.new("ShaderNodeTexWave"); wv.wave_type = "BANDS"; wv.bands_direction = "X"
        wv.inputs["Scale"].default_value = 1.6; wv.inputs["Distortion"].default_value = 5; wv.inputs["Detail"].default_value = 4
        l.new(mp.outputs["Vector"], wv.inputs["Vector"])
        tint(wv.outputs["Fac"], 0.7, 1.15)
        bsdf.inputs["Roughness"].default_value = 0.85
    elif kind == "Neon":
        bsdf.inputs["Emission Color"].default_value = base; bsdf.inputs["Emission Strength"].default_value = 4
    elif kind in ("Metal", "DiamondPlate", "Foil", "CorrodedMetal"):
        bsdf.inputs["Metallic"].default_value = 0.85; bsdf.inputs["Roughness"].default_value = 0.35
    elif kind == "Glass":
        bsdf.inputs["Transmission Weight"].default_value = 0.85; bsdf.inputs["Roughness"].default_value = 0.05
    elif kind == "SmoothPlastic":
        bsdf.inputs["Roughness"].default_value = 0.45
    return mat

# ---------------------------------------------------------------------------------------------------------------
# shapes (all return the object; sizes are full extents in studs)
# ---------------------------------------------------------------------------------------------------------------
def _finish(obj, mat, loc, rot, bevel):
    obj.data.materials.append(mat)
    obj.location = loc
    obj.rotation_euler = Euler([math.radians(r) for r in rot], "XYZ")
    if bevel:
        mod = obj.modifiers.new("bevel", "BEVEL"); mod.width = bevel; mod.segments = 1
        mod.limit_method = "ANGLE"
    return obj

def _from_bmesh(name, bm):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    obj = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(obj)
    return obj

def box(name, size, loc=(0, 0, 0), rot=(0, 0, 0), mat=None, bevel=0.0, taper=None):
    """Box. `taper` = (sx, sy) scale of the top face (1 = straight sides) for tapered blocks / blades."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]; v.co.y *= size[1]; v.co.z *= size[2]
        if taper and v.co.z > 0:
            v.co.x *= taper[0]; v.co.y *= taper[1]
    return _finish(_from_bmesh(name, bm), mat, loc, rot, bevel)

def cyl(name, radius, depth, loc=(0, 0, 0), rot=(0, 0, 0), mat=None, verts=12, bevel=0.0, top_scale=1.0):
    """Cylinder along Blender Z (rotate to lay it down). top_scale < 1 makes a cone/frustum."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=radius, radius2=radius * top_scale, depth=depth)
    return _finish(_from_bmesh(name, bm), mat, loc, rot, bevel)

def wedge(name, size, loc=(0, 0, 0), rot=(0, 0, 0), mat=None, bevel=0.0):
    """Roblox-style wedge: full height at -Y, sloping down to the ground at +Y."""
    bm = bmesh.new()
    sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
    vs = [bm.verts.new(v) for v in [(-sx, -sy, -sz), (sx, -sy, -sz), (sx, sy, -sz), (-sx, sy, -sz), (-sx, -sy, sz), (sx, -sy, sz)]]
    for f in [(0, 1, 2, 3), (0, 4, 5, 1), (1, 5, 2), (0, 3, 4), (3, 2, 5, 4)]:
        bm.faces.new([vs[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _finish(_from_bmesh(name, bm), mat, loc, rot, bevel)

def sphere(name, radius, loc=(0, 0, 0), mat=None, subdiv=1):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    return _finish(_from_bmesh(name, bm), mat, loc, (0, 0, 0), 0)

def rotated(vec, deg_z):
    a = math.radians(deg_z)
    return (vec[0] * math.cos(a) - vec[1] * math.sin(a), vec[0] * math.sin(a) + vec[1] * math.cos(a), vec[2])

# ---------------------------------------------------------------------------------------------------------------
# export + preview
# ---------------------------------------------------------------------------------------------------------------
def apply_all():
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        bpy.context.view_layer.objects.active = obj
        for m in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=m.name)

def join_by_material():
    """Join every mesh that shares a material into one object named after the material."""
    apply_all()
    groups = {}
    for obj in list(bpy.context.scene.objects):
        if obj.type == "MESH" and obj.data.materials:
            groups.setdefault(obj.data.materials[0].name, []).append(obj)
    for name, objs in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1:
            bpy.ops.object.join()
        joined = bpy.context.view_layer.objects.active
        joined.name = name; joined.data.name = name
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

def stats():
    tris = 0
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            obj.data.calc_loop_triangles(); tris += len(obj.data.loop_triangles)
    return tris

def add_origin_marker():
    """A tiny triangle at (0,0,0) named "Origin__000000". In Roblox it tells the loader where the model's origin is
    (the importer re-centres meshes), then it is deleted."""
    me = bpy.data.meshes.new("Origin__000000")
    me.from_pydata([(0, 0, 0), (0.02, 0, 0), (0, 0.02, 0)], [], [(0, 1, 2)])
    mat = bpy.data.materials.get("Origin__000000") or bpy.data.materials.new("Origin__000000")
    me.materials.append(mat)
    obj = bpy.data.objects.new("Origin__000000", me)
    bpy.context.scene.collection.objects.link(obj)

def export_glb(path):
    add_origin_marker()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=True, export_materials="EXPORT")

def preview(path, size=(900, 700), dist=None, height=None, target_z=None, samples=32, yaw=35):
    """Cycles render of the current scene from a 3/4 front view, on a grass ground with sun + sky."""
    sc = bpy.context.scene
    # frame the model
    mins = Vector((1e9, 1e9, 1e9)); maxs = Vector((-1e9, -1e9, -1e9))
    for obj in sc.objects:
        if obj.type == "MESH":
            for c in obj.bound_box:
                w = obj.matrix_world @ Vector(c)
                mins = Vector(map(min, mins, w)); maxs = Vector(map(max, maxs, w))
    centre = (mins + maxs) / 2
    extent = max((maxs - mins).length, 2)
    ground = box("__ground", (extent * 6, extent * 6, 0.2), (0, 0, -0.1), mat=material("Grass", (88, 158, 44)))
    cam_d = bpy.data.cameras.new("cam"); cam_d.lens = 40
    cam = bpy.data.objects.new("cam", cam_d); sc.collection.objects.link(cam)
    d = dist or extent * 1.25
    a = math.radians(yaw)
    cam.location = (centre.x + math.sin(a) * d, centre.y + math.cos(a) * d, (height if height is not None else centre.z + extent * 0.35))
    look = Vector((centre.x, centre.y, target_z if target_z is not None else centre.z))
    cam.rotation_euler = (look - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sun_d = bpy.data.lights.new("sun", "SUN"); sun_d.energy = 4.2; sun_d.angle = math.radians(4); sun_d.color = (1, 0.96, 0.9)
    sun = bpy.data.objects.new("sun", sun_d); sc.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(42), 0, math.radians(150))
    world = bpy.data.worlds.new("w"); sc.world = world; world.use_nodes = True
    bg = world.node_tree.nodes["Background"]; bg.inputs["Color"].default_value = (0.55, 0.72, 1.0, 1); bg.inputs["Strength"].default_value = 1.1
    sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = samples; sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.view_settings.view_transform = "AgX"; sc.view_settings.look = "AgX - Medium High Contrast"
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    # remove preview helpers so they never get exported
    for o in (ground, cam, sun):
        bpy.data.objects.remove(o, do_unlink=True)
