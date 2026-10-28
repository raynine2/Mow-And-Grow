"""Render the voxel Mayor (tools/blender/voxel/mayor.py) posed, to check the sculpture, in Blender (bpy).

    <python with bpy> tools/blender/voxel/mayor_preview.py OUT.png [view] [pose] [level]
view: front | three | face | side | back | low (default three); pose: rest | point | cheer | talk | blink;
level: FULL | LITE
"""
import math
import os
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mayor  # noqa: E402
from sculptkit import corner_of, rot, voxels_of  # noqa: E402

FACES = [
    ((1, 0, 0), [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)]),
    ((-1, 0, 0), [(0, 0, 1), (0, 1, 1), (0, 1, 0), (0, 0, 0)]),
    ((0, 1, 0), [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)]),
    ((0, -1, 0), [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)]),
    ((0, 0, 1), [(1, 0, 1), (1, 1, 1), (0, 1, 1), (0, 0, 1)]),
    ((0, 0, -1), [(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)]),
]
C = np.array([[1, 0, 0, 0], [0, 0, -1, 0], [0, 1, 0, 0], [0, 0, 0, 1]], float)  # design -> Blender

A_POSE = 12  # degrees the arms hang out from the body (client/MayorRig's rest pose)


def T(x=0, y=0, z=0):
    m = np.eye(4)
    m[:3, 3] = (x, y, z)
    return m


def R(ax=0, ay=0, az=0):
    m = np.eye(4)
    m[:3, :3] = rot(ax, ay, az)
    return m


# (client/MayorRig's tables, copied here to preview the poses: REST then POSES, degrees, CFrame.Angles order)
REST = {"LeftUpperArm": (0, 0, -A_POSE), "RightUpperArm": (0, 0, A_POSE), "LeftLowerArm": (8, 0, 0), "RightLowerArm": (8, 0, 0), "Hat": (0, 0, -5)}
JOINT = {
    "Root": "LowerTorso", "Waist": "UpperTorso", "Neck": "Head", "RShoulder": "RightUpperArm", "RElbow": "RightLowerArm",
    "RWrist": "RightHand", "LShoulder": "LeftUpperArm", "LElbow": "LeftLowerArm", "LWrist": "LeftHand", "RHip": "RightUpperLeg",
    "RKnee": "RightLowerLeg", "RAnkle": "RightFoot", "LHip": "LeftUpperLeg", "LKnee": "LeftLowerLeg", "LAnkle": "LeftFoot",
    "Hat": "Hat", "Jaw": "Jaw", "Stache": "Stache", "BrowL": "BrowL", "BrowR": "BrowR",
}


def sym(d):
    """Mirror the R joints of a pose onto L (x kept, y and z flipped)."""
    out = dict(d)
    for k, v in d.items():
        if k[0] == "R" and k[1:] in ("Shoulder", "Elbow", "Wrist", "Hip", "Knee", "Ankle"):
            out["L" + k[1:]] = (v[0], -v[1], -v[2])
    return out


