#!/usr/bin/env python3
"""Draw a JSON scene from tools/preview/scene.luau to a PNG (a rough stand-in for Studio's view).

    python3 tools/preview/render.py /tmp/run.json out.png --cam 0,6,-70 --look 0,4,40 [--fov 70]

Software z-buffer rasteriser: boxes, cylinders and balls, sun + ambient shading, sky gradient, distance haze,
and a little grain on textured materials (Grass, Wood, Ground ...), so shapes and colours can be judged
against reference screenshots.
"""
import argparse, json, math
import numpy as np
from PIL import Image

TEXTURED = {"Grass": 0.10, "Ground": 0.10, "Wood": 0.08, "WoodPlanks": 0.08, "Pebble": 0.12, "Mud": 0.08,
            "Slate": 0.10, "Snow": 0.03, "Sand": 0.06, "LeafyGrass": 0.10}

def box_mesh():
    v = np.array([[x, y, z] for x in (-.5, .5) for y in (-.5, .5) for z in (-.5, .5)], float)
    f = [(0,1,3),(0,3,2),(4,6,7),(4,7,5),(0,4,5),(0,5,1),(2,3,7),(2,7,6),(0,2,6),(0,6,4),(1,5,7),(1,7,3)]
    return v, np.array(f)

def cyl_mesh(n=16):
    # axis along X (Roblox cylinders)
    ang = np.linspace(0, 2*np.pi, n, endpoint=False)
    ring = np.stack([np.cos(ang)*.5, np.sin(ang)*.5], 1)
    v = [[-.5, r[0], r[1]] for r in ring] + [[.5, r[0], r[1]] for r in ring] + [[-.5,0,0],[.5,0,0]]
    f = []
    for i in range(n):
        j = (i+1) % n
        f += [(i, j, n+j), (i, n+j, n+i), (2*n, j, i), (2*n+1, n+i, n+j)]
    return np.array(v, float), np.array(f)

def ball_mesh():
    t = (1+5**.5)/2
    v = np.array([[-1,t,0],[1,t,0],[-1,-t,0],[1,-t,0],[0,-1,t],[0,1,t],[0,-1,-t],[0,1,-t],[t,0,-1],[t,0,1],[-t,0,-1],[-t,0,1]], float)
    v /= np.linalg.norm(v, axis=1)[:, None] * 2
    f = [(0,11,5),(0,5,1),(0,1,7),(0,7,10),(0,10,11),(1,5,9),(5,11,4),(11,10,2),(10,7,6),(7,1,8),(3,9,4),(3,4,2),(3,2,6),(3,6,8),(3,8,9),(4,9,5),(2,4,11),(6,2,10),(8,6,7),(9,8,1)]
    return v, np.array(f)

