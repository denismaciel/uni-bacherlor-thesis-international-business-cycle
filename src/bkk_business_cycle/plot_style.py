"""Shared publication styling for thesis and research-extension figures."""

from collections.abc import Iterable
from pathlib import Path
from typing import Literal

import matplotlib as mpl
from matplotlib.axes import Axes
from matplotlib.backends.backend_agg import FigureCanvasAgg
from matplotlib.figure import Figure
from matplotlib.layout_engine import ConstrainedLayoutEngine
from matplotlib.ticker import FuncFormatter, MaxNLocator
import numpy as np

INK = "#202B30"
MUTED = "#64716F"
TEAL = "#27665D"
RUST = "#B14539"
BLUE = "#356F9B"
GRID = "#E5EBE8"
RULE = "#BBC8C2"
SHADE = "#F0F4F2"
FONT = "DejaVu Sans"


def new_figure(width: float = 6.4, height: float = 4.4) -> Figure:
    fig = Figure(
        figsize=(width, height),
        dpi=300,
        facecolor="white",
        layout=ConstrainedLayoutEngine(
            w_pad=0.10, h_pad=0.10, wspace=0.08, hspace=0.10
        ),
    )
    FigureCanvasAgg(fig)
    return fig


def style_axes(ax: Axes, *, grid_axis: Literal["x", "y", "both"] = "y") -> None:
    ax.set_facecolor("white")
    ax.set_axisbelow(True)
    ax.grid(axis=grid_axis, color=GRID, linewidth=0.65)
    for edge in ("top", "right"):
        ax.spines[edge].set_visible(False)
    for edge in ("bottom", "left"):
        ax.spines[edge].set_color(RULE)
        ax.spines[edge].set_linewidth(0.65)
    ax.tick_params(axis="both", colors=MUTED, labelsize=9, length=0, pad=7)
    for label in [
        *ax.get_xticklabels(),
        *ax.get_yticklabels(),
        ax.xaxis.label,
        ax.yaxis.label,
    ]:
        label.set_fontfamily(FONT)
        label.set_color(MUTED)
    ax.xaxis.label.set_fontsize(9)
    ax.yaxis.label.set_fontsize(9)
    ax.xaxis.labelpad = 10
    ax.yaxis.labelpad = 10
    ax.yaxis.set_major_locator(MaxNLocator(nbins=5))
    ax.margins(x=0.025, y=0.10)


def title(ax: Axes, heading: str, subtitle: str = "") -> None:
    ax.set_title(
        heading,
        loc="left",
        fontfamily=FONT,
        fontsize=11,
        fontweight="semibold",
        color=INK,
        pad=30 if subtitle else 15,
    )

    if subtitle:
        ax.text(
            0,
            1.015,
            subtitle,
            transform=ax.transAxes,
            fontsize=8.5,
            fontfamily=FONT,
            color=MUTED,
            va="bottom",
            clip_on=False,
        )


def legend(
    ax: Axes,
    *,
    location: Literal[
        "best", "upper left", "upper right", "lower left", "lower right"
    ] = "best",
    columns: int = 1,
) -> None:
    ax.legend(
        loc=location,
        ncols=columns,
        frameon=False,
        labelcolor=MUTED,
        prop={"family": FONT, "size": 8},
        handlelength=2,
        columnspacing=1.5,
        borderaxespad=0.4,
    )


def correlation_axes(ax: Axes, limits: tuple[float, float]) -> None:
    ax.set(
        xlim=limits,
        ylim=limits,
        xlabel="Consumption correlation",
        ylabel="Output correlation",
    )
    ax.set_aspect("equal", adjustable="box")
    style_axes(ax, grid_axis="both")
    ticks = np.arange(-1, 1.01, 0.25)
    ticks = ticks[(ticks >= limits[0]) & (ticks <= limits[1])]
    ax.set_xticks(ticks)
    ax.set_yticks(ticks)
    formatter = FuncFormatter(
        lambda value, _: "0" if value == 0 else f"{value:.2f}".rstrip("0").rstrip(".")
    )
    ax.xaxis.set_major_formatter(formatter)
    ax.yaxis.set_major_formatter(formatter)
    ax.plot(limits, limits, color=RULE, linewidth=1, linestyle=(0, (4, 4)), zorder=1)


def correlation_limits(values: Iterable[float]) -> tuple[float, float]:
    finite = [value for value in values if np.isfinite(value)]
    lower = max(-1.0, min(0.0, np.floor((min(finite, default=0) - 0.025) * 4) / 4))
    return float(lower), 1.0


def save_figure(fig: Figure, directory: Path, stem: str) -> None:
    """PNG for existing LaTeX includes; SVG/PDF for sharp print and reuse."""
    with mpl.rc_context(
        {"svg.fonttype": "path", "svg.hashsalt": "bkk-publication", "pdf.fonttype": 42}
    ):
        fig.savefig(directory / f"{stem}.png", dpi=300, facecolor="white")
        svg = directory / f"{stem}.svg"
        fig.savefig(svg, metadata={"Date": None})
        svg.write_text(
            "\n".join(line.rstrip() for line in svg.read_text().splitlines()) + "\n"
        )
        fig.savefig(
            directory / f"{stem}.pdf", metadata={"CreationDate": None, "ModDate": None}
        )
    fig.clear()
