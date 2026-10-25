#!/usr/bin/env python3
"""
fig_stages.py -- generate images/01-structure-stages.svg.

Purpose:
    Draw the published stage chain of the GSMG.io web puzzle as a left-to-right row
    of solved stages (blue) that forks into the two final gates (orange), each
    pointing at its own escrow address and balance. This is the structural fact that
    explains the puzzle's current state: every stage since 2019 has been passed, and
    what remains is two independent, still-locked encrypted blobs.

    Each gate's escrow address is shortened to first6...last6 on the figure (the full
    address stays in the README prose and in data/stage-chain.json); the canvas width
    is then computed from the actual widest line so nothing runs past the right edge.

Usage:
    python3 tools/fig_stages.py

Input:
    data/stage-chain.json (chain stages and the two final gates, each with a state).

Output:
    images/01-structure-stages.svg
"""

import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DATA_PATH = os.path.join(ROOT, "data", "stage-chain.json")
OUT_PATH = os.path.join(ROOT, "images", "01-structure-stages.svg")

BOX_W = 140
BOX_H = 56
GAP = 34
GATE_W = 220
GATE_H = 56
MARGIN = 30
FONT = "DejaVu Sans"

COLOR_SOLVED = "#1F5FBF"
COLOR_OPEN = "#E07A1F"
COLOR_TEXT = "#FFFFFF"
COLOR_TITLE = "#1a1a1a"
COLOR_EDGE = "#333333"
COLOR_BG = "#FFFFFF"


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def shorten_address(text):
    """Shorten a bare base58 (26-35 char) or 0x-hex (40+ char) address token to
    first6...last6, so a long address never has to fit as a single unbroken run.
    Other tokens (amounts, words) pass through unchanged."""
    import re

    def repl(m):
        addr = m.group(0)
        return f"{addr[:6]}...{addr[-6:]}"

    text = re.sub(r"0x[0-9a-fA-F]{40,}", repl, text)
    text = re.sub(r"\b[13][a-km-zA-HJ-NP-Z0-9]{25,34}\b", repl, text)
    return text


def draw_box(parts, x, y, w, h, label, color):
    parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" '
                 f'fill="{color}" stroke="#222222" stroke-width="1.2"/>')
    lines = label.split("\n")
    line_h = 13
    start_ty = y + h / 2 - (len(lines) - 1) * line_h / 2 + 4
    for li, line in enumerate(lines):
        parts.append(f'<text x="{x + w / 2}" y="{start_ty + li * line_h}" text-anchor="middle" '
                     f'font-size="10.5" fill="{COLOR_TEXT}">{esc(line)}</text>')


def main():
    with open(DATA_PATH, encoding="utf-8") as f:
        data = json.load(f)
    chain = data["chain"]
    gates = data["gates"]

    n = len(chain)
    chain_width = n * BOX_W + (n - 1) * GAP
    height = 260

    # Shorten any bare address in a gate's target lines up front, so both the layout
    # width and the drawn text use the same (short) string.
    for gate in gates:
        target = gate.get("target", "")
        if target:
            gate["target"] = "\n".join(shorten_address(line) for line in target.split("\n"))

    parts = []
    max_right = MARGIN  # tracks the widest element drawn, to size the canvas after the fact
    parts.append(f'<text x="{MARGIN}" y="24" font-size="13" font-weight="bold" '
                 f'fill="{COLOR_TITLE}">Published stage chain (passed 2019-2023)</text>')

    y = height // 2 - BOX_H // 2
    x = MARGIN
    centers = []
    for stage in chain:
        color = COLOR_SOLVED if stage["state"] == "solved" else COLOR_OPEN
        draw_box(parts, x, y, BOX_W, BOX_H, stage["label"], color)
        centers.append(x)
        x += BOX_W + GAP

    for i in range(1, n):
        prev_right = centers[i - 1] + BOX_W
        this_left = centers[i]
        mid_y = y + BOX_H / 2
        parts.append(f'<line x1="{prev_right}" y1="{mid_y}" x2="{this_left - 6}" y2="{mid_y}" '
                     f'stroke="{COLOR_EDGE}" stroke-width="1.5" marker-end="url(#arrow)"/>')

    last_right = centers[-1] + BOX_W
    fork_x = last_right + 30
    gate_x = fork_x + 20
    n_gates = len(gates)
    gate_gap = 30
    gates_total_h = n_gates * GATE_H + (n_gates - 1) * gate_gap
    gate_y0 = height / 2 - gates_total_h / 2
    mid_y = y + BOX_H / 2

    for i, gate in enumerate(gates):
        gy = gate_y0 + i * (GATE_H + gate_gap)
        gate_mid_y = gy + GATE_H / 2
        parts.append(f'<line x1="{fork_x - 20}" y1="{mid_y}" x2="{fork_x}" y2="{mid_y}" '
                     f'stroke="{COLOR_EDGE}" stroke-width="1.5"/>')
        parts.append(f'<path d="M {fork_x} {mid_y} L {gate_x - 6} {gate_mid_y}" '
                     f'stroke="{COLOR_EDGE}" stroke-width="1.5" fill="none" marker-end="url(#arrow)"/>')
        color = COLOR_SOLVED if gate["state"] == "solved" else COLOR_OPEN
        draw_box(parts, gate_x, gy, GATE_W, GATE_H, gate["label"], color)
        max_right = max(max_right, gate_x + GATE_W)
        target = gate.get("target", "")
        if target:
            target_font_size = 9.5
            for li, line in enumerate(target.split("\n")):
                parts.append(f'<text x="{gate_x + GATE_W + 8}" y="{gate_mid_y - 6 + li * 12}" '
                             f'font-size="{target_font_size}" fill="{COLOR_TITLE}">{esc(line)}</text>')
                line_right = gate_x + GATE_W + 8 + len(line) * target_font_size * 0.62
                max_right = max(max_right, line_right)

    legend_y = height - 22
    parts.append(f'<rect x="{MARGIN}" y="{legend_y}" width="14" height="14" fill="{COLOR_SOLVED}"/>')
    parts.append(f'<text x="{MARGIN + 20}" y="{legend_y + 11}" font-size="10" '
                 f'fill="{COLOR_TITLE}">solved (community, 2019-2023)</text>')
    parts.append(f'<rect x="{MARGIN + 230}" y="{legend_y}" width="14" height="14" fill="{COLOR_OPEN}"/>')
    parts.append(f'<text x="{MARGIN + 250}" y="{legend_y + 11}" font-size="10" '
                 f'fill="{COLOR_TITLE}">open (still locked)</text>')
    max_right = max(max_right, MARGIN + 250 + len("open (still locked)") * 10 * 0.62)

    parts.append('<defs><marker id="arrow" markerWidth="8" markerHeight="8" refX="6" refY="3" '
                 'orient="auto"><path d="M0,0 L6,3 L0,6 Z" fill="#333333"/></marker></defs>')
    parts.append("</svg>")

    width = int(max_right) + MARGIN
    header = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}" font-family="{FONT}">',
        f'<rect x="0" y="0" width="{width}" height="{height}" fill="{COLOR_BG}"/>',
    ]
    parts = header + parts

    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    with open(OUT_PATH, "w", encoding="utf-8") as f:
        f.write("\n".join(parts))
    print(f"wrote {OUT_PATH} ({os.path.getsize(OUT_PATH)} bytes)")


if __name__ == "__main__":
    main()
