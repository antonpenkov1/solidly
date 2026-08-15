#!/usr/bin/env python3
"""Builds AppIcon.icon — the layered Liquid Glass icon for iOS 26+.

    python3 Tools/make_glass_icon.py --list
    python3 Tools/make_glass_icon.py --install bowl-spoon
    python3 Tools/make_glass_icon.py --preview serif-t     # into IconDrafts/

A Liquid Glass icon is not a flat PNG. The system composites the layers itself, adding the
glass material, the specular highlights, the drop shadow and the gradient, and derives the
light, dark and tinted 1024s from the same artwork. That only happens if it is handed
*layers* on transparency plus a background fill — a baked PNG is passed through untouched
and reads as an iOS 18 icon sitting on an iOS 26 home screen.

So nothing here draws a highlight, a bevel or a shadow: all of that is the system's job,
and drawing our own would fight it. The layers are flat cream silhouettes, nothing more.

Confirmed by what actool writes into Assets.car: AppIcon1024x1024_UIAppearanceAny,
_UIAppearanceDark and _ISAppearanceTintable, plus AppIcon.iconstack and the legacy 60/76pt
sizes that keep the iOS 17 deployment target working.
"""
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
BUNDLE = ROOT / "AppIcon.icon"

SIZE = 1024
SS = 4
W = SIZE * SS
CREAM = (255, 253, 247, 255)
SERIF = "/System/Library/Fonts/Supplemental/Georgia Bold.ttf"

# Sage, as display-p3 with the alpha actool insists on: three components fail the build with
# "Expected four comma separated color components", which is what the first attempt hit.
SAGE_FILL = "display-p3:0.17255,0.35294,0.27451,1.0"
INK_FILL = "display-p3:0.12941,0.11373,0.09804,1.0"

# Apple's icon grid keeps artwork off the edge; the glass edge treatment needs the room.
BLEED = 0.86


def blank():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def done(img):
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def scaled(img, factor=BLEED):
    """Shrinks the artwork about the centre without changing the canvas."""
    small = img.resize((int(W * factor), int(W * factor)), Image.LANCZOS)
    out = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    offset = (W - small.width) // 2
    out.paste(small, (offset, offset), small)
    return out


# ---------------------------------------------------------------- layer artwork

