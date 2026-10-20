"""Writes a baked toy model's mesh (assets/toy_models/<Name>.fbx) as JSON for building it in Studio with an
EditableMesh (no Import 3D needed):

    blender -b --factory-startup -P tools/blender/toy/mesh_json.py -- <out_dir> Name1 Name2 ...

JSON: {"pos": [x,y,z,...], "uv": [u,v,...], "nrm": [x,y,z,...], "tri": [v0,v1,v2, t0,t1,t2, n0,n1,n2, ...]} in Roblox
model space (studs, Y up, the face looking along -Z), UVs with v flipped for Roblox textures.
"""
import json
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
args = sys.argv[sys.argv.index("--") + 1:]
out_dir, names = args[0], args[1:]
os.makedirs(out_dir, exist_ok=True)


def key(vals, nd=4):
    return tuple(round(v, nd) for v in vals)


for name in names:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.path.join(REPO, "assets", "toy_models", f"{name}.fbx"))
    obj = next(o for o in bpy.context.scene.objects if o.type == "MESH")
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(obj.evaluated_get(dg), depsgraph=dg)
    me.transform(obj.matrix_world)
    me.calc_loop_triangles()
    uv_layer = me.uv_layers.active.data
    pos = []
    for v in me.vertices:  # Blender (x, y, z) -> Roblox (x, z, -y): front +Y becomes -Z (the LookVector)
        pos += [round(v.co.x, 4), round(v.co.z, 4), round(-v.co.y, 4)]
    uvs, uv_ix, nrms, n_ix, tri = [], {}, [], {}, []
    for lt in me.loop_triangles:
        t_ids, n_ids = [], []
        for li, n in zip(lt.loops, lt.split_normals):
            u = uv_layer[li].uv
            ku = key((u.x, 1 - u.y))
            if ku not in uv_ix:
                uv_ix[ku] = len(uv_ix)
                uvs += list(ku)
            t_ids.append(uv_ix[ku])
            kn = key((n[0], n[2], -n[1]), 3)
            if kn not in n_ix:
                n_ix[kn] = len(n_ix)
                nrms += list(kn)
            n_ids.append(n_ix[kn])
        tri += list(lt.vertices) + t_ids + n_ids
    data = dict(pos=pos, uv=uvs, nrm=nrms, tri=tri)
    with open(os.path.join(out_dir, f"{name}.json"), "w", encoding="utf-8") as f:
        json.dump(data, f, separators=(",", ":"))
    ys = pos[1::3]
    print(f"MESH_OK {name} verts={len(me.vertices)} tris={len(me.loop_triangles)} uvs={len(uv_ix)} "
          f"nrms={len(n_ix)} height={max(ys) - min(ys):.3f}")
