#!/usr/bin/env python3
"""Draws the Tummi app icon: a sage bowl with a spoon resting in it, on warm oat.

Deliberately not a cartoon baby or a pastel rattle — the app carries clinical guidance
and the icon should read as calm and grown-up on a home screen full of trackers.
"""
from PIL import Image, ImageDraw
import sys, os

S = 1024
SS = 4                      # supersample for clean curves
W = S * SS

OAT = (250, 245, 235)
SAGE = (62, 118, 92)
SAGE_DEEP = (44, 90, 70)
CREAM = (255, 253, 247)

img = Image.new("RGB", (W, W), OAT)
d = ImageDraw.Draw(img)

cx, cy = W // 2, int(W * 0.53)

# Bowl: a half-disc with a flat rim.
r = int(W * 0.30)
d.pieslice([cx - r, cy - r, cx + r, cy + r], start=0, end=180, fill=SAGE)

# Rim, slightly wider than the bowl so it reads as a lip.
rim_w = int(W * 0.68)
rim_h = int(W * 0.055)
d.rounded_rectangle(
    [cx - rim_w // 2, cy - rim_h // 2, cx + rim_w // 2, cy + rim_h // 2],
    radius=rim_h // 2, fill=SAGE_DEEP,
)

# Spoon leaning out of the bowl to the upper right.
handle_w = int(W * 0.038)
d.line([(cx + int(r * 0.35), cy - int(r * 0.15)),
        (cx + int(r * 1.08), cy - int(r * 1.25))],
       fill=CREAM, width=handle_w)
bowl_r = int(W * 0.072)
d.ellipse([cx + int(r * 1.08) - bowl_r, cy - int(r * 1.25) - int(bowl_r * 1.25),
           cx + int(r * 1.08) + bowl_r, cy - int(r * 1.25) + int(bowl_r * 1.25)],
          fill=CREAM)

# Three rising dots — the portion growing month by month.
dot_r = int(W * 0.021)
for i, (dx, dy) in enumerate([(-0.62, -0.86), (-0.44, -1.02), (-0.26, -1.18)]):
    x = cx + int(r * dx)
    y = cy + int(r * dy)
    d.ellipse([x - dot_r, y - dot_r, x + dot_r, y + dot_r], fill=SAGE_DEEP)

img = img.resize((S, S), Image.LANCZOS)
out = sys.argv[1] if len(sys.argv) > 1 else "icon-1024.png"
img.save(out)
print("wrote", out, os.path.getsize(out), "bytes")
