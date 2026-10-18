"""Render a hit effect (src/shared/FxPresets.json) frame by frame in Blender, from the player's first-person view,
so it can be judged without Studio. It re-creates what client/HitFx + ViewModel do:

- particle layers: emitted at the impact, moved with Speed / SpreadAngle / Drag / Acceleration, drawn as
  camera-facing (or velocity-aligned) cards with their texture, flipbook frame, Size / Transparency / Color
  over life, LightEmission (additive) blending and ZOffset;
- clippings: the Blender fx_clip models thrown with Roblox gravity (196.2 studs/s^2) and bounced on the ground;
- the clump: white Highlight flash and wobble; the camera FOV kick; the glove hand's jab with the hit-stop.

    blender -b -P tools/preview/fx_sim.py -- punch out.png [--tuft tuft_lawn] [--color 92,168,56] [--times ...]

Assumptions (Roblox doesn't document them): particle Size = the card's full width in studs; Drag halves the
speed every 1/Drag seconds; SpreadAngle tilts the emit direction by up to (x, y) degrees about X and Z.
"""
import argparse, json, math, os, random, sys
import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("event"); ap.add_argument("out")
ap.add_argument("--tuft", default="tuft_lawn")
ap.add_argument("--color", default="92,168,56", help="the clump's grass colour (r,g,b)")
ap.add_argument("--times", default="-0.06,0,0.025,0.05,0.08,0.12,0.18,0.26,0.4", help="seconds after the impact")
ap.add_argument("--w", type=int, default=640); ap.add_argument("--h", type=int, default=360)
ap.add_argument("--samples", type=int, default=12)
ap.add_argument("--seed", type=int, default=3)
ap.add_argument("--nohand", action="store_true")
a = ap.parse_args(argv)

PRESETS = json.load(open(os.path.join(ROOT, "src", "shared", "FxPresets.json")))
FX = os.path.join(ROOT, "assets", "fx"); MODELS = os.path.join(ROOT, "assets", "models")
GRAVITY = 196.2
SWING_TIME = 0.32; STRIKE = 0.11  # ViewModel / HitFx timings
preset = PRESETS[a.event]
grass = tuple(int(v) for v in a.color.split(","))

# ---------------------------------------------------------------------------------------------------------------
# Roblox maths: CFrames as 4x4 matrices in Roblox space (y up, look = -z); converted to Blender (z up) at the end
# ---------------------------------------------------------------------------------------------------------------
C = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))

def cf(x=0, y=0, z=0):
    m = Matrix.Identity(4); m.translation = Vector((x, y, z)); return m

def angles(rx, ry, rz):
    return (Matrix.Rotation(rx, 4, "X") @ Matrix.Rotation(ry, 4, "Y") @ Matrix.Rotation(rz, 4, "Z"))

def look_at(eye, target):
    eye = Vector(eye); f = (Vector(target) - eye).normalized()
    r = f.cross(Vector((0, 1, 0))).normalized(); u = r.cross(f)
    m = Matrix.Identity(4)
    m[0][0], m[1][0], m[2][0] = r
    m[0][1], m[1][1], m[2][1] = u
    m[0][2], m[1][2], m[2][2] = -f
    m.translation = eye
    return m

def to_blender(m, scale=1.0):
    R = m.to_3x3(); out = (C @ R @ C.transposed() * scale).to_4x4()
    out.translation = C @ m.translation
    return out

def rb(v):
    return C @ Vector(v)

def local_to_blender(m):
    """For objects whose own local axes are Roblox-style (the camera, the particle cards)."""
    out = (C @ m.to_3x3()).to_4x4(); out.translation = C @ m.translation
    return out

def lerp_cf(m0, m1, k):
    q = m0.to_quaternion().slerp(m1.to_quaternion(), k)
    out = q.to_matrix().to_4x4(); out.translation = m0.translation.lerp(m1.translation, k); return out

# ---------------------------------------------------------------------------------------------------------------
# scene: meadow, the clump you hit and a few behind it, sky and sun (like blender_render.py)
# ---------------------------------------------------------------------------------------------------------------
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

