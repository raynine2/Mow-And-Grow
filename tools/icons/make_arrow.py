"""The coach's pointer arrow (client/Coach: beside the UPGRADES button), drawn in the HUD icons' glossy cartoon style
(assets/icons: a dark brown outline, a darker extruded side, a light inner rim, a gloss streak, a sparkle or two).

    python3 tools/icons/make_arrow.py            -> assets/icons/arrow_point.png (512 x 320, pointing right)

Drawn at 4x and scaled down so every edge is smooth. (Owner, 4 Nov, on the old one, a yellow bar and a turned
square: "make this a good arrow".)
"""
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

S = 4  # supersampling
W, H = 512, 320
OUTLINE = (59, 35, 22, 255)
SIDE = (226, 112, 40, 255)
SIDE_DARK = (196, 86, 30, 255)
TOP = (255, 226, 96)
BOTTOM = (247, 176, 40)
RIM = (255, 244, 186, 255)


def shape_mask(dx=0.0, dy=0.0, grow=0.0):
    """The arrow's outline (pointing right) as an L mask at W*S x H*S, rounded, moved by (dx, dy), grown by `grow` px."""
    w, h = W * S, H * S
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    # in 512 x 320 units: a chunky shaft from x 44, y 104..216, the head from x 250 to 462, y 40..280
    pts = [(44, 104), (250, 104), (250, 40), (462, 160), (250, 280), (250, 216), (44, 216)]
    d.polygon([((x + dx) * S, (y + dy) * S) for x, y in pts], fill=255)
    # round the corners: blur, then cut at the middle (grow by cutting lower)
    r = 14 * S
    m = m.filter(ImageFilter.GaussianBlur(r))
    cut = 128 - grow * 9
    return m.point(lambda v: 255 if v > cut else 0)


def gradient(mask, top, bottom):
    w, h = mask.size
    g = Image.new("RGBA", (w, h))
    px = []
    for y in range(h):
        k = y / (h - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * k) for i in range(3))
        px.append(c + (255,))
    col = Image.new("RGBA", (1, h))
    col.putdata(px)
    g = col.resize((w, h))
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(g, (0, 0), mask)
    return out


def sparkle(d, cx, cy, r):
    cx, cy, r = cx * S, cy * S, r * S
    d.polygon([(cx, cy - r), (cx + r * 0.22, cy - r * 0.22), (cx + r, cy), (cx + r * 0.22, cy + r * 0.22), (cx, cy + r),
               (cx - r * 0.22, cy + r * 0.22), (cx - r, cy), (cx - r * 0.22, cy - r * 0.22)], fill=(255, 255, 255, 235))


def main():
    w, h = W * S, H * S
    face = shape_mask(-6, -9)
    side = shape_mask(5, 8)
    body = ImageChops.lighter(face, side)
    outline = body.filter(ImageFilter.MaxFilter(1 + 2 * (15 * S // 2)))
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    img.paste(Image.new("RGBA", (w, h), OUTLINE), (0, 0), outline)
    # the extruded side: darker toward its far edge
    img.paste(gradient(side, SIDE[:3], SIDE_DARK[:3]), (0, 0), side)
    # a dark seam where the face sits on the side
    seam = face.filter(ImageFilter.MaxFilter(1 + 2 * (5 * S // 2)))
    img.paste(Image.new("RGBA", (w, h), OUTLINE), (0, 0), ImageChops.subtract(seam, face))
    # the face, top-lit gold
    img.paste(gradient(face, TOP, BOTTOM), (0, 0), face)
    # the light inner rim along the face's edge
    inner = face.filter(ImageFilter.MinFilter(1 + 2 * (7 * S // 2)))
    inner2 = inner.filter(ImageFilter.MinFilter(1 + 2 * (4 * S // 2)))
    rim = ImageChops.subtract(inner, inner2)
    rimimg = Image.new("RGBA", (w, h), RIM)
    rimimg.putalpha(rim.point(lambda v: int(v * 0.85)))
    img.alpha_composite(rimimg)
    # the gloss: a soft white streak along the top of the shaft and up the head's upper edge
    gloss = Image.new("L", (w, h), 0)
    gd = ImageDraw.Draw(gloss)
    gd.rounded_rectangle([62 * S, 110 * S, 226 * S, 128 * S], radius=9 * S, fill=205)
    gd.polygon([(260 * S, 60 * S), (276 * S, 58 * S), (414 * S, 138 * S), (398 * S, 145 * S)], fill=175)
    gloss = gloss.filter(ImageFilter.GaussianBlur(2 * S))
    gloss = ImageChops.multiply(gloss, inner)
    g = Image.new("RGBA", (w, h), (255, 255, 255, 255))
    g.putalpha(gloss)
    img.alpha_composite(g)
    d = ImageDraw.Draw(img)
    sparkle(d, 96, 172, 14)
    sparkle(d, 124, 192, 8)
    out = img.resize((W, H), Image.LANCZOS)
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    path = os.path.join(root, "assets", "icons", "arrow_point.png")
    out.save(path)
    print(path, out.size)


if __name__ == "__main__":
    main()
