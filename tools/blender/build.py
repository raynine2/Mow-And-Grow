"""Build Blender models: preview render + GLB export.

    blender -b -P tools/blender/build.py -- all
    blender -b -P tools/blender/build.py -- oak birch shredder

Each tools/blender/models/<name>.py defines build(lib) (and optionally PREVIEW = dict(...) for the camera).
Outputs: assets/models/<name>.glb and assets/previews/<name>.png
"""
import importlib.util, os, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import lib  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["all"]
models_dir = os.path.join(HERE, "models")
names = sorted(f[:-3] for f in os.listdir(models_dir) if f.endswith(".py") and not f.startswith("_"))
if args and args[0] != "all":
    names = [n for n in names if n in args]
os.makedirs(os.path.join(ROOT, "assets", "models"), exist_ok=True)
os.makedirs(os.path.join(ROOT, "assets", "previews"), exist_ok=True)
skip_preview = "--no-preview" in args

for name in names:
    t0 = time.time()
    spec = importlib.util.spec_from_file_location(name, os.path.join(models_dir, name + ".py"))
    mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
    lib.reset()
    mod.build(lib)
    lib.join_by_material()
    tris = lib.stats()
    if not skip_preview:
        lib.preview(os.path.join(ROOT, "assets", "previews", name + ".png"), **getattr(mod, "PREVIEW", {}))
    lib.export_glb(os.path.join(ROOT, "assets", "models", name + ".glb"))
    mats = sorted(o.name for o in __import__("bpy").context.scene.objects if o.type == "MESH")
    print("MODEL %s: %d tris, %d meshes %s (%.1fs)" % (name, tris, len(mats), mats, time.time() - t0))