POSES = {
    "rest": {},
    "idle": sym({"RShoulder": (4, 0, 2), "RElbow": (10, 0, 0)}),
    "proud": dict(sym({"RShoulder": (16, 30, 14), "RElbow": (52, 0, 0), "RWrist": (0, 0, -20)}), Waist=(6, 0, 0), Neck=(9, 0, 0), Root=(2, 0, 0)),
    "worried": dict(sym({"RShoulder": (32, -14, -4), "RElbow": (72, 18, 0), "RWrist": (0, 0, 10)}), Waist=(-5, 0, 0), Neck=(-12, 0, 0), BrowL=(0, 0, 14), BrowR=(0, 0, -14)),
    "present": dict(sym({"RShoulder": (34, 0, 52), "RElbow": (24, 0, 0), "RWrist": (0, -20, 0)}), Waist=(4, 0, 0), Neck=(6, 0, 0)),
    "point": dict(RShoulder=(92, -8, 4), RElbow=(4, 0, 0), RWrist=(0, 0, 0), LShoulder=(-12, 0, -16), LElbow=(30, 0, 0), Waist=(0, -18, 0), Neck=(4, -10, 0), Root=(0, -6, 0)),
    "cheer": dict(sym({"RShoulder": (14, 0, 150), "RElbow": (22, 0, 0)}), Neck=(14, 0, 0), Waist=(5, 0, 0), Jaw=(-16, 0, 0), BrowL=(0, 0, 10), BrowR=(0, 0, -10)),
    "shock": dict(sym({"RShoulder": (38, 0, 62), "RElbow": (96, 0, 0), "RWrist": (0, 0, 20)}), Root=(7, 0, 0), Neck=(10, 0, 0), Jaw=(-18, 0, 0), BrowL=(0, 0, 8), BrowR=(0, 0, -8)),
    "tiphat": dict(RShoulder=(150, -20, 16), RElbow=(40, 0, 0), LShoulder=(6, 0, -4), LElbow=(16, 0, 0), Neck=(-6, -8, 4), Hat=(-18, 0, 6)),
    "sigh": dict(sym({"RShoulder": (2, 0, -4), "RElbow": (6, 0, 0)}), Waist=(-8, 0, 0), Neck=(-18, 0, 0), Root=(-2, 0, 0)),
    "talk": dict(RShoulder=(38, 10, 30), RElbow=(62, 0, 0), RWrist=(0, -30, 0), LShoulder=(10, 0, -6), LElbow=(24, 0, 0), Neck=(-3, 6, 3), Jaw=(-10, 0, 0)),
    "clasp": dict(sym({"RShoulder": (26, -20, -6), "RElbow": (64, 22, 0), "RWrist": (0, 0, 14)}), Waist=(-2, 0, 0), Neck=(-4, 0, 0)),
    "wave": dict(RShoulder=(10, 0, 140), RElbow=(30, 0, 0), LShoulder=(6, 0, -4), LElbow=(14, 0, 0), Neck=(4, 0, -4)),
    "laugh": dict(sym({"RShoulder": (16, 30, 14), "RElbow": (52, 0, 0), "RWrist": (0, 0, -20)}), Waist=(8, 0, 0), Neck=(16, 0, 0), Root=(3, 0, 0), Jaw=(-14, 0, 0)),
    "fist": dict(RShoulder=(30, 20, 34), RElbow=(118, 0, 0), LShoulder=(4, 0, -6), LElbow=(14, 0, 0), Neck=(6, 0, 0), Waist=(4, 8, 0)),
    "cower": dict(sym({"RShoulder": (60, -10, 30), "RElbow": (110, 0, 0), "RWrist": (0, 0, 10)}), Waist=(-10, 0, 0), Neck=(-14, 0, 0), Root=(-4, 0, 0)),
    "lookOut": dict(sym({"RShoulder": (-22, 85, 6), "RElbow": (75, 0, 0)}), Waist=(2, 0, 0), Neck=(4, 0, 0)),
}


def pose_angles(name):
    """Per group: (rest angles, pose angles)."""
    out = {}
    for k, v in POSES.get(name, {}).items():
        out[JOINT.get(k, k)] = v
    return out


def frames(groups, pose):
    ang = pose_angles(pose)
    F = {}
    for S in groups:  # parents come before children in mayor.sculpts()
        rel = T(*S.pivot) @ R(*REST.get(S.name, (0, 0, 0))) @ R(*ang.get(S.name, (0, 0, 0)))
        F[S.name] = (F[S.parent] @ rel) if S.parent else rel
    return F


