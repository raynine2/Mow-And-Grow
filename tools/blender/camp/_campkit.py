"""Helpers for the camp models (tools/blender/camp/models.py), built with Blender's Python (bpy 5.2).

Like tools/blender/to_parts.py, every shape is one native Roblox part (Block, Cylinder, Wedge, Ball), so the
models need no mesh upload: tools/blender/camp/build.py writes them into src/server/CampProps.luau as compact text
and server/CampProps builds them at run start.

Conventions (as tools/blender/lib.py): 1 unit = 1 stud, the model stands on z = 0 centred on x = y = 0, its FRONT
faces Blender +Y (Roblox -Z, the CFrame's LookVector).

Materials are "<Kind>__<colour>[__T<percent>]":
  * Kind: a Roblox material (Wood, Plaster, Fabric, Neon, ...), or the world's voxel textures VLog, VStone, VPlank,
    VRoof, VMetal (server/VoxelKit's MaterialVariants), or "Mark" for an invisible marker part (its colour field is
    the marker's name: Smoke, Lamp, SignFace, ...);
  * colour: RRGGBB, or "@role": a colour (and maybe material) the area's theme picks when the model is placed
    (wall, roof, trim, cloth, coat, hat ...). Previews use PREVIEW_ROLES.
Groups: parts that move on their own in the game (a windmill's sails, a gnome's arms) are put in a group with a
pivot (kit.group(name, pivot)); client/CampLife animates them.
"""
import math
import bmesh
import bpy
from mathutils import Euler, Vector

VOXEL = {"VLog": "Wood", "VStone": "Cobblestone", "VPlank": "WoodPlanks", "VRoof": "RoofShingles", "VMetal": "CorrodedMetal"}
KINDS = {"Plastic", "SmoothPlastic", "Wood", "WoodPlanks", "Slate", "Fabric", "Metal", "Neon", "Glass", "Grass",
         "LeafyGrass", "Ground", "Sand", "Snow", "Ice", "Brick", "Cobblestone", "Marble", "Granite", "Pebble",
         "Concrete", "Plaster", "ClayRoofTiles", "RoofShingles", "CeramicTiles", "Leather", "Basalt", "CrackedLava",
         "Rock", "Limestone", "Sandstone", "CorrodedMetal", "DiamondPlate", "Foil", "Rubber", "Carpet", "Mud",
         "Mark"} | set(VOXEL)

# the colours (and materials) the roles get in previews: Golden Wheat Hills' theme
PREVIEW_ROLES = {
    "wall": ("VPlank", (176, 58, 46)), "trim": (None, (236, 228, 214)), "roof": ("VRoof", (110, 74, 56)),
    "base": (None, (230, 222, 205)), "door": (None, (120, 70, 40)), "glass": ("Glass", (190, 220, 240)),
    "cloth": (None, (226, 128, 44)), "accent": (None, (250, 206, 60)), "board": (None, (196, 140, 88)),
    "goods1": (None, (232, 196, 90)), "goods2": (None, (236, 128, 34)), "flower": (None, (250, 200, 60)),
    "coat": (None, (200, 60, 50)), "pants": (None, (60, 90, 160)), "hat": (None, (226, 190, 110)),
    "beard": (None, (240, 236, 228)), "tower": ("Plaster", (244, 238, 226)), "post": (None, (200, 50, 60)),
    "wood": (None, (176, 124, 78)), "stone": (None, (200, 196, 188)), "sail": (None, (246, 240, 226)),
    "skin": (None, (255, 204, 170)), "water": (None, (70, 150, 200)), "roof2": ("VRoof", (86, 56, 42)),
    "scope": (None, (44, 48, 96)),
}

_groups = {}      # name -> pivot (Blender coords)
_current = [None]  # the group new shapes go into


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m)
    _groups.clear()
    _current[0] = None


def lin(c):
    c = c / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexcol(rgb):
    return "%02X%02X%02X" % tuple(int(round(c)) for c in rgb)


