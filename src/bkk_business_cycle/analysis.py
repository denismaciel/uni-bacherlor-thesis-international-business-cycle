"""Polars statistics and thesis tables, with the original R rounding rules."""

from dataclasses import dataclass
import math
from pathlib import Path
from statistics import mean

import polars as pl

from .panel import VARIABLES, build_analysis_panel, load_raw_data, timespan_by_country

SYMBOLS = dict(zip(VARIABLES, ("y", "c", "x", "g", "nx", "n", "z"), strict=True))
PROBABILITIES = (0.0, 0.1, 0.25, 0.4, 0.5, 0.6, 0.75, 0.9, 1.0)


@dataclass(frozen=True)
class VariableResult:
    series: pl.DataFrame
    correlation: pl.DataFrame
    stdv: pl.DataFrame
    timespan: pl.DataFrame


@dataclass(frozen=True)
class AnalysisResult:
    panel: pl.DataFrame
    variable_results: dict[str, VariableResult]
    tables: dict[str, pl.DataFrame]
    employment_initial_timespan: pl.DataFrame

    @property
    def series(self) -> dict[str, pl.DataFrame]:
        return {name: result.series for name, result in self.variable_results.items()}

    @property
    def correlations(self) -> dict[str, pl.DataFrame]:
        return {name: result.correlation for name, result in self.variable_results.items()}


def pairwise_correlation(data: pl.DataFrame, left: str, right: str) -> float:
    pair = data.select(pl.col(left).alias("left"), pl.col(right).alias("right")).drop_nulls()
    return float(pair.select(pl.corr("left", "right")).item())


def cross_country_correlation(series: pl.DataFrame) -> pl.DataFrame:
    wide = series.pivot(on="location", index="time", values="filtered", sort_columns=True)
    countries = [name for name in wide.columns if name != "time"]
    return pl.DataFrame({
        "country": countries,
        **{right: [round(pairwise_correlation(wide, left, right), 3) for left in countries] for right in countries},
    })


def correlation_pairs(matrix: pl.DataFrame) -> pl.DataFrame:
    countries = matrix["country"].to_list()
    return pl.DataFrame([
        {"left": left, "right": right, "correlation": matrix[right][i]}
        for i, left in enumerate(countries) for right in countries[i + 1:]
    ])


def build_variable_results(panel: pl.DataFrame) -> dict[str, VariableResult]:
    results = {}
    for variable in VARIABLES:
        series = panel.filter(pl.col("variable") == variable).drop("variable")
        results[variable] = VariableResult(
            series, cross_country_correlation(series),
            series.group_by("location", maintain_order=True).agg(pl.col("filtered").std(ddof=1).alias("stdv")).rename({"location": "country"}),
            timespan_by_country(series),
        )
    return results


def full_join(left: pl.DataFrame, right: pl.DataFrame) -> pl.DataFrame:
    return left.join(right, on="country", how="full", coalesce=True, maintain_order="left_right", validate="1:1")


def build_timespan(results: dict[str, VariableResult]) -> pl.DataFrame:
    table = pl.DataFrame(schema={"country": pl.String})
    for variable in VARIABLES[:6]:
        table = full_join(table, results[variable].timespan.rename({
            "last_observation": f"{variable}_last", "first_observation": f"{variable}_first",
        }))
    return table.sort("country")


def build_standard_deviations(results: dict[str, VariableResult]) -> pl.DataFrame:
    table = pl.DataFrame(schema={"country": pl.String})
    for variable, symbol in SYMBOLS.items():
        table = full_join(table, results[variable].stdv.rename({"stdv": symbol}))
    return table.with_columns(
        (pl.col("y") * 100).round(2), (pl.col("nx") * 100).round(2),
        *((pl.col(symbol) / pl.col("y")).round(2) for symbol in ("c", "x", "g", "n", "z")),
    ).select("country", "y", "nx", "c", "x", "g", "n", "z").sort("country")


def build_usa_correlation_matrix(results: dict[str, VariableResult]) -> pl.DataFrame:
    table = pl.DataFrame(schema={"country": pl.String})
    for variable in VARIABLES:
        matrix = results[variable].correlation
        name = "solow" if variable == "solow_residuals" else variable
        table = full_join(table, matrix.select("country", pl.col("USA").alias(name)))
    return table


def rounded_text(value: float, digits: int = 2) -> str | None:
    if not math.isfinite(value):
        return None
    result = round(value, digits)
    return "0" if result == 0 else f"{result:.{digits}f}".rstrip("0").rstrip(".")


def build_within_country_correlations(panel: pl.DataFrame) -> pl.DataFrame:
    rows: list[dict[str, str | None]] = []
    columns = dict(zip(VARIABLES, ("gdp", "cons", "inv", "gov", "net", "emp", "sol"), strict=True))
    for (country,), data in panel.group_by("location", maintain_order=True):
        wide = data.pivot(on="variable", index="time", values="filtered")
        gdp = data.filter(pl.col("variable") == "gdp").select("filtered").with_columns(pl.col("filtered").shift().alias("lag"))
        row: dict[str, str | None] = {
            "country": str(country),
            "autocorrelation": rounded_text(pairwise_correlation(gdp, "filtered", "lag")),
        }
        for variable, column in columns.items():
            row[column] = rounded_text(pairwise_correlation(wide, "gdp", variable)) if variable in wide.columns else None
        rows.append(row)
    return pl.DataFrame(rows).sort("country")


def type_one_quantile(values: list[float], probability: float) -> float:
    """R quantile(type=1): inverse empirical CDF, including endpoint handling."""
    if not values or not 0 <= probability <= 1:
        raise ValueError("Quantiles require nonempty data and probability in [0, 1]")
    return sorted(values)[max(0, math.ceil(len(values) * probability) - 1)]


def build_average_cross_country_correlations(results: dict[str, VariableResult]) -> pl.DataFrame:
    rows: list[dict[str, str | float]] = []
    for variable, symbol in SYMBOLS.items():
        matrix = results[variable].correlation
        values = correlation_pairs(matrix)["correlation"].to_list()
        usa = matrix.filter(pl.col("country") != "USA")["USA"].to_list()
        rows.append({
            # Exact accumulation avoids double rounding from sum()/len(). This
            # matches R's extended-precision mean at CSV's 15-digit precision.
            "Variable": symbol, "Mean": mean(values), "USA Mean": mean(usa),
            **{f"{probability * 100:g}%": type_one_quantile(values, probability) for probability in PROBABILITIES},
        })
    return pl.DataFrame(rows)


def run_analysis(data_dir: Path | str = Path("data/raw")) -> AnalysisResult:
    panel, initial_timespan = build_analysis_panel(load_raw_data(Path(data_dir)))
    variables = build_variable_results(panel)
    return AnalysisResult(panel, variables, {
        "timespan": build_timespan(variables),
        "standard_deviations": build_standard_deviations(variables),
        "within_country_correlations": build_within_country_correlations(panel),
        "usa_correlation_matrix": build_usa_correlation_matrix(variables),
        "average_cross_country_correlations": build_average_cross_country_correlations(variables),
    }, initial_timespan)