def lin(c):
    c = c / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def mat_ground():
    m = bpy.data.materials.new("Ground"); m.use_nodes = True
    n = m.node_tree.nodes; l = m.node_tree.links; b = n["Principled BSDF"]
    noise = n.new("ShaderNodeTexNoise"); noise.inputs["Scale"].default_value = 40; noise.inputs["Detail"].default_value = 8
    ramp = n.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (lin(70), lin(140), lin(42), 1); ramp.color_ramp.elements[1].color = (lin(108), lin(182), lin(64), 1)
    l.new(noise.outputs["Fac"], ramp.inputs["Fac"]); l.new(ramp.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.95
    return m

bpy.ops.mesh.primitive_plane_add(size=400)
ground = bpy.context.object; ground.data.materials.append(mat_ground())

def import_glb(name):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(MODELS, name + ".glb"))
    objs = []
    for o in list(set(bpy.data.objects) - before):
        if o.name.startswith("Origin__"):
            bpy.data.objects.remove(o, do_unlink=True)
        else:
            objs.append(o)
    # flat Roblox-like colours from the part names (Kind__RRGGBB)
    for o in objs:
        if o.type != "MESH":
            continue
        base = o.name.split(".")[0]; kind, _, hx = base.partition("__")
        if len(hx) >= 6:
            col = tuple(lin(int(hx[i:i + 2], 16)) for i in (0, 2, 4))
            mm = bpy.data.materials.new("M_" + base); mm.use_nodes = True
            bsdf = mm.node_tree.nodes["Principled BSDF"]; bsdf.inputs["Base Color"].default_value = col + (1,)
            bsdf.inputs["Roughness"].default_value = 0.8 if kind != "SmoothPlastic" else 0.5
            o.data.materials.clear(); o.data.materials.append(mm)
    root = bpy.data.objects.new("ROOT_" + name, None); scene.collection.objects.link(root)
    for o in objs:
        if o.parent is None:
            o.parent = root
    return root, [o for o in objs if o.type == "MESH"]

clump, clump_meshes = import_glb(a.tuft)
stubble = None
if preset.get("pop") and os.path.exists(os.path.join(MODELS, a.tuft + "_cut.glb")):
    stubble, _ = import_glb(a.tuft + "_cut")
rng_scene = random.Random(9)
for i in range(14):
    r, mesh = import_glb(a.tuft)
    ang = rng_scene.uniform(0, math.tau); dist = rng_scene.uniform(7, 30)
    pos = (math.cos(ang) * dist, 0, -abs(math.sin(ang)) * dist - 4)
    r.matrix_world = to_blender(cf(*pos) @ angles(0, rng_scene.uniform(0, 6.28), 0), rng_scene.uniform(0.9, 1.1))

# the white hit flash on the clump: a mix toward white in each of its materials
flash_nodes = []
for o in clump_meshes:
    for mm in o.data.materials:
        nt = mm.node_tree; b = nt.nodes["Principled BSDF"]
        emis = nt.nodes.new("ShaderNodeEmission"); emis.inputs["Color"].default_value = (1, 1, 1, 1)
        mix = nt.nodes.new("ShaderNodeMixShader"); mix.inputs[0].default_value = 0
        out = nt.nodes["Material Output"]
        nt.links.new(b.outputs[0], mix.inputs[1]); nt.links.new(emis.outputs[0], mix.inputs[2])
        nt.links.new(mix.outputs[0], out.inputs["Surface"])
        flash_nodes.append(mix)

# sun + sky
sun_d = bpy.data.lights.new("Sun", "SUN"); sun_d.energy = 4.0; sun_d.angle = math.radians(3)
sun = bpy.data.objects.new("Sun", sun_d); scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(40), math.radians(10), math.radians(-30))
world = bpy.data.worlds.new("W"); scene.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.45, 0.65, 1.0, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.4

# ---------------------------------------------------------------------------------------------------------------
# particle cards
# ---------------------------------------------------------------------------------------------------------------
card_mesh = bpy.data.meshes.new("card")
# vertices in Roblox-local space (x right, z up, facing +y); objects using it get matrix_world = C @ M
card_mesh.from_pydata([(-0.5, 0, -0.5), (0.5, 0, -0.5), (0.5, 0, 0.5), (-0.5, 0, 0.5)], [], [(0, 1, 2, 3)])
card_mesh.uv_layers.new(name="UV")
for i, uv in enumerate([(0, 0), (1, 0), (1, 1), (0, 1)]):
    card_mesh.uv_layers["UV"].data[i].uv = uv
card_mesh.materials.append(None)

images = {}
def image(key):
    if key not in images:
        images[key] = bpy.data.images.load(os.path.join(FX, key + ".png"))
    return images[key]

