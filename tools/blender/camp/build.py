"""Build the camp models (tools/blender/camp/models.py) into src/server/CampProps.luau, and render previews.

    <python with bpy> tools/blender/camp/build.py [--preview <out.png>] [--only name,name] [--sheet cols]

Each model becomes compact text, one line per part: shape (b block, w wedge, c cylinder, s ball; upper case when
it is turned), size x y z, position x y z, [turn x y z in degrees: CFrame.fromOrientation], material number,
[group number]. Lines "m ..." list the materials, "g name x y z" the groups (pivot in the model's own studs).
Roblox axes: x = Blender x, y = Blender z, z = -Blender y (the model's front faces -Z, the LookVector).
"""
import importlib.util, math, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
import _campkit as kit  # noqa: E402
import models  # noqa: E402

OUT = os.path.join(ROOT, "src", "server", "CampProps.luau")
M = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))
P_BOX = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
P_CYL = Matrix(((0, 1, 0), (0, 0, 1), (1, 0, 0)))


def num(v, nd=2):
    s = ("%." + str(nd) + "f") % v
    if "." in s:
        s = s.rstrip("0").rstrip(".")
    if s in ("-0", ""):
        s = "0"
    if s.startswith("0."):
        s = s[1:]
    elif s.startswith("-0."):
        s = "-" + s[2:]
    return s


def ry(a):
    c, s = math.cos(a), math.sin(a)
    return Matrix(((c, 0, s), (0, 1, 0), (-s, 0, c)))


def rx(a):
    c, s = math.cos(a), math.sin(a)
    return Matrix(((1, 0, 0), (0, c, -s), (0, s, c)))


def rz(a):
    c, s = math.cos(a), math.sin(a)
    return Matrix(((c, -s, 0), (s, c, 0), (0, 0, 1)))


def orientation(R):
    """(rx, ry, rz) in degrees with R = Ry(ry) Rx(rx) Rz(rz) (Roblox's CFrame.fromOrientation)."""
    b = math.asin(max(-1.0, min(1.0, -R[1][2])))
    if abs(math.cos(b)) > 1e-3:
        a = math.atan2(R[0][2], R[2][2])
        g = math.atan2(R[1][0], R[1][1])
    else:
        # gimbal lock (turned straight up or down): put all the yaw in ry
        a = math.atan2(-R[0][1], R[0][0]) if b < 0 else math.atan2(R[0][1], R[0][0])
        b = -math.pi / 2 if b < 0 else math.pi / 2
        g = 0.0
    out = (math.degrees(b), math.degrees(a), math.degrees(g))
    back = ry(math.radians(round(out[1], 1))) @ rx(math.radians(round(out[0], 1))) @ rz(math.radians(round(out[2], 1)))
    err = max(abs(back[i][j] - R[i][j]) for i in range(3) for j in range(3))
    assert err < 0.01, ("orientation", err, R)
    return out


def convert(name):
    kit.reset()
    models.MODELS[name](kit)
    bpy.context.view_layer.update()
    mats, gnames, lines = [], [], []
    for o in bpy.context.scene.objects:
        if o.type != "MESH" or not o.data.materials:
            continue
        mname = o.data.materials[0].name
        if mname not in mats:
            mats.append(mname)
        mi = mats.index(mname) + 1
        g = o.get("group")
        gi = 0
        if g:
            if g not in gnames:
                gnames.append(g)
            gi = gnames.index(g) + 1
        loc, quat, scale = o.matrix_world.decompose()
        rb = quat.to_matrix()
        pos = M @ loc
        prim, dims = o.get("prim"), list(o.get("dims", []))
        if prim in ("box", "wedge"):
            size = (dims[0] * scale.x, dims[2] * scale.z, dims[1] * scale.y)
            R = M @ rb @ P_BOX
            shape = "b" if prim == "box" else "w"
        elif prim == "cyl":
            r, d = dims[0] * scale.x, dims[1] * scale.z
            size = (d, r * 2, r * 2)
            R = M @ rb @ P_CYL
            shape = "c"
        elif prim == "ball":
            r = dims[0] * scale.x
            size = (r * 2, r * 2, r * 2)
            R = Matrix.Identity(3)
            shape = "s"
        else:
            raise RuntimeError("%s: %s has no primitive" % (name, o.name))
        ori = orientation(R)
        turned = any(abs(round(v, 1)) > 0.05 for v in ori)
        f = [shape.upper() if turned else shape] + [num(v) for v in size] + [num(v) for v in pos]
        if turned:
            f += [num(v, 1) for v in ori]
        f.append(str(mi))
        if gi:
            f.append(str(gi))
        lines.append(" ".join(f))
    groups = kit.groups()
    head = ["m " + " ".join(mats)]
    for g in gnames:
        p = M @ Vector(groups[g])
        head.append("g %s %s %s %s" % (g, num(p.x), num(p.y), num(p.z)))
    return "\n".join(head + lines), len(lines)


