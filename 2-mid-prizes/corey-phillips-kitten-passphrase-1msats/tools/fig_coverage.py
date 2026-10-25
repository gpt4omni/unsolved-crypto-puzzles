#!/usr/bin/env python3
"""
fig_coverage.py -- generate images/02-coverage-tested-space.png.

Purpose:
    Horizontal log-scale bar chart of every passphrase corpus family tested against
    the fixed mnemonic, with a witness marker, so a reader can see both the scale of
    what has been tried and that none of it is unverified guesswork.

Usage:
    python3 tools/fig_coverage.py

Input:
    data/coverage.csv (family, candidates, engine, rate_per_s, witness, date).

Output:
    images/02-coverage-tested-space.png
"""

import csv
import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DATA_PATH = os.path.join(ROOT, "data", "coverage.csv")
OUT_PATH = os.path.join(ROOT, "images", "02-coverage-tested-space.png")

COLOR_TESTED = "#9A9A9A"
COLOR_WITNESS = "#1F5FBF"


def main():
    with open(DATA_PATH, encoding="utf-8") as f:
        data_lines = [line for line in f if not line.startswith("#")]
    rows = list(csv.DictReader(data_lines))
    rows.sort(key=lambda r: int(r["candidates"]))

    families = [r["family"] for r in rows]
    counts = [int(r["candidates"]) for r in rows]
    colors = [COLOR_WITNESS if r["witness"] == "yes" else COLOR_TESTED for r in rows]

    fig, ax = plt.subplots(figsize=(10.5, 5.2), dpi=150)
    y_pos = range(len(families))
    ax.barh(y_pos, counts, color=colors, edgecolor="#222222", linewidth=0.5)
    ax.set_yticks(list(y_pos))
    ax.set_yticklabels(families, fontsize=8)
    ax.set_xscale("log")
    total = sum(counts)
    ax.set_xlabel(f"candidates tested (log scale), 0 matches in every family, {total:,} total")
    ax.set_title("Passphrase search coverage by corpus family", fontsize=13)

    for y, c in zip(y_pos, counts):
        ax.text(c * 1.15, y, f"{c:,}", va="center", fontsize=7.5)

    for spine in ("top", "right"):
        ax.spines[spine].set_visible(False)

    handles = [
        plt.Rectangle((0, 0), 1, 1, color=COLOR_WITNESS, label="witness: planted control recovered"),
    ]
    ax.legend(handles=handles, loc="lower right", fontsize=8, frameon=False)

    fig.tight_layout()
    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    fig.savefig(OUT_PATH, dpi=150)
    print(f"wrote {OUT_PATH} ({os.path.getsize(OUT_PATH)} bytes)")


if __name__ == "__main__":
    main()
