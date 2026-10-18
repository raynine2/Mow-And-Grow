"""Preview the R15 animations from tools/anim/make_anims.luau on a box mannequin.

    lune run tools/anim/make_anims.luau                    # writes assets/anims/*.json (+ .rbxm)
    blender -b -P tools/anim/preview_anim.py -- [names]    # renders assets/previews/anim_<name>.png

Each sheet is a strip of 8 moments across the animation, seen from the side (top row) and from the front 3/4
(bottom row). The mannequin uses the same R15 joints (C0/C1) as the generator (assets/anims/rig.json) and plays the
baked keyframes exactly as Roblox does: part1 = part0 * C0 * Pose.CFrame * C1^-1. Right-side limbs are lighter than
left-side ones so you can tell them apart. The floor has stripes 1 stud apart.

Blender renders the frames; the sheet is put together by plain python3 (Pillow), which this script runs itself.
"""
import json, os, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ANIMS = os.path.join(ROOT, "assets", "anims")
PREVIEWS = os.path.join(ROOT, "assets", "previews")
FRAMES = 8
TILE = (300, 380)
VIEWS = ("side", "3/4")

COLORS = {
    "Head": (1.0, 0.80, 0.25), "UpperTorso": (0.20, 0.62, 0.95), "LowerTorso": (0.12, 0.40, 0.70),
    "RightUpperArm": (1.0, 0.80, 0.25), "RightLowerArm": (1.0, 0.80, 0.25), "RightHand": (1.0, 0.86, 0.40),
    "LeftUpperArm": (0.75, 0.55, 0.15), "LeftLowerArm": (0.75, 0.55, 0.15), "LeftHand": (0.80, 0.62, 0.25),
    "RightUpperLeg": (0.35, 0.80, 0.35), "RightLowerLeg": (0.35, 0.80, 0.35), "RightFoot": (0.95, 0.95, 0.95),
    "LeftUpperLeg": (0.16, 0.45, 0.18), "LeftLowerLeg": (0.16, 0.45, 0.18), "LeftFoot": (0.45, 0.45, 0.48),
}


# ----------------------------------------------------------------------------------------------------------
# pose maths (numpy only, so it also runs outside Blender)
# ----------------------------------------------------------------------------------------------------------
def load(name):
    with open(os.path.join(ANIMS, name + ".json")) as f:
        return json.load(f)


def mat(c):
    import numpy as np
    x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = c
    return np.array([[r00, r01, r02, x], [r10, r11, r12, y], [r20, r21, r22, z], [0, 0, 0, 1.0]])


def trans(v):
    import numpy as np
    m = np.eye(4)
    m[:3, 3] = v
    return m


