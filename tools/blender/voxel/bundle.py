"""The grass bundle (the cut grass you carry on your back and that drops on the ground), as voxel models in the
world's style (the owner, 27 Oct: "make it voxel like we have in the game, don't make it feel rubbish, make it
unique").

A sheaf of cut grass lying on its side: the stems run along X, packed in an oval, each stem its own streak of green;
one end is cut flat (pale cut stems with dark centres), the other fans out into blade tips; two straw-twine bands with
a knot and dangling ends on the front, and a few loose blades sticking up. One mesh per grass mutation (the normal
grass, Golden, Rainbow, Diamond, Toxic, Galaxy), all on one small atlas, so a golden bundle really looks golden.

    <blender python> tools/blender/voxel/bundle.py <out_dir> [--render]

Outputs: MowBundles.fbx (meshes Bundle_None, Bundle_Golden, ...), MowBundlesAtlas.png, sizes.luau (lines for
src/shared/ModelSizes.luau), preview.png. Import MowBundles.fbx into Studio (Import 3D) and put the meshes in
ServerStorage.VoxelModels; server/Carry and server/Loot use them from then on (the older bundle model until then).
"""
import math
import os
import random
import sys

import bpy
import mathutils

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
OUT = os.path.abspath(args[0] if args else "/tmp/bundles")
RENDER = "--render" in args
os.makedirs(OUT, exist_ok=True)

VS = 0.125  # studs per voxel: the bundle is 19 voxels long (about 2.4 studs)
L = 19  # stems run x = 0 .. L-1; the tips fan out past x = 0
RY, RZ = 4.6, 5.6  # the oval's half height / half depth (voxels)
CY, CZ = 5, 0  # its middle (the bottom is flattened a little so it sits)
BANDS = (4, 13)  # twine bands (x)

# palettes per mutation: stems (3 shades), tips, cut end, cut centre, twine (2), knot; extra sparkle colour
PALETTES = {
    "None": dict(stems=[(62, 140, 38), (84, 166, 48), (104, 184, 58), (52, 122, 32)], tips=[(124, 196, 66), (104, 180, 56)], daisy=True, cut=(176, 206, 104), core=(120, 160, 60), twine=[(226, 178, 86), (196, 146, 64)], knot=(176, 122, 50)),
    "Golden": dict(stems=[(236, 186, 40), (250, 208, 70), (214, 160, 30)], tips=[(255, 236, 140), (255, 224, 100)], cut=(255, 246, 190), core=(206, 150, 30), twine=[(150, 92, 40), (124, 74, 32)], knot=(104, 62, 26), sparkle=(255, 255, 230)),
    "Rainbow": dict(stems=[(255, 110, 170), (255, 186, 80), (120, 210, 255)], tips=[(190, 140, 255), (140, 240, 140)], cut=(255, 240, 250), core=(255, 140, 200), twine=[(255, 255, 255), (230, 230, 240)], knot=(200, 200, 216), sparkle=(255, 255, 255)),
    "Diamond": dict(stems=[(140, 228, 255), (186, 244, 255), (100, 200, 240)], tips=[(230, 252, 255), (200, 246, 255)], cut=(250, 255, 255), core=(90, 180, 230), twine=[(90, 120, 160), (70, 96, 130)], knot=(56, 76, 110), sparkle=(255, 255, 255)),
    "Toxic": dict(stems=[(150, 255, 40), (120, 230, 30), (180, 255, 90)], tips=[(210, 255, 120), (110, 255, 60)], cut=(230, 255, 160), core=(80, 170, 20), twine=[(90, 60, 120), (70, 46, 96)], knot=(56, 36, 80), sparkle=(230, 255, 140)),
    "Galaxy": dict(stems=[(110, 60, 230), (140, 80, 255), (80, 44, 190)], tips=[(200, 150, 255), (120, 200, 255)], cut=(236, 214, 255), core=(70, 30, 160), twine=[(255, 210, 90), (226, 176, 60)], knot=(196, 140, 40), sparkle=(255, 255, 255)),
}


