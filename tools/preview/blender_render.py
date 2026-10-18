"""Render a scene JSON (from tools/preview/scene.luau) in Blender with sun, shadows, sky and simple
material textures, as a close stand-in for how Roblox Studio will show it.

    blender -b -P tools/preview/blender_render.py -- scene.json out.png --cam 0,6,10 --look 0,4,60 [--samples 24]

Roblox is Y-up, Blender is Z-up: a Roblox point (x, y, z) becomes (x, -z, y) here.
"""
import argparse, json, math, sys
import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("scene"); ap.add_argument("out")
ap.add_argument("--cam", default="0,8,-60"); ap.add_argument("--look", default="0,4,40")
ap.add_argument("--fov", type=float, default=70); ap.add_argument("--samples", type=int, default=24)
ap.add_argument("--w", type=int, default=1280); ap.add_argument("--h", type=int, default=720)
ap.add_argument("--far", type=float, default=600)
a = ap.parse_args(argv)

C = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))  # roblox -> blender axes

def lin(c):
    # Roblox colours are sRGB; Blender's object colour is linear
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def rb(v):
    return Vector((v[0], -v[2], v[1]))

# fresh scene
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# shared unit meshes
def unit_cube():
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.object; m = o.data; bpy.data.objects.remove(o); return m
def unit_cyl():
    # Roblox cylinders run along X
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.5, depth=1, rotation=(0, math.pi / 2, 0))
    o = bpy.context.object
    o.data.transform(o.matrix_basis); o.matrix_basis = Matrix()
    m = o.data; bpy.data.objects.remove(o); return m
def unit_ball():
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.5, segments=16, ring_count=8)
    o = bpy.context.object; m = o.data; bpy.data.objects.remove(o)
    for p in m.polygons: p.use_smooth = True
    return m
MESH = {"Block": unit_cube(), "Cylinder": unit_cyl(), "Ball": unit_ball()}

