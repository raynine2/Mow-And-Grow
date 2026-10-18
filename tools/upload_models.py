#!/usr/bin/env python3
"""Upload Blender models (assets/models/*.glb) to Roblox with Open Cloud and record their asset ids.

    ROBLOX_API_KEY=... python3 tools/upload_models.py [--user 1994267229 | --group 96047379] [names...]

- Needs an Open Cloud API key with Assets read + write (create.roblox.com > Open Cloud > API Keys).
- Uploads each GLB as a "Model" asset owned by the user or group that owns the game (the game loads them with
  InsertService:LoadAsset, which only works for assets owned by the game's owner).
- Re-uploads only models whose GLB changed (hashes kept in assets/uploaded.json); --force re-uploads all.
- Writes src/shared/ModelIds.luau, which the game reads.
"""
import argparse, hashlib, json, os, sys, time, urllib.error, urllib.request, uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API = "https://apis.roblox.com/assets/v1"

def request(method, url, key, body=None, headers=None):
    # Status checks (GET) retry on Roblox server errors and rate limits; an upload (POST) is sent once.
    tries = 6 if method == "GET" else 1
    for attempt in range(tries):
        req = urllib.request.Request(url, data=body, method=method, headers={"x-api-key": key, **(headers or {})})
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.loads(r.read().decode() or "{}")
        except urllib.error.HTTPError as e:
            if attempt == tries - 1 or (e.code < 500 and e.code != 429):
                raise
            time.sleep(2 ** (attempt + 1))

def upload(path, name, key, creator, kind="Model"):
    meta = {"assetType": kind, "displayName": "MowALawn_" + name, "description": "Mow A Lawn %s: %s" % (kind.lower(), name),
            "creationContext": {"creator": creator}}
    boundary = uuid.uuid4().hex
    with open(path, "rb") as f:
        data = f.read()
    body = b"".join([
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\nContent-Type: application/json\r\n\r\n".encode(),
        json.dumps(meta).encode(), b"\r\n",
        (f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{os.path.basename(path)}\"\r\n"
         f"Content-Type: {'image/png' if kind == 'Decal' else 'model/gltf-binary'}\r\n\r\n").encode(),
        data, f"\r\n--{boundary}--\r\n".encode(),
    ])
    op = request("POST", API + "/assets", key, body, {"Content-Type": f"multipart/form-data; boundary={boundary}"})
    op_path = op.get("path") or ("operations/" + op["operationId"])
    for _ in range(90):
        res = request("GET", API + "/" + op_path, key)
        if res.get("done"):
            if "error" in res:
                raise RuntimeError(json.dumps(res["error"]))
            return int(res["response"]["assetId"])
        time.sleep(2)
    raise TimeoutError("upload of %s did not finish" % name)

def image_id(decal_id, key):
    """A Decal upload returns the decal's id; ImageLabels need the image inside it. Asset delivery (needs the
    Legacy Assets scope on the key) gives the decal's XML, which holds the image url."""
    import re
    for attempt in range(10):
        try:
            loc = request("GET", "https://apis.roblox.com/asset-delivery-api/v1/assetId/%d" % decal_id, key)["location"]
            raw = urllib.request.urlopen(loc, timeout=60).read()
            if raw[:2] == b"\x1f\x8b":
                import gzip
                raw = gzip.decompress(raw)
            xml = raw.decode("utf-8", "replace")
            m = re.search(r"\?id=(\d+)", xml)
            if m:
                return int(m.group(1))
        except (urllib.error.HTTPError, KeyError):
            pass
        time.sleep(3)  # a fresh upload can take a moment to be deliverable
    raise RuntimeError("couldn't find the image inside decal %d" % decal_id)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("names", nargs="*")
    ap.add_argument("--user", type=int, default=1994267229)
    ap.add_argument("--group", type=int)
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--icons", action="store_true", help="upload assets/icons/*.png as images instead")
    ap.add_argument("--fx", action="store_true", help="upload assets/fx/*.png (effect textures) as images instead")
    a = ap.parse_args()
    images = a.icons or a.fx
    folder = "fx" if a.fx else "icons" if a.icons else "models"
    key = os.environ.get("ROBLOX_API_KEY")
    if not key:
        sys.exit("ROBLOX_API_KEY is not set (add it in the cloud environment settings, then start a new session)")
    creator = {"groupId": str(a.group)} if a.group else {"userId": str(a.user)}
    kind, ext = ("Decal", ".png") if images else ("Model", ".glb")
    state_path = os.path.join(ROOT, "assets", {"fx": "uploaded_fx.json", "icons": "uploaded_icons.json"}.get(folder, "uploaded.json"))
    state = json.load(open(state_path)) if os.path.exists(state_path) else {}
    src_dir = os.path.join(ROOT, "assets", folder)
    names = a.names or sorted(f[:-4] for f in os.listdir(src_dir) if f.endswith(ext))
    for name in names:
        path = os.path.join(src_dir, name + ext)
        digest = hashlib.sha256(open(path, "rb").read()).hexdigest()
        if not a.force and state.get(name, {}).get("sha") == digest:
            print("unchanged", name, state[name]["id"])
        else:
            asset_id = upload(path, name, key, creator, kind)
            state[name] = {"id": asset_id, "sha": digest}  # a changed image gets a new image id below
            print("uploaded", name, asset_id)
        if images and "image" not in state[name]:
            state[name]["image"] = image_id(state[name]["id"], key)
            print("  image", name, state[name]["image"])
        json.dump(state, open(state_path, "w"), indent=1, sort_keys=True)
    if a.fx:
        lines = ["-- Generated by tools/upload_models.py --fx: image ids of the effect textures (assets/fx/*.png, drawn",
                 "-- by tools/fx/make_textures.py). client/Fx reads these. Don't edit by hand.", "return {"]
        for name in sorted(state):
            lines.append('\t%s = "rbxassetid://%d",' % (name, state[name]["image"]))
        out = "FxIds.luau"
    elif a.icons:
        lines = ["-- Generated by tools/upload_models.py --icons: image ids of the Blender icons (assets/icons/*.png).",
                 "-- Config.ICONS reads these. Don't edit by hand.", "return {"]
        for name in sorted(state):
            lines.append('\t%s = "rbxassetid://%d",' % (name, state[name]["image"]))
        out = "IconIds.luau"
    else:
        lines = ["-- Generated by tools/upload_models.py: Roblox asset ids of the Blender models (assets/models/*.glb).",
                 "-- The server loads these with InsertService (see server/Models.luau). Don't edit by hand.", "return {"]
        for name in sorted(state):
            lines.append('\t%s = %d,' % (name, state[name]["id"]))
        out = "ModelIds.luau"
    lines.append("}")
    open(os.path.join(ROOT, "src", "shared", out), "w").write("\n".join(lines) + "\n")
    print("wrote src/shared/%s with %d entries" % (out, len(state)))

if __name__ == "__main__":
    main()