def bowl_and_spoon():
    bowl, bd = blank()
    cx, cy = W // 2, int(W * 0.58)
    r = int(W * 0.30)
    bd.pieslice([cx - r, cy - r, cx + r, cy + r], 0, 180, fill=CREAM)
    rim_w, rim_h = int(r * 2.30), int(W * 0.056)
    bd.rounded_rectangle([cx - rim_w // 2, cy - rim_h // 2, cx + rim_w // 2, cy + rim_h // 2],
                         radius=rim_h // 2, fill=CREAM)

    spoon, sd = blank()
    tip = (cx + int(r * 0.96), cy - int(r * 1.20))
    tail = (cx + int(r * 0.28), cy - int(r * 0.06))
    sd.line([tail, tip], fill=CREAM, width=int(W * 0.042))
    hr = int(W * 0.072)
    sd.ellipse([tip[0] - hr, tip[1] - int(hr * 1.28),
                tip[0] + hr, tip[1] + int(hr * 1.28)], fill=CREAM)

    return [("Spoon", done(scaled(spoon))), ("Bowl", done(scaled(bowl)))], SAGE_FILL


def serif_t():
    img, d = blank()
    try:
        font = ImageFont.truetype(SERIF, int(W * 0.60))
    except OSError:
        font = ImageFont.load_default()
    box = d.textbbox((0, 0), "T", font=font)
    d.text(((W - (box[2] - box[0])) / 2 - box[0],
            (W - (box[3] - box[1])) / 2 - box[1]), "T", font=font, fill=CREAM)
    return [("Letter", done(scaled(img, 0.94)))], INK_FILL


def bowl_above():
    ring, rd = blank()
    cx, cy = W // 2, W // 2
    outer, thickness = int(W * 0.33), int(W * 0.072)
    rd.ellipse([cx - outer, cy - outer, cx + outer, cy + outer], fill=CREAM)
    inner = outer - thickness
    rd.ellipse([cx - inner, cy - inner, cx + inner, cy + inner], fill=(0, 0, 0, 0))

    spoon, sd = blank()
    head, tail = (cx, int(W * 0.30)), (cx, int(W * 0.68))
    sd.line([head, tail], fill=CREAM, width=int(W * 0.044))
    hr = int(W * 0.082)
    sd.ellipse([head[0] - hr, head[1] - int(hr * 1.28),
                head[0] + hr, head[1] + int(hr * 1.28)], fill=CREAM)
    spoon = spoon.rotate(-28, resample=Image.BICUBIC, center=(cx, cy))

    return [("Spoon", done(scaled(spoon))), ("Ring", done(scaled(ring)))], SAGE_FILL


def bowl_portions():
    bars, bd = blank()
    cx, cy = W // 2, int(W * 0.62)
    heights = [0.15, 0.24, 0.33]
    bar_w, gap = int(W * 0.072), int(W * 0.036)
    total = len(heights) * bar_w + (len(heights) - 1) * gap
    x = cx - total // 2
    for h in heights:
        bd.rounded_rectangle([x, cy - int(W * h), x + bar_w, cy],
                             radius=bar_w // 2, fill=CREAM)
        x += bar_w + gap

    bowl, wd = blank()
    r = int(W * 0.31)
    wd.pieslice([cx - r, cy - r, cx + r, cy + r], 0, 180, fill=CREAM)
    rim_w, rim_h = int(r * 2.30), int(W * 0.056)
    wd.rounded_rectangle([cx - rim_w // 2, cy - rim_h // 2, cx + rim_w // 2, cy + rim_h // 2],
                         radius=rim_h // 2, fill=CREAM)

    return [("Portions", done(scaled(bars))), ("Bowl", done(scaled(bowl)))], SAGE_FILL


CONCEPTS = {
    "bowl-spoon": ("Bowl and spoon, the mark the app already uses", bowl_and_spoon),
    "serif-t": ("Serif T, matching the app's serif headings", serif_t),
    "bowl-above": ("Bowl seen from above, spoon resting inside", bowl_above),
    "bowl-portions": ("Bowl holding three rising portions", bowl_portions),
}


def manifest(layers, fill):
    entries = ",\n".join(
        f'        {{\n          "image-name" : "{name}.png",\n          "name" : "{name}"\n        }}'
        for name, _ in layers
    )
    return f"""{{
  "fill" : {{
    "automatic-gradient" : "{fill}"
  }},
  "groups" : [
    {{
      "layers" : [
{entries}
      ],
      "shadow" : {{
        "kind" : "neutral",
        "opacity" : 0.5
      }},
      "specular" : true,
      "translucency" : {{
        "enabled" : true,
        "value" : 0.5
      }}
    }}
  ],
  "supported-platforms" : {{
    "circles" : [
      "watchOS"
    ],
    "squares" : "shared"
  }}
}}
"""


def build(concept: str, bundle: Path):
    if concept not in CONCEPTS:
        raise SystemExit(f"unknown concept '{concept}' — try --list")
    layers, fill = CONCEPTS[concept][1]()

    if bundle.exists():
        shutil.rmtree(bundle)
    assets = bundle / "Assets"
    assets.mkdir(parents=True)
    for name, image in layers:
        image.save(assets / f"{name}.png")
    (bundle / "icon.json").write_text(manifest(layers, fill))
    print(f"built {bundle.name} from '{concept}' ({len(layers)} layers)")


def main() -> int:
    args = sys.argv[1:]
    if not args or args[0] == "--list":
        for key, (blurb, _) in CONCEPTS.items():
            print(f"  {key:15} {blurb}")
        return 0
    if args[0] == "--install" and len(args) > 1:
        build(args[1], BUNDLE)
        return 0
    if args[0] == "--preview" and len(args) > 1:
        build(args[1], ROOT / "IconDrafts" / f"{args[1]}.icon")
        return 0
    raise SystemExit("usage: --list | --install <concept> | --preview <concept>")


if __name__ == "__main__":
    raise SystemExit(main())