# materials: base colour comes from the object colour, texture depends on the Roblox material
def make_material(name, kind):
    mat = bpy.data.materials.new(name); mat.use_nodes = True
    nt = mat.node_tree; n = nt.nodes; l = nt.links
    bsdf = n["Principled BSDF"]
    info = n.new("ShaderNodeObjectInfo")
    col = info.outputs["Color"]
    if kind in ("Grass", "Ground", "Mud", "Pebble", "Sand", "Slate", "Fabric", "Snow"):
        noise = n.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = {"Grass": 18, "Pebble": 30, "Fabric": 40}.get(kind, 12)
        noise.inputs["Detail"].default_value = 8
        ramp = n.new("ShaderNodeMath"); ramp.operation = "MULTIPLY_ADD"
        ramp.inputs[1].default_value = {"Grass": 0.55, "Pebble": 0.5}.get(kind, 0.35)
        ramp.inputs[2].default_value = {"Grass": 0.72, "Pebble": 0.75}.get(kind, 0.82)
        l.new(noise.outputs["Fac"], ramp.inputs[0])
        mix = n.new("ShaderNodeMix"); mix.data_type = "RGBA"; mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        l.new(col, mix.inputs[6]); l.new(ramp.outputs[0], mix.inputs[7])
        l.new(mix.outputs[2], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.95
    elif kind in ("Wood", "WoodPlanks"):
        wave = n.new("ShaderNodeTexWave"); wave.inputs["Scale"].default_value = 3.5
        wave.inputs["Distortion"].default_value = 6; wave.inputs["Detail"].default_value = 3
        wave.bands_direction = "Z"
        ramp = n.new("ShaderNodeMath"); ramp.operation = "MULTIPLY_ADD"
        ramp.inputs[1].default_value = 0.3; ramp.inputs[2].default_value = 0.8
        l.new(wave.outputs["Fac"], ramp.inputs[0])
        mix = n.new("ShaderNodeMix"); mix.data_type = "RGBA"; mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        l.new(col, mix.inputs[6]); l.new(ramp.outputs[0], mix.inputs[7])
        l.new(mix.outputs[2], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.85
    elif kind == "Neon":
        l.new(col, bsdf.inputs["Emission Color"]); bsdf.inputs["Emission Strength"].default_value = 3
        l.new(col, bsdf.inputs["Base Color"])
    elif kind in ("Metal", "DiamondPlate"):
        l.new(col, bsdf.inputs["Base Color"]); bsdf.inputs["Metallic"].default_value = 0.8
        bsdf.inputs["Roughness"].default_value = 0.35
    elif kind == "Glass":
        l.new(col, bsdf.inputs["Base Color"]); bsdf.inputs["Transmission Weight"].default_value = 0.8
        bsdf.inputs["Roughness"].default_value = 0.05
    else:  # Plastic / SmoothPlastic
        l.new(col, bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.55 if kind == "SmoothPlastic" else 0.7
    # see-through parts use object colour alpha
    alpha = n.new("ShaderNodeMath"); alpha.operation = "SUBTRACT"; alpha.inputs[0].default_value = 1
    l.new(info.outputs["Alpha"], alpha.inputs[1])
    inv = n.new("ShaderNodeMath"); inv.operation = "SUBTRACT"; inv.inputs[0].default_value = 1
    l.new(alpha.outputs[0], inv.inputs[1])
    l.new(inv.outputs[0], bsdf.inputs["Alpha"])
    return mat
mats = {}

parts = json.load(open(a.scene))
cam_r = [float(x) for x in a.cam.split(",")]; look_r = [float(x) for x in a.look.split(",")]
cam_b = rb(cam_r)
coll = bpy.data.collections.new("Parts"); scene.collection.children.link(coll)
count = 0
for p in parts:
    pos = p["c"][:3]
    if (Vector(pos) - Vector(cam_r)).length - max(p["s"]) > a.far:
        continue
    R = Matrix((p["c"][3:6], p["c"][6:9], p["c"][9:12]))
    Rb = C @ R @ C.transposed()
    sx, sy, sz = p["s"]
    S = Matrix.Diagonal((sx, sy, sz))
    M = (C @ R @ S @ C.transposed()).to_4x4()
    M.translation = rb(pos)
    obj = bpy.data.objects.new(p.get("n", "Part"), MESH.get(p["sh"], MESH["Block"]))
    obj.matrix_world = M
    kind = p["m"]
    if kind not in mats:
        mats[kind] = make_material("M_" + kind, kind)
    obj.data.materials.clear() if False else None
    obj.material_slots  # noqa
    obj.active_material = None
    if not obj.data.materials:
        pass
    obj.color = (lin(p["col"][0]), lin(p["col"][1]), lin(p["col"][2]), 1 - p.get("t", 0))
    coll.objects.link(obj)
    # material per object (link to object, not mesh, since meshes are shared)
    obj.data.materials.append(None) if len(obj.data.materials) == 0 else None
    obj.material_slots[0].link = "OBJECT"
    obj.material_slots[0].material = mats[kind]
    count += 1

# camera
cam_data = bpy.data.cameras.new("Cam"); cam_data.sensor_fit = "VERTICAL"
cam_data.angle_y = math.radians(a.fov); cam_data.clip_end = 2000
cam = bpy.data.objects.new("Cam", cam_data); scene.collection.objects.link(cam)
cam.location = cam_b
d = rb(look_r) - cam_b
cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
scene.camera = cam

# sun + sky
sun_data = bpy.data.lights.new("Sun", "SUN"); sun_data.energy = 4.2; sun_data.angle = math.radians(3)
sun_data.color = (1.0, 0.96, 0.88)
sun = bpy.data.objects.new("Sun", sun_data); scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(38), math.radians(12), math.radians(-35))
world = bpy.data.worlds.new("World"); scene.world = world; world.use_nodes = True
bg = world.node_tree.nodes["Background"]
# Roblox-like sky: light blue gradient, brighter at the horizon
nt = world.node_tree
tc = nt.nodes.new("ShaderNodeTexCoord"); sep = nt.nodes.new("ShaderNodeSeparateXYZ")
ramp = nt.nodes.new("ShaderNodeValToRGB")
ramp.color_ramp.elements[0].position = 0.0; ramp.color_ramp.elements[0].color = (0.62, 0.80, 1.0, 1)
ramp.color_ramp.elements[1].position = 0.45; ramp.color_ramp.elements[1].color = (0.20, 0.45, 0.95, 1)
nt.links.new(tc.outputs["Generated"], sep.inputs[0]); nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
nt.links.new(ramp.outputs["Color"], bg.inputs["Color"]); bg.inputs["Strength"].default_value = 1.0
# Roblox adds a strong flat "outdoor ambient" fill; light the scene with a brighter sky than the camera sees
fill = nt.nodes.new("ShaderNodeBackground"); fill.inputs["Color"].default_value = (0.75, 0.8, 0.9, 1)
fill.inputs["Strength"].default_value = 1.6
lp = nt.nodes.new("ShaderNodeLightPath"); mixs = nt.nodes.new("ShaderNodeMixShader")
nt.links.new(lp.outputs["Is Camera Ray"], mixs.inputs[0])
nt.links.new(fill.outputs[0], mixs.inputs[1]); nt.links.new(bg.outputs[0], mixs.inputs[2])
nt.links.new(mixs.outputs[0], nt.nodes["World Output"].inputs["Surface"])

# render
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = a.samples
scene.cycles.use_denoising = True
scene.cycles.max_bounces = 3
scene.render.resolution_x = a.w; scene.render.resolution_y = a.h
scene.render.film_transparent = False
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Medium High Contrast"
scene.render.filepath = a.out
bpy.ops.render.render(write_still=True)
print("rendered", count, "parts ->", a.out)