def write(texts):
    names = sorted(texts)
    body = []
    for n in names:
        txt = texts[n]
        eq = "="
        while ("]" + eq + "]") in txt:
            eq += "="
        body.append("\t%s = [%s[\n%s\n]%s]," % (n, eq, txt, eq))
    with open(os.path.join(HERE, "CampProps.template.luau"), encoding="utf-8") as f:
        tpl = f.read()
    out = tpl.replace("--@@DATA@@", "\n".join(body))
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(out)


def preview(path, names, cols=6, gap=26.0, size=(1500, 950), samples=16, yaw=30, dist=None, height=None):
    kit.reset()
    for i, n in enumerate(names):
        before = set(bpy.context.scene.objects)
        models.MODELS[n](kit)
        new = [o for o in bpy.context.scene.objects if o not in before]
        e = bpy.data.objects.new("grp_" + n, None)
        bpy.context.scene.collection.objects.link(e)
        e.location = ((i % cols) * gap, -(i // cols) * gap, 0)
        for o in new:
            o.parent = e
    bpy.context.view_layer.update()
    sc = bpy.context.scene
    mins = Vector((1e9, 1e9, 1e9))
    maxs = Vector((-1e9, -1e9, -1e9))
    for o in sc.objects:
        if o.type == "MESH" and not o.hide_render:
            for c in o.bound_box:
                w = o.matrix_world @ Vector(c)
                mins = Vector(map(min, mins, w))
                maxs = Vector(map(max, maxs, w))
    centre = (mins + maxs) / 2
    ext = (maxs - mins).length
    ground = kit.box("__ground", (ext * 4, ext * 4, 0.2), (centre.x, centre.y, -0.1), m=kit.mat("Grass", (96, 160, 60)))
    cam_d = bpy.data.cameras.new("cam")
    cam_d.lens = 38
    cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam)
    d = dist or ext * 0.95
    a = math.radians(yaw)
    cam.location = (centre.x + math.sin(a) * d, centre.y + math.cos(a) * d, height if height is not None else ext * 0.55)
    cam.rotation_euler = (Vector((centre.x, centre.y, 2)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sun_d = bpy.data.lights.new("sun", "SUN")
    sun_d.energy = 4.0
    sun_d.angle = math.radians(5)
    sun = bpy.data.objects.new("sun", sun_d)
    sc.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(45), 0, math.radians(150))
    world = bpy.data.worlds.new("w")
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.55, 0.72, 1.0, 1)
    bg.inputs["Strength"].default_value = 1.0
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Medium High Contrast"
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def tile(path, name, size=(520, 400), samples=12, yaw=35, elev=24, roles=None):
    """One model alone, framed on its bounding box from a 3/4 front view."""
    kit.reset()
    if roles:
        kit.PREVIEW_ROLES.update(roles)
    models.MODELS[name](kit)
    bpy.context.view_layer.update()
    sc = bpy.context.scene
    mins = Vector((1e9, 1e9, 1e9))
    maxs = Vector((-1e9, -1e9, -1e9))
    for o in sc.objects:
        if o.type == "MESH" and not o.hide_render:
            for c in o.bound_box:
                w = o.matrix_world @ Vector(c)
                mins = Vector(map(min, mins, w))
                maxs = Vector(map(max, maxs, w))
    centre = (mins + maxs) / 2
    ext = max((maxs - mins).length, 1.5)
    kit.box("__ground", (ext * 8, ext * 8, 0.2), (centre.x, centre.y, -0.1), m=kit.mat("Grass", (96, 160, 60)))
    cam_d = bpy.data.cameras.new("cam")
    cam_d.lens = 50
    cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam)
    d = ext * 1.45
    a, e = math.radians(yaw), math.radians(elev)
    cam.location = (centre.x + math.sin(a) * math.cos(e) * d, centre.y + math.cos(a) * math.cos(e) * d, centre.z + math.sin(e) * d)
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sun_d = bpy.data.lights.new("sun", "SUN")
    sun_d.energy = 4.0
    sun_d.angle = math.radians(5)
    sun = bpy.data.objects.new("sun", sun_d)
    sc.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(45), 0, math.radians(150))
    world = bpy.data.worlds.new("w")
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.55, 0.72, 1.0, 1)
    bg.inputs["Strength"].default_value = 1.0
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Medium High Contrast"
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
only = None
prev = None
tiles = None
cols = 6
i = 0
while i < len(args):
    if args[i] == "--only":
        only = args[i + 1].split(",")
        i += 2
    elif args[i] == "--preview":
        prev = args[i + 1]
        i += 2
    elif args[i] == "--tiles":
        tiles = args[i + 1]
        i += 2
    elif args[i] == "--cols":
        cols = int(args[i + 1])
        i += 2
    else:
        i += 1
names = only or list(models.MODELS)
if tiles:
    os.makedirs(tiles, exist_ok=True)
    for n in names:
        tile(os.path.join(tiles, n + ".png"), n)
        print("TILE", n)
elif prev:
    preview(prev, names, cols=cols)
    print("PREVIEW", prev)
else:
    texts, total = {}, 0
    for n in models.MODELS:
        texts[n], c = convert(n)
        total += c
        print("%-18s %4d parts %6d chars" % (n, c, len(texts[n])))
    write(texts)
    print("TOTAL %d parts, %d chars -> %s" % (total, sum(len(t) for t in texts.values()), OUT))
