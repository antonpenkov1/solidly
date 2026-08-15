#!/usr/bin/env python3
"""Draws candidate app icons and a contact sheet at real home-screen size.

    python3 Tools/make_icons.py

Writes IconDrafts/<letter>-<name>.png at 1024, plus IconDrafts/_sheet-large.png and
IconDrafts/_sheet-home.png. The home sheet is the one that decides: an icon lives at
about 60pt, and everything that only works at 1024 dies there.

Once a variant wins:  python3 Tools/make_icons.py --install <letter>
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
DRAFTS = ROOT / "IconDrafts"
SS = 4                       # supersample factor
SIZE = 1024

# The app's palette, so the icon belongs to the same object as the interface.
OAT = (250, 245, 235)
CREAM = (255, 253, 247)
SAGE = (62, 118, 92)
SAGE_DEEP = (44, 90, 70)
INK = (33, 29, 25)
AMBER = (180, 121, 33)

SERIF = "/System/Library/Fonts/Supplemental/Georgia Bold.ttf"


def canvas(bg):
    img = Image.new("RGB", (SIZE * SS, SIZE * SS), bg)
    return img, ImageDraw.Draw(img)


def finish(img):
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def spoon(d, W, tip, handle_end, width, bowl_r, colour):
    """A spoon drawn as a thick line plus an ellipse head."""
    d.line([handle_end, tip], fill=colour, width=width)
    d.ellipse([tip[0] - bowl_r, tip[1] - int(bowl_r * 1.28),
               tip[0] + bowl_r, tip[1] + int(bowl_r * 1.28)], fill=colour)


# ---------------------------------------------------------------- variants

def variant_a():
    """Bowl and spoon, with the contrast bug fixed: the spoon is dark, not cream."""
    img, d = canvas(OAT)
    W = SIZE * SS
    cx, cy = W // 2, int(W * 0.55)
    r = int(W * 0.31)
    d.pieslice([cx - r, cy - r, cx + r, cy + r], 0, 180, fill=SAGE)
    rim_w, rim_h = int(W * 0.70), int(W * 0.058)
    d.rounded_rectangle([cx - rim_w // 2, cy - rim_h // 2, cx + rim_w // 2, cy + rim_h // 2],
                        radius=rim_h // 2, fill=SAGE_DEEP)
    spoon(d, W, (cx + int(r * 1.00), cy - int(r * 1.26)),
          (cx + int(r * 0.30), cy - int(r * 0.10)),
          int(W * 0.045), int(W * 0.078), SAGE_DEEP)
    return finish(img), "bowl-spoon-dark"


def variant_b():
    """Inverted: deep sage field, cream bowl. Highest contrast of the set."""
    img, d = canvas(SAGE_DEEP)
    W = SIZE * SS
    cx, cy = W // 2, int(W * 0.55)
    r = int(W * 0.31)
    d.pieslice([cx - r, cy - r, cx + r, cy + r], 0, 180, fill=CREAM)
    rim_w, rim_h = int(W * 0.70), int(W * 0.058)
    d.rounded_rectangle([cx - rim_w // 2, cy - rim_h // 2, cx + rim_w // 2, cy + rim_h // 2],
                        radius=rim_h // 2, fill=OAT)
    spoon(d, W, (cx + int(r * 1.00), cy - int(r * 1.26)),
          (cx + int(r * 0.30), cy - int(r * 0.10)),
          int(W * 0.045), int(W * 0.078), CREAM)
    return finish(img), "inverted-sage"


def variant_c():
    """Just a spoon, tilted, with cutlery proportions — a long thin handle and an egg
    head. Drawn straight and stubby it read as a thermometer."""
    img, d = canvas(OAT)
    W = SIZE * SS
    cx, cy = W // 2, W // 2

    layer = Image.new("RGB", (W, W), OAT)
    ld = ImageDraw.Draw(layer)
    head = (cx, int(W * 0.24))
    tail = (cx, int(W * 0.80))
    ld.line([head, tail], fill=SAGE, width=int(W * 0.058))
    hr = int(W * 0.115)
    ld.ellipse([head[0] - hr, head[1] - int(hr * 1.30),
                head[0] + hr, head[1] + int(hr * 1.30)], fill=SAGE)
    # Rotating the finished shape keeps the head an even oval; drawing it on a diagonal
    # would flatten it.
    layer = layer.rotate(-22, resample=Image.BICUBIC, center=(cx, cy), fillcolor=OAT)
    return finish(layer), "spoon-only"


def variant_d():
    """A bowl holding three rising portions. Food and measurement in one shape — the loose
    line-and-dots version read as a squiggle floating above a bowl."""
    img, d = canvas(OAT)
    W = SIZE * SS
    cx, cy = W // 2, int(W * 0.60)
    r = int(W * 0.32)

    heights = [0.16, 0.26, 0.36]
    bar_w = int(W * 0.075)
    gap = int(W * 0.038)
    total = len(heights) * bar_w + (len(heights) - 1) * gap
    x = cx - total // 2
    for h in heights:
        top = cy - int(W * h)
        d.rounded_rectangle([x, top, x + bar_w, cy], radius=bar_w // 2, fill=SAGE_DEEP)
        x += bar_w + gap

    # The bowl is drawn last so the bars appear to sit inside it.
    d.pieslice([cx - r, cy - r, cx + r, cy + r], 0, 180, fill=SAGE)
    rim_w, rim_h = int(W * 0.72), int(W * 0.060)
    d.rounded_rectangle([cx - rim_w // 2, cy - rim_h // 2, cx + rim_w // 2, cy + rim_h // 2],
                        radius=rim_h // 2, fill=SAGE_DEEP)
    return finish(img), "bowl-portions"


def variant_e():
    """A serif T on sage, in the same voice as the app's serif headings. The small bowl
    that used to sit under it read as a smudge at icon size, so it is gone."""
    img, d = canvas(SAGE_DEEP)
    W = SIZE * SS
    try:
        font = ImageFont.truetype(SERIF, int(W * 0.66))
    except OSError:
        font = ImageFont.load_default()
    box = d.textbbox((0, 0), "T", font=font)
    d.text(((W - (box[2] - box[0])) / 2 - box[0],
            (W - (box[3] - box[1])) / 2 - box[1]), "T", font=font, fill=OAT)
    return finish(img), "serif-t"


def variant_f():
    """The bowl seen from above, with the spoon resting inside it. Laid across the whole
    ring it read as a prohibition sign — which is a very bad thing for a feeding app."""
    img, d = canvas(OAT)
    W = SIZE * SS
    cx, cy = W // 2, W // 2
    outer = int(W * 0.34)
    d.ellipse([cx - outer, cy - outer, cx + outer, cy + outer], fill=SAGE)

    layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    head = (cx, int(W * 0.30))
    tail = (cx, int(W * 0.68))
    ld.line([head, tail], fill=CREAM, width=int(W * 0.046))
    hr = int(W * 0.085)
    ld.ellipse([head[0] - hr, head[1] - int(hr * 1.30),
                head[0] + hr, head[1] + int(hr * 1.30)], fill=CREAM)
    layer = layer.rotate(-28, resample=Image.BICUBIC, center=(cx, cy))
    img.paste(layer, (0, 0), layer)
    return finish(img), "bowl-above"


VARIANTS = [
    ("A", variant_a), ("B", variant_b), ("C", variant_c),
    ("D", variant_d), ("E", variant_e), ("F", variant_f),
]


# ---------------------------------------------------------------- sheets

def rounded(img, size, radius_ratio=0.2237):
    """iOS squircle, approximated with a rounded rectangle — close enough to judge."""
    small = img.resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size * 4 - 1, size * 4 - 1],
        radius=int(size * 4 * radius_ratio), fill=255)
    mask = mask.resize((size, size), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(small, (0, 0), mask)
    return out


def sheet(images, tile, gap, label_h, bg, path):
    cols = len(images)
    width = gap + cols * (tile + gap)
    height = gap + tile + label_h + gap
    canvas_img = Image.new("RGB", (width, height), bg)
    d = ImageDraw.Draw(canvas_img)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Georgia Bold.ttf",
                                  max(11, tile // 6))
    except OSError:
        font = ImageFont.load_default()

    for index, (letter, img) in enumerate(images):
        x = gap + index * (tile + gap)
        canvas_img.paste(rounded(img, tile), (x, gap), rounded(img, tile))
        box = d.textbbox((0, 0), letter, font=font)
        d.text((x + (tile - (box[2] - box[0])) / 2, gap + tile + 8),
               letter, font=font, fill=(120, 113, 102))
    canvas_img.save(path)
    print("wrote", path)


def main() -> int:
    DRAFTS.mkdir(exist_ok=True)

    if len(sys.argv) > 2 and sys.argv[1] == "--install":
        wanted = sys.argv[2].upper()
        for letter, fn in VARIANTS:
            if letter == wanted:
                img, name = fn()
                target = ROOT / "Tummi" / "Assets.xcassets" / "AppIcon.appiconset" / "icon-1024.png"
                img.save(target)
                print(f"installed variant {letter} ({name}) → {target}")
                return 0
        raise SystemExit(f"unknown variant '{wanted}'")

    rendered = []
    for letter, fn in VARIANTS:
        img, name = fn()
        path = DRAFTS / f"{letter}-{name}.png"
        img.save(path)
        print("wrote", path.name)
        rendered.append((letter, img))

    # 180px is a 60pt icon at @3x — the size that actually decides.
    sheet(rendered, tile=180, gap=26, label_h=34, bg=(238, 233, 224),
          path=DRAFTS / "_sheet-home.png")
    sheet(rendered, tile=300, gap=30, label_h=48, bg=(238, 233, 224),
          path=DRAFTS / "_sheet-large.png")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