def quat(m):
    import numpy as np
    t = np.trace(m[:3, :3])
    if t > 0:
        s = np.sqrt(t + 1.0) * 2
        q = [0.25 * s, (m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s]
    else:
        i = int(np.argmax([m[0, 0], m[1, 1], m[2, 2]]))
        j, k = (i + 1) % 3, (i + 2) % 3
        s = np.sqrt(1.0 + m[i, i] - m[j, j] - m[k, k]) * 2
        q = [0.0] * 4
        q[0] = (m[k, j] - m[j, k]) / s
        q[1 + i] = 0.25 * s
        q[1 + j] = (m[j, i] + m[i, j]) / s
        q[1 + k] = (m[k, i] + m[i, k]) / s
    return np.array(q)


def quat_mat(q):
    import numpy as np
    w, x, y, z = q / np.linalg.norm(q)
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def lerp_pose(a, b, s):
    """CFrame:Lerp: straight line for the offset, slerp for the rotation."""
    import numpy as np
    qa, qb = quat(a), quat(b)
    if np.dot(qa, qb) < 0:
        qb = -qb
    d = min(1.0, max(-1.0, float(np.dot(qa, qb))))
    th = np.arccos(d)
    q = qa if th < 1e-6 else (np.sin((1 - s) * th) * qa + np.sin(s * th) * qb) / np.sin(th)
    m = np.eye(4)
    m[:3, :3] = quat_mat(q)
    m[:3, 3] = a[:3, 3] + (b[:3, 3] - a[:3, 3]) * s
    return m


def sample(anim, t):
    kfs = anim["keyframes"]
    i = 0
    while i < len(kfs) - 2 and kfs[i + 1]["t"] <= t:
        i += 1
    a, b = kfs[i], kfs[i + 1]
    s = 0.0 if b["t"] == a["t"] else min(1.0, max(0.0, (t - a["t"]) / (b["t"] - a["t"])))
    return {part: lerp_pose(mat(a["poses"][part]), mat(b["poses"][part]), s) for part in a["poses"]}


def world(rig, poses):
    import numpy as np
    cf = {"HumanoidRootPart": trans([0, rig["root_height"], 0])}
    for j in rig["joints"]:
        cf[j["part"]] = cf[j["parent"]] @ trans(j["c0"]) @ poses[j["part"]] @ np.linalg.inv(trans(j["c1"]))
    return cf


def times(anim):
    n, L = FRAMES, anim["length"]
    return [L * i / n for i in range(n)] if anim["loop"] else [L * i / (n - 1) for i in range(n)]


# ----------------------------------------------------------------------------------------------------------
# Blender side
# ----------------------------------------------------------------------------------------------------------
def build_scene(rig):
    import bpy
    from mathutils import Matrix
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    # Cycles on the CPU (headless servers have no GPU for Eevee/Workbench); few samples + denoising is plenty
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 10
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 2
    scene.render.resolution_x, scene.render.resolution_y = TILE
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.72, 0.9, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    scene.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 2.6
    sun.data.angle = 0.2
    sun.rotation_euler = (0.75, 0.25, 0.9)
    scene.collection.objects.link(sun)
    # one material that takes each object's colour
    mat = bpy.data.materials.new("obj")
    mat.use_nodes = True
    nt = mat.node_tree
    info = nt.nodes.new("ShaderNodeObjectInfo")
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.55
    nt.links.new(info.outputs["Color"], bsdf.inputs["Base Color"])

    def box(name, size, centre, colour, parent_space=None):
        sx, sy, sz = (v / 2 for v in size)
        cx, cy, cz = centre
        verts = [(cx + x * sx, cy + y * sy, cz + z * sz) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
        faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        me = bpy.data.meshes.new(name)
        me.from_pydata(verts, [], faces)
        ob = bpy.data.objects.new(name, me)
        ob.color = (*colour, 1)
        me.materials.append(mat)
        bev = ob.modifiers.new("b", "BEVEL")
        bev.width = 0.06
        bev.segments = 2
        scene.collection.objects.link(ob)
        return ob

    parts = {}
    for j in rig["joints"]:
        w, h, d, cy, cz = j["box"]
        parts[j["part"]] = [box(j["part"], (w, h, d), (0, cy, cz), COLORS[j["part"]])]
    # a face, so you can see where the head points (Roblox front = -Z)
    head = parts["Head"]
    for x in (-0.24, 0.24):
        head.append(box("eye", (0.16, 0.3, 0.06), (x, 0.24, -0.63), (0.1, 0.1, 0.12)))
    head.append(box("mouth", (0.5, 0.08, 0.06), (0, -0.12, -0.63), (0.45, 0.2, 0.15)))

    # floor with stripes every stud (Blender: z up; Roblox -Z forward = Blender +Y)
    floor = box("floor", (30, 0.2, 30), (0, -0.1, 0), (0.45, 0.72, 0.35))
    floor.matrix_world = to_blender()
    for i in range(-12, 13):
        s = box("stripe", (30, 0.02, 0.12), (0, 0.005, i), (0.36, 0.6, 0.28))
        s.matrix_world = to_blender()

    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 7.2
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    return scene, parts, cam


def to_blender():
    from mathutils import Matrix
    # Roblox (x, y, z) -> Blender (x, -z, y)
    return Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def place_camera(cam, view):
    from mathutils import Vector
    target = Vector((0, 0, 2.55))
    pos = Vector((14, 0, 4.2)) if view == "side" else Vector((9.5, 10.5, 5.5))
    cam.location = pos
    cam.rotation_euler = (target - pos).to_track_quat("-Z", "Y").to_euler()


def render(names):
    import bpy
    from mathutils import Matrix
    with open(os.path.join(ANIMS, "rig.json")) as f:
        rig = json.load(f)
    scene, parts, cam = build_scene(rig)
    tmp = tempfile.mkdtemp(prefix="animprev_")
    for name in names:
        anim = load(name)
        for vi, view in enumerate(VIEWS):
            place_camera(cam, view)
            for fi, t in enumerate(times(anim)):
                cf = world(rig, sample(anim, t))
                for part, objs in parts.items():
                    m = to_blender() @ Matrix(cf[part].tolist())
                    for ob in objs:
                        ob.matrix_world = m
                scene.render.filepath = os.path.join(tmp, "%s_%d_%d.png" % (name, vi, fi))
                bpy.ops.render.render(write_still=True)
    return tmp


# ----------------------------------------------------------------------------------------------------------
# sheet (plain python3 + Pillow)
# ----------------------------------------------------------------------------------------------------------
def compose(tmp, names):
    from PIL import Image, ImageDraw, ImageFont
    try:
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", 18)
        small = ImageFont.truetype("DejaVuSans.ttf", 15)
    except OSError:
        font = small = ImageFont.load_default()
    w, h = TILE
    for name in names:
        anim = load(name)
        ts = times(anim)
        head = 40
        sheet = Image.new("RGB", (w * FRAMES, head + h * len(VIEWS)), (30, 34, 40))
        d = ImageDraw.Draw(sheet)
        d.text((10, 10), "%s   %.2f s %s" % (name, anim["length"], "loop" if anim["loop"] else "once"),
               fill=(255, 255, 255), font=font)
        for vi, view in enumerate(VIEWS):
            for fi, t in enumerate(ts):
                tile = Image.open(os.path.join(tmp, "%s_%d_%d.png" % (name, vi, fi))).convert("RGB")
                sheet.paste(tile, (fi * w, head + vi * h))
                d.text((fi * w + 8, head + vi * h + 6), "%s  t=%.2f" % (view, t), fill=(20, 30, 40), font=small)
        out = os.path.join(PREVIEWS, "anim_%s.png" % name)
        sheet.save(out)
        print("wrote", os.path.relpath(out, ROOT))


def all_names():
    return sorted(f[:-5] for f in os.listdir(ANIMS) if f.endswith(".json") and f != "rig.json")


if __name__ == "__main__":
    try:
        import bpy  # noqa: F401
        in_blender = True
    except ImportError:
        in_blender = False
    if in_blender:
        args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
        names = args or all_names()
        tmp = render(names)
        subprocess.check_call(["python3", os.path.abspath(__file__), "--compose", tmp] + names)
    elif len(sys.argv) > 2 and sys.argv[1] == "--compose":
        compose(sys.argv[2], sys.argv[3:])
    else:
        sys.exit("run me with Blender: blender -b -P tools/anim/preview_anim.py -- [names]")