def inside(y, z, grow=0.0):
    """Is (y, z) inside the bundle's oval (grown by `grow` voxels)? The bottom row is flattened."""
    dy = (y + 0.5 - (CY + 0.5)) / (RY + grow)
    dz = (z + 0.5 - (CZ + 0.5)) / (RZ + grow)
    return dy * dy + dz * dz <= 1.0 and y >= 0


def bundle(name):
    p = PALETTES[name]
    pal = []

    def idx(c):
        if c not in pal:
            pal.append(c)
        return pal.index(c)

    rng = random.Random(7)
    vox = {}
    zr = int(math.ceil(RZ + 2))
    yr = int(math.ceil(CY + RY + 2))
    # each stem (a (y, z) cell of the oval) has its own shade and a slightly different cut length
    stems = {}
    for y in range(0, yr):
        for z in range(-zr, zr + 1):
            if inside(y, z):
                stems[(y, z)] = (idx(rng.choice(p["stems"])), rng.randint(0, 1))
    for (y, z), (ci, short) in stems.items():
        for x in range(0, L - short):
            vox[(x, y, z)] = ci
        # the cut end: pale stems with darker centres in a ring pattern, a few short of the face
        end = L - 1 - short
        ring = ((y - CY) ** 2 + (z - CZ) ** 2) % 3 == 0
        vox[(end, y, z)] = idx(p["core"] if ring else p["cut"])
    # the tips: past x = 0 the stems fan outward (further from the middle = further out), 1 to 4 voxels
    for (y, z), (ci, _) in stems.items():
        oy, oz = y - CY, z - CZ
        d = math.hypot(oy / RY, oz / RZ)
        n = rng.randint(1, 2) + (1 if d > 0.6 else 0)
        # each tip is one unbroken blade: it moves at most one voxel sideways per voxel out
        ty, tz = oy / RY * n * 0.9, oz / RZ * n * 0.9
        for k in range(1, n + 1):
            fy = y + round(ty * k / n)
            fz = z + round(tz * k / n)
            if fy < 0:
                continue
            vox[(-k, fy, fz)] = idx(rng.choice(p["tips"]) if k >= n - 1 else rng.choice(p["stems"]))
    # the twine bands: a ring one voxel proud of the oval, two voxels wide, rope-striped
    for bx in BANDS:
        for x in (bx, bx + 1):
            for y in range(0, yr + 1):
                for z in range(-zr - 1, zr + 2):
                    if inside(y, z, 0.9) and not inside(y, z):
                        vox[(x, y, z)] = idx(p["twine"][(x + y + z) % 2])
    # the knot on the front of the second band (front = -Z), with two dangling ends
    kx = BANDS[1]
    zf = min(z for (y, z) in stems if y == CY) - 2
    for dx in (-1, 0, 1, 2):
        for dy in (0, 1):
            vox[(kx + dx, CY + dy, zf)] = idx(p["knot"] if dx in (0, 1) else p["twine"][0])
    for dy, dx in ((-1, -1), (-2, -1), (-3, -2), (-1, 2), (-2, 3)):
        vox[(kx + dx, CY + dy, zf)] = idx(p["twine"][1])
    # a daisy tucked under the twine by the knot (the plain grass only: the special ones sparkle instead)
    if p.get("daisy"):
        dx0, dy0 = BANDS[1] - 3, CY + 2
        for a, b in ((0, 1), (1, 0), (-1, 0), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
            vox[(dx0 + a, dy0 + b, zf + 1)] = idx((255, 255, 255) if abs(a) + abs(b) == 1 else (236, 236, 228))
        vox[(dx0, dy0, zf)] = idx((255, 206, 40))
        vox[(dx0 + 1, dy0 - 2, zf + 1)] = idx((80, 160, 50))
    # a few loose blades poking up out of the top (bent towards the tips)
    ytop = max(y for (y, z) in stems)
    for bx, bz, h, lean in ((2, -1, 3, -1), (7, 2, 2, -1), (16, -2, 2, 0), (10, 0, 3, -1)):
        for k in range(1, h + 1):
            vox[(bx + (lean if k == h else 0), ytop + k, bz)] = idx(rng.choice(p["tips"]))
    # sparkles for the special grass: a few bright voxels set into the surface
    if "sparkle" in p:
        surface = [q for q in vox if any((q[0] + a, q[1] + b, q[2] + c) not in vox for a, b, c in ((0, 1, 0), (0, 0, 1), (0, 0, -1)))]
        for q in rng.sample(surface, min(14, len(surface))):
            vox[q] = idx(p["sparkle"])
    return vox, pal


kit.clear_scene()
atlas = kit.Atlas(grid=16, px=32)
objects, sizes = {}, {}
for name in PALETTES:
    vox, pal = bundle(name)
    obj, size = kit.build_shared("Bundle_" + name, vox, pal, atlas, voxel_size=VS)
    objects[obj.name] = obj
    sizes[obj.name] = size
    print(f"{obj.name:16s} voxels {len(vox):5d} tris {len(obj.data.polygons) * 2:5d} size {size[0]:.2f} x {size[1]:.2f} x {size[2]:.2f}")
img = atlas.image("MowBundlesAtlas", os.path.join(OUT, "MowBundlesAtlas.png"))
mat = kit.shared_material(img, "MowBundlesAtlas")
for obj in objects.values():
    obj.data.materials.append(mat)

bpy.ops.object.select_all(action="DESELECT")
for obj in objects.values():
    obj.select_set(True)
bpy.ops.export_scene.fbx(
    filepath=os.path.join(OUT, "MowBundles.fbx"),
    use_selection=True,
    apply_unit_scale=True,
    global_scale=1.0,
    axis_forward="-Z",
    axis_up="Y",
    path_mode="COPY",
    embed_textures=True,
    mesh_smooth_type="FACE",
    object_types={"MESH"},
)
with open(os.path.join(OUT, "sizes.luau"), "w") as f:
    for n, (x, y, z) in sizes.items():
        f.write(f"\t{n} = Vector3.new({x:.2f}, {y:.2f}, {z:.2f}),\n")

if RENDER:
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.device = "CPU"
    scene.render.resolution_x, scene.render.resolution_y = 1400, 520
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("w")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.82, 0.9, 0.96, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.45
    x = 0.0
    for n, obj in objects.items():
        obj.location = (x, 0, 0)
        x += sizes[n][0] + 0.9
    # a little stack of three, as on a player's back
    for k in range(3):
        o = objects["Bundle_None"].copy()
        o.data = objects["Bundle_None"].data
        scene.collection.objects.link(o)
        o.location = (x + 0.6, 0, k * sizes["Bundle_None"][1] * 0.92)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = x + 4
    mid = mathutils.Vector(((x + 2) / 2 - 1, 0, 0.9))
    cam.location = mid + mathutils.Vector((3.5, -9, 6))
    cam.rotation_euler = (mid - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.2
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-30))
    scene.collection.objects.link(sun)
    scene.render.filepath = os.path.join(OUT, "preview.png")
    bpy.ops.render.render(write_still=True)
    # close-ups of the plain bundle: its knot side (-Z in voxels = Blender +Y) and its cut end
    o = objects["Bundle_None"]
    for other in scene.objects:
        if other.type == "MESH":
            other.hide_render = other != o
    scene.render.resolution_x, scene.render.resolution_y = 900, 600
    cam.data.ortho_scale = 4.2
    c = o.location + mathutils.Vector((0, 0, 0.8))
    for tag, off in (("knot", (2.5, 9, 4)), ("cut", (9, -3, 3.5)), ("back", (-3, -9, 4))):
        cam.location = c + mathutils.Vector(off)
        cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(OUT, "close_" + tag + ".png")
        bpy.ops.render.render(write_still=True)
print("done", OUT)
