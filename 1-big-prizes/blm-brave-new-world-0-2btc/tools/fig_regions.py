#!/usr/bin/env python3
"""
fig_regions.py -- generates images/01-annotated-regions.png

Purpose:
    Draw the 3 measured regions listed in data/candidate-regions.json (dial, monument,
    rune column) as boxes over the published puzzle collage, so a reader can see where
    on the image the candidate signal sits without hunting through the full 1600x1200
    original. Every box and label comes from the data file; nothing here is invented.

Usage:
    python3 tools/fig_regions.py

Input:
    clues/welcome-to-the-brave-new-world.png (the published puzzle image)
    data/candidate-regions.json (region boxes and labels)

Output:
    images/01-annotated-regions.png
"""

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
REGIONS_FILE = ROOT / "data" / "candidate-regions.json"
OUT_FILE = ROOT / "images" / "01-annotated-regions.png"

ACCENT = (224, 122, 31)  # unknown/candidate orange, docs/illustrations.md palette


def main() -> None:
    with open(REGIONS_FILE, encoding="utf-8") as f:
        spec = json.load(f)

    art = Image.open(ROOT / spec["image"]).convert("RGB")

    # Downscale the artwork to keep the PNG under the illustration cap while staying legible.
    max_side = 900
    scale = min(1.0, max_side / max(art.size))
    if scale < 1.0:
        art = art.resize((int(art.width * scale), int(art.height * scale)), Image.LANCZOS)

    regions = spec["regions"]

    # Fonts.
    try:
        num_font = ImageFont.truetype("DejaVuSans-Bold.ttf", 22)
        leg_font = ImageFont.truetype("DejaVuSans.ttf", 18)
        leg_bold = ImageFont.truetype("DejaVuSans-Bold.ttf", 18)
    except OSError:
        num_font = leg_font = leg_bold = ImageFont.load_default()

    # Compose a canvas: the artwork on top, a white legend strip below. Labels live in the
    # legend, never on the artwork, so nothing can clip at an edge.
    line_h = 26
    legend_h = 20 + line_h * len(regions) + 12
    canvas = Image.new("RGB", (art.width, art.height + legend_h), (255, 255, 255))
    canvas.paste(art, (0, 0))
    draw = ImageDraw.Draw(canvas)

    def marker(cx, cy, n):
        r = 15
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=ACCENT, outline=(255, 255, 255), width=3)
        tw = draw.textlength(str(n), font=num_font)
        draw.text((cx - tw / 2, cy - 13), str(n), fill=(255, 255, 255), font=num_font)

    for i, region in enumerate(regions, 1):
        x0, y0, x1, y1 = [c * scale for c in region["box"]]
        draw.rectangle([x0, y0, x1, y1], outline=ACCENT, width=4)
        # Numbered marker at the top-left corner of the box, clamped inside the artwork.
        mx = min(max(x0, 16), art.width - 16)
        my = min(max(y0, 16), art.height - 16)
        marker(mx, my, i)

    # Legend strip.
    ly = art.height + 14
    for i, region in enumerate(regions, 1):
        marker(24, ly + 9, i)
        draw.text((46, ly), f'{region["label"]}', fill=(34, 34, 34), font=leg_font)
        ly += line_h

    OUT_FILE.parent.mkdir(exist_ok=True)
    quantized = canvas.quantize(colors=192, method=Image.MEDIANCUT)
    quantized.save(OUT_FILE, format="PNG", optimize=True)
    print(f"wrote {OUT_FILE} ({OUT_FILE.stat().st_size} bytes, {canvas.size})")


if __name__ == "__main__":
    main()
