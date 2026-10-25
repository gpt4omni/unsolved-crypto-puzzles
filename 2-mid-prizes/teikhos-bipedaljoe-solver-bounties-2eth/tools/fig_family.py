#!/usr/bin/env python3
"""
fig_family.py -- generate images/02-family-map.svg.

Purpose:
    Draw the 5 TeikhosBounty contracts as a row of boxes, one per contract, colored by
    state (solved by me, open, dead) and labeled with balance and masking variant.

Usage:
    python3 tools/fig_family.py

Input:
    data/contracts.csv (tag, address, eth, variant, state).

Output:
    images/02-family-map.svg
"""

import csv
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DATA_PATH = os.path.join(ROOT, "data", "contracts.csv")
OUT_PATH = os.path.join(ROOT, "images", "02-family-map.svg")

COLOR_SOLVED = "#1F5FBF"
COLOR_OPEN = "#E07A1F"
COLOR_DEAD = "#9A9A9A"
COLOR_TEXT = "#FFFFFF"
COLOR_BG = "#FFFFFF"
FONT = "DejaVu Sans"

STATE_COLOR = {"solved": COLOR_SOLVED, "open": COLOR_OPEN, "dead": COLOR_DEAD}
STATE_LABEL = {"solved": "solved (me)", "open": "open", "dead": "dead, no payout path"}

BOX_W = 190
BOX_H = 110
GAP = 20
MARGIN = 30


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def main():
    with open(DATA_PATH, encoding="utf-8") as f:
        rows = list(csv.DictReader(line for line in f if not line.startswith("#")))

    n = len(rows)
    width = MARGIN * 2 + n * BOX_W + (n - 1) * GAP
    height = MARGIN * 2 + BOX_H + 40

    parts = []
    parts.append(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}" font-family="{FONT}">'
    )
    parts.append(f'<rect x="0" y="0" width="{width}" height="{height}" fill="{COLOR_BG}"/>')

    x = MARGIN
    y = MARGIN
    for r in rows:
        color = STATE_COLOR[r["state"]]
        parts.append(
            f'<rect x="{x}" y="{y}" width="{BOX_W}" height="{BOX_H}" rx="8" '
            f'fill="{color}" stroke="#222222" stroke-width="1"/>'
        )
        parts.append(
            f'<text x="{x + BOX_W/2}" y="{y + 24}" text-anchor="middle" font-size="15" '
            f'font-weight="bold" fill="{COLOR_TEXT}">{esc(r["tag"])}</text>'
        )
        parts.append(
            f'<text x="{x + BOX_W/2}" y="{y + 46}" text-anchor="middle" font-size="10" '
            f'fill="{COLOR_TEXT}">{esc(r["eth"])} ETH</text>'
        )
        parts.append(
            f'<text x="{x + BOX_W/2}" y="{y + 64}" text-anchor="middle" font-size="10" '
            f'fill="{COLOR_TEXT}">{esc(r["variant"])} variant</text>'
        )
        parts.append(
            f'<text x="{x + BOX_W/2}" y="{y + 86}" text-anchor="middle" font-size="10.5" '
            f'font-weight="bold" fill="{COLOR_TEXT}">{esc(STATE_LABEL[r["state"]])}</text>'
        )
        x += BOX_W + GAP

    legend_y = height - 14
    lx = MARGIN
    for label, color in [
        ("solved (me)", COLOR_SOLVED), ("open", COLOR_OPEN), ("dead, no payout path", COLOR_DEAD)
    ]:
        parts.append(f'<rect x="{lx}" y="{legend_y - 10}" width="14" height="14" fill="{color}"/>')
        parts.append(f'<text x="{lx + 20}" y="{legend_y + 1}" font-size="11" fill="#111111">{esc(label)}</text>')
        lx += 190

    parts.append("</svg>")

    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    with open(OUT_PATH, "w", encoding="utf-8") as f:
        f.write("\n".join(parts))
    print(f"wrote {OUT_PATH} ({os.path.getsize(OUT_PATH)} bytes)")


if __name__ == "__main__":
    main()
