#!/usr/bin/env python3
"""
fig_geometry.py -- generates images/01-annotated-geometry.png

Purpose:
    Draw the 12 measured building bounding boxes and the large sailboat bounding box
    over the published puzzle image, so a reader can see the geometry that was fed
    into the roughly 460 negative derivation candidates without re-running the
    measurement. Every box comes from data/geometry.json; nothing here is invented.

    Follows the numbered-callout + legend-strip pattern used across this repository
    (see tools/fig_regions.py in blm-brave-new-world-0-2btc): boxes are drawn on the
    artwork, but every label lives in a white legend strip appended below it, never
    on the artwork itself, so nothing can clip at an edge regardless of where a box
    sits in the frame. Long legend lines are word-wrapped to the canvas width, and the
    escrow address quoted in the decoy note is shortened to first6...last6 on the
    figure (the full address stays in clues/author-posts.md and the README prose).

Usage:
    python3 tools/fig_geometry.py

Input:
    clues/arweave-puzzle-11.png (the published puzzle image)
    data/geometry.json (measured bounding boxes)

Output:
    images/01-annotated-geometry.png
"""

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
DATA_FILE = ROOT / "data" / "geometry.json"
OUT_FILE = ROOT / "images" / "01-annotated-geometry.png"

CONFIRMED = (31, 95, 191)   # measured geometry, docs/illustrations.md "confirmed" blue
UNKNOWN = (224, 122, 31)    # decoy / unresolved, "unknown" orange
MARGIN = 20


def shorten_address(text: str) -> str:
    """Replace any 0x-prefixed hex address of 20+ hex chars with first6...last6."""
    import re

    def repl(m):
        addr = m.group(0)
        return f"{addr[:6]}...{addr[-6:]}"

    return re.sub(r"0x[0-9a-fA-F]{20,}", repl, text)


def wrap_line(draw, text, font, max_width):
    words = text.split(" ")
    lines = []
    cur = ""
    for w in words:
        candidate = (cur + " " + w).strip()
        if draw.textlength(candidate, font=font) <= max_width or not cur:
            cur = candidate
        else:
            lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def main() -> None:
    with open(DATA_FILE, encoding="utf-8") as f:
        spec = json.load(f)

    art = Image.open(ROOT / spec["image"]).convert("L").convert("RGB")

    # Downscale to keep the PNG under the 500 KB illustration cap.
    max_side = 1100
    scale = min(1.0, max_side / max(art.size))
    if scale < 1.0:
        art = art.resize((int(art.width * scale), int(art.height * scale)), Image.LANCZOS)

    buildings = spec["buildings"]
    sailboat = spec["large_sailboat"]
    sail_widths = spec["small_sail_widths_left_to_right_px"]
    decoy_note = shorten_address(spec["tEXt_decoy_note"])

    try:
        num_font = ImageFont.truetype("DejaVuSans-Bold.ttf", 16)
        leg_font = ImageFont.truetype("DejaVuSans.ttf", 16)
        leg_bold = ImageFont.truetype("DejaVuSans-Bold.ttf", 15)
    except OSError:
        num_font = leg_font = leg_bold = ImageFont.load_default()

    # Legend lines: one per building, one for the sailboat, plus two unpositioned notes.
    legend_lines = [f'building {b["id"]}: x {b["x0"]}-{b["x1"]}, y {b["roof_y"]}-{b["bottom_y"]}' for b in buildings]
    legend_lines.append(f'large sailboat: x {sailboat["x0"]}-{sailboat["x1"]}, y {sailboat["y0"]}-{sailboat["y1"]}')
    n_numbered = len(legend_lines)
    note_raw = [
        "5 small sail widths measured (px, left to right): " + ", ".join(str(w) for w in sail_widths)
        + " -- no reliable per-sail x position recovered, so not boxed above.",
        decoy_note,
    ]

    probe = Image.new("RGB", (10, 10))
    pdraw = ImageDraw.Draw(probe)
    note_max_w = art.width - 2 * MARGIN
    note_lines = []
    for raw in note_raw:
        note_lines.extend(wrap_line(pdraw, raw, leg_bold, note_max_w))

    # Compose the canvas: the artwork on top, a white legend strip below. Labels live in
    # the legend, never on the artwork, so nothing can clip at an edge.
    line_h = 24
    note_line_h = 22
    legend_h = 20 + line_h * n_numbered + 10 + note_line_h * len(note_lines) + 16
    canvas = Image.new("RGB", (art.width, art.height + legend_h), (255, 255, 255))
    canvas.paste(art, (0, 0))
    draw = ImageDraw.Draw(canvas)

    def marker(cx, cy, n, r=13):
        label = str(n)
        bbox = draw.textbbox((0, 0), label, font=num_font)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        # Grow the circle to fit multi-digit numbers so the digits never clip the ring.
        r = max(r, int(max(tw, th) / 2) + 6)
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=CONFIRMED, outline=(255, 255, 255), width=3)
        draw.text((cx - tw / 2 - bbox[0], cy - th / 2 - bbox[1]), label, fill=(255, 255, 255), font=num_font)

    for i, b in enumerate(buildings, 1):
        box = [b["x0"] * scale, b["roof_y"] * scale, b["x1"] * scale, b["bottom_y"] * scale]
        draw.rectangle(box, outline=CONFIRMED, width=2)
        mx = min(max(box[0], 20), art.width - 20)
        my = min(max(box[1], 20), art.height - 20)
        marker(mx, my, i)

    sbox = [sailboat["x0"] * scale, sailboat["y0"] * scale, sailboat["x1"] * scale, sailboat["y1"] * scale]
    draw.rectangle(sbox, outline=CONFIRMED, width=3)
    mx = min(max(sbox[0], 20), art.width - 20)
    my = min(max(sbox[1], 20), art.height - 20)
    marker(mx, my, n_numbered)

    # Legend strip: one numbered marker + line per box, then the two unpositioned notes.
    ly = art.height + 14
    for i, line in enumerate(legend_lines, 1):
        marker(24, ly + 10, i, r=11)
        draw.text((46, ly), line, fill=(34, 34, 34), font=leg_font)
        ly += line_h
    ly += 6
    for line in note_lines:
        draw.text((MARGIN, ly), line, fill=UNKNOWN, font=leg_bold)
        ly += note_line_h

    OUT_FILE.parent.mkdir(exist_ok=True)
    quantized = canvas.quantize(colors=192, method=Image.MEDIANCUT)
    quantized.save(OUT_FILE, format="PNG", optimize=True)
    print(f"wrote {OUT_FILE} ({OUT_FILE.stat().st_size} bytes, {canvas.size})")


if __name__ == "__main__":
    main()
