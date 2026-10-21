"""Build the smooth cartoon models (smodels.CATALOGUE), export them as one FBX with one shared palette texture,
write the sizes and origins the game reads, and render preview sheets.

    <blender python> build_smooth.py <out_dir> [--no-render] [--only name1,name2]

Outputs: SmoothModels.fbx, SmoothPalette.png, SmoothSizes.luau, SmoothOrigins.luau, preview_*.png
"""
import math
import os
import sys

import bpy
import mathutils

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import skit  # noqa: E402
import smodels  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
OUT = os.path.abspath(args[0])
RENDER = "--no-render" not in args
ONLY = args[args.index("--only") + 1].split(",") if "--only" in args else None
os.makedirs(OUT, exist_ok=True)

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)

pal = skit.Palette()
objects, sizes, origins = {}, {}, {}
for i, (name, (fn, kw)) in enumerate(smodels.CATALOGUE.items()):
    if ONLY and name not in ONLY:
        continue
    m = skit.Model(name, pal, seed=1000 + i)
    fn(m, **kw)
    obj, size, origin = m.finish()
    objects[name], sizes[name], origins[name] = obj, size, origin
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    flag = "  <-- OVER 20k" if tris > 20000 else ""
    print(f"{name:22s} tris {tris:6d}  size {size[0]:5.1f} x {size[1]:5.1f} x {size[2]:5.1f}{flag}")

img = pal.image("SmoothPalette", os.path.join(OUT, "SmoothPalette.png"))
mat = skit.material(img, "SmoothPalette")
for obj in objects.values():
    obj.data.materials.append(mat)
print("palette colours", len(pal.index))

bpy.ops.object.select_all(action="DESELECT")
for obj in objects.values():
    obj.select_set(True)
bpy.ops.export_scene.fbx(
    filepath=os.path.join(OUT, "SmoothModels.fbx"),
    use_selection=True,
    apply_unit_scale=True,
    global_scale=1.0,
    axis_forward="-Z",
    axis_up="Y",
    path_mode="COPY",
    embed_textures=True,
    mesh_smooth_type="OFF",  # write the normals as Blender has them (flat caps, smooth sides)
    object_types={"MESH"},
)

with open(os.path.join(OUT, "SmoothSizes.luau"), "w") as f:
    f.write("-- Made by tools/blender/smooth/build_smooth.py: each smooth model's size in studs (x, y, z). server/VoxelModels\n")
    f.write("-- sets MeshPart.Size from this, so the import scale in Studio doesn't matter.\n")
    f.write("return {\n")
    for name, (x, y, z) in sizes.items():
        f.write(f"\t{name} = Vector3.new({x:.3f}, {y:.3f}, {z:.3f}),\n")
    f.write("}\n")

with open(os.path.join(OUT, "SmoothOrigins.luau"), "w") as f:
    f.write("-- Made by tools/blender/smooth/build_smooth.py: where each smooth model's footprint middle (at its lowest point)\n")
    f.write("-- sits relative to the model's own origin (its foot, front = -Z), in studs. server/Models uses it.\n")
    f.write("return {\n")
    for name, (x, y, z) in origins.items():
        f.write(f"\t{name} = Vector3.new({x:.3f}, {y:.3f}, {z:.3f}),\n")
    f.write("}\n")


def sheet(names, path):
    scene = bpy.context.scene
    for o in objects.values():
        o.hide_render = True
    x = 0.0
    hmax = 1.0
    for n in names:
        o = objects[n]
        w = sizes[n][0]
        o.location = (x + w / 2, 0, 0)
        o.hide_render = False
        x += w + 3
        hmax = max(hmax, sizes[n][1])
    cam = bpy.data.objects.get("cam")
    if not cam:
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        scene.collection.objects.link(cam)
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        sun.data.energy = 3.2
        sun.rotation_euler = (math.radians(40), math.radians(10), math.radians(-35))
        scene.collection.objects.link(sun)
        world = bpy.data.worlds.new("w")
        world.use_nodes = True
        world.node_tree.nodes["Background"].inputs[0].default_value = (0.6, 0.78, 1.0, 1)
        world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
        scene.world = world
        bpy.ops.mesh.primitive_plane_add(size=3000, location=(0, 0, -0.02))
        g = bpy.context.active_object
        gm = bpy.data.materials.new("g")
        gm.use_nodes = True
        gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.22, 0.45, 0.16, 1)
        g.data.materials.append(gm)
    cx = x / 2
    d = max(x * 0.95, hmax * 2.0)
    cam.data.lens = 40
    # in front of the models (their fronts face -z in game space = +y in Blender), a little to the left, above
    cam.location = (cx - d * 0.2, d, hmax * 0.6 + d * 0.3)
    lk = mathutils.Vector((cx, 0, hmax * 0.4)) - cam.location
    cam.rotation_euler = lk.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 16
    scene.render.resolution_x = 1400
    scene.render.resolution_y = 640
    scene.view_settings.view_transform = "Standard"
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    for n in names:
        objects[n].location = (0, 0, 0)


if RENDER:
    groups = {
        "trees": [n for n in objects if n.startswith("S_tree")][:8],
        "trees2": [n for n in objects if n.startswith("S_tree")][8:] + [n for n in objects if n.startswith(("S_bush", "S_rock"))],
        "houses": [n for n in ("S_house_red", "S_shop_teal", "S_house_blue", "S_shop_red") if n in objects],
        "cabin": [n for n in ("S_log_cabin", "S_fountain", "S_well") if n in objects],
        "props": [n for n in ("S_stall_blue", "S_stall_red", "S_lantern_post", "S_bench", "S_barrel", "S_crate_stack", "S_hay_bale", "S_planter", "S_flower_bed", "S_cart", "S_fence", "S_picnic_table", "S_mailbox", "S_pot") if n in objects],
    }
    for g, names in groups.items():
        if names:
            sheet(names, os.path.join(OUT, f"preview_{g}.png"))
print("done")
