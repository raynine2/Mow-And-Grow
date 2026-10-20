"""Toy grass clumps, one per zone style, uncut and cut. Blades curve outward from a dark root mound and fade to
lighter tips; wheat gets grain heads, reeds get cattails, jungle gets broad leaves. The cut version is short
stubble with pale cut tops and a few clippings lying around. Replaces tuft_<style> and tuft_<style>_cut."""
import math
import random

from mathutils import Vector

STYLES = {
    "lawn": dict(n=21, h=1.5, w=0.12, cols=("#5fb83f", "#4a9e33"), tip="#a8dc6a", root="#2f6e25", lean=0.35, curl=0.25),
    "golf": dict(n=22, h=0.9, w=0.08, cols=("#6fcf4a", "#5bbd3c"), tip="#bdef85", root="#3a8a2c", lean=0.3, curl=0.2),
    "wheat": dict(n=12, h=2.0, w=0.05, cols=("#e3c15a", "#d2a843"), tip="#f2dc8a", root="#8a9a3a", lean=0.15,
                  curl=0.08, heads="#f0cf6a"),
    "reeds": dict(n=11, h=2.3, w=0.065, cols=("#6f9a45", "#5a8a3a"), tip="#a8c46a", root="#3f5f2a", lean=0.18,
                  curl=0.15, cattails=3),
    "jungle": dict(n=7, h=1.7, w=0.3, cols=("#2f8a2a", "#22701f"), tip="#5fb84a", root="#174f16", lean=0.5, curl=0.35),
}
CUT_TIP = "#d8ee9a"


def build(k, name, style, cut=False):
    st = STYLES[style]
    rnd = random.Random(sum(map(ord, style)) + (7 if cut else 0))
    coll = k.new_scene(name)
    h = st["h"]
    tip_col = CUT_TIP if not style == "wheat" else "#f6e7b0"
    mats = [k.region_mat(f"{name}_Blade{i}", col, [("root", st["root"], 0.8), ("tip", tip_col if cut else st["tip"], 0.6)],
                         rough=0.6, coat=0.1) for i, col in enumerate(st["cols"])]
    k.blob(f"{name}_Root", coll, [dict(co=(0, 0, -0.05), size=(0.24, 0.24, 0.1))],
           k.mat(f"{name}_RootMat", st["root"], rough=0.8), resolution=0.03)
    tips = []
    for i in range(st["n"]):
        a = 2 * math.pi * i / st["n"] + rnd.uniform(-0.25, 0.25)
        o = Vector((math.cos(a), math.sin(a), 0))
        base = o * rnd.uniform(0.02, 0.18) + Vector((0, 0, -0.02))
        ln = h * rnd.uniform(0.75, 1.2)
        d = o * st["lean"] * rnd.uniform(0.6, 1.3) + Vector((0, 0, 1))
        blade = k.leaf(f"{name}_B{i}", coll, base, d, ln, st["w"] * rnd.uniform(0.85, 1.15), mats[i % 2],
                       curl=st["curl"] * rnd.uniform(0.6, 1.3), fold=0.12, up=tuple(o))
        if cut:
            hc = h * 0.2 * rnd.uniform(0.8, 1.2)
            k.trim(blade, (0, 0, hc), (0, 0, 1))
            k.sdf_attr(blade, "tip", lambda c, t=hc - 0.05: c.z - t)
        else:
            k.sdf_attr(blade, "tip", lambda c, t=ln * 0.72: c.z - t)
        k.sdf_attr(blade, "root", lambda c: h * 0.12 - c.z)
        tips.append((base, d.normalized(), ln, o))
    if cut:
        # clippings lying around the stubble
        for j in range(6):
            a = rnd.uniform(0, 2 * math.pi)
            p = Vector((math.cos(a), math.sin(a), 0)) * rnd.uniform(0.45, 0.8) + Vector((0, 0, 0.02))
            k.leaf(f"{name}_Clip{j}", coll, p, (math.cos(a + 1.3), math.sin(a + 1.3), 0.04), h * 0.18, st["w"],
                   mats[j % 2], curl=0.02, fold=0.05)
    elif st.get("heads"):
        grain = k.mat(f"{name}_Grain", st["heads"], rough=0.6, bump="pores", bump_scale=60, bump_strength=0.3)
        for i, (base, d, ln, o) in enumerate(tips):
            if i % 3 == 2:
                continue
            p0 = base + d * ln * 0.82
            k.blob(f"{name}_Head{i}", coll, [k.capsule(p0, p0 + d * ln * 0.25, 0.055)], grain, resolution=0.015)
    elif st.get("cattails"):
        stem = k.mat(f"{name}_Stem", st["cols"][1], rough=0.6)
        brown = k.mat(f"{name}_Cattail", "#6b4428", rough=0.85, bump="fabric", bump_scale=80, bump_strength=0.2)
        for j in range(st["cattails"]):
            a = 2 * math.pi * j / st["cattails"] + 0.4
            o = Vector((math.cos(a), math.sin(a), 0)) * 0.12
            top = o * 2.2 + Vector((0, 0, h * 1.15))
            k.tube(f"{name}_Stem{j}", coll, [tuple(o), tuple(o * 1.6 + Vector((0, 0, h * 0.6))), tuple(top)],
                   [0.03, 0.025, 0.02], stem)
            k.blob(f"{name}_Tail{j}", coll, [k.capsule(top - Vector((0, 0, 0.42)), top - Vector((0, 0, 0.08)), 0.075)],
                   brown, resolution=0.015)
    return coll
