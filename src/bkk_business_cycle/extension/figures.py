"""Render the same three research figures from Python's own result tables."""

from pathlib import Path

import numpy as np
import polars as pl
from matplotlib.backends.backend_pdf import PdfPages
from matplotlib.figure import Figure

from .data import quarter_number
from .domain import Method, Result, Table

LABELS = {Method.HP: "HP (1600)", Method.GROWTH: "Quarterly log growth", Method.HAMILTON: "Hamilton (h=8, p=4)"}
COLORS = {Method.HP: "#245A81", Method.GROWTH: "#B55435", Method.HAMILTON: "#44774A"}


def export_figures(result: Result, output: Path) -> None:
    output.mkdir(parents=True, exist_ok=True)
    with PdfPages(output / "figures.pdf") as pdf:
        figure = Figure(figsize=(10, 6))
        ax = figure.subplots()
        ax.axvspan(2020, 2022, color="#EEEEEE")
        ax.axhline(0, color="grey", linestyle="--", linewidth=0.8)
        for method in Method:
            rows = result.tables[Table.ROLLING].filter(pl.col("method") == method)
            ax.plot([quarter_number(t) / 4 for t in rows["end"]], rows["gap"].to_numpy(), label=LABELS[method], color=COLORS[method])
        ax.set(title="Quantity anomaly: rolling 40-quarter windows", xlabel="Window ending year",
               ylabel="Mean correlation gap (output minus consumption)")
        ax.legend(frameon=False)
        figure.text(0.5, 0.02, "Descriptive overlapping windows; filters fitted only through each endpoint. Grey: 2020–2021.", ha="center", fontsize=8)
        figure.tight_layout(rect=(0, 0.04, 1, 1))
        pdf.savefig(figure)

        figure = Figure(figsize=(10, 6))
        for ax, method in zip(figure.subplots(1, 3), Method, strict=True):
            rows = result.tables[Table.PAIRS].filter((pl.col("period") == "full_common") & (pl.col("method") == method))
            ax.scatter(rows["consumption_correlation"].to_numpy(), rows["output_correlation"].to_numpy(), color=COLORS[method], s=16)
            ax.plot([-0.4, 1], [-0.4, 1], color="grey", linestyle="--")
            ax.set(xlim=(-0.4, 1), ylim=(-0.4, 1), xlabel="Consumption correlation", ylabel="Output correlation",
                   title=f"{LABELS[method]}\n{(rows['gap'] > 0).sum()} of 45 pairs above diagonal")
            ax.set_aspect("equal")
            ax.title.set_fontsize(10)
        figure.tight_layout()
        pdf.savefig(figure)

        figure = Figure(figsize=(10, 6))
        ax = figure.subplots()
        rows = result.tables[Table.SUMMARY]
        positions = np.arange(rows.height)[::-1]
        for position, row in zip(positions, rows.iter_rows(named=True), strict=True):
            color = COLORS[Method(row["method"])]
            ax.hlines(position, row["gap_lower"], row["gap_upper"], color=color)
            ax.plot(row["gap"], position, "o", color=color, markersize=4)
        ax.set_yticks(positions, [f"{r['period']}: {LABELS[Method(r['method'])]}" for r in rows.iter_rows(named=True)], fontsize=8)
        ax.axvline(0, color="grey", linestyle="--", linewidth=0.8)
        ax.set(title="Period and transformation sensitivity", xlabel="Mean pairwise gap (95% conditional bootstrap interval)")
        figure.tight_layout()
        pdf.savefig(figure)
