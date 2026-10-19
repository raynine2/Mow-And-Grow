"""Glowing floor outline (the neon rectangle that marks where to stand): four thin Neon bars `w` x `d` around the
model origin, 0.12 high. The glow_*.py files pick the size; the game recolours the bars."""


def outline(lib, w, d, rgb=(40, 230, 255)):
    neon = lib.material("Neon", rgb)
    for name, x, y, sx, sy in (("n", 0, d / 2, w + 0.4, 0.4), ("s", 0, -d / 2, w + 0.4, 0.4),
                               ("e", w / 2, 0, 0.4, d - 0.4), ("w", -w / 2, 0, 0.4, d - 0.4)):
        lib.box("bar_" + name, (sx, sy, 0.12), (x, y, 0.06), mat=neon)
