"""Build every model, export them as one FBX (one shared texture), write the size manifest the game reads, and
render one preview per area.

    <blender python> build_all.py <out_dir> [--no-render] [--only meadow,wheat]

Outputs in <out_dir>:
    MowModels.fbx          every mesh, each object named as in models.catalogue()
    MowAtlas.png           the shared texture (also embedded in the FBX)
    ModelSizes.luau        each mesh's size in studs, copied to src/shared/ModelSizes.luau
    preview_<area>.png     a little scene of that area's models
"""
import math
import os
import sys

import bpy
import mathutils

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402
import models  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
OUT = os.path.abspath(args[0])
RENDER = "--no-render" not in args
ONLY = None
if "--only" in args:
    ONLY = args[args.index("--only") + 1].split(",")
os.makedirs(OUT, exist_ok=True)

kit.clear_scene()
atlas = kit.Atlas()
objects = {}
sizes = {}
for name, (fn, kw) in models.catalogue().items():
    vox, pal, vs = fn(**kw)
    builder = kit.build_columns if name.startswith(("Clump", "Stubble")) else kit.build_shared
    obj, size = builder(name, vox, pal, atlas, voxel_size=vs)
    objects[name] = obj
    sizes[name] = size
    print(f"{name:32s} voxels {len(vox):6d}  tris {len(obj.data.polygons) * 2:6d}  size {size[0]:.1f} x {size[1]:.1f} x {size[2]:.1f}")
    if len(obj.data.polygons) * 2 > 20000:
        print("  WARNING: over 20k triangles, Roblox will refuse it")

img = atlas.image("MowAtlas", os.path.join(OUT, "MowAtlas.png"))
mat = kit.shared_material(img)
for obj in objects.values():
    obj.data.materials.append(mat)
print("atlas colours", len(atlas.index))

# --- export ------------------------------------------------------------------------------------------------------
bpy.ops.object.select_all(action="DESELECT")
for obj in objects.values():
    obj.select_set(True)
bpy.ops.export_scene.fbx(
    filepath=os.path.join(OUT, "MowModels.fbx"),
    use_selection=True,
    apply_unit_scale=True,
    global_scale=1.0,
    axis_forward="-Z",
    axis_up="Y",
    path_mode="COPY",
    embed_textures=True,
    mesh_smooth_type="FACE",
    object_types={"MESH"},
)

with open(os.path.join(OUT, "ModelSizes.luau"), "w") as f:
    f.write("-- Made by tools/blender/voxel/build_all.py: each Blender model's size in studs (x = width, y = height,\n")
    f.write("-- z = depth). The game sets MeshPart.Size from this, so the import scale in Studio doesn't matter.\n")
    f.write("return {\n")
    for name, (x, y, z) in sizes.items():
        f.write(f'\t{name} = Vector3.new({x:.2f}, {y:.2f}, {z:.2f}),\n')
    f.write("}\n")


# --- previews ----------------------------------------------------------------------------------------------------
def preview(area, names, path):
    scene = bpy.context.scene
    for o in objects.values():
        o.hide_render = True
    placed = []
    x = 0.0
    for n in names:
        o = objects[n]
        o.hide_render = False
        w = sizes[n][0]
        o.location = (x + w / 2, 0, 0)
        placed.append(o)
        x += w + 3
    cx = x / 2
    cam = bpy.data.objects.get("cam")
    if not cam:
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        scene.collection.objects.link(cam)
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        sun.data.energy = 3.0
        sun.rotation_euler = (math.radians(48), math.radians(8), math.radians(30))
        scene.collection.objects.link(sun)
        world = bpy.data.worlds.new("w")
        world.use_nodes = True
        world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.72, 1.0, 1)
        world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
        scene.world = world
        bpy.ops.mesh.primitive_plane_add(size=2000, location=(0, 0, -0.02))
        g = bpy.context.active_object
        g.name = "ground"
        gm = bpy.data.materials.new("g")
        gm.use_nodes = True
        gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.16, 0.36, 0.14, 1)
        g.data.materials.append(gm)
    h = max(sizes[n][1] for n in names)
    d = max(x * 1.05, h * 1.8)
    cam.data.lens = 40
    cam.location = (cx, -d, h * 0.7 + d * 0.35)
    look = mathutils.Vector((cx, 0, h * 0.35)) - cam.location
    cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 20
    scene.render.resolution_x = 1200
    scene.render.resolution_y = 600
    scene.view_settings.view_transform = "Standard"
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    for o in placed:
        o.location = (0, 0, 0)


if RENDER:
    for area in models.AREAS:
        if ONLY and area not in ONLY:
            continue
        names = [n for n in objects if n.split("_")[1] == area and not n.startswith("Landmark")]
        order = [n for n in names if n.startswith("Tree")] + [n for n in names if not n.startswith("Tree")]
        preview(area, order, os.path.join(OUT, f"preview_{area}.png"))
    if not ONLY:
        lms = ["Landmark_" + models.LANDMARKS[a] for a in models.AREAS]
        preview("landmarks1", ["Landmark_windmill", "Landmark_windmill_sails"] + lms[1:4], os.path.join(OUT, "preview_landmarks1.png"))
        preview("landmarks2", lms[4:], os.path.join(OUT, "preview_landmarks2.png"))
print("done")