card_mats = {}
def card_material(texture, frame, flip, additive):
    """One material per texture / flipbook frame / blend mode; tint and alpha come from the object colour."""
    k = (texture, frame if flip else -1, round(additive, 2))
    if k in card_mats:
        return card_mats[k]
    m = bpy.data.materials.new("P_%s_%s_%s" % k); m.use_nodes = True
    nt = m.node_tree; n = nt.nodes; l = nt.links
    for node in list(n):
        if node.type != "OUTPUT_MATERIAL":
            n.remove(node)
    out = n["Material Output"]
    tx = n.new("ShaderNodeTexImage"); tx.image = image(texture); tx.interpolation = "Linear"
    uv = n.new("ShaderNodeUVMap"); uv.uv_map = "UV"
    if flip:
        mp = n.new("ShaderNodeMapping"); mp.inputs["Scale"].default_value = (0.25, 0.25, 1)
        col_i, row_i = frame % 4, frame // 4
        mp.inputs["Location"].default_value = (col_i * 0.25, 1 - (row_i + 1) * 0.25, 0)
        l.new(uv.outputs["UV"], mp.inputs["Vector"]); l.new(mp.outputs["Vector"], tx.inputs["Vector"])
    else:
        l.new(uv.outputs["UV"], tx.inputs["Vector"])
    info = n.new("ShaderNodeObjectInfo")
    tint = n.new("ShaderNodeMix"); tint.data_type = "RGBA"; tint.blend_type = "MULTIPLY"; tint.inputs["Factor"].default_value = 1
    l.new(tx.outputs["Color"], tint.inputs[6]); l.new(info.outputs["Color"], tint.inputs[7])
    alpha = n.new("ShaderNodeMath"); alpha.operation = "MULTIPLY"
    l.new(tx.outputs["Alpha"], alpha.inputs[0]); l.new(info.outputs["Alpha"], alpha.inputs[1])
    emis = n.new("ShaderNodeEmission"); l.new(tint.outputs[2], emis.inputs["Color"])
    transp = n.new("ShaderNodeBsdfTransparent")
    # normal blending: mix(transparent, colour, alpha); additive: transparent + colour * alpha
    normal = n.new("ShaderNodeMixShader"); l.new(alpha.outputs[0], normal.inputs[0])
    l.new(transp.outputs[0], normal.inputs[1]); l.new(emis.outputs[0], normal.inputs[2])
    emis2 = n.new("ShaderNodeEmission"); l.new(tint.outputs[2], emis2.inputs["Color"]); l.new(alpha.outputs[0], emis2.inputs["Strength"])
    add = n.new("ShaderNodeAddShader"); l.new(transp.outputs[0], add.inputs[0]); l.new(emis2.outputs[0], add.inputs[1])
    blend = n.new("ShaderNodeMixShader"); blend.inputs[0].default_value = additive
    l.new(normal.outputs[0], blend.inputs[1]); l.new(add.outputs[0], blend.inputs[2])
    l.new(blend.outputs[0], out.inputs["Surface"])
    card_mats[k] = m
    return m

def seq_at(stops, t, default):
    if not stops:
        return default
    if t <= stops[0][0]:
        return stops[0][1]
    for (t0, v0), (t1, v1) in zip(stops, stops[1:]):
        if t <= t1:
            k = (t - t0) / max(t1 - t0, 1e-6)
            if isinstance(v0, (int, float)):
                return v0 + (v1 - v0) * k
            return [x0 + (x1 - x0) * k for x0, x1 in zip(v0, v1)]
    return stops[-1][1]

def stop_color(v):
    g = grass
    def shade(c, k):
        return [min(255, x * k) for x in c]
    def mix(c, d, k):
        return [x + (y - x) * k for x, y in zip(c, d)]
    if isinstance(v, list):
        return v
    if v == "grassLight":
        return mix(shade(g, 1.45), [255, 255, 230], 0.25)
    if v == "grassPale":
        return mix(shade(g, 1.6), [255, 255, 235], 0.5)
    if v == "grassDark":
        return shade(g, 0.75)
    return list(g)

# ---------------------------------------------------------------------------------------------------------------
# the hit: where things are (same rules as HitFx)
# ---------------------------------------------------------------------------------------------------------------
EYE = Vector((0.4, 4.5, 3.9))
TARGET = Vector((0.0, 2.0, 0.0))
OUT = Vector((0, 0, 1))  # from the clump toward the player

