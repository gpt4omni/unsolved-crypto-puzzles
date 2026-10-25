#!/usr/bin/env python3
"""
fig_format_fork.py -- generates images/02-format-fork.svg

Purpose:
    Show the 3 coupled unknowns in the BLM derivation and the 2 candidate seed formats,
    each backed by a distinct set of words that appear only on that format's side of the
    fork. Every unknown, format name, path, and word list is read from
    data/format-fork.json, not hard-coded here.

    The unknowns row is measured before the canvas is sized (each box already sizes to
    its own label; the row as a whole now sizes the canvas, instead of a fixed 860px
    canvas that could run narrower than the row). The per-box footnote is word-wrapped
    to the box's own inner width instead of being drawn as a single unbroken line.

Usage:
    python3 tools/fig_format_fork.py

Input:
    data/format-fork.json

Output:
    images/02-format-fork.svg
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA_FILE = ROOT / "data" / "format-fork.json"
OUT_FILE = ROOT / "images" / "02-format-fork.svg"

ORANGE = "#E07A1F"   # unknown
BLUE = "#1F5FBF"     # confirmed structure (paths are confirmed derivation code, not answers)
GRAY = "#9A9A9A"
INK = "#222222"

CHAR_W = 0.62


def wrap_words(words, per_line=5):
    lines = []
    for i in range(0, len(words), per_line):
        lines.append(", ".join(words[i:i + per_line]))
    return lines


def wrap_line(text, font_size, max_width):
    max_chars = max(1, int(max_width / (font_size * CHAR_W)))
    words = text.split(" ")
    lines, cur = [], ""
    for w in words:
        trial = (cur + " " + w).strip()
        if len(trial) > max_chars and cur:
            lines.append(cur)
            cur = w
        else:
            cur = trial
    if cur:
        lines.append(cur)
    return lines


def main() -> None:
    with open(DATA_FILE, encoding="utf-8") as f:
        spec = json.load(f)

    unknowns = spec["unknowns"]
    formats = spec["formats"]

    title = "3 coupled unknowns, 2 candidate formats"
    title_font = 20

    # Two format boxes (fixed size; the exclusive-word lists and footnote are all
    # comfortably shorter than the box width once wrapped).
    box_w, box_h = 380, 340
    gap = 40
    formats_w = box_w * 2 + gap

    # Unknowns row: each box already sizes to its own "N. label" text (matches
    # docs/illustrations.md's box-sizing method: font_size * 0.62 per char + padding).
    # Measure the row's total width so the canvas can be sized to fit it, instead of
    # assuming a fixed canvas width.
    ux = 110
    unknown_boxes = []
    for i, unk in enumerate(unknowns):
        label = f"{i + 1}. {unk}"
        bw = int(len(label) * 13 * CHAR_W) + 24
        unknown_boxes.append((ux, bw, label))
        ux += bw + 16
    row_right = ux - 16

    content_w = max(formats_w, row_right, int(len(title) * title_font * CHAR_W))
    width = content_w + 40  # left margin (20) + right margin (20)
    height = 560

    parts = []
    parts.append(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}" font-family="DejaVu Sans, sans-serif">'
    )
    parts.append(f'<rect x="0" y="0" width="{width}" height="{height}" fill="#FFFFFF"/>')

    # Title
    parts.append(f'<text x="20" y="32" font-size="{title_font}" font-weight="bold" fill="{INK}">'
                  f'{title}</text>')

    # Unknowns row
    parts.append(f'<text x="20" y="64" font-size="14" fill="{INK}">Unknown:</text>')
    for bx, bw, label in unknown_boxes:
        parts.append(f'<rect x="{bx}" y="46" width="{bw}" height="28" rx="6" '
                      f'fill="none" stroke="{ORANGE}" stroke-width="2"/>')
        parts.append(f'<text x="{bx + bw / 2}" y="65" font-size="13" fill="{INK}" '
                      f'text-anchor="middle">{label}</text>')

    # Arrow down to the fork
    parts.append(f'<line x1="{width / 2}" y1="90" x2="{width / 2}" y2="130" '
                  f'stroke="{INK}" stroke-width="2" marker-end="url(#arrow)"/>')
    parts.append('<defs><marker id="arrow" markerWidth="10" markerHeight="10" '
                  'refX="6" refY="3" orient="auto"><path d="M0,0 L6,3 L0,6 Z" '
                  f'fill="{INK}"/></marker></defs>')
    parts.append(f'<text x="{width / 2}" y="122" font-size="13" fill="{INK}" '
                  f'text-anchor="middle">which format?</text>')

    total_w = formats_w
    x0 = (width - total_w) / 2
    y0 = 150
    inner_w = box_w - 32  # left/right padding of 16px each inside the box
    for i, fmt in enumerate(formats):
        bx = x0 + i * (box_w + gap)
        parts.append(f'<rect x="{bx}" y="{y0}" width="{box_w}" height="{box_h}" rx="10" '
                      f'fill="none" stroke="{BLUE}" stroke-width="2"/>')
        parts.append(f'<text x="{bx + box_w / 2}" y="{y0 + 34}" font-size="17" '
                      f'font-weight="bold" fill="{INK}" text-anchor="middle">{fmt["name"]}</text>')
        parts.append(f'<text x="{bx + box_w / 2}" y="{y0 + 58}" font-size="13" fill="{INK}" '
                      f'text-anchor="middle">{fmt["path"]}</text>')
        parts.append(f'<text x="{bx + 16}" y="{y0 + 90}" font-size="13" fill="{INK}">'
                      f'Exclusive words on the image ({len(fmt["exclusive_words"])}):</text>')
        ty = y0 + 114
        for line in wrap_words(fmt["exclusive_words"], per_line=3):
            parts.append(f'<text x="{bx + 16}" y="{ty}" font-size="13" fill="{ORANGE}">{line}</text>')
            ty += 22

        footnote = "settled if one of these words is confirmed as a real seed word"
        footnote_lines = wrap_line(footnote, 12, inner_w)
        fy0 = y0 + box_h - 20 - (len(footnote_lines) - 1) * 16
        for li, line in enumerate(footnote_lines):
            parts.append(f'<text x="{bx + 16}" y="{fy0 + li * 16}" font-size="12" fill="{GRAY}">'
                          f'{line}</text>')

    parts.append('</svg>')

    OUT_FILE.parent.mkdir(exist_ok=True)
    OUT_FILE.write_text("\n".join(parts), encoding="utf-8")
    print(f"wrote {OUT_FILE} ({OUT_FILE.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
