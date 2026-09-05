"""Render the seven thesis figures without an R runtime."""

from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import polars as pl

from .analysis import AnalysisResult, correlation_pairs
from .panel import employment_sources, load_raw_data


def quarter_axis(series: pl.Series) -> list[float]:
    return [int(time[:4]) + (int(time[-1]) - 1) / 4 for time in series.to_list()]


def export_figures(results: AnalysisResult, data_dir: Path, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    def save(name: str) -> None:
        plt.gcf().set_size_inches(2600 / 300, 2000 / 300)
        plt.tight_layout()
        plt.savefig(output_dir / name, dpi=300)
        plt.close()

    usa = results.series["gdp"].filter(pl.col("location") == "USA")
    x = quarter_axis(usa["time"])
    _, axes = plt.subplots(2, 1, sharex=True)
    axes[0].plot(x, usa["value"].to_list(), label="Logged GDP")
    axes[0].plot(x, (usa["value"] - usa["filtered"]).to_list(), label="HP trend")
    axes[0].set_title("Logged GDP of the United States")
    axes[0].legend()
    axes[1].plot(x, usa["filtered"].to_list())
    axes[1].set_ylabel("HP cycle")
    axes[1].set_xlabel("Quarter")
    save("filteredgdp.png")

    for variable, filename in (("gdp", "gdpcor.png"), ("consumption", "concor.png")):
        pairs = correlation_pairs(results.correlations[variable]).sort("correlation").with_row_index("rank", offset=1)
        plt.figure()
        for is_usa, label, color in ((False, "Other Countries", "#f8766d"), (True, "USA", "#00bfc4")):
            subset = pairs.filter((pl.col("right") == "USA") == is_usa)
            plt.scatter(subset["rank"].to_list(), subset["correlation"].to_list(), label=label, color=color)
        plt.xlabel("Correlations in Ascending Order")
        plt.ylabel("Correlation Magnitude")
        plt.legend(title="Country")
        save(filename)

    pairs = correlation_pairs(results.correlations["gdp"]).rename({"correlation": "gdp"}).join(
        correlation_pairs(results.correlations["consumption"]).rename({"correlation": "consumption"}),
        on=["left", "right"], validate="1:1",
    )
    plt.figure()
    plt.scatter(pairs["consumption"].to_list(), pairs["gdp"].to_list(),
                c=["#00bfc4" if above else "#f8766d" for above in (pairs["gdp"] >= pairs["consumption"]).to_list()])
    plt.plot([-1, 1], [-1, 1], color="black", linewidth=1)
    plt.xlim(-1, 1)
    plt.ylim(-1, 1)
    plt.xlabel("Consumption Correlation")
    plt.ylabel("Output Correlation")
    save("gdpconplot.png")

    raw = load_raw_data(data_dir)
    for country in ("FRA", "GBR", "ITA"):
        fred, oecd = employment_sources(raw, country)
        plt.figure()
        for data, label in ((fred, "FRED"), (oecd, "OECD")):
            data = data.sort("time")
            plt.plot(quarter_axis(data["time"]), data["value"].to_list(), label=label)
        plt.xlabel("Quarter")
        plt.ylabel("Employment")
        plt.legend()
        save(f"{country.lower()}employment.png")