def anchor(layer):
    at_kind = layer.get("at", "base")
    if at_kind == "contact":
        right = OUT.cross(Vector((0, 1, 0)))
        p = Vector((0, min(3.2, max(1.2, EYE.y - 1.6)), 0)) + OUT * 1.3 - right * 0.35
    elif at_kind == "top":
        p = Vector((0, layer.get("height", 3.2), 0))
    else:
        p = Vector((0, layer.get("height", 0.6), 0))
    m = cf(*p)
    if layer.get("dir") == "out":
        m = look_at(p, p + OUT) @ angles(-math.radians(layer.get("tilt", 60)), 0, 0)
    return m

class Particle:
    pass

def spawn_particles(layer, rng):
    m = anchor(layer)
    R = m.to_3x3()
    out = []
    for _ in range(layer.get("count", 1)):
        p = Particle()
        lo, hi = layer.get("lifetime", [0.5, 0.5]); p.life = rng.uniform(lo, hi)
        lo, hi = layer.get("speed", [0, 0]); sp = rng.uniform(lo, hi)
        sx, sy = layer.get("spread", [0, 0])
        d = Matrix.Rotation(math.radians(rng.uniform(-sx, sx)), 3, "X") @ Matrix.Rotation(math.radians(rng.uniform(-sy, sy)), 3, "Z") @ Vector((0, 1, 0))
        p.vel = (R @ d) * sp
        p.pos = m.translation.copy()
        lo, hi = layer.get("rotation", [0, 0]); p.rot = rng.uniform(lo, hi)
        lo, hi = layer.get("rotSpeed", [0, 0]); p.rotspeed = rng.uniform(lo, hi)
        out.append(p)
    return out

def spawn_sprites(layer, rng):
    m = anchor(layer); out = []
    off = layer.get("offset", 0)
    for i in range(layer.get("count", 1)):
        p = Particle()
        lo, hi = layer.get("lifetime", [0.3, 0.3]); p.life = rng.uniform(lo, hi)
        p.pos = m.translation + Vector((rng.uniform(-off, off), rng.uniform(-off, off) * 0.6, rng.uniform(-off, off)))
        p.vel = Vector((0, layer.get("rise", 0), 0))
        lo, hi = layer.get("rotation", [0, 0]); p.rot = rng.uniform(lo, hi); p.rotspeed = 0
        p.delay = layer.get("delay", 0) * i
        out.append(p)
    return out

def particle_state(layer, p, age):
    """Position / velocity after `age` seconds (small steps: acceleration + exponential drag)."""
    pos = p.pos.copy(); vel = p.vel.copy()
    acc = Vector(layer.get("acceleration", [0, 0, 0])); drag = layer.get("drag", 0)
    steps = max(1, int(age * 240)); dt = age / steps
    for _ in range(steps):
        vel += acc * dt
        if drag:
            vel *= 2 ** (-drag * dt)
        pos += vel * dt
    return pos, vel

# clippings: ballistic with Roblox gravity, bounce on the ground
def spawn_clips(layer, rng, count):
    m = anchor(layer); base = m.translation
    o = layer.get("out", [6, 12]); u = layer.get("up", [10, 16]); side = layer.get("side", 6)
    clips = []
    for _ in range(count):
        c = Particle()
        c.pos = base + Vector((rng.uniform(-0.4, 0.4), rng.uniform(-0.3, 0.3), rng.uniform(-0.4, 0.4)))
        sv = Vector((rng.uniform(-1, 1), 0, rng.uniform(-1, 1))) * side
        c.vel = OUT * rng.uniform(*o) + sv + Vector((0, rng.uniform(*u), 0))
        c.rot0 = Vector((rng.uniform(0, 6), rng.uniform(0, 6), rng.uniform(0, 6)))
        c.spin = Vector((rng.uniform(-22, 22), rng.uniform(-22, 22), rng.uniform(-22, 22)))
        c.scale = layer.get("size", 1) * rng.uniform(0.85, 1.2)
        c.model = rng.choice(["fx_clip_a", "fx_clip_b", "fx_clip_c"])
        c.tint = [min(255, x * rng.uniform(0.9, 1.25)) for x in grass]
        clips.append(c)
    return clips

def clip_state(c, age):
    pos = c.pos.copy(); vel = c.vel.copy(); spin = c.spin.copy(); ang = Vector((0, 0, 0))
    steps = max(1, int(age * 480)); dt = age / steps
    for _ in range(steps):
        vel.y -= GRAVITY * dt
        pos += vel * dt; ang += spin * dt
        if pos.y < 0.08:
            pos.y = 0.08
            if vel.y < 0:
                vel.y = -vel.y * 0.3
                vel.x *= 0.6; vel.z *= 0.6; spin *= 0.5
    return pos, ang