MESH = {"Block": box_mesh(), "Cylinder": cyl_mesh(), "Ball": ball_mesh()}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("scene"); ap.add_argument("out")
    ap.add_argument("--cam", default="0,8,-60"); ap.add_argument("--look", default="0,4,40")
    ap.add_argument("--fov", type=float, default=70); ap.add_argument("--w", type=int, default=1280)
    ap.add_argument("--h", type=int, default=720); ap.add_argument("--far", type=float, default=700)
    a = ap.parse_args()
    parts = json.load(open(a.scene))
    W, H = a.w, a.h
    cam = np.array([float(x) for x in a.cam.split(",")]); look = np.array([float(x) for x in a.look.split(",")])
    fwd = look - cam; fwd /= np.linalg.norm(fwd)
    right = np.cross(fwd, [0, 1, 0]); right /= np.linalg.norm(right)
    up = np.cross(right, fwd)
    f = 1 / math.tan(math.radians(a.fov) / 2)
    sun = np.array([0.45, 0.8, -0.35]); sun /= np.linalg.norm(sun)
    sky_top, sky_bot = np.array([0.36, 0.62, 0.95]), np.array([0.80, 0.90, 1.0])

    # sky
    yy = np.linspace(0, 1, H)[:, None, None]
    img = np.broadcast_to(sky_top * (1 - yy) + sky_bot * yy, (H, W, 3)).copy()
    zbuf = np.full((H, W), np.inf)
    rng = np.random.default_rng(1)
    grain = rng.normal(0, 1, (H, W))

    near = 0.2
    def to_cam(p):
        d = p - cam
        return np.stack([d @ right, d @ up, d @ fwd], -1)

    tris = []  # (cam-space verts 3x3, colour, material)
    for prt in parts:
        sx, sy, sz = prt["s"]; c = prt["c"]
        pos = np.array(c[:3]); R = np.array(c[3:]).reshape(3, 3)
        if np.linalg.norm(pos - cam) - max(sx, sy, sz) > a.far:
            continue
        v, fc = MESH.get(prt["sh"], MESH["Block"])
        wv = (v * [sx, sy, sz]) @ R.T + pos
        cv = to_cam(wv)
        if (cv[:, 2] < near).all():
            continue
        col = np.array(prt["col"]); mat = prt["m"]
        if mat == "Neon":
            col = np.minimum(col * 1.3 + 0.1, 1)
        for tri in fc:
            p3 = wv[list(tri)]
            n = np.cross(p3[1] - p3[0], p3[2] - p3[0]); nl = np.linalg.norm(n)
            if nl == 0:
                continue
            n /= nl
            if np.dot(n, p3[0] - cam) > 0:  # back face
                continue
            light = 1.0 if mat == "Neon" else 0.55 + 0.6 * max(0.0, float(n @ sun)) + 0.08 * max(0.0, n[1])
            tris.append((cv[list(tri)], col * light, mat, prt.get("t", 0)))

    def clip(tv):
        # clip a camera-space triangle against the near plane -> list of triangles
        inside = [p for p in tv if p[2] >= near]
        if len(inside) == 3:
            return [tv]
        out = []
        poly = []
        for i in range(3):
            p, q = tv[i], tv[(i + 1) % 3]
            pin, qin = p[2] >= near, q[2] >= near
            if pin:
                poly.append(p)
            if pin != qin:
                t = (near - p[2]) / (q[2] - p[2])
                poly.append(p + (q - p) * t)
        for i in range(1, len(poly) - 1):
            out.append(np.array([poly[0], poly[i], poly[i + 1]]))
        return out

    aspect = W / H
    for tv, col, mat, tr in tris:
        for t in clip(tv):
            z = t[:, 2]
            px = (t[:, 0] / z * f / aspect * 0.5 + 0.5) * W
            py = (0.5 - t[:, 1] / z * f * 0.5) * H
            x0, x1 = int(max(0, np.floor(px.min()))), int(min(W - 1, np.ceil(px.max())))
            y0, y1 = int(max(0, np.floor(py.min()))), int(min(H - 1, np.ceil(py.max())))
            if x0 > x1 or y0 > y1:
                continue
            xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            d = (py[1] - py[2]) * (px[0] - px[2]) + (px[2] - px[1]) * (py[0] - py[2])
            if abs(d) < 1e-9:
                continue
            w0 = ((py[1] - py[2]) * (xs - px[2]) + (px[2] - px[1]) * (ys - py[2])) / d
            w1 = ((py[2] - py[0]) * (xs - px[2]) + (px[0] - px[2]) * (ys - py[2])) / d
            w2 = 1 - w0 - w1
            m = (w0 >= -1e-4) & (w1 >= -1e-4) & (w2 >= -1e-4)
            if not m.any():
                continue
            invz = w0 / z[0] + w1 / z[1] + w2 / z[2]
            depth = 1 / invz
            sub = zbuf[y0:y1 + 1, x0:x1 + 1]
            m &= depth < sub
            if not m.any():
                continue
            if tr > 0.05:
                # simple blend for see-through parts (no depth write)
                region = img[y0:y1 + 1, x0:x1 + 1]
                region[m] = region[m] * tr + col * (1 - tr)
                continue
            sub[m] = depth[m]
            c = np.broadcast_to(col, (*m.shape, 3)).copy()
            g = TEXTURED.get(mat)
            if g:
                c *= (1 + grain[y0:y1 + 1, x0:x1 + 1][..., None] * g)
            haze = np.clip((depth - 60) / (a.far - 60), 0, 1)[..., None] * 0.55
            c = c * (1 - haze) + sky_bot * haze
            img[y0:y1 + 1, x0:x1 + 1][m] = c[m]

    out = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))
    out.save(a.out)
    print("wrote", a.out, len(tris), "triangles")

if __name__ == "__main__":
    main()
