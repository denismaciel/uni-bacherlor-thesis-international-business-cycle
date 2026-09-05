"""Publication figures from prepared data, using the shared visual style."""

from pathlib import Path

from matplotlib.ticker import FuncFormatter, MaxNLocator
import polars as pl

from .domain import Variable
from .figure_data import FigureData
from .plot_style import (
    RULE,
    RUST,
    TEAL,
    correlation_axes,
    correlation_limits,
    legend,
    new_figure,
    save_figure,
    style_axes,
    title,
)


def export_figures(data: FigureData, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    fig = new_figure(6.4, 4.5)
    axes = fig.subplots(2, 1, sharex=True, gridspec_kw={"height_ratios": [1.35, 1]})
    usa = data.usa_gdp
    axes[0].plot(
        usa["quarter"], usa["value"], color=TEAL, linewidth=1.65, label="Observed"
    )
    axes[0].plot(
        usa["quarter"],
        usa["trend"],
        color=RUST,
        linewidth=1.4,
        linestyle=(0, (4, 2)),
        label="HP trend",
    )
    axes[0].set_ylabel("Log GDP")
    title(axes[0], "US output: trend and cycle")
    style_axes(axes[0])
    legend(axes[0], location="upper left", columns=2)
    axes[1].axhline(0, color=RULE, linewidth=0.8)
    axes[1].fill_between(
        usa["quarter"].to_numpy(), 0, usa["filtered"].to_numpy(), color=TEAL, alpha=0.10
    )
    axes[1].plot(usa["quarter"], usa["filtered"], color=TEAL, linewidth=1.3)
    axes[1].set(xlabel="Year", ylabel="Log deviation")
    style_axes(axes[1])
    axes[1].xaxis.set_major_locator(MaxNLocator(nbins=7, integer=True))
    save_figure(fig, output_dir, "filteredgdp")

    for variable, filename, heading in (
        (Variable.GDP, "gdpcor", "Output"),
        (Variable.CONSUMPTION, "concor", "Consumption"),
    ):
        fig = new_figure(4.2, 3.5)
        ax = fig.subplots()
        for group, label, color, marker in (
            ("Other Countries", "Other pairs", TEAL, "o"),
            ("USA", "US pairs", RUST, "D"),
        ):
            subset = data.distributions[variable].filter(pl.col("group") == group)
            ax.scatter(
                subset["rank"],
                subset["correlation"],
                label=label,
                color=color,
                marker=marker,
                s=24,
                edgecolors="white",
                linewidths=0.45,
                zorder=3,
            )
        ax.set(
            xlabel="Country pairs, ranked by correlation",
            ylabel="Correlation",
            ylim=correlation_limits(
                value
                for frame in data.distributions.values()
                for value in frame["correlation"]
            ),
        )
        title(ax, heading)
        style_axes(ax)
        ax.xaxis.set_major_locator(MaxNLocator(nbins=5, integer=True))
        ax.axhline(0, color=RULE, linewidth=0.8)
        legend(ax, location="upper left")
        save_figure(fig, output_dir, filename)

    fig = new_figure(6.4, 5.4)
    ax = fig.subplots()
    pairs = data.gdp_consumption
    limits = correlation_limits(
        [*pairs["consumption"].to_list(), *pairs["gdp"].to_list()]
    )
    correlation_axes(ax, limits)
    for group, label, color, marker in (
        ("output_at_least_consumption", "Output ≥ consumption", TEAL, "o"),
        ("consumption_above_output", "Consumption > output", RUST, "D"),
    ):
        subset = pairs.filter(pl.col("comparison") == group)
        ax.scatter(
            subset["consumption"],
            subset["gdp"],
            color=color,
            marker=marker,
            s=38,
            edgecolors="white",
            linewidths=0.6,
            label=label,
            zorder=3,
        )
        if group == "consumption_above_output":
            for row in subset.iter_rows(named=True):
                ax.annotate(
                    f"{row['left']}–{row['right']}",
                    (row["consumption"], row["gdp"]),
                    xytext=(9, -15),
                    textcoords="offset points",
                    fontsize=8,
                    color=RUST,
                    arrowprops={"arrowstyle": "-", "color": RUST, "linewidth": 0.6},
                )
    count = pairs.filter(pl.col("comparison") == "output_at_least_consumption").height
    title(
        ax,
        "The quantity anomaly",
        f"{count} of {pairs.height} pairs: output correlation ≥ consumption correlation",
    )
    legend(ax, location="lower right")
    save_figure(fig, output_dir, "gdpconplot")

    countries = {"FRA": "France", "GBR": "United Kingdom", "ITA": "Italy"}
    for country, comparison in data.employment.items():
        fig = new_figure(4.5, 3.3)
        ax = fig.subplots()
        for label, color, linestyle in (("FRED", TEAL, "-"), ("OECD", RUST, "--")):
            source = comparison.filter(pl.col("source") == label)
            ax.plot(
                source["quarter"],
                source["value"],
                label=label,
                color=color,
                linewidth=1.6,
                linestyle=linestyle,
            )
        ax.set(xlabel="Year", ylabel="Employment (thousands)")
        title(ax, countries.get(country, country))
        style_axes(ax)
        ax.xaxis.set_major_locator(MaxNLocator(nbins=5, integer=True))
        ax.yaxis.set_major_formatter(FuncFormatter(lambda value, _: f"{value:,.0f}"))
        legend(ax, location="upper left", columns=2)
        save_figure(fig, output_dir, f"{country.lower()}employment")
