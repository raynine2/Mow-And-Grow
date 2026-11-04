"""Render the grass clumps old (models.stalk_clump, top row) against new (grass_v2.clump2, bottom row), every area.
    python3 grass_v2_preview.py <out.png> [areas,comma,separated]
"""
import math
import os
import sys

import bpy
import mathutils

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402
import models  # noqa: E402
import grass_v2  # noqa: E402

out = os.path.abspath(sys.argv[1])
areas = sys.argv[2].split(",") if len(sys.argv) > 2 else grass_v2.AREAS
kit.clear_scene()
atlas = kit.Atlas()
GAP = 7.5
for row, label in ((0, "old"), (1, "new")):
    for i, area in enumerate(areas):
        if row == 0:
            vox, pal, vs = models.stalk_clump(seed=31, area=area)
        else:
            vox, pal, vs = grass_v2.clump2(seed=31, area=area)
        obj, size = kit.build_columns(f"{label}_{area}", vox, pal, atlas, voxel_size=vs)
        obj.location = (i * GAP, row * -GAP * 2.2, 0)
img = atlas.image("preview_atlas", "/tmp/claude_grass_atlas.png")
mat = kit.shared_material(img, "preview_atlas")
for o in bpy.data.objects:
    if o.type == "MESH":
        o.data.materials.append(mat)
scene = bpy.context.scene
bpy.ops.mesh.primitive_plane_add(size=600, location=(0, 0, -0.02))
ground = bpy.context.active_object
gm = bpy.data.materials.new("g")
gm.use_nodes = True
gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.13, 0.3, 0.1, 1)
ground.data.materials.append(gm)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
w = (len(areas) - 1) * GAP
cx, cy = w / 2, -GAP * 1.1
cam.data.lens = 40
cam.location = (cx, cy - w * 1.05, 30 + w * 0.32)
look = mathutils.Vector((cx, cy, 3)) - cam.location
cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
scene.camera = cam
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.2
sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(25))
scene.collection.objects.link(sun)
world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.72, 1.0, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
scene.world = world
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = int(os.environ.get("SAMPLES", "20"))
scene.cycles.use_denoising = True
scene.render.resolution_x = int(os.environ.get("W", "1800"))
scene.render.resolution_y = int(os.environ.get("H", "1000"))
scene.view_settings.view_transform = "Standard"
scene.render.filepath = out
bpy.ops.render.render(write_still=True)
print("RENDERED", out)
