"""Build the second-look grass clumps (grass_v2) into one FBX for Studio's Import 3D, like build_clumps.py:
    python3 grass_v2_build.py <out_dir>
Outputs MowClumpsV2.fbx (+ its atlas texture) and ClumpSizes.txt (lines for src/shared/ModelSizes.luau).
After importing in Studio, the clumps replace the old ones in ServerStorage.VoxelModels (same names)."""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402
import grass_v2  # noqa: E402

OUT = os.path.abspath(sys.argv[1])
os.makedirs(OUT, exist_ok=True)
kit.clear_scene()
atlas = kit.Atlas()
objects, sizes = {}, {}
for area in grass_v2.AREAS:
    for n, seed in enumerate((31, 62), 1):
        vox, pal, vs = grass_v2.clump2(seed=seed, area=area)
        name = f"Clump_{area}_{n}"
        obj, size = kit.build_columns(name, vox, pal, atlas, voxel_size=vs)
        objects[name], sizes[name] = obj, size
        print(f"{name:20s} tris {len(obj.data.polygons) * 2:6d}  size {size[0]:.2f} x {size[1]:.2f} x {size[2]:.2f}")
img = atlas.image("MowClumpsV2Atlas", os.path.join(OUT, "MowClumpsV2Atlas.png"))
mat = kit.shared_material(img, "MowClumpsV2Atlas")
for obj in objects.values():
    obj.data.materials.append(mat)
bpy.ops.object.select_all(action="DESELECT")
for obj in objects.values():
    obj.select_set(True)
bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "MowClumpsV2.fbx"), use_selection=True, apply_unit_scale=True, global_scale=1.0,
    axis_forward="-Z", axis_up="Y", path_mode="COPY", embed_textures=True, mesh_smooth_type="FACE", object_types={"MESH"})
with open(os.path.join(OUT, "ClumpSizes.txt"), "w") as f:
    for name, (x, y, z) in sizes.items():
        f.write(f"\t{name} = Vector3.new({x:.2f}, {y:.2f}, {z:.2f}),\n")
print("done")
