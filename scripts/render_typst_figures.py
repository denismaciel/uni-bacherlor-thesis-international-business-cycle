"""Redraw the archived thesis figure data as print-ready SVGs for Typst."""
from pathlib import Path

import matplotlib as mpl
from matplotlib.figure import Figure
import polars as pl

from bkk_business_cycle.analysis import analyze
from bkk_business_cycle.domain import Variable
from bkk_business_cycle.inputs import InvalidInputs, load_inputs
from bkk_business_cycle.figure_data import build_figure_data

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "paper/typst/assets"
GREEN, RED, BLUE = "#27665d", "#b14539", "#356f9b"


def main() -> None:
    inputs = load_inputs(ROOT / "data/raw")
    if isinstance(inputs, InvalidInputs):
        raise ValueError(inputs)
    data = build_figure_data(analyze(inputs), inputs)
    OUT.mkdir(parents=True, exist_ok=True)
    with mpl.rc_context({"font.family": "DejaVu Sans", "font.size": 9,
                         "axes.spines.top": False, "axes.spines.right": False,
                         "axes.edgecolor": "#bbc8c2", "axes.labelcolor": "#34423d",
                         "xtick.color": "#64716f", "ytick.color": "#64716f",
                         "svg.hashsalt": "bkk-thesis-2015", "svg.fonttype": "path"}):
        def save(fig: Figure, name: str) -> None:
            fig.tight_layout(pad=0.8)
            path = OUT / f"{name}.svg"
            fig.savefig(path, metadata={"Date": None})
            path.write_text("\n".join(line.rstrip() for line in path.read_text().splitlines()) + "\n")

        fig = Figure(figsize=(6.4, 4.1))
        axes = fig.subplots(2, 1, sharex=True)
        usa = data.usa_gdp
        axes[0].plot(usa["quarter"], usa["value"], color=GREEN, lw=1, label="Logged GDP")
        axes[0].plot(usa["quarter"], usa["trend"], color=RED, lw=1.2, label="HP trend")
        axes[0].legend(frameon=False, loc="upper left", fontsize=8)
        axes[0].set_ylabel("Log GDP")
        axes[1].plot(usa["quarter"], usa["filtered"], color=BLUE, lw=1)
        axes[1].axhline(0, color="#bbc8c2", lw=0.7)
        axes[1].set(xlabel="Year", ylabel="HP cycle")
        save(fig, "filteredgdp")

        for variable, filename in ((Variable.GDP, "gdpcor"), (Variable.CONSUMPTION, "concor")):
            fig = Figure(figsize=(3.3, 2.9))
            ax = fig.subplots()
            for group, color, marker in (("Other Countries", GREEN, "o"), ("USA", RED, "D")):
                part = data.distributions[variable].filter(pl.col("group") == group)
                ax.scatter(part["rank"], part["correlation"], s=12, color=color, marker=marker,
                           label="US pairs" if group == "USA" else "Other pairs")
            ax.set(xlabel="Rank (ascending)", ylabel="Correlation")
            ax.legend(frameon=False, fontsize=7, loc="lower right")
            save(fig, filename)

        fig = Figure(figsize=(6.4, 4.7))
        ax = fig.subplots()
        pairs = data.gdp_consumption
        for group, color, marker in (("output_at_least_consumption", GREEN, "o"), ("consumption_above_output", RED, "D")):
            part = pairs.filter(pl.col("comparison") == group)
            ax.scatter(part["consumption"], part["gdp"], color=color, marker=marker, s=24)
            if group == "consumption_above_output":
                for row in part.iter_rows(named=True):
                    ax.annotate(f"{row['left']}–{row['right']}", (row["consumption"], row["gdp"]),
                                xytext=(7, -9), textcoords="offset points", fontsize=7, color=RED)
        ax.plot([-1, 1], [-1, 1], color="#7d8983", lw=0.8, ls="--")
        ax.set(xlim=(-1, 1), ylim=(-1, 1), xlabel="Consumption correlation", ylabel="Output correlation")
        ax.set_aspect("equal")
        save(fig, "gdpconplot")

        for country, comparison in data.employment.items():
            fig = Figure(figsize=(6.4, 1.8))
            ax = fig.subplots()
            for label, color, style in (("FRED", GREEN, "-"), ("OECD", RED, "--")):
                part = comparison.filter(pl.col("source") == label)
                ax.plot(part["quarter"], part["value"], label=label, color=color, ls=style, lw=1)
            ax.set(xlabel="Year", ylabel="Employment")
            ax.legend(frameon=False, fontsize=7, loc="upper left")
            save(fig, country.lower() + "employment")


if __name__ == "__main__":
    main()
