"""Turn Blender models into native Roblox parts (no mesh upload needed).

    blender -b -P tools/blender/to_parts.py -- bag_stand hay_bale ...

Runs each tools/blender/models/<name>.py exactly like build.py, but writes src/server/PartModels/<name>.luau: a list
of Roblox parts (Block / Cylinder / Wedge / Ball) that server/Models.luau builds into a template at server start.
- lib.box / lib.cyl / lib.wedge / lib.sphere become one matching Roblox part each (bevels are dropped).
- Everything else (cones, tapered boxes, extruded outlines, discs, faceted gems) is cut into triangles, and each
  triangle becomes two thin wedges (the usual Roblox triangle trick).
Coordinates are the model's own studs the way Models.place uses them: x = Blender x, y = up (Blender z),
z = -Blender y, so the model's front (Blender +Y) faces the CFrame's LookVector (-Z).
"""
import importlib.util, math, os, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
import lib  # noqa: E402

OUT = os.path.join(ROOT, "src", "server", "PartModels")
THIN = 0.08  # thickness of the wedges a triangle is made of

# Blender -> Roblox axes: x = x, y = z, z = -y
M = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))
# a part's own axes, in the Blender object's local axes
P_BOX = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))  # part X, Y, Z = local x, z, -y
P_CYL = Matrix(((0, 1, 0), (0, 0, 1), (1, 0, 0)))   # part X (the cylinder's axis) = local z, Y = x, Z = y

# --- tag every primitive the model scripts make, so it can become one native part ------------------------------
_box, _cyl, _wedge, _sphere = lib.box, lib.cyl, lib.wedge, lib.sphere


def box(name, size, loc=(0, 0, 0), rot=(0, 0, 0), mat=None, bevel=0.0, taper=None):
    o = _box(name, size, loc, rot, mat, bevel, taper)
    if not taper or (abs(taper[0] - 1) < 1e-3 and abs(taper[1] - 1) < 1e-3):
        o["prim"] = "box"
        o["dims"] = list(size)
    elif min(taper) >= 0.7:
        # a gently tapered box (tree trunks, roots) reads fine as a plain box of its average width
        o["prim"] = "box"
        o["dims"] = [size[0] * (1 + taper[0]) / 2, size[1] * (1 + taper[1]) / 2, size[2]]
    return o


def cyl(name, radius, depth, loc=(0, 0, 0), rot=(0, 0, 0), mat=None, verts=12, bevel=0.0, top_scale=1.0):
    o = _cyl(name, radius, depth, loc, rot, mat, verts, bevel, top_scale)
    if top_scale >= 0.8 and top_scale <= 1.25:
        o["prim"] = "cyl"
        o["dims"] = [radius * (1 + top_scale) / 2, depth]  # a gentle frustum reads fine as a cylinder
    return o


def wedge(name, size, loc=(0, 0, 0), rot=(0, 0, 0), mat=None, bevel=0.0):
    o = _wedge(name, size, loc, rot, mat, bevel)
    o["prim"] = "wedge"
    o["dims"] = list(size)
    return o


def sphere(name, radius, loc=(0, 0, 0), mat=None, subdiv=1):
    o = _sphere(name, radius, loc, mat, subdiv)
    o["prim"] = "ball"
    o["dims"] = [radius]
    return o


lib.box, lib.cyl, lib.wedge, lib.sphere = box, cyl, wedge, sphere


# --- conversion ----------------------------------------------------------------------------------------------------
def r3(v):
    return round(v, 3)


def part(shape, size, pos, rot, mat):
    """One part: shape, size (x, y, z), position, rotation (3x3, rows), material index."""
    cf = [pos[0], pos[1], pos[2]] + [rot[i][j] for i in range(3) for j in range(3)]
    return [shape, r3(size[0]), r3(size[1]), r3(size[2])] + [r3(v) for v in cf] + [mat]


