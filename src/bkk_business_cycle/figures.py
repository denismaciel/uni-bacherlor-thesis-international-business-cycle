"""Matplotlib rendering adapter; all analytical choices arrive as figure data."""

from pathlib import Path

from matplotlib.backends.backend_agg import FigureCanvasAgg
from matplotlib.figure import Figure
import polars as pl

from .domain import Variable
from .figure_data import FigureData


def export_figures(data: FigureData, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    def figure() -> Figure:
        fig = Figure(figsize=(2600 / 300, 2000 / 300), dpi=300)
        FigureCanvasAgg(fig)
        return fig

    def save(fig: Figure, name: str) -> None:
        fig.tight_layout()
        fig.savefig(output_dir / name, dpi=300)
        fig.clear()

    fig = figure()
    axes = fig.subplots(2, 1, sharex=True)
    usa = data.usa_gdp
    axes[0].plot(usa["quarter"], usa["value"], label="Logged GDP")
    axes[0].plot(usa["quarter"], usa["trend"], label="HP trend")
    axes[0].set_title("Logged GDP of the United States")
    axes[0].legend()
    axes[1].plot(usa["quarter"], usa["filtered"])
    axes[1].set_ylabel("HP cycle")
    axes[1].set_xlabel("Quarter")
    save(fig, "filteredgdp.png")

    for variable, filename in (
        (Variable.GDP, "gdpcor.png"),
        (Variable.CONSUMPTION, "concor.png"),
    ):
        fig = figure()
        ax = fig.subplots()
        for label, color in (("Other Countries", "#f8766d"), ("USA", "#00bfc4")):
            subset = data.distributions[variable].filter(pl.col("group") == label)
            ax.scatter(
                subset["rank"].to_list(),
                subset["correlation"].to_list(),
                label=label,
                color=color,
            )
        ax.set_xlabel("Correlations in Ascending Order")
        ax.set_ylabel("Correlation Magnitude")
        ax.legend(title="Country")
        save(fig, filename)

    fig = figure()
    ax = fig.subplots()
    pairs = data.gdp_consumption
    colors = {
        "output_at_least_consumption": "#00bfc4",
        "consumption_above_output": "#f8766d",
    }
    ax.scatter(
        pairs["consumption"].to_list(),
        pairs["gdp"].to_list(),
        c=[colors[group] for group in pairs["comparison"].to_list()],
    )
    ax.plot([-1, 1], [-1, 1], color="black", linewidth=1)
    ax.set(
        xlim=(-1, 1),
        ylim=(-1, 1),
        xlabel="Consumption Correlation",
        ylabel="Output Correlation",
    )
    save(fig, "gdpconplot.png")

    for country, comparison in data.employment.items():
        fig = figure()
        ax = fig.subplots()
        for label in ("FRED", "OECD"):
            source = comparison.filter(pl.col("source") == label)
            ax.plot(source["quarter"].to_list(), source["value"].to_list(), label=label)
        ax.set(xlabel="Quarter", ylabel="Employment")
        ax.legend()
        save(fig, f"{country.lower()}employment.png")