clip_templates = {}
def clip_template(name):
    if name not in clip_templates:
        root, meshes = import_glb(name)
        root.hide_render = True
        for o in meshes:
            o.hide_render = True
        clip_templates[name] = meshes
    return clip_templates[name]

# ---------------------------------------------------------------------------------------------------------------
# the glove hand's jab (ViewModel punchOffset), with the hit-stop
# ---------------------------------------------------------------------------------------------------------------
REST_R = cf(1.55, -1.45, -2.4) @ angles(math.radians(8), math.radians(8), 0)
def punch_offset(t, side=1):
    wind = cf(0.12 * side, -0.12, 0.4) @ angles(math.radians(-14), 0, 0)
    strike = cf(-0.6 * side, 0.4, -1.8) @ angles(math.radians(10), math.radians(12 * side), math.radians(-8 * side))
    ident = Matrix.Identity(4)
    if t < 0.16:
        return lerp_cf(ident, wind, t / 0.16)
    if t < 0.36:
        k = (t - 0.16) / 0.2
        return lerp_cf(wind, strike, 1 - (1 - k) ** 2)
    if t < 0.48:
        return strike
    k = (t - 0.48) / 0.52
    return lerp_cf(strike, ident, k * k * (3 - 2 * k))

def swing_t(tau):
    """Swing progress at `tau` seconds after the impact, with the hit-stop holding the pose at contact."""
    hs = preset.get("hitstop", 0)
    t = tau + STRIKE
    if tau > 0:
        t = STRIKE + max(0, tau - hs)
    return t / SWING_TIME

hand_root = None
if not a.nohand and a.event in ("punch", "hit") and os.path.exists(os.path.join(MODELS, "hand_right.glb")):
    hand_root, _ = import_glb("hand_right")

# ---------------------------------------------------------------------------------------------------------------
# render each time
# ---------------------------------------------------------------------------------------------------------------
cam_d = bpy.data.cameras.new("Cam"); cam_d.sensor_fit = "VERTICAL"; cam_d.clip_start = 0.1
cam = bpy.data.objects.new("Cam", cam_d); scene.collection.objects.link(cam); scene.camera = cam
scene.render.engine = "CYCLES"; scene.cycles.samples = a.samples; scene.cycles.use_denoising = True
scene.cycles.transparent_max_bounces = 48; scene.cycles.max_bounces = 4
scene.render.resolution_x = a.w; scene.render.resolution_y = a.h
scene.view_settings.view_transform = "Standard"

rng = random.Random(a.seed)
layers = []
for layer in preset["layers"]:
    if layer["kind"] == "particles":
        layers.append((layer, spawn_particles(layer, rng)))
    elif layer["kind"] == "sprite":
        layers.append((layer, spawn_sprites(layer, rng)))
    elif layer["kind"] == "clippings":
        layers.append((layer, spawn_clips(layer, rng, layer.get("mineCount", layer.get("count", 5)))))

