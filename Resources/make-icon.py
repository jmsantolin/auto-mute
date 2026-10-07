#!/usr/bin/env python3
"""Génère Resources/AppIcon.icns : haut-parleur barré sur fond dégradé."""
import math, os, subprocess, tempfile
from PIL import Image, ImageDraw

S = 1024
M = 100                      # marge (les icônes macOS ne touchent pas le bord)
R = 230                      # rayon des coins


def gradient(size, top, bottom):
    img = Image.new("RGB", (1, size))
    for y in range(size):
        t = y / (size - 1)
        img.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return img.resize((size, size))


def base():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    bg = gradient(S, (94, 92, 230), (40, 38, 110)).convert("RGBA")
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([M, M, S - M, S - M], radius=R, fill=255)
    img.paste(bg, (0, 0), mask)
    return img


def rounded_line(d, p1, p2, width, fill):
    d.line([p1, p2], fill=fill, width=width)
    for (x, y) in (p1, p2):
        r = width / 2
        d.ellipse([x - r, y - r, x + r, y + r], fill=fill)


def glyph(img):
    d = ImageDraw.Draw(img)
    w = (255, 255, 255, 255)
    dark = (34, 32, 92, 255)
    # corps du haut-parleur + pavillon
    d.rounded_rectangle([286, 442, 392, 582], radius=16, fill=w)
    d.polygon([(380, 452), (530, 318), (530, 706), (380, 572)], fill=w)
    d.rounded_rectangle([508, 318, 538, 706], radius=15, fill=w)
    # ondes sonores
    for r in (112, 196):
        box = [596 - r, 512 - r, 596 + r, 512 + r]
        d.arc(box, start=-54, end=54, fill=w, width=40)
    # barre oblique, détachée du reste par un liseré sombre
    rounded_line(d, (300, 288), (772, 760), 124, dark)
    rounded_line(d, (300, 288), (772, 760), 58, w)
    return img


icon = glyph(base())

with tempfile.TemporaryDirectory() as tmp:
    iconset = os.path.join(tmp, "AppIcon.iconset")
    os.mkdir(iconset)
    for size in (16, 32, 64, 128, 256, 512):
        icon.resize((size, size), Image.LANCZOS).save(f"{iconset}/icon_{size}x{size}.png")
        icon.resize((size * 2, size * 2), Image.LANCZOS).save(f"{iconset}/icon_{size}x{size}@2x.png")
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "AppIcon.icns")
    subprocess.run(["iconutil", "-c", "icns", iconset, "-o", out], check=True)
    icon.resize((512, 512), Image.LANCZOS).save(
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "icon-preview.png"))
    print("écrit", out)
