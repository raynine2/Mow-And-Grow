# Render a concept dump (tools/concepts/dry_run.luau) with Blender's Python (pip install bpy):
#   python3 render.py <concept.json> <out.png> <eyeX,eyeY,eyeZ> <lookX,lookY,lookZ> [sun_elev,sun_azim] [sky r,g,b] [lens]
# Coordinates are Roblox studs relative to the concept's origin (y up). Parts are merged into one mesh per
# material so thousands of parts render quickly. Colours only: Roblox's material textures and studs aren't drawn.
import sys, json, math, os
import bpy, bmesh
from mathutils import Matrix, Vector

a = sys.argv[1:]
path, out = a[0], a[1]
eye = [float(v) for v in a[2].split(",")]
look = [float(v) for v in a[3].split(",")]
sun_e, sun_a = (float(v) for v in (a[4].split(",") if len(a) > 4 else ("50", "140")))
sky = [float(v) for v in (a[5].split(",") if len(a) > 5 else ("0.55", "0.72", "1.0"))]
lens = float(a[6]) if len(a) > 6 else 30

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
MB = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))  # Roblox -> Blender


def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


ROUGH = {"Neon": 0.5, "Glass": 0.05, "Ice": 0.1, "Metal": 0.35, "SmoothPlastic": 0.45, "Foil": 0.2}


def material(c, m, t):
    mt = bpy.data.materials.new("m")
    mt.use_nodes = True
    b = mt.node_tree.nodes["Principled BSDF"]
    base = (lin(c[0]), lin(c[1]), lin(c[2]), 1)
    b.inputs["Base Color"].default_value = base
    b.inputs["Roughness"].default_value = ROUGH.get(m, 0.75)
    if m == "Neon":
        b.inputs["Emission Color"].default_value = base
        b.inputs["Emission Strength"].default_value = 4
    if m in ("Metal", "CorrodedMetal", "DiamondPlate", "Foil"):
        b.inputs["Metallic"].default_value = 0.6
    if t > 0:
        b.inputs["Alpha"].default_value = max(0.15, 1 - t)
    return mt


def add_shape(bm, shape, s, M):
    sx, sy, sz = s
    vs = []
    if shape == "B":
        for (x, y, z) in [(-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1), (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]:
            vs.append(bm.verts.new(M @ Vector((x * sx / 2, y * sy / 2, z * sz / 2))))
        for f in [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (2, 3, 7, 6), (1, 2, 6, 5), (0, 4, 7, 3)]:
            bm.faces.new([vs[i] for i in f])
    elif shape == "C":  # axis along local X
        seg = 14
        ring0, ring1 = [], []
        for k in range(seg):
            ang = 2 * math.pi * k / seg
            y, z = math.cos(ang) * sy / 2, math.sin(ang) * sz / 2
            ring0.append(bm.verts.new(M @ Vector((-sx / 2, y, z))))
            ring1.append(bm.verts.new(M @ Vector((sx / 2, y, z))))
        for k in range(seg):
            n = (k + 1) % seg
            bm.faces.new([ring0[k], ring0[n], ring1[n], ring1[k]])
        bm.faces.new(list(reversed(ring0)))
        bm.faces.new(ring1)
    elif shape == "S":
        r = sx / 2
        lat, lon = 6, 10
        rows = []
        for i in range(1, lat):
            th = math.pi * i / lat
            rows.append([bm.verts.new(M @ Vector((r * math.sin(th) * math.cos(2 * math.pi * j / lon), r * math.cos(th), r * math.sin(th) * math.sin(2 * math.pi * j / lon)))) for j in range(lon)])
        top = bm.verts.new(M @ Vector((0, r, 0)))
        bot = bm.verts.new(M @ Vector((0, -r, 0)))
        for j in range(lon):
            n = (j + 1) % lon
            bm.faces.new([top, rows[0][n], rows[0][j]])
            bm.faces.new([bot, rows[-1][j], rows[-1][n]])
            for i in range(len(rows) - 1):
                bm.faces.new([rows[i][j], rows[i][n], rows[i + 1][n], rows[i + 1][j]])
    else:  # wedge: tall at +Z, sloping down toward -Z
        pts = [(-sx / 2, -sy / 2, -sz / 2), (sx / 2, -sy / 2, -sz / 2), (sx / 2, -sy / 2, sz / 2), (-sx / 2, -sy / 2, sz / 2), (-sx / 2, sy / 2, sz / 2), (sx / 2, sy / 2, sz / 2)]
        vs = [bm.verts.new(M @ Vector(p)) for p in pts]
        for f in [(0, 1, 2, 3), (3, 2, 5, 4), (0, 3, 4), (1, 5, 2), (0, 4, 5, 1)]:
            bm.faces.new([vs[i] for i in f])


groups = {}
for p in json.load(open(path)):
    key = (round(p["c"][0], 2), round(p["c"][1], 2), round(p["c"][2], 2), p["m"], round(p["t"], 1))
    groups.setdefault(key, []).append(p)
for key, parts in groups.items():
    bm = bmesh.new()
    for p in parts:
        x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = p["cf"]
        M = MB @ Matrix(((r00, r01, r02, x), (r10, r11, r12, y), (r20, r21, r22, z), (0, 0, 0, 1)))
        add_shape(bm, p["s"], p["z"], M)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("g")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("g", me)
    sc.collection.objects.link(o)
    o.data.materials.append(material(key[:3], key[3], key[4]))


def bl(v):
    return Vector((v[0], -v[2], v[1]))


cam_d = bpy.data.cameras.new("cam")
cam_d.lens = lens
cam_d.clip_end = 5000
cam = bpy.data.objects.new("cam", cam_d)
sc.collection.objects.link(cam)
cam.location = bl(eye)
cam.rotation_euler = (bl(look) - bl(eye)).to_track_quat("-Z", "Y").to_euler()
sc.camera = cam
sun_d = bpy.data.lights.new("sun", "SUN")
sun_d.energy = 4.2
sun_d.angle = math.radians(2)
sun = bpy.data.objects.new("sun", sun_d)
sc.collection.objects.link(sun)
sun.rotation_euler = (math.radians(90 - sun_e), 0, math.radians(sun_a))
w = bpy.data.worlds.new("w")
sc.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs["Color"].default_value = (lin(sky[0]), lin(sky[1]), lin(sky[2]), 1)
w.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.1
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = int(os.environ.get("SAMPLES", "24"))
sc.cycles.use_denoising = True
sc.render.resolution_x, sc.render.resolution_y = (int(v) for v in os.environ.get("RES", "1500x900").split("x"))
sc.view_settings.view_transform = "AgX"
sc.view_settings.look = "AgX - Medium High Contrast"
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
print("RENDERED", out)