def mat(kind, col, transparency=0.0):
    """A material slot. `col`: (r, g, b) or "@role" (or the marker name for kind "Mark")."""
    assert kind in KINDS, kind
    if kind == "Mark":
        name = "Mark__%s" % col
    elif isinstance(col, str):
        assert col.startswith("@") and col[1:] in PREVIEW_ROLES, col
        name = "%s__%s" % (kind, col)
    else:
        name = "%s__%s" % (kind, hexcol(col))
    if transparency > 0:
        name += "__T%02d" % int(round(transparency * 100))
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    # preview look: the role's preview colour / material
    pk, rgb = kind, col
    if isinstance(col, str) and kind != "Mark":
        rk, rgb = PREVIEW_ROLES[col[1:]]
        pk = rk or kind
    if kind == "Mark":
        rgb = (255, 0, 255)
    pk = VOXEL.get(pk, pk)
    m.use_nodes = True
    nt = m.node_tree
    n, l = nt.nodes, nt.links
    bsdf = n["Principled BSDF"]
    base = (lin(rgb[0]), lin(rgb[1]), lin(rgb[2]), 1)
    bsdf.inputs["Base Color"].default_value = base
    bsdf.inputs["Roughness"].default_value = 0.75
    m.diffuse_color = base
    tc = n.new("ShaderNodeTexCoord")

    def tint(fac_out, lo, hi):
        mr = n.new("ShaderNodeMapRange")
        mr.inputs["To Min"].default_value = lo
        mr.inputs["To Max"].default_value = hi
        l.new(fac_out, mr.inputs["Value"])
        mix = n.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1
        mix.inputs[6].default_value = base
        l.new(mr.outputs["Result"], mix.inputs[7])
        l.new(mix.outputs[2], bsdf.inputs["Base Color"])

    if pk in ("Wood", "WoodPlanks"):
        mp = n.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (1, 1, 0.08) if pk == "Wood" else (0.15, 1, 1)
        l.new(tc.outputs["Object"], mp.inputs["Vector"])
        wv = n.new("ShaderNodeTexWave")
        wv.wave_type = "BANDS"
        wv.bands_direction = "X"
        wv.inputs["Scale"].default_value = 1.6
        wv.inputs["Distortion"].default_value = 5
        l.new(mp.outputs["Vector"], wv.inputs["Vector"])
        tint(wv.outputs["Fac"], 0.72, 1.12)
    elif pk in ("Cobblestone", "Brick", "Slate", "RoofShingles", "ClayRoofTiles", "Rock", "Basalt", "Pebble",
                "Fabric", "Grass", "LeafyGrass", "Snow", "Plaster", "Leather", "Ground", "Sand", "Granite"):
        vz = n.new("ShaderNodeTexVoronoi")
        vz.inputs["Scale"].default_value = {"Fabric": 18, "Plaster": 4, "Snow": 3, "Grass": 10}.get(pk, 2.2)
        l.new(tc.outputs["Object"], vz.inputs["Vector"])
        tint(vz.outputs["Distance"], 0.75, 1.15)
        bsdf.inputs["Roughness"].default_value = 0.9
    elif pk == "Neon":
        bsdf.inputs["Emission Color"].default_value = base
        bsdf.inputs["Emission Strength"].default_value = 3
    elif pk in ("Metal", "CorrodedMetal", "DiamondPlate", "Foil"):
        bsdf.inputs["Metallic"].default_value = 0.8
        bsdf.inputs["Roughness"].default_value = 0.4
    elif pk in ("Glass", "Ice"):
        bsdf.inputs["Roughness"].default_value = 0.08
        bsdf.inputs["Transmission Weight"].default_value = 0.6
    elif pk == "SmoothPlastic":
        bsdf.inputs["Roughness"].default_value = 0.45
    if transparency > 0 or kind == "Mark":
        bsdf.inputs["Alpha"].default_value = 0.0 if kind == "Mark" else 1 - transparency
    return m


def group(name, pivot=None):
    """Shapes made after this go into group `name` (pivot in model coordinates) until group(None)."""
    if name is not None:
        _groups[name] = tuple(pivot)
    _current[0] = name


def groups():
    return dict(_groups)


def _link(name, bm, m, loc, rot):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(m)
    obj.location = loc
    obj.rotation_euler = Euler([math.radians(r) for r in rot], "XYZ")
    if _current[0]:
        obj["group"] = _current[0]
    if m.name.startswith("Mark__"):
        obj.hide_render = True
    return obj


def box(name, size, loc=(0, 0, 0), rot=(0, 0, 0), m=None):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    o = _link(name, bm, m, loc, rot)
    o["prim"] = "box"
    o["dims"] = list(size)
    return o


