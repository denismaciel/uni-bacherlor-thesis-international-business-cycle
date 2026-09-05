"""Research figures using the same publication style as the thesis."""

from pathlib import Path

import matplotlib as mpl
import numpy as np
import polars as pl
from matplotlib.backends.backend_pdf import PdfPages
from matplotlib.lines import Line2D
from matplotlib.ticker import MaxNLocator

from ..plot_style import (
    BLUE,
    FONT,
    INK,
    MUTED,
    RULE,
    RUST,
    SHADE,
    TEAL,
    correlation_axes,
    correlation_limits,
    legend,
    new_figure,
    save_figure,
    style_axes,
    title,
)
from .data import quarter_number
from .domain import Method, Result, Table

LABELS = {
    Method.HP: "HP filter",
    Method.GROWTH: "Log growth",
    Method.HAMILTON: "Hamilton filter",
}
COLORS = {Method.HP: TEAL, Method.GROWTH: RUST, Method.HAMILTON: BLUE}
LINESTYLES = {Method.HP: "-", Method.GROWTH: "--", Method.HAMILTON: "-."}
MARKERS = {Method.HP: "o", Method.GROWTH: "D", Method.HAMILTON: "s"}
PERIOD_LABELS = {
    "full_common": "Full sample",
    "pre_pandemic": "Before COVID-19",
    "thesis_overlap": "Thesis overlap",
    "post_thesis": "After the thesis",
}


def export_figures(result: Result, output: Path) -> None:
    output.mkdir(parents=True, exist_ok=True)
    with (
        mpl.rc_context({"pdf.fonttype": 42}),
        PdfPages(
            output / "figures.pdf",
            metadata={
                "Title": "International business cycles — research figures",
                "CreationDate": None,
                "ModDate": None,
            },
        ) as pdf,
    ):
        figure = new_figure(8.8, 5.2)
        ax = figure.subplots()
        ax.axvspan(2020, 2022, color=SHADE, zorder=0)
        ax.axhline(0, color=RULE, linestyle=(0, (4, 4)), linewidth=1)
        for method in Method:
            rows = result.tables[Table.ROLLING].filter(pl.col("method") == method)
            ax.plot(
                [quarter_number(t) / 4 for t in rows["end"]],
                rows["gap"].to_numpy(),
                label=LABELS[method],
                color=COLORS[method],
                linestyle=LINESTYLES[method],
                linewidth=1.8,
            )
        ax.set(
            xlabel="Window ending year",
            ylabel="Output correlation − consumption correlation",
        )
        title(
            ax,
            "How the correlation gap changes over time",
            "Rolling 40-quarter windows · shaded period: 2020–2021",
        )
        style_axes(ax)
        ax.xaxis.set_major_locator(MaxNLocator(nbins=8, integer=True))
        legend(ax, location="upper left", columns=3)
        figure.supxlabel(
            "Overlapping windows; filters estimated only through each endpoint. Descriptive estimates, without confidence bands.",
            fontsize=8,
            color=MUTED,
            fontfamily=FONT,
        )
        pdf.savefig(figure)
        save_figure(figure, output, "rolling_correlations")

        figure = new_figure(10, 4.6)
        pairs = result.tables[Table.PAIRS].filter(pl.col("period") == "full_common")
        limits = correlation_limits(
            [
                *pairs["consumption_correlation"].to_list(),
                *pairs["output_correlation"].to_list(),
            ]
        )
        figure.suptitle(
            "Output and consumption across country pairs",
            x=0.02,
            ha="left",
            fontfamily=FONT,
            fontsize=13,
            fontweight="semibold",
            color=INK,
        )
        for index, (ax, method) in enumerate(
            zip(figure.subplots(1, 3), Method, strict=True)
        ):
            rows = pairs.filter(pl.col("method") == method)
            correlation_axes(ax, limits)
            ax.scatter(
                rows["consumption_correlation"].to_numpy(),
                rows["output_correlation"].to_numpy(),
                color=COLORS[method],
                marker=MARKERS[method],
                s=27,
                edgecolors="white",
                linewidths=0.45,
                zorder=3,
            )
            title(
                ax,
                LABELS[method],
                f"{(rows['gap'] > 0).sum()} of {rows.height} pairs above equality",
            )
            if index > 0:
                ax.set_ylabel("")
        figure.supxlabel(
            "Full common sample · identical axis scales · dashed line: equal output and consumption correlations",
            fontsize=8,
            color=MUTED,
            fontfamily=FONT,
        )
        pdf.savefig(figure)
        save_figure(figure, output, "country_pair_correlations")

        figure = new_figure(8.8, 5.4)
        ax = figure.subplots()
        rows = result.tables[Table.SUMMARY]
        periods = rows["period"].unique(maintain_order=True).to_list()
        labels = []
        for position, period in enumerate(periods):
            subset = rows.filter(pl.col("period") == period)
            first = subset.row(0, named=True)
            label = PERIOD_LABELS.get(period, period.replace("_", " ").capitalize())
            labels.append(
                f"{label}\n{first['start'].replace('-Q', ' Q')} – {first['end'].replace('-Q', ' Q')}"
            )
            if position % 2 == 0:
                ax.axhspan(position - 0.42, position + 0.42, color=SHADE, zorder=0)
            for offset, method in zip((-0.22, 0.0, 0.22), Method, strict=True):
                selected = subset.filter(pl.col("method") == method)
                if selected.is_empty():
                    continue
                row = selected.row(0, named=True)
                y = position + offset
                if row["gap_lower"] is not None and row["gap_upper"] is not None:
                    ax.hlines(
                        y,
                        row["gap_lower"],
                        row["gap_upper"],
                        color=COLORS[method],
                        linewidth=1.8,
                        zorder=2,
                    )
                ax.plot(
                    row["gap"],
                    y,
                    marker=MARKERS[method],
                    color=COLORS[method],
                    markersize=6,
                    markeredgecolor="white",
                    markeredgewidth=0.7,
                    zorder=3,
                )
        ax.set(
            xlabel="Output correlation − consumption correlation",
            ylim=(len(periods) - 0.5, -0.65),
        )
        title(
            ax,
            "Sensitivity to the sample period",
            "Mean pairwise gap with 95% conditional bootstrap intervals",
        )
        style_axes(ax, grid_axis="x")
        ax.set_yticks(np.arange(len(periods)), labels, fontsize=9, color=INK)
        ax.axvline(0, color=RULE, linestyle=(0, (4, 4)), linewidth=1)
        ax.spines["left"].set_visible(False)
        handles = [
            Line2D(
                [],
                [],
                color=COLORS[method],
                marker=MARKERS[method],
                linewidth=1.5,
                markersize=5,
                label=LABELS[method],
            )
            for method in Method
        ]
        figure.legend(
            handles=handles,
            loc="outside lower center",
            ncols=3,
            frameon=False,
            prop={"family": FONT, "size": 9},
            labelcolor=MUTED,
        )
        pdf.savefig(figure)
        save_figure(figure, output, "period_sensitivity")