frames = []
times = [float(t) for t in a.times.split(",")]
cam_cf = look_at(EYE, TARGET)
for fi, tau in enumerate(times):
    temp = []
    # camera kick and the clump's flash / wobble
    kick = preset.get("kick", 0) * max(0, 1 - tau / 0.16) if tau >= 0 else 0
    cam.matrix_world = local_to_blender(cam_cf)
    cam_d.angle_y = math.radians(70 - kick)
    flash = preset.get("flash", 0) * max(0, 1 - tau / 0.14) if tau >= 0 else 0
    for mix in flash_nodes:
        mix.inputs[0].default_value = flash
    wob = math.radians(14 * preset.get("wobble", 0)) * math.exp(-tau * 8) * math.cos(tau * 24) if tau >= 0 else 0
    clump.matrix_world = to_blender(angles(-wob, 0, 0))
    pp = preset.get("pop")
    if pp and tau >= 0:
        g, t1, t2 = pp.get("grow", 1.15), pp.get("growTime", 0.05), pp.get("shrinkTime", 0.13)
        sc = 1 + (g - 1) * tau / t1 if tau < t1 else (g * (1 - ((tau - t1) / t2) ** 2) if tau < t1 + t2 else 0.001)
        clump.matrix_world = to_blender(Matrix.Identity(4), max(0.001, sc))
        for mix in flash_nodes:
            mix.inputs[0].default_value = pp.get("white", 0.7) if tau < t1 + t2 else 0
    if stubble:
        stubble.hide_render = tau < 0
        for ch in stubble.children:
            ch.hide_render = tau < 0
    if hand_root:
        st = swing_t(tau)
        off = punch_offset(st) if 0 <= st <= 1 else Matrix.Identity(4)
        hand_root.matrix_world = to_blender(cam_cf @ REST_R @ off)
    if tau >= 0:
        cam_pos = cam_cf.translation
        for layer, items in layers:
            if layer["kind"] in ("particles", "sprite"):
                sprite_kind = layer["kind"] == "sprite"
                for p in items:
                    age = tau - getattr(p, "delay", 0)
                    if age < 0 or age >= p.life:
                        continue
                    k = age / p.life
                    pos, vel = particle_state(layer, p, age)
                    size = seq_at(layer.get("size"), k, 1)
                    tr = seq_at(layer.get("transparency"), k, 0)
                    col = stop_color(seq_at([[s[0], stop_color(s[1])] for s in layer["color"]], k, [255, 255, 255]))
                    bright = layer.get("brightness", 1) if layer.get("lightInfluence", 0) == 0 else 1
                    if sprite_kind:
                        vel = Vector((0, 0, 0))
                    pos = pos + (cam_pos - pos).normalized() * layer.get("zOffset", 0)
                    flip = layer.get("flipbook") is not None
                    frame = min(15, int(k * 16)) if flip else 0
                    o = bpy.data.objects.new("p", card_mesh)
                    mat = card_material(layer["texture"], frame, flip, 0 if sprite_kind else layer.get("lightEmission", 0))
                    o.material_slots[0].link = "OBJECT"; o.material_slots[0].material = mat
                    o.color = (lin(col[0]) * bright, lin(col[1]) * bright, lin(col[2]) * bright, 1 - tr)
                    # orientation: face the camera, rolled by Rotation; VelocityParallel: up along the velocity
                    to_cam = (cam_pos - pos).normalized()
                    orient = layer.get("orientation", "FacingCamera")
                    if orient == "VelocityPerpendicular" and vel.length > 1e-6:
                        nrm = vel.normalized(); up = nrm.cross(Vector((1, 0, 0)))
                        if up.length < 1e-3:
                            up = nrm.cross(Vector((0, 0, 1)))
                        up.normalize(); right = up.cross(nrm)
                        fwd = nrm
                    else:
                        if orient == "VelocityParallel" and vel.length > 1e-6:
                            up = vel - to_cam * vel.dot(to_cam)
                            up = up.normalized() if up.length > 1e-6 else Vector((0, 1, 0))
                        else:
                            up = Vector((0, 1, 0)) - to_cam * to_cam.y
                            up.normalize()
                            r = math.radians(p.rot + p.rotspeed * age)
                            right0 = up.cross(to_cam)
                            up = up * math.cos(r) + right0 * math.sin(r)
                        right = up.cross(to_cam); fwd = to_cam
                    # card: local X = right, local Y (plane normal) = toward camera, local Z = up (in Roblox axes)
                    M = Matrix((right, fwd, up)).transposed().to_4x4() @ Matrix.Diagonal((size, size, size, 1))
                    M.translation = pos
                    o.matrix_world = local_to_blender(M)
                    scene.collection.objects.link(o); temp.append(o)
            else:
                for c in items:
                    pos, ang = clip_state(c, tau)
                    for src in clip_template(c.model):
                        o = src.copy(); o.data = src.data; o.hide_render = False
                        o.parent = None
                        mm = None
                        if src.data.materials and src.data.materials[0].name.startswith("M_SmoothPlastic__FFFFFF"):
                            mm = bpy.data.materials.new("tint"); mm.use_nodes = True
                            mm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = tuple(lin(x) for x in c.tint) + (1,)
                            o.material_slots[0].link = "OBJECT"; o.material_slots[0].material = mm
                        M = cf(*pos) @ angles(*(c.rot0 + ang))
                        o.matrix_world = to_blender(M, c.scale) @ src.matrix_basis
                        scene.collection.objects.link(o); temp.append(o)
    path = os.path.join(os.path.dirname(os.path.abspath(a.out)), "_fxsim_%02d.png" % fi)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    frames.append((tau, path))
    for o in temp:
        bpy.data.objects.remove(o, do_unlink=True)

# frames are joined into a contact sheet by tools/preview/fx_sheet.py (Blender's Python has no PIL)
json.dump({"event": a.event, "out": a.out, "frames": frames}, open(a.out + ".json", "w"))
print("fx frames ->", a.out + ".json")
