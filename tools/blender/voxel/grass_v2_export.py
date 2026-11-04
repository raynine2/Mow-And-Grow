"""Export the second-look grass clumps (grass_v2) for building in Studio, no Blender needed:
    python3 grass_v2_export.py <out_dir>
writes <out_dir>/grass_v2.json (every clump's faces, in the column-run style of kit.build_columns) and
<out_dir>/grass_v2_atlas.png (the colour tiles, each with kit.Atlas's lit rim and soft centre).

The json: { "atlas": { "grid": 16 }, "clumps": { "Clump_<area>_<n>": { "voxel": 0.4, "min": [x, y, z],
"max": [x, y, z], "faces": [[face, x, y0, z, y1, tile], ...] } } }, face 0..5 = +x, -x, +y, -y, +z, -z (kit.FACES order).
Coordinates are voxels; a run fills x..x+1, y0..y1, z..z+1. The stalk is the 3 x 3 column at x, z = -1..1.
Studio builds the meshes from it (an EditableMesh per clump, uploaded with AssetService:CreateAssetAsync).
"""
import json
import os
import struct
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import grass_v2  # noqa: E402

OUT = os.path.abspath(sys.argv[1])
os.makedirs(OUT, exist_ok=True)
SEEDS = (31, 62)  # Clump_<area>_1 and _2 (models.catalogue uses seed s * 31)
GRID, PX = 16, 32


class Atlas:
    def __init__(self):
        self.index = {}

    def tile(self, rgb):
        rgb = tuple(int(max(0, min(255, c))) for c in rgb)
        if rgb not in self.index:
            self.index[rgb] = len(self.index)
            if len(self.index) > GRID * GRID:
                raise RuntimeError("atlas full")
        return self.index[rgb]

    def png(self, path):
        w = GRID * PX
        rows = []
        cells = {i: rgb for rgb, i in self.index.items()}
        for py in range(w):
            row = bytearray([0])
            # png rows run top to bottom; tile row 0 is at the top (v = 1 - ...) handled in Studio's uvs
            ty, y = py // PX, py % PX
            for px in range(w):
                tx, x = px // PX, px % PX
                rgb = cells.get(ty * GRID + tx, (0, 0, 0))
                edge = min(x, y, PX - 1 - x, PX - 1 - y)
                k = 1.13 if edge < 2 else (1.05 if edge < 4 else (0.98 if edge > 9 else 1.0))
                row += bytes(min(255, int(c * k)) for c in rgb)
            rows.append(bytes(row))
        raw = b"".join(rows)

        def chunk(t, d):
            return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

        png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, w, 8, 2, 0, 0, 0))
        png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
        open(path, "wb").write(png)


NORMALS = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)]


def faces_of(vox, tiles):
    """kit.build_columns' runs and visible faces."""
    ys = [p[1] for p in vox]
    oy = min(ys)
    cols = {}
    for (x, y, z), ci in vox.items():
        cols.setdefault((x, z), []).append((y, ci))
    runs = []
    for (x, z), items in cols.items():
        items.sort()
        start, prev, pci = items[0][0], items[0][0], items[0][1]
        for y, ci in items[1:] + [(None, None)]:
            if y is not None and y == prev + 1 and ci == pci:
                prev = y
                continue
            runs.append((x, start, z, prev + 1, pci))
            if y is not None:
                start, prev, pci = y, y, ci
    out = []
    for (x, y0, z, y1, ci) in runs:
        for f, n in enumerate(NORMALS):
            if n == (0, -1, 0) and ((x, y0 - 1, z) in vox or y0 == oy):
                continue
            if n == (0, 1, 0) and (x, y1, z) in vox:
                continue
            if n[1] == 0 and all((x + n[0], y, z + n[2]) in vox for y in range(y0, y1)):
                continue
            out.append([f, x, y0, z, y1, tiles[ci]])
    return out


atlas = Atlas()
data = {"atlas": {"grid": GRID}, "clumps": {}}
for area in grass_v2.AREAS:
    for n, seed in enumerate(SEEDS, 1):
        vox, pal, vs = grass_v2.clump2(seed=seed, area=area)
        tiles = [atlas.tile(c) for c in pal]
        faces = faces_of(vox, tiles)
        xs, ys, zs = [p[0] for p in vox], [p[1] for p in vox], [p[2] for p in vox]
        name = f"Clump_{area}_{n}"
        data["clumps"][name] = {"voxel": vs, "min": [min(xs), min(ys), min(zs)], "max": [max(xs) + 1, max(ys) + 1, max(zs) + 1], "faces": faces}
        size = [(max(xs) + 1 - min(xs)) * vs, (max(ys) + 1 - min(ys)) * vs, (max(zs) + 1 - min(zs)) * vs]
        print(f"{name:20s} voxels {len(vox):5d} faces {len(faces):5d} tris {len(faces) * 2:5d} size {size[0]:.2f} x {size[1]:.2f} x {size[2]:.2f}")
atlas.png(os.path.join(OUT, "grass_v2_atlas.png"))
json.dump(data, open(os.path.join(OUT, "grass_v2.json"), "w"), separators=(",", ":"))
print("tiles", len(atlas.index), "json bytes", os.path.getsize(os.path.join(OUT, "grass_v2.json")))
