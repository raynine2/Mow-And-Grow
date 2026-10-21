"""Render a quick preview of one model (Cycles, CPU), for checking the look before exporting."""
import math
import sys

import bpy

sys.path.insert(0, __file__.rsplit("/", 1)[0])
import kit
import models


def render(obj, path, dist=1.0, height=0.45, az=-45):
    scene = bpy.context.scene
    # frame the model
    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    cx, cy, cz = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, (min(zs) + max(zs)) / 2
    size = max(max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))
    cam_data = bpy.data.cameras.new("cam")
    cam_data.lens = 50
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    d = size * 2.1 * dist
    a = math.radians(az)
    cam.location = (cx + d * 1.06 * math.cos(a), cy + d * 1.06 * math.sin(a), cz + d * height)
    direction = (cx - cam.location[0], cy - cam.location[1], cz - cam.location[2])
    rot_quat = __import__("mathutils").Vector(direction).to_track_quat("-Z", "Y")
    cam.rotation_euler = rot_quat.to_euler()
    scene.camera = cam
    sun_data = bpy.data.lights.new("sun", "SUN")
    sun_data.energy = 3.2
    sun = bpy.data.objects.new("sun", sun_data)
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(35))
    scene.collection.objects.link(sun)
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.72, 1.0, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    scene.world = world
    # ground plane
    bpy.ops.mesh.primitive_plane_add(size=size * 6, location=(cx, cy, min(zs) - 0.01))
    g = bpy.context.active_object
    gm = bpy.data.materials.new("g")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.12, 0.45, 0.12, 1)
    g.data.materials.append(gm)
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.render.resolution_x = 640
    scene.render.resolution_y = 520
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "Medium High Contrast" if "Medium High Contrast" in [i.identifier for i in bpy.types.ColorManagedViewSettings.bl_rna.properties["look"].enum_items] else "None"
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    name, out, az = sys.argv[-3], sys.argv[-2], float(sys.argv[-1])
    kit.clear_scene()
    fn = getattr(models, name)
    vox, pal, vs, origin = fn()
    obj = kit.build(name, vox, pal, voxel_size=vs, origin=origin, atlas_dir="/tmp")
    print("voxels", len(vox), "faces", len(obj.data.polygons))
    render(obj, out, az=az)
