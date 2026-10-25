#!/usr/bin/env python3
"""
fig_pipeline.py -- generate images/01-pipeline-derivation.svg.

Purpose:
    Draw the authenticate() verification pipeline as a left-to-right chain of boxes: from a
    candidate 64-byte public key, through unmasking the stored proof, to ECDSA public-key
    recovery, to the reward() payout on a match. This is the exact check confirmed by the
    735B claim.

    Every box is sized to its own label (width = longest line * font size * 0.62 +
    padding) and every gap is widened to fit its edge label, so no text ever runs
    past a box edge or the canvas edge regardless of label length.

Usage:
    python3 tools/fig_pipeline.py

Input:
    data/pipeline-stages.json (stage labels and edge labels).

Output:
    images/01-pipeline-derivation.svg
"""

import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DATA_PATH = os.path.join(ROOT, "data", "pipeline-stages.json")
OUT_PATH = os.path.join(ROOT, "images", "01-pipeline-derivation.svg")

BOX_W_MIN = 170
BOX_H = 66
GAP_MIN = 85
MARGIN = 30
FONT = "DejaVu Sans"
FONT_SIZE = 11.5
EDGE_FONT_SIZE = 9.5
CHAR_W = 0.62
PAD_X = 12
EDGE_PAD_X = 8

COLOR_BOX = "#1F5FBF"
COLOR_UNKNOWN = "#E07A1F"
COLOR_TEXT = "#FFFFFF"
COLOR_EDGE = "#333333"
COLOR_BG = "#FFFFFF"


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def box_width(lines):
    longest = max(len(line) for line in lines)
    return max(BOX_W_MIN, int(longest * FONT_SIZE * CHAR_W) + 2 * PAD_X)


def gap_width(edge_lines):
    if not edge_lines:
        return GAP_MIN
    longest = max(len(line) for line in edge_lines)
    return max(GAP_MIN, int(longest * EDGE_FONT_SIZE * CHAR_W) + 2 * EDGE_PAD_X)


def main():
    with open(DATA_PATH, encoding="utf-8") as f:
        data = json.load(f)
    stages = data["stages"]
    n = len(stages)

    box_lines = [stage["label"].split("\n") for stage in stages]
    box_ws = [box_width(lines) for lines in box_lines]
    edge_lines_list = [(stages[i].get("edge") or "").split("\n") if stages[i].get("edge") else [] for i in range(n)]
    gaps = [0] + [gap_width(edge_lines_list[i]) for i in range(1, n)]

    lefts = []
    x = MARGIN
    for i in range(n):
        x += gaps[i]
        lefts.append(x)
        x += box_ws[i]
    width = x + MARGIN
    height = 230

    parts = []
    parts.append(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}" font-family="{FONT}">'
    )
    parts.append(f'<rect x="0" y="0" width="{width}" height="{height}" fill="{COLOR_BG}"/>')

    y = height // 2 - BOX_H // 2 + 10
    for i, stage in enumerate(stages):
        x = lefts[i]
        bw = box_ws[i]
        cx = x + bw / 2
        color = COLOR_UNKNOWN if i == 0 else COLOR_BOX
        parts.append(
            f'<rect x="{x}" y="{y}" width="{bw}" height="{BOX_H}" rx="8" '
            f'fill="{color}" stroke="#14406e" stroke-width="1.5"/>'
        )
        lines = box_lines[i]
        line_h = 15
        start_ty = y + BOX_H / 2 - (len(lines) - 1) * line_h / 2 + 5
        for li, line in enumerate(lines):
            parts.append(
                f'<text x="{cx}" y="{start_ty + li * line_h}" text-anchor="middle" '
                f'font-size="{FONT_SIZE}" fill="{COLOR_TEXT}">{esc(line)}</text>'
            )

    for i in range(1, n):
        prev_right = lefts[i - 1] + box_ws[i - 1]
        this_left = lefts[i]
        mid_y = y + BOX_H / 2
        parts.append(
            f'<line x1="{prev_right}" y1="{mid_y}" x2="{this_left - 8}" y2="{mid_y}" '
            f'stroke="{COLOR_EDGE}" stroke-width="1.5" marker-end="url(#arrow)"/>'
        )
        edge_lines = edge_lines_list[i]
        if edge_lines and edge_lines != [""]:
            label_x = (prev_right + this_left) / 2
            line_h = 12
            base_y = mid_y - 12 - (len(edge_lines) - 1) * line_h
            for li, line in enumerate(edge_lines):
                parts.append(
                    f'<text x="{label_x}" y="{base_y + li * line_h}" text-anchor="middle" '
                    f'font-size="{EDGE_FONT_SIZE}" fill="{COLOR_EDGE}">{esc(line)}</text>'
                )

    legend_y = height - 20
    parts.append(f'<rect x="{MARGIN}" y="{legend_y}" width="14" height="14" fill="{COLOR_UNKNOWN}"/>')
    parts.append(f'<text x="{MARGIN + 20}" y="{legend_y + 12}" font-size="11" fill="#111111">unknown for C1, C2, 9732</text>')
    parts.append(f'<rect x="{MARGIN + 260}" y="{legend_y}" width="14" height="14" fill="{COLOR_BOX}"/>')
    parts.append(f'<text x="{MARGIN + 280}" y="{legend_y + 12}" font-size="11" fill="#111111">on-chain check, confirmed by the 735B claim</text>')

    parts.append(
        '<defs><marker id="arrow" markerWidth="8" markerHeight="8" refX="6" refY="3" '
        'orient="auto"><path d="M0,0 L6,3 L0,6 Z" fill="#333333"/></marker></defs>'
    )
    parts.append("</svg>")

    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    with open(OUT_PATH, "w", encoding="utf-8") as f:
        f.write("\n".join(parts))
    print(f"wrote {OUT_PATH} ({os.path.getsize(OUT_PATH)} bytes)")


if __name__ == "__main__":
    main()