def triangle_wedges(a, b, c, mat):
    """Two wedges filling triangle a, b, c (Roblox space Vectors)."""
    ab, ac, bc = b - a, c - a, c - b
    abd, acd, bcd = ab.dot(ab), ac.dot(ac), bc.dot(bc)
    if abd > acd and abd > bcd:
        c, a = a, c
    elif acd > bcd and acd > abd:
        a, b = b, a
    ab, ac, bc = b - a, c - a, c - b
    right = ac.cross(ab)
    if right.length < 1e-6 or bc.length < 1e-6:
        return []
    right.normalize()
    up = bc.cross(right).normalized()
    back = bc.normalized()
    height = abs(ab.dot(up))
    out = []
    for mid, w_right, w_back, depth in (((a + b) / 2, right, back, abs(ab.dot(back))), ((a + c) / 2, -right, -back, abs(ac.dot(back)))):
        if height < 1e-3 or depth < 1e-3:
            continue
        rot = ((w_right.x, up.x, w_back.x), (w_right.y, up.y, w_back.y), (w_right.z, up.z, w_back.z))
        out.append(part("W", (THIN, height, depth), mid, rot, mat))
    return out


def source(name):
    """The low-part design in parts_models/<name>.py if there is one (models too detailed to convert well, e.g. the
    grass clumps and bosses), else the normal model script in models/<name>.py."""
    low = os.path.join(HERE, "parts_models", name + ".py")
    return low if os.path.exists(low) else os.path.join(HERE, "models", name + ".py")


def convert(name):
    lib.reset()
    spec = importlib.util.spec_from_file_location(name, source(name))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    mod.build(lib)
    bpy.context.view_layer.update()
    mats, parts = [], []
    tri_count = 0
    for o in bpy.context.scene.objects:
        if o.type != "MESH" or not o.data.materials:
            continue
        mname = o.data.materials[0].name
        if mname not in mats:
            mats.append(mname)
        mi = mats.index(mname) + 1  # this object's own material (1-based, for Luau)
        mw = o.matrix_world
        loc, quat, scale = mw.decompose()
        rb = quat.to_matrix()
        pos = M @ loc
        prim = o.get("prim")
        dims = list(o.get("dims", []))
        if prim == "box":
            s = (dims[0] * scale.x, dims[2] * scale.z, dims[1] * scale.y)
            parts.append(part("B", s, pos, M @ rb @ P_BOX, mi))
        elif prim == "wedge":
            s = (dims[0] * scale.x, dims[2] * scale.z, dims[1] * scale.y)
            parts.append(part("W", s, pos, M @ rb @ P_BOX, mi))
        elif prim == "cyl":
            r, d = dims[0] * scale.x, dims[1] * scale.z
            parts.append(part("C", (d, r * 2, r * 2), pos, M @ rb @ P_CYL, mi))
        elif prim == "ball":
            r = dims[0] * scale.x
            parts.append(part("S", (r * 2, r * 2, r * 2), pos, Matrix.Identity(3), mi))
        else:
            me = o.data
            me.calc_loop_triangles()
            for t in me.loop_triangles:
                vs = [M @ (mw @ me.vertices[i].co) for i in t.vertices]
                parts.extend(triangle_wedges(vs[0], vs[1], vs[2], mi))
                tri_count += 1
    return mats, parts, tri_count


def lua(name, mats, parts):
    lines = [
        "-- Generated by tools/blender/to_parts.py from tools/blender/models/%s.py. Don't edit by hand." % name,
        "-- materials: \"<RobloxMaterial>__<RRGGBB>[__T<percent>]\"; parts: { shape (B block, C cylinder, W wedge,",
        "-- S ball), size x, y, z, then the CFrame (x, y, z, R00..R22), then the material index }.",
        "return {",
        "\tmaterials = { %s }," % ", ".join('"%s"' % m for m in mats),
        "\tparts = {",
    ]
    for p in parts:
        lines.append("\t\t{ \"%s\", %s }," % (p[0], ", ".join(repr(v) if isinstance(v, int) else ("%g" % v) for v in p[1:])))
    lines += ["\t},", "}", ""]
    return "\n".join(lines)


args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
os.makedirs(OUT, exist_ok=True)
for name in args:
    t0 = time.time()
    mats, parts, tris = convert(name)
    with open(os.path.join(OUT, name + ".luau"), "w", encoding="utf-8", newline="\n") as f:
        f.write(lua(name, mats, parts))
    print("PARTS %s: %d parts (%d from %d triangles), %d materials (%.1fs)" % (name, len(parts), tris * 2, tris, len(mats), time.time() - t0))