def mesh_from(name, vox, v, pal, corner, hide=False):
    bm = bmesh.new()
    cols = bm.loops.layers.color.new("Col")
    verts = {}
    glass_faces = []

    def vert(p):
        q = verts.get(p)
        if q is None:
            x, y, z = p
            x, y, z = corner[0] + x * v, corner[1] + y * v, corner[2] + z * v
            q = bm.verts.new((x, -z, y))
            verts[p] = q
        return q

    for (x, y, z), ci in vox.items():
        e = pal.entries[ci]
        rgb = (e[0] / 255, e[1] / 255, e[2] / 255, 1)
        for normal, corners in FACES:
            nb = (x + normal[0], y + normal[1], z + normal[2])
            if nb in vox and pal.entries[vox[nb]][4] != "glass":
                continue
            try:
                f = bm.faces.new([vert((x + c[0], y + c[1], z + c[2])) for c in corners])
            except ValueError:
                continue
            for loop in f.loops:
                loop[cols] = rgb
            f.material_index = 1 if e[4] == "glass" else 0
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    try:
        me.color_attributes.active_color = me.color_attributes["Col"]
        me.color_attributes.render_color_index = 0
    except Exception:
        pass
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    m = bpy.data.materials.new(name + "_m")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.6
    me.materials.append(m)
    g = bpy.data.materials.new(name + "_glass")
    g.use_nodes = True
    gb = g.node_tree.nodes.get("Principled BSDF")
    gb.inputs["Base Color"].default_value = (0.8, 0.9, 1.0, 1)
    gb.inputs["Transmission Weight"].default_value = 0.92
    gb.inputs["Roughness"].default_value = 0.05
    me.materials.append(g)
    obj.hide_render = hide
    return obj


def main():
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else sys.argv[1:]
    out = args[0]
    view = args[1] if len(args) > 1 else "three"
    pose = args[2] if len(args) > 2 else "rest"
    level = args[3] if len(args) > 3 else "FULL"
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    groups = mayor.sculpts(**mayor.LEVELS[level])
    objs = {}
    for S in groups:
        vox = voxels_of(S)
        objs[S.name] = mesh_from(S.name, vox, S.v, mayor.PAL, corner_of(S))
    poses = pose.split(",")

    def place(pz):
        F = frames(groups, pz)
        for S in groups:
            obj = objs[S.name]
            obj.hide_render = (S.name == "Lids" and pz != "blink") or (S.name in ("Eyes", "Pupils") and pz == "blink")
            Bm = C @ F[S.name] @ np.linalg.inv(C)
            obj.matrix_world = Matrix(Bm.tolist())

    place(poses[0])
    # camera (Blender: he faces -Y... design -Z maps to Blender +Y; up is +Z)
    targets = {
        "front": ((0, 14, 4.2), (0, 0, 3.9), 50),
        "three": ((-7.5, 11, 5.0), (0, 0, 3.8), 50),
        "face": ((-1.4, 4.6, 5.5), (0, 0.6, 5.25), 60),
        "side": ((14, 0, 4.2), (0, 0, 3.9), 50),
        "back": ((6, -12, 5.2), (0, 0, 3.9), 50),
        "backthree": ((-7, -9, 4.6), (0, 0, 3.6), 50),
        "low": ((-2.5, 7.5, 1.0), (0, 0, 4.4), 35),
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
    sun_data.energy = 3.2
    sun_data.angle = math.radians(8)
    sun = bpy.data.objects.new("sun", sun_data)
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-160))
    scene.collection.objects.link(sun)
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.55, 0.72, 1.0, 1)
    bg.inputs[1].default_value = 0.9
    scene.world = world
    bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, 0))
    g = bpy.context.active_object
    gm = bpy.data.materials.new("g")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.16, 0.36, 0.1, 1)
    g.data.materials.append(gm)
    if os.environ.get("FAST"):
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.display.shading.light = "STUDIO"
        scene.display.shading.color_type = "VERTEX"
        scene.display.shading.show_shadows = True
        scene.display.shading.show_cavity = True
    else:
        scene.render.engine = "CYCLES"
        scene.cycles.device = "CPU"
        scene.cycles.samples = 48
        scene.cycles.use_denoising = True
    scene.render.resolution_x = 900
    scene.render.resolution_y = 1000 if view != "face" else 800
    scene.view_settings.view_transform = "Standard"
    for pz in poses:
        place(pz)
        scene.render.filepath = out if len(poses) == 1 else out.replace(".png", "_%s.png" % pz)
        bpy.ops.render.render(write_still=True)


main()
