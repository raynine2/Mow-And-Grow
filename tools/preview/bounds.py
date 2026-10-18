#!/usr/bin/env python3
"""Write the bounding box of every Blender model (assets/models/*.glb) in Roblox model space, for the preview:

    python3 tools/preview/bounds.py /tmp/bounds.json
    MODEL_BOUNDS=/tmp/bounds.json lune run tools/preview/scene.luau lobby /tmp/lobby.json

Model space is the glTF file's: x = x, y = up, z = glTF z (the model's front faces -z), like server/Models.
"""
import glob, json, os, struct, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
out = {}
for path in sorted(glob.glob(os.path.join(ROOT, "assets", "models", "*.glb"))):
    data = open(path, "rb").read()
    n = struct.unpack("<I", data[12:16])[0]
    gltf = json.loads(data[20:20 + n])
    lo, hi = [1e9] * 3, [-1e9] * 3
    for node in gltf["nodes"]:
        if "mesh" not in node or node.get("name") == "Origin__000000":
            continue
        t = node.get("translation", [0, 0, 0])
        for prim in gltf["meshes"][node["mesh"]]["primitives"]:
            acc = gltf["accessors"][prim["attributes"]["POSITION"]]
            for i in range(3):
                lo[i] = min(lo[i], acc["min"][i] + t[i]); hi[i] = max(hi[i], acc["max"][i] + t[i])
    name = os.path.basename(path)[:-4]
    out[name] = {"centre": [(lo[i] + hi[i]) / 2 for i in range(3)], "size": [hi[i] - lo[i] for i in range(3)]}
json.dump(out, open(sys.argv[1] if len(sys.argv) > 1 else "/tmp/bounds.json", "w"))
print("bounds for", len(out), "models")
