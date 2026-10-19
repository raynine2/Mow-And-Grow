"""Angry cartoon face for the low-part bosses (parts_models/boss_*.py), boxes and balls only: two big eyes with
pupils glaring inward, two slanted brows, and an open mouth with a row of pointed teeth. Centred on (x, y, z) on the
boss's front (+Y); `s` scales the whole face. About 13 parts."""


def face(lib, x, y, z, s, eye, pupil, brow, mouth, tooth, teeth=4, eye_gap=1.2, glow=False):
    for sx in (-1, 1):
        ex = x + sx * eye_gap * s
        lib.sphere("eye%d" % sx, 0.75 * s, (ex, y, z + 0.6 * s), mat=eye)
        # pupils sit toward the middle: the eyes glare inward
        if not glow:
            lib.sphere("pupil%d" % sx, 0.33 * s, (ex - sx * 0.25 * s, y + 0.55 * s, z + 0.55 * s), mat=pupil)
        lib.box("brow%d" % sx, (1.6 * s, 0.4 * s, 0.35 * s), (ex, y + 0.35 * s, z + 1.55 * s), rot=(0, sx * 22, 0), mat=brow)
    lib.box("mouth", (2.6 * s, 0.4 * s, 0.9 * s), (x, y + 0.05 * s, z - 1.0 * s), mat=mouth)
    w = 2.4 * s / teeth
    for i in range(teeth):
        tx = x - 1.2 * s + w * (i + 0.5)
        # upper fangs point down: a wedge turned over
        lib.wedge("tooth%d" % i, (w * 0.8, 0.3 * s, 0.5 * s), (tx, y + 0.25 * s, z - 0.7 * s), rot=(180, 0, 0), mat=tooth)
