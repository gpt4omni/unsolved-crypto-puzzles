#!/usr/bin/env python3
"""
fig_lots.py -- generate images/02-structure-lots.svg.

Purpose:
    Draw the 12-lot series as a grid (2 editions x 4 difficulties), one box per lot,
    colored by state: open (orange), solved by me (blue), solved by the community
    (gray). This is the portfolio-level view of the series.

Usage:
    python3 tools/fig_lots.py

Input:
    data/lots.csv (lot, edition, difficulty, address, amount_sats, state, solved_by,
    solve_date).

Output:
    images/02-structure-lots.svg
"""

import csv
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DATA_PATH = os.path.join(ROOT, "data", "lots.csv")
OUT_PATH = os.path.join(ROOT, "images", "02-structure-lots.svg")

COLOR_OPEN = "#E07A1F"
COLOR_ME = "#1F5FBF"
COLOR_COMMUNITY = "#9A9A9A"
COLOR_TEXT = "#FFFFFF"
COLOR_BG = "#FFFFFF"
FONT = "DejaVu Sans"

STATE_COLOR = {
    "open": COLOR_OPEN,
    "solved-by-me": COLOR_ME,
    "solved-by-community": COLOR_COMMUNITY,
}
STATE_LABEL = {
    "open": "OPEN",
    "solved-by-me": "solved (me)",
    "solved-by-community": "solved (community)",
}

DIFF_ORDER = ["easy", "medium", "hard", "veryhard"]
DIFF_LABEL = {"easy": "easy", "medium": "medium", "hard": "hard", "veryhard": "very hard"}
EDITIONS = ["EN", "IT"]

BOX_W = 210
BOX_H = 70
COL_GAP = 20
ROW_GAP = 18
LEFT_LABEL_W = 40
TOP_LABEL_H = 30
MARGIN = 20


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def main():
    with open(DATA_PATH, encoding="utf-8") as f:
        data_lines = [line for line in f if not line.startswith("#")]
    rows = list(csv.DictReader(data_lines))

    # bucket rows by (edition, difficulty); an edition/difficulty cell can hold more
    # than one lot (EN has both a community-solved "_s" easy/medium/veryhard lot and
    # a live one at medium/veryhard/hard difficulty), so stack multiple lots per cell.
    cells = {}
    for r in rows:
        key = (r["edition"], r["difficulty"])
        cells.setdefault(key, []).append(r)

    max_stack = max(len(v) for v in cells.values())
    cell_h = max_stack * (BOX_H + 6) - 6

    n_cols = len(DIFF_ORDER)
    n_rows = len(EDITIONS)
    LEGEND_H = 40
    width = MARGIN * 2 + LEFT_LABEL_W + n_cols * (BOX_W + COL_GAP) - COL_GAP
    height = MARGIN * 2 + TOP_LABEL_H + n_rows * (cell_h + ROW_GAP) - ROW_GAP + LEGEND_H

    parts = []
    parts.append(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}" font-family="{FONT}">'
    )
    parts.append(f'<rect x="0" y="0" width="{width}" height="{height}" fill="{COLOR_BG}"/>')

    # column headers
    for ci, diff in enumerate(DIFF_ORDER):
        cx = MARGIN + LEFT_LABEL_W + ci * (BOX_W + COL_GAP) + BOX_W / 2
        parts.append(
            f'<text x="{cx}" y="{MARGIN + 18}" text-anchor="middle" font-size="13" '
            f'font-weight="bold" fill="#111111">{esc(DIFF_LABEL[diff])}</text>'
        )

    for ri, edition in enumerate(EDITIONS):
        row_y = MARGIN + TOP_LABEL_H + ri * (cell_h + ROW_GAP)
        label_y = row_y + cell_h / 2 + 5
        parts.append(
            f'<text x="{MARGIN}" y="{label_y}" font-size="14" font-weight="bold" '
            f'fill="#111111">{esc(edition)}</text>'
        )
        for ci, diff in enumerate(DIFF_ORDER):
            cx = MARGIN + LEFT_LABEL_W + ci * (BOX_W + COL_GAP)
            lots = cells.get((edition, diff), [])
            for li, lot in enumerate(lots):
                by = row_y + li * (BOX_H + 6)
                color = STATE_COLOR[lot["state"]]
                parts.append(
                    f'<rect x="{cx}" y="{by}" width="{BOX_W}" height="{BOX_H}" rx="6" '
                    f'fill="{color}" stroke="#222222" stroke-width="1"/>'
                )
                parts.append(
                    f'<text x="{cx + BOX_W / 2}" y="{by + 24}" text-anchor="middle" '
                    f'font-size="12" font-weight="bold" fill="{COLOR_TEXT}">{esc(lot["lot"])}</text>'
                )
                parts.append(
                    f'<text x="{cx + BOX_W / 2}" y="{by + 42}" text-anchor="middle" '
                    f'font-size="10" fill="{COLOR_TEXT}">{esc(STATE_LABEL[lot["state"]])}</text>'
                )
                amt = f'{int(lot["amount_sats"]):,} sats'
                parts.append(
                    f'<text x="{cx + BOX_W / 2}" y="{by + 58}" text-anchor="middle" '
                    f'font-size="10" fill="{COLOR_TEXT}">{esc(amt)}</text>'
                )

    # legend
    legend_y = height - 14
    lx = MARGIN + LEFT_LABEL_W
    for label, color in [
        ("open", COLOR_OPEN), ("solved by me", COLOR_ME), ("solved by community", COLOR_COMMUNITY)
    ]:
        parts.append(f'<rect x="{lx}" y="{legend_y - 10}" width="14" height="14" fill="{color}"/>')
        parts.append(f'<text x="{lx + 20}" y="{legend_y + 1}" font-size="11" fill="#111111">{esc(label)}</text>')
        lx += 150

    parts.append("</svg>")

    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    with open(OUT_PATH, "w", encoding="utf-8") as f:
        f.write("\n".join(parts))
    print(f"wrote {OUT_PATH} ({os.path.getsize(OUT_PATH)} bytes)")


if __name__ == "__main__":
    main()
