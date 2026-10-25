#!/usr/bin/env python3
"""
fig_slots.py -- generate images/01-seed-slot-grid.svg.

Purpose:
    Draw the 12-word seed as a grid of 12 cells, colored by what is known
    about each position (confirmed word, or unknown), plus a side panel for
    the 2 words confirmed to belong to the list but with no confirmed
    position. This is the structural summary of etat/contraintes.md C4 to C9.

Usage:
    python3 tools/fig_slots.py

Input:
    data/seed-slots.json (12 positional slots and the floating candidates).

Output:
    images/01-seed-slot-grid.svg
"""

import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DATA_PATH = os.path.join(ROOT, "data", "seed-slots.json")
OUT_PATH = os.path.join(ROOT, "images", "01-seed-slot-grid.svg")

CELL_W = 92
CELL_H = 70
GAP = 10
MARGIN = 30
FONT = "DejaVu Sans"

COLOR_CONFIRMED = "#1F5FBF"
COLOR_UNKNOWN = "#9A9A9A"
COLOR_CANDIDATE = "#E07A1F"
COLOR_TEXT = "#FFFFFF"
COLOR_TITLE = "#1a1a1a"
COLOR_BG = "#FFFFFF"

STATE_COLOR = {
    "confirmed": COLOR_CONFIRMED,
    "unknown": COLOR_UNKNOWN,
    "candidate": COLOR_CANDIDATE,
}


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def main():
    with open(DATA_PATH, encoding="utf-8") as f:
        data = json.load(f)
    slots = data["slots"]
    floating = data.get("floating", [])

    n = len(slots)
    width = MARGIN * 2 + n * CELL_W + (n - 1) * GAP
    height = 260

    parts = []
    parts.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
                 f'viewBox="0 0 {width} {height}" font-family="{FONT}">')
    parts.append(f'<rect x="0" y="0" width="{width}" height="{height}" fill="{COLOR_BG}"/>')
    parts.append(f'<text x="{MARGIN}" y="24" font-size="13" font-weight="bold" '
                 f'fill="{COLOR_TITLE}">12-word seed, position by position</text>')

    y = 40
    x = MARGIN
    for slot in slots:
        color = STATE_COLOR[slot["state"]]
        parts.append(f'<rect x="{x}" y="{y}" width="{CELL_W}" height="{CELL_H}" rx="8" '
                     f'fill="{color}" stroke="#222222" stroke-width="1.2"/>')
        parts.append(f'<text x="{x + CELL_W / 2}" y="{y + 16}" text-anchor="middle" '
                     f'font-size="10" fill="{COLOR_TEXT}" opacity="0.85">pos {slot["pos"]}</text>')
        label_lines = slot["label"].split(" | ")
        line_h = 14
        start_ty = y + CELL_H / 2 - (len(label_lines) - 1) * line_h / 2 + 8
        for li, line in enumerate(label_lines):
            parts.append(f'<text x="{x + CELL_W / 2}" y="{start_ty + li * line_h}" text-anchor="middle" '
                         f'font-size="12" fill="{COLOR_TEXT}">{esc(line)}</text>')
        x += CELL_W + GAP

    fy = y + CELL_H + 30
    parts.append(f'<text x="{MARGIN}" y="{fy}" font-size="12" fill="{COLOR_TITLE}">'
                 f'confirmed list members, position unknown:</text>')
    fx = MARGIN
    fy2 = fy + 14
    for cand in floating:
        w = 80
        parts.append(f'<rect x="{fx}" y="{fy2}" width="{w}" height="34" rx="6" '
                     f'fill="{COLOR_CANDIDATE}" stroke="#222222" stroke-width="1.2"/>')
        parts.append(f'<text x="{fx + w / 2}" y="{fy2 + 21}" text-anchor="middle" '
                     f'font-size="12" fill="{COLOR_TEXT}">{esc(cand["label"])}</text>')
        fx += w + 12

    legend_y = height - 24
    lx = MARGIN
    for label, color in (("confirmed (word + position)", COLOR_CONFIRMED),
                         ("candidate (word, position free)", COLOR_CANDIDATE),
                         ("unknown", COLOR_UNKNOWN)):
        parts.append(f'<rect x="{lx}" y="{legend_y}" width="14" height="14" fill="{color}"/>')
        parts.append(f'<text x="{lx + 20}" y="{legend_y + 11}" font-size="10" '
                     f'fill="{COLOR_TITLE}">{esc(label)}</text>')
        lx += 20 + 8 * len(label) + 20

    parts.append("</svg>")

    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    with open(OUT_PATH, "w", encoding="utf-8") as f:
        f.write("\n".join(parts))
    print(f"wrote {OUT_PATH} ({os.path.getsize(OUT_PATH)} bytes)")


if __name__ == "__main__":
    main()
