#!/usr/bin/env python3
"""
fig_cards.py -- generate images/01-structure-card-faces.svg.

Purpose:
    Draw the two physical faces of each of the 3 Ballet cards discussed in this
    folder (the solved oracle card AA007448, and the two open cards AA009926 and
    AA012381), showing which half of the BIP38 pair (encrypted WIF on the back,
    passphrase on the front) is known and which is missing for each card. This is
    the structural fact that explains why the two open cards are not brute-forceable:
    each publishes only the half on one physical face, and the other face was never
    photographed.

    Each face box's height is computed from its own wrapped label/known/detail line
    count (label line + up to 2 known lines + up to 2 detail lines, each with its own
    line height and bottom padding), so a face with more text (AA012381's front, 2
    known lines and 2 detail lines) gets a taller box instead of letting its last
    line clip past a fixed box bottom.

Usage:
    python3 tools/fig_cards.py

Input:
    data/card-faces.json (per card: front/back label, known value or MISSING, detail).

Output:
    images/01-structure-card-faces.svg
"""

import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DATA_PATH = os.path.join(ROOT, "data", "card-faces.json")
OUT_PATH = os.path.join(ROOT, "images", "01-structure-card-faces.svg")

CARD_W = 260
FACE_H_MIN = 60
LABEL_Y = 14         # label baseline, relative to face box top
KNOWN_Y0 = 28         # first known-value line baseline, relative to face box top
KNOWN_LINE_H = 12
DETAIL_LINE_H = 11
BOTTOM_PAD = 10        # clearance below the last line's baseline, inside the box
GAP_V = 6              # vertical gap between the front and back box
GAP_X = 40
MARGIN = 30
FONT = "DejaVu Sans"

COLOR_KNOWN = "#1F5FBF"
COLOR_MISSING = "#E07A1F"
COLOR_TEXT = "#FFFFFF"
COLOR_TITLE = "#1a1a1a"
COLOR_BG = "#FFFFFF"


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def wrap(text, width=30):
    words = text.split(" ")
    lines, cur = [], ""
    for w in words:
        trial = (cur + " " + w).strip()
        if len(trial) > width and cur:
            lines.append(cur)
            cur = w
        else:
            cur = trial
    if cur:
        lines.append(cur)
    return lines


def face_layout(face):
    """Return (known_lines, detail_lines, box_h) for one face, sized to its own text."""
    known_lines = wrap(face["known"], 34)[:2]
    detail_lines = wrap(face["detail"], 40)[:2]
    if detail_lines:
        last_y = KNOWN_Y0 + len(known_lines) * KNOWN_LINE_H + (len(detail_lines) - 1) * DETAIL_LINE_H
    elif known_lines:
        last_y = KNOWN_Y0 + (len(known_lines) - 1) * KNOWN_LINE_H
    else:
        last_y = LABEL_Y
    box_h = max(FACE_H_MIN, last_y + BOTTOM_PAD)
    return known_lines, detail_lines, box_h


def render_face(parts, x, fy, face, box_h):
    is_missing = face["known"] == "MISSING"
    color = COLOR_MISSING if is_missing else COLOR_KNOWN
    parts.append(
        f'<rect x="{x}" y="{fy}" width="{CARD_W}" height="{box_h}" rx="8" '
        f'fill="{color}" stroke="#333333" stroke-width="1"/>'
    )
    parts.append(
        f'<text x="{x + 8}" y="{fy + LABEL_Y}" font-size="9" font-weight="bold" '
        f'fill="{COLOR_TEXT}">{esc(face["label"].upper())}</text>'
    )
    known_lines, detail_lines, _ = face_layout(face)
    for li, line in enumerate(known_lines):
        parts.append(
            f'<text x="{x + 8}" y="{fy + KNOWN_Y0 + li * KNOWN_LINE_H}" font-size="9.5" '
            f'fill="{COLOR_TEXT}">{esc(line)}</text>'
        )
    detail_y0 = fy + KNOWN_Y0 + len(known_lines) * KNOWN_LINE_H
    for li, line in enumerate(detail_lines):
        parts.append(
            f'<text x="{x + 8}" y="{detail_y0 + li * DETAIL_LINE_H}" '
            f'font-size="8" fill="{COLOR_TEXT}" opacity="0.9">{esc(line)}</text>'
        )


def main():
    with open(DATA_PATH, encoding="utf-8") as f:
        data = json.load(f)
    cards = data["cards"]

    n = len(cards)
    width = MARGIN * 2 + n * CARD_W + (n - 1) * GAP_X

    # First pass: work out how tall each card's front/back stack needs to be, so the
    # canvas (and the legend strip under it) can be sized to fit the tallest card.
    card_heights = []
    for card in cards:
        _, _, front_h = face_layout(card["front"])
        _, _, back_h = face_layout(card["back"])
        card_heights.append(front_h + GAP_V + back_h)
    top_y = MARGIN + 30
    max_stack_h = max(card_heights)
    legend_h = 50
    height = top_y + max_stack_h + legend_h

    parts = []
    parts.append(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}" font-family="{FONT}">'
    )
    parts.append(f'<rect x="0" y="0" width="{width}" height="{height}" fill="{COLOR_BG}"/>')

    x = MARGIN
    for card in cards:
        parts.append(
            f'<text x="{x + CARD_W / 2}" y="{MARGIN}" text-anchor="middle" '
            f'font-size="14" font-weight="bold" fill="{COLOR_TITLE}">{esc(card["name"])}</text>'
        )
        parts.append(
            f'<text x="{x + CARD_W / 2}" y="{MARGIN + 16}" text-anchor="middle" '
            f'font-size="10" fill="{COLOR_TITLE}">{esc(card["state"])}</text>'
        )

        _, _, front_h = face_layout(card["front"])
        front_fy = top_y
        render_face(parts, x, front_fy, card["front"], front_h)

        back_fy = front_fy + front_h + GAP_V
        _, _, back_h = face_layout(card["back"])
        render_face(parts, x, back_fy, card["back"], back_h)

        x += CARD_W + GAP_X

    legend_y = height - 30
    parts.append(f'<rect x="{MARGIN}" y="{legend_y}" width="14" height="14" fill="{COLOR_KNOWN}"/>')
    parts.append(
        f'<text x="{MARGIN + 20}" y="{legend_y + 11}" font-size="10" fill="{COLOR_TITLE}">known (published)</text>'
    )
    parts.append(f'<rect x="{MARGIN + 190}" y="{legend_y}" width="14" height="14" fill="{COLOR_MISSING}"/>')
    parts.append(
        f'<text x="{MARGIN + 210}" y="{legend_y + 11}" font-size="10" fill="{COLOR_TITLE}">missing (never photographed)</text>'
    )

    parts.append("</svg>")

    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    with open(OUT_PATH, "w", encoding="utf-8") as f:
        f.write("\n".join(parts))
    print(f"wrote {OUT_PATH} ({os.path.getsize(OUT_PATH)} bytes)")


if __name__ == "__main__":
    main()
