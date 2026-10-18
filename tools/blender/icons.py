"""Render UI icons (3D, transparent background) for the HUD and menus.

    blender -b -P tools/blender/icons.py -- all        (or icon names)

Each tools/blender/icons/<name>.py defines build(lib) and optional VIEW = dict(yaw=, pitch=, zoom=).
An icon may instead reuse a model: MODEL = "tool_scissors" (built from tools/blender/models/<model>.py).
Output: assets/icons/<name>.png (256x256, transparent).
"""
import importlib.util, math, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
import lib  # noqa: E402
from mathutils import Vector  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["all"]
icons_dir = os.path.join(HERE, "icons")
names = sorted(f[:-3] for f in os.listdir(icons_dir) if f.endswith(".py") and not f.startswith("_"))
if args and args[0] != "all":
    names = [n for n in names if n in args]
out_dir = os.path.join(ROOT, "assets", "icons")
os.makedirs(out_dir, exist_ok=True)

def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
    return mod

for name in names:
    mod = load(os.path.join(icons_dir, name + ".py"), name)
    lib.reset()
    if getattr(mod, "MODEL", None):
        load(os.path.join(HERE, "models", mod.MODEL + ".py"), mod.MODEL).build(lib)
    else:
        mod.build(lib)
    view = dict(yaw=25, pitch=20, zoom=1.0, roll=0); view.update(getattr(mod, "VIEW", {}))
    sc = bpy.context.scene
    bpy.context.view_layer.update()  # make matrix_world current before measuring
    mins = Vector((1e9,) * 3); maxs = Vector((-1e9,) * 3)
    for o in sc.objects:
        if o.type == "MESH":
            for c in o.bound_box:
                w = o.matrix_world @ Vector(c); mins = Vector(map(min, mins, w)); maxs = Vector(map(max, maxs, w))
    centre = (mins + maxs) / 2; radius = (maxs - mins).length / 2
    cam_d = bpy.data.cameras.new("cam"); cam_d.type = "ORTHO"; cam_d.ortho_scale = radius * 2.05 / view["zoom"]
    cam = bpy.data.objects.new("cam", cam_d); sc.collection.objects.link(cam)
    yaw, pitch = math.radians(view["yaw"]), math.radians(view["pitch"])
    d = radius * 4
    cam.location = centre + Vector((math.sin(yaw) * math.cos(pitch) * d, -math.cos(yaw) * math.cos(pitch) * d, math.sin(pitch) * d))
    rot = (centre - cam.location).to_track_quat("-Z", "Y").to_euler(); rot.rotate_axis("Z", math.radians(view["roll"]))
    cam.rotation_euler = rot
    sc.camera = cam
    key = bpy.data.lights.new("key", "SUN"); key.energy = 3.4; key.angle = math.radians(8)
    k = bpy.data.objects.new("key", key); sc.collection.objects.link(k)
    k.rotation_euler = (math.radians(35), math.radians(-25), math.radians(-30))
    fill = bpy.data.lights.new("fill", "SUN"); fill.energy = 1.2
    f = bpy.data.objects.new("fill", fill); sc.collection.objects.link(f)
    f.rotation_euler = (math.radians(60), math.radians(40), math.radians(150))
    world = bpy.data.worlds.new("w"); sc.world = world; world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.8, 0.85, 1, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
    sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 48; sc.cycles.use_denoising = True
    sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = 256
    sc.view_settings.view_transform = "Standard"; sc.view_settings.look = "Medium High Contrast"
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.filepath = os.path.join(out_dir, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("ICON", name)
