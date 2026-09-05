"""Pure preparation of the data displayed in the thesis figures."""

from dataclasses import dataclass
from collections.abc import Mapping
from types import MappingProxyType

import polars as pl

from .analysis import AnalysisResult, correlation_pairs
from .domain import ValidatedInputs, Variable
from .panel import employment_sources


@dataclass(frozen=True)
class FigureData:
    usa_gdp: pl.DataFrame
    distributions: Mapping[Variable, pl.DataFrame]
    gdp_consumption: pl.DataFrame
    employment: Mapping[str, pl.DataFrame]


def with_quarter_axis(data: pl.DataFrame) -> pl.DataFrame:
    # Boundary validation guarantees canonical YYYY-Qn; this is a display projection.
    return data.with_columns(
        (
            pl.col("time").str.slice(0, 4).cast(pl.Int32)
            + (pl.col("time").str.slice(6, 1).cast(pl.Int32) - 1) / 4
        ).alias("quarter")
    )


def build_figure_data(results: AnalysisResult, inputs: ValidatedInputs) -> FigureData:
    usa = with_quarter_axis(
        results.series[Variable.GDP].filter(pl.col("location") == "USA")
    ).with_columns((pl.col("value") - pl.col("filtered")).alias("trend"))
    distributions = {
        variable: correlation_pairs(results.correlations[variable])
        .drop_nulls("correlation")
        .sort("correlation")
        .with_row_index("rank", offset=1)
        .with_columns(
            pl.when((pl.col("left") == "USA") | (pl.col("right") == "USA"))
            .then(pl.lit("USA"))
            .otherwise(pl.lit("Other Countries"))
            .alias("group")
        )
        for variable in (Variable.GDP, Variable.CONSUMPTION)
    }
    pairs = (
        correlation_pairs(results.correlations[Variable.GDP])
        .rename({"correlation": "gdp"})
        .join(
            correlation_pairs(results.correlations[Variable.CONSUMPTION]).rename(
                {"correlation": "consumption"}
            ),
            on=["left", "right"],
            validate="1:1",
        )
        .drop_nulls(["gdp", "consumption"])
        .with_columns(
            pl.when(pl.col("gdp") >= pl.col("consumption"))
            .then(pl.lit("output_at_least_consumption"))
            .otherwise(pl.lit("consumption_above_output"))
            .alias("comparison")
        )
    )
    employment = {}
    for rule in inputs.policy.splices:
        fred, oecd = employment_sources(inputs, rule)
        employment[rule.country] = with_quarter_axis(
            pl.concat(
                [
                    fred.select("time", "value").with_columns(
                        pl.lit("FRED").alias("source")
                    ),
                    oecd.select("time", "value").with_columns(
                        pl.lit("OECD").alias("source")
                    ),
                ]
            ).sort("source", "time")
        )
    return FigureData(
        usa, MappingProxyType(distributions), pairs, MappingProxyType(employment)
    )
