"""Builds one toy model (tools/blender/toy/models/<Name>.py), renders it front + back, makes a compare sheet with
its reference picture, and with --export bakes the Roblox mesh into assets/toy_models/.

    blender -b --factory-startup -P tools/blender/toy/run_toy.py -- <Name> [--export] [--ref <png>] [--out <dir>]

Method by fwjelaa (FWJ STUDIOS); see toykit.py.
"""
import importlib.util
import os
import sys
import time
import traceback

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
import toykit as k  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
name = args[0]
do_export = "--export" in args
ref = args[args.index("--ref") + 1] if "--ref" in args else os.path.join(HERE, "ref", f"{name}.png")
out = args[args.index("--out") + 1] if "--out" in args else os.path.join(REPO, "tmp_toy")
t0 = time.time()
try:
    os.makedirs(out, exist_ok=True)
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, "models", f"{name}.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    coll = mod.build(k)
    h = getattr(mod, "HEIGHT", 4.2)
    cam = k.studio(h)
    front = k.render(os.path.join(out, f"{name}_front.png"))
    k.view(cam, h, (0.75, 1, 0.25))
    back = k.render(os.path.join(out, f"{name}_back.png"))
    k.view(cam, h, (-0.42, -1, 0.2))
    k.compare([ref, front, back], os.path.join(out, f"compare_{name}.png"))
    stats = None
    if do_export:
        stats = k.export(coll, name, os.path.join(REPO, "assets", "toy_models"), height=h,
                         tri_budget=getattr(mod, "BUDGET", 16000), tex_size=getattr(mod, "TEX", 1024),
                         preview_path=os.path.join(out, f"{name}_baked.png"))
    print(f"TOY_OK {name} {round(time.time() - t0, 1)}s {stats or ''}")
except Exception:
    traceback.print_exc()
    print(f"TOY_FAIL {name}")
    sys.exit(1)
