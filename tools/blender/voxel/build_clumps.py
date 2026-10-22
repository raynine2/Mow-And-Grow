"""Build only the grass clumps and their stubble (Clump_<area>_<n>, Stubble_<area>) into their own FBX, so they can
be re-imported without touching the other voxel models, and print their sizes for src/shared/ModelSizes.luau.

    <blender python> build_clumps.py <out_dir> [--no-render]

Outputs in <out_dir>: MowClumps.fbx (+ its texture), ClumpSizes.txt (lines to paste into ModelSizes.luau),
preview_clumps.png (every area's clumps side by side).
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
os.makedirs(OUT, exist_ok=True)

kit.clear_scene()
atlas = kit.Atlas()
objects, sizes = {}, {}
for name, (fn, kw) in models.catalogue().items():
    if not name.startswith(("Clump_", "Stubble_")):
        continue
    vox, pal, vs = fn(**kw)
    obj, size = kit.build_columns(name, vox, pal, atlas, voxel_size=vs)
    objects[name] = obj
    sizes[name] = size
    tris = len(obj.data.polygons) * 2
    print(f"{name:24s} voxels {len(vox):5d}  tris {tris:6d}  size {size[0]:.2f} x {size[1]:.2f} x {size[2]:.2f}")
img = atlas.image("MowClumpsAtlas", os.path.join(OUT, "MowClumpsAtlas.png"))
mat = kit.shared_material(img, "MowClumpsAtlas")
for obj in objects.values():
    obj.data.materials.append(mat)

bpy.ops.object.select_all(action="DESELECT")
for obj in objects.values():
    obj.select_set(True)
bpy.ops.export_scene.fbx(
    filepath=os.path.join(OUT, "MowClumps.fbx"),
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
with open(os.path.join(OUT, "ClumpSizes.txt"), "w") as f:
    for name, (x, y, z) in sizes.items():
        f.write(f"\t{name} = Vector3.new({x:.2f}, {y:.2f}, {z:.2f}),\n")

if RENDER:
    scene = bpy.context.scene
    names = [n for n in objects if n.endswith(("_1", "_2")) and n.split("_")[1] in ("meadow", "wheat", "blossom", "swamp")]
    names += ["Stubble_meadow", "Stubble_wheat"]
    x = 0.0
    for n in names:
        o = objects[n]
        o.location = (x + sizes[n][0] / 2, 0, 0)
        x += sizes[n][0] + 1.5
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(48), math.radians(8), math.radians(30))
    scene.collection.objects.link(sun)
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.72, 1.0, 1)
    scene.world = world
    bpy.ops.mesh.primitive_plane_add(size=500, location=(0, 0, -0.02))
    ground = bpy.context.active_object
    gm = bpy.data.materials.new("g")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.16, 0.36, 0.14, 1)
    ground.data.materials.append(gm)
    h = max(sizes[n][1] for n in names)
    d = max(x * 0.95, h * 2)
    cam.data.lens = 40
    cam.location = (x / 2, -d, h * 0.6 + d * 0.22)
    look = mathutils.Vector((x / 2, 0, h * 0.4)) - cam.location
    cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 16
    scene.render.resolution_x = 1400
    scene.render.resolution_y = 520
    scene.view_settings.view_transform = "Standard"
    scene.render.filepath = os.path.join(OUT, "preview_clumps.png")
    bpy.ops.render.render(write_still=True)
print("done")
