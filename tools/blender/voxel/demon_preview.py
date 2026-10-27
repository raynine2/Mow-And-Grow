"""Render the glitch demon (tools/blender/voxel/demon.py) posed like client/Demon poses it, to check the sculpture.

    <python with bpy> tools/blender/voxel/demon_preview.py OUT.png [view] [roar] [light]
view: front | three | face | side | back (default three); roar 0..1; light: day | corrupt
"""
import math
import os
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import demon  # noqa: E402

VOX, VOXH = 0.5, 0.5

FACES = [
    ((1, 0, 0), [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)]),
    ((-1, 0, 0), [(0, 0, 1), (0, 1, 1), (0, 1, 0), (0, 0, 0)]),
    ((0, 1, 0), [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)]),
    ((0, -1, 0), [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)]),
    ((0, 0, 1), [(1, 0, 1), (1, 1, 1), (0, 1, 1), (0, 0, 1)]),
    ((0, 0, -1), [(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)]),
]
C = np.array([[1, 0, 0, 0], [0, 0, -1, 0], [0, 1, 0, 0], [0, 0, 0, 1]], float)  # design -> Blender


def T(x=0, y=0, z=0):
    m = np.eye(4)
    m[:3, 3] = (x, y, z)
    return m


def R(ax=0, ay=0, az=0):
    m = np.eye(4)
    m[:3, :3] = demon.rot(ax, ay, az)
    return m


def frames(roar, t=0.0, rise=1.0, scale=1.0):
    """Each group's frame in design space, as client/Demon's groupFrames."""
    breathe = math.sin(t * 1.6)
    hunch = (1 - rise) * (1 - roar)
    root = T(0, -(1 - rise) * 40 * 1.05, 0)
    f = {}
    f["body"] = root @ R(roar * 5 + breathe * 0.6 - hunch * 18, 0, 0)
    head = f["body"] @ T(*demon.HEAD_PIVOT) @ R(roar * 20 + math.sin(t * 0.9) * 2.5 - hunch * 14, math.sin(t * 0.55) * 6 * (1 - roar), math.sin(t * 0.7) * 2)
    f["head"] = head
    f["jaw"] = head @ T(*demon.JAW_PIVOT) @ R(-(roar * 34 + max(0, math.sin(t * 2.2)) * 3), 0, 0)
    for side in (-1, 1):
        swing = math.sin(t * 1.1 + side) * 4
        upper = f["body"] @ T(side * 11.2, 13.4, 0) @ R(8 + roar * 27 + swing, 0, side * (roar * 56 + 12))
        f["armL" if side < 0 else "armR"] = upper
        f["foreL" if side < 0 else "foreR"] = upper @ T(0, -8.6, 0) @ R(34 * (1 - roar) + 6 + swing * 0.6, 0, side * roar * 58)
        f["wingL" if side < 0 else "wingR"] = f["body"] @ T(side * 5.5, 13, 4.6) @ R(10, 0, side * (roar * 22 + math.sin(t * 1.8) * 3))
    return f


def mesh_from(name, vox, neon, v):
    bm = bmesh.new()
    cols = bm.loops.layers.color.new("Col")
    verts = {}

    def vert(p):
        q = verts.get(p)
        if q is None:
            x, y, z = p
            q = bm.verts.new((x * v, -z * v, y * v))
            verts[p] = q
        return q

    for (x, y, z), ci in vox.items():
        e = demon.PAL[ci]
        if bool(e[3]) != neon:
            continue
        rgb = (e[0] / 255, e[1] / 255, e[2] / 255, 1)
        for normal, corners in FACES:
            nb = (x + normal[0], y + normal[1], z + normal[2])
            if nb in vox:
                continue
            try:
                f = bm.faces.new([vert((x + c[0], y + c[1], z + c[2])) for c in corners])
            except ValueError:
                continue
            for loop in f.loops:
                loop[cols] = rgb
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    m = bpy.data.materials.new(name + "_m")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    if neon:
        em = nt.nodes.new("ShaderNodeEmission")
        nt.links.new(attr.outputs["Color"], em.inputs["Color"])
        em.inputs["Strength"].default_value = 4.0
        out = nt.nodes.get("Material Output")
        nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    else:
        nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.55
    me.materials.append(m)
    return obj


def main():
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else sys.argv[1:]
    out = args[0]
    view = args[1] if len(args) > 1 else "three"
    roar = float(args[2]) if len(args) > 2 else 0.0
    light = args[3] if len(args) > 3 else "day"
    global VOX, VOXH
    VOX = float(args[4]) if len(args) > 4 else 0.5
    VOXH = float(args[5]) if len(args) > 5 else VOX
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    f = frames(roar)
    for S, vox in demon.voxels(VOX, VOXH):
        Bm = C @ f[S.name] @ np.linalg.inv(C)
        for neon in (False, True):
            obj = mesh_from(S.name + ("_neon" if neon else ""), vox, neon, S.v)
            obj.matrix_world = Matrix(Bm.tolist())
    # camera (Blender: the demon faces +Y; up is +Z)
    targets = {
        "front": ((0, 100, 22), (0, 0, 21), 40),
        "three": ((-58, 82, 30), (0, 0, 20), 40),
        "face": ((-8, 30, 26), (0, -1, 24.2), 40),
        "side": ((95, 0, 22), (0, 0, 20), 40),
        "back": ((40, -85, 30), (0, 0, 20), 40),
        "low": ((-20, 60, 2), (0, 0, 22), 30),
    }
    pos, tgt, lens = targets[view]
    cam_data = bpy.data.cameras.new("cam")
    cam_data.lens = lens
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = pos
    d = Vector(tgt) - Vector(pos)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    sun_data = bpy.data.lights.new("sun", "SUN")
    sun = bpy.data.objects.new("sun", sun_data)
    sun.rotation_euler = (math.radians(55), math.radians(15), math.radians(-150))
    scene.collection.objects.link(sun)
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    if light == "corrupt":
        sun_data.energy = 1.2
        sun_data.color = (1.0, 0.6, 0.75)
        bg.inputs[0].default_value = (0.08, 0.02, 0.06, 1)
        bg.inputs[1].default_value = 0.6
    else:
        sun_data.energy = 3.0
        bg.inputs[0].default_value = (0.55, 0.72, 1.0, 1)
        bg.inputs[1].default_value = 0.8
    scene.world = world
    bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, 0))
    g = bpy.context.active_object
    gm = bpy.data.materials.new("g")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.1, 0.25, 0.08, 1) if light == "day" else (0.03, 0.01, 0.03, 1)
    g.data.materials.append(gm)
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 20
    scene.cycles.use_denoising = False
    scene.render.resolution_x = 900
    scene.render.resolution_y = 700
    scene.view_settings.view_transform = "Standard"
    scene.render.filepath = out
    bpy.ops.render.render(write_still=True)


main()