def wedge(name, size, loc=(0, 0, 0), rot=(0, 0, 0), m=None):
    """Roblox wedge: full height at -Y (the back), sloping down to the ground toward +Y (the front)."""
    bm = bmesh.new()
    sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
    vs = [bm.verts.new(v) for v in [(-sx, -sy, -sz), (sx, -sy, -sz), (sx, sy, -sz), (-sx, sy, -sz), (-sx, -sy, sz), (sx, -sy, sz)]]
    for f in [(0, 1, 2, 3), (0, 4, 5, 1), (1, 5, 2), (0, 3, 4), (3, 2, 5, 4)]:
        bm.faces.new([vs[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = _link(name, bm, m, loc, rot)
    o["prim"] = "wedge"
    o["dims"] = list(size)
    return o


def cyl(name, radius, depth, loc=(0, 0, 0), rot=(0, 0, 0), m=None, verts=14):
    """Cylinder along Blender Z (rot to lay it down)."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=radius, radius2=radius, depth=depth)
    o = _link(name, bm, m, loc, rot)
    o["prim"] = "cyl"
    o["dims"] = [radius, depth]
    return o


def ball(name, radius, loc=(0, 0, 0), m=None):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=radius)
    o = _link(name, bm, m, loc, (0, 0, 0))
    o["prim"] = "ball"
    o["dims"] = [radius]
    return o


def beam(name, p0, p1, w, h, m):
    """A box from p0 to p1 (its length), w wide and h thick (h along the up side as far as it can)."""
    a, b = Vector(p0), Vector(p1)
    d = b - a
    o = box(name, (w, d.length, h), tuple((a + b) / 2), (0, 0, 0), m)
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = d.normalized().to_track_quat("Y", "Z")
    return o


def rod(name, p0, p1, r, m, verts=10):
    """A cylinder from p0 to p1."""
    a, b = Vector(p0), Vector(p1)
    d = b - a
    o = cyl(name, r, d.length, tuple((a + b) / 2), (0, 0, 0), m, verts)
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = d.normalized().to_track_quat("Z", "Y")
    return o


def stepped_cone(name, r0, r1, z0, h, steps, m, x=0.0, y=0.0):
    """A cone made of `steps` stacked cylinders (the world's voxel look)."""
    out = []
    for i in range(steps):
        k = i / steps
        r = r0 + (r1 - r0) * k
        out.append(cyl("%s%d" % (name, i), r, h / steps, (x, y, z0 + h / steps * (i + 0.5)), (0, 0, 0), m))
    return out


def roof(name, width, depth, rise, z, m, over=0.8, thick=0.5, ridge_m=None, shingles=None):
    """A gable roof along X: two slopes from the eaves (y = +-depth/2 at height z, plus `over` overhang) up to the
    ridge (y = 0, z + rise). `shingles`: a material for three strips across each slope; `ridge_m`: a ridge cap."""
    half = depth / 2
    ang = math.atan2(rise, half)
    out = []
    for s in (1, -1):
        e = Vector((0, s * (half + over), z - over * math.tan(ang)))
        r = Vector((0, 0, z + rise))
        phi = -ang if s > 0 else ang
        normal = Vector((0, -math.sin(phi), math.cos(phi)))
        length = (r - e).length
        c = (e + r) / 2 + normal * (thick / 2)
        out.append(box("%s_slope%d" % (name, s), (width, length, thick), tuple(c), (math.degrees(phi), 0, 0), m))
        if shingles:
            for k in range(1, 4):
                t = k / 4.2
                p = e + (r - e) * t + normal * (thick + 0.08)
                out.append(box("%s_sh%d_%d" % (name, s, k), (width + 0.1, 0.45, 0.16), tuple(p), (math.degrees(phi), 0, 0), shingles))
    if ridge_m:
        out.append(box(name + "_ridge", (width + 0.25, 1.0, 0.5), (0, 0, z + rise + thick / math.cos(ang) - 0.05), (0, 0, 0), ridge_m))
    return out


def gable(name, depth, rise, z, x, m, thick=0.6):
    """The triangle under a gable roof at x (two wedges back to back)."""
    half = depth / 2
    return [
        wedge(name + "_a", (thick, half, rise), (x, half / 2, z + rise / 2), (0, 0, 0), m),
        wedge(name + "_b", (thick, half, rise), (x, -half / 2, z + rise / 2), (0, 0, 180), m),
    ]
