# Render a dry-run camp (dump/camp_<z>.json from test_dress.luau) in Blender: render_camp.py <json> <out.png> <baseX> [yaw] [elev] [dist]
import sys, json, math
import bpy, bmesh
from mathutils import Matrix, Vector
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
path, out, baseX = args[0], args[1], float(args[2])
yaw = float(args[3]) if len(args) > 3 else 200
elev = float(args[4]) if len(args) > 4 else 38
dist = float(args[5]) if len(args) > 5 else 95
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
MB = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))  # Roblox world -> Blender world
mats = {}
def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
ROUGH = {"Neon": 0.5, "Glass": 0.05, "Metal": 0.35, "SmoothPlastic": 0.45}
def material(c, m, t):
    key = (round(c[0], 2), round(c[1], 2), round(c[2], 2), m, round(t, 1))
    if key in mats:
        return mats[key]
    mt = bpy.data.materials.new("m%d" % len(mats))
    mt.use_nodes = True
    b = mt.node_tree.nodes["Principled BSDF"]
    base = (lin(c[0]), lin(c[1]), lin(c[2]), 1)
    b.inputs["Base Color"].default_value = base
    b.inputs["Roughness"].default_value = ROUGH.get(m, 0.8)
    if m == "Neon":
        b.inputs["Emission Color"].default_value = base
        b.inputs["Emission Strength"].default_value = 3
    if m in ("Metal", "CorrodedMetal", "DiamondPlate"):
        b.inputs["Metallic"].default_value = 0.7
    if t > 0:
        b.inputs["Alpha"].default_value = 1 - t
    mats[key] = mt
    return mt
def mesh(shape, s):
    bm = bmesh.new()
    sx, sy, sz = s
    if shape == "B":
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz))
    elif shape == "C":
        bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=0.5, radius2=0.5, depth=1.0)
        for v in bm.verts:  # axis along local X
            x, y, z = v.co.z * sx, v.co.x * sy, v.co.y * sz
            v.co = Vector((x, y, z))
    elif shape == "S":
        bmesh.ops.create_icosphere(bm, subdivisions=2, radius=sx / 2)
    else:  # wedge: tall at +Z, sloping down toward -Z
        vs = [bm.verts.new(v) for v in [(-sx / 2, -sy / 2, -sz / 2), (sx / 2, -sy / 2, -sz / 2), (sx / 2, -sy / 2, sz / 2), (-sx / 2, -sy / 2, sz / 2), (-sx / 2, sy / 2, sz / 2), (sx / 2, sy / 2, sz / 2)]]
        for f in [(0, 1, 2, 3), (3, 2, 5, 4), (0, 3, 4), (1, 5, 2), (0, 4, 5, 1)]:
            bm.faces.new([vs[i] for i in f])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("p")
    bm.to_mesh(me)
    bm.free()
    return me
def place(shape, s, cf, c, m, t):
    me = mesh(shape, s)
    o = bpy.data.objects.new("p", me)
    sc.collection.objects.link(o)
    o.data.materials.append(material(c, m, t))
    x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf
    M = Matrix(((r00, r01, r02, x), (r10, r11, r12, y), (r20, r21, r22, z), (0, 0, 0, 1)))
    o.matrix_world = MB @ M
for p in json.load(open(path)):
    place(p["s"], p["z"], p["cf"], p["c"], p["m"], p["t"])
# the stub ground (as test_dress.luau) and the plaza Outposts lays
def gy(x, z):
    return math.floor(math.sin(x * 0.05) * 3 + math.cos(z * 0.04) * 2) * 2
for i in range(-12, 13):
    for j in range(-12, 13):
        x, z = i * 4.0, j * 4.0
        h = gy(baseX + x, z) - 10
        place("B", [4, 1, 4], [x, h - 0.5, z, 1, 0, 0, 0, 1, 0, 0, 0, 1], (0.36, 0.62, 0.25), "Grass", 0)
place("C", [0.4, 48, 48], [0, -0.2, 0, 0, -1, 0, 1, 0, 0, 0, 0, 1], (0.75, 0.7, 0.62), "Slate", 0)
place("C", [0.5, 9, 9], [0, 0.05, 0, 0, -1, 0, 1, 0, 0, 0, 0, 1], (0.3, 0.75, 0.3), "Grass", 0)
for x in (-6.5, 6.5):
    place("B", [9, 6, 4], [x, 3, -11, 1, 0, 0, 0, 1, 0, 0, 0, 1], (0.9, 0.5, 0.2), "Wood", 0)
place("B", [2, 5, 2], [12, 2.5, -3, 1, 0, 0, 0, 1, 0, 0, 0, 1], (0.85, 0.2, 0.2), "Plastic", 0)
# camera, sun, sky
cam_d = bpy.data.cameras.new("cam")
cam_d.lens = 32
cam = bpy.data.objects.new("cam", cam_d)
sc.collection.objects.link(cam)
a, e = math.radians(yaw), math.radians(elev)
target = Vector((0, 0, 3))
cam.location = target + Vector((math.sin(a) * math.cos(e), math.cos(a) * math.cos(e), math.sin(e))) * dist
cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
sc.camera = cam
sun_d = bpy.data.lights.new("sun", "SUN")
sun_d.energy = 3.8
sun = bpy.data.objects.new("sun", sun_d)
sc.collection.objects.link(sun)
sun.rotation_euler = (math.radians(50), 0, math.radians(140))
w = bpy.data.worlds.new("w")
sc.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.72, 1.0, 1)
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 12
sc.cycles.use_denoising = True
sc.render.resolution_x, sc.render.resolution_y = 1400, 900
sc.view_settings.view_transform = "AgX"
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
print("RENDERED", out)
