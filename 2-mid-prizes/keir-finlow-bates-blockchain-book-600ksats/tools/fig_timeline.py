#!/usr/bin/env python3
"""
fig_timeline.py -- generate images/03-timeline-funding.png.

Purpose:
    Plot every funding and solve event of the 12-lot series on a single horizontal
    timeline, from the first escrow funding (2020) to the most recent solve (2026).

Usage:
    python3 tools/fig_timeline.py

Input:
    data/timeline.csv (date, block_height, event, lot, amount_sats, txid).

Output:
    images/03-timeline-funding.png
"""

import csv
import datetime
import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.dates as mdates

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DATA_PATH = os.path.join(ROOT, "data", "timeline.csv")
OUT_PATH = os.path.join(ROOT, "images", "03-timeline-funding.png")

COLOR_FUND = "#1F5FBF"
COLOR_SOLVE_ME = "#1F5FBF"
COLOR_SOLVE_COMMUNITY = "#9A9A9A"


def main():
    with open(DATA_PATH, encoding="utf-8") as f:
        data_lines = [line for line in f if not line.startswith("#")]
    rows = list(csv.DictReader(data_lines))

    me_lots = {"EN_hard_1", "EN_hard_2", "IT_medium", "IT_hard"}

    fig, ax = plt.subplots(figsize=(10.3, 3.4), dpi=150)

    solve_rows = sorted((r for r in rows if r["event"] == "solve"), key=lambda r: r["date"])
    fund_rows = sorted((r for r in rows if r["event"] == "fund"), key=lambda r: r["date"])

    # Funding events are well separated (2020, 2021): label each one directly.
    for r in fund_rows:
        d = datetime.date.fromisoformat(r["date"])
        ax.scatter([d], [1], color=COLOR_FUND, marker="s", s=70, zorder=3, edgecolor="#222222", linewidth=0.6)
        ax.annotate(
            f'{r["lot"]}\n{r["date"]}', (d, 1), textcoords="offset points", xytext=(0, -34),
            ha="center", fontsize=8,
        )

    # Solve events cluster in two tight windows (early community solves, my 2026 solves);
    # plot every point (color = who solved it) but label clusters instead of every dot,
    # since individual dates a few weeks apart are indistinguishable at a 6-year scale.
    # Exact lot and date for every point: see the ledger table in README.md / analysis/tested.md.
    for r in solve_rows:
        d = datetime.date.fromisoformat(r["date"])
        color = COLOR_SOLVE_ME if r["lot"] in me_lots else COLOR_SOLVE_COMMUNITY
        ax.scatter([d], [0], color=color, marker="o", s=70, zorder=3, edgecolor="#222222", linewidth=0.6)

    clusters = [
        ("2021-01-20", "3 community solves\nJan-Feb 2021"),
        ("2022-02-01", "IT_easy\nFeb 2022 (community)"),
        ("2026-06-27", "4 solves by me\nJun-Jul 2026"),
    ]
    for date_str, label in clusters:
        d = datetime.date.fromisoformat(date_str)
        ax.annotate(label, (d, 0), textcoords="offset points", xytext=(0, -34), ha="center", fontsize=8)

    ax.axhline(0, color="#cccccc", linewidth=0.8, zorder=1)
    ax.axhline(1, color="#cccccc", linewidth=0.8, zorder=1)
    ax.set_yticks([0, 1])
    ax.set_yticklabels(["solve", "fund"])
    ax.set_ylim(-0.9, 1.7)
    ax.xaxis.set_major_locator(mdates.YearLocator())
    ax.xaxis.set_major_formatter(mdates.DateFormatter("%Y"))
    ax.set_xlabel("date (on-chain block time)")
    ax.set_title("Finlow-Bates series: funding and solve events, 2020 to 2026")
    for spine in ("top", "right", "left"):
        ax.spines[spine].set_visible(False)

    handles = [
        plt.Line2D([0], [0], marker="s", color="w", markerfacecolor=COLOR_FUND, markersize=8, label="funding tx"),
        plt.Line2D([0], [0], marker="o", color="w", markerfacecolor=COLOR_SOLVE_ME, markersize=8, label="solved by me"),
        plt.Line2D([0], [0], marker="o", color="w", markerfacecolor=COLOR_SOLVE_COMMUNITY, markersize=8, label="solved by community"),
    ]
    ax.legend(handles=handles, loc="upper left", fontsize=8, frameon=False)

    fig.tight_layout()
    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    fig.savefig(OUT_PATH, dpi=150)
    print(f"wrote {OUT_PATH} ({os.path.getsize(OUT_PATH)} bytes)")


if __name__ == "__main__":
    main()
