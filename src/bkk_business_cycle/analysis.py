"""Polars statistics and thesis tables, with the original R rounding rules."""

from dataclasses import dataclass
import math
from statistics import mean
from collections.abc import Mapping
from types import MappingProxyType

import polars as pl

from .panel import build_analysis_panel, timespan_by_country
from .domain import (
    VARIABLES,
    SYMBOLS,
    TIMESPAN_VARIABLES,
    Variable,
    ThesisTables,
    Thesis2015Policy,
    ValidatedInputs,
    Estimate,
    Estimated,
    Unavailable,
    UnavailableReason,
    StatisticAssessment,
    StatisticScope,
)


@dataclass(frozen=True)
class VariableResult:
    series: pl.DataFrame
    correlation: pl.DataFrame
    stdv: pl.DataFrame
    timespan: pl.DataFrame


@dataclass(frozen=True)
class AnalysisResult:
    panel: pl.DataFrame
    variable_results: Mapping[Variable, VariableResult]
    tables: ThesisTables
    employment_initial_timespan: pl.DataFrame
    assessments: tuple[StatisticAssessment, ...]

    @property
    def statistic_status(self) -> pl.DataFrame:
        return pl.DataFrame(
            [
                {
                    "scope": item.scope.value,
                    "context": item.context,
                    "left": item.left,
                    "right": item.right,
                    "value": item.estimate.value
                    if isinstance(item.estimate, Estimated)
                    else None,
                    "status": "estimated"
                    if isinstance(item.estimate, Estimated)
                    else item.estimate.reason.value,
                    "observations": item.estimate.observations,
                }
                for item in self.assessments
            ]
        )

    @property
    def series(self) -> dict[Variable, pl.DataFrame]:
        return {name: result.series for name, result in self.variable_results.items()}

    @property
    def correlations(self) -> dict[Variable, pl.DataFrame]:
        return {
            name: result.correlation for name, result in self.variable_results.items()
        }


def pairwise_correlation(data: pl.DataFrame, left: str, right: str) -> Estimate:
    if left not in data.columns or right not in data.columns:
        return Unavailable(UnavailableReason.SERIES_ABSENT, 0)
    pair = data.select(
        pl.col(left).alias("left"), pl.col(right).alias("right")
    ).drop_nulls()
    if pair.height < 2:
        return Unavailable(UnavailableReason.INSUFFICIENT_OVERLAP, pair.height)
    if pair.select(pl.all().is_finite().all()).row(0) != (True, True):
        raise ValueError("Nonfinite values violate the validated analysis contract")
    if pair["left"].n_unique() == 1 or pair["right"].n_unique() == 1:
        return Unavailable(UnavailableReason.ZERO_VARIANCE, pair.height)
    return Estimated(float(pair.select(pl.corr("left", "right")).item()), pair.height)


def estimate_value(result: Estimate, digits: int) -> float | None:
    return round(result.value, digits) if isinstance(result, Estimated) else None


def cross_country_correlation(
    series: pl.DataFrame, variable: Variable, policy: Thesis2015Policy
) -> tuple[pl.DataFrame, list[StatisticAssessment]]:
    wide = series.pivot(
        on="location", index="time", values="filtered", sort_columns=True
    )
    countries = [name for name in wide.columns if name != "time"]
    columns: dict[str, list[float | None]] = {}
    statuses = []
    for right in countries:
        estimates = [pairwise_correlation(wide, left, right) for left in countries]
        columns[right] = [
            estimate_value(result, policy.correlation_digits) for result in estimates
        ]
        statuses.extend(
            StatisticAssessment(
                StatisticScope.CROSS_COUNTRY, variable, left, right, result
            )
            for left, result in zip(countries, estimates, strict=True)
        )
    return pl.DataFrame(
        {"country": countries, **columns},
        schema_overrides={country: pl.Float64 for country in countries},
    ), statuses


def correlation_pairs(matrix: pl.DataFrame) -> pl.DataFrame:
    countries = matrix["country"].to_list()
    return pl.DataFrame(
        [
            {"left": left, "right": right, "correlation": matrix[right][i]}
            for i, left in enumerate(countries)
            for right in countries[i + 1 :]
        ],
        schema={"left": pl.String, "right": pl.String, "correlation": pl.Float64},
    )


def build_variable_results(
    panel: pl.DataFrame, policy: Thesis2015Policy
) -> tuple[dict[Variable, VariableResult], list[StatisticAssessment]]:
    results = {}
    statuses = []
    for variable in VARIABLES:
        series = panel.filter(pl.col("variable") == variable).drop("variable")
        correlation, status = cross_country_correlation(series, variable, policy)
        statuses.extend(status)
        results[variable] = VariableResult(
            series,
            correlation,
            series.group_by("location", maintain_order=True)
            .agg(pl.col("filtered").std(ddof=policy.sample_ddof).alias("stdv"))
            .rename({"location": "country"}),
            timespan_by_country(series),
        )
    return results, statuses


def full_join(left: pl.DataFrame, right: pl.DataFrame) -> pl.DataFrame:
    return left.join(
        right,
        on="country",
        how="full",
        coalesce=True,
        maintain_order="left_right",
        validate="1:1",
    )


def build_timespan(results: dict[Variable, VariableResult]) -> pl.DataFrame:
    table = pl.DataFrame(schema={"country": pl.String})
    for variable in TIMESPAN_VARIABLES:
        table = full_join(
            table,
            results[variable].timespan.rename(
                {
                    "last_observation": f"{variable}_last",
                    "first_observation": f"{variable}_first",
                }
            ),
        )
    return table.sort("country")


def build_standard_deviations(
    results: dict[Variable, VariableResult], policy: Thesis2015Policy
) -> tuple[pl.DataFrame, list[StatisticAssessment]]:
    table = pl.DataFrame(schema={"country": pl.String})
    for variable, symbol in SYMBOLS.items():
        table = full_join(table, results[variable].stdv.rename({"stdv": symbol}))
    statuses = []
    for row in table.iter_rows(named=True):
        for variable in (
            Variable.CONSUMPTION,
            Variable.INVESTMENT,
            Variable.GOVERNMENT,
            Variable.EMPLOYMENT,
            Variable.SOLOW,
        ):
            numerator, denominator = row[SYMBOLS[variable]], row["y"]
            count = (
                results[variable]
                .series.filter(pl.col("location") == row["country"])
                .height
            )
            if numerator is None or denominator is None:
                estimate: Estimate = Unavailable(UnavailableReason.SERIES_ABSENT, count)
            elif denominator == 0:
                estimate = Unavailable(UnavailableReason.ZERO_VARIANCE, count)
            else:
                estimate = Estimated(numerator / denominator, count)
            statuses.append(
                StatisticAssessment(
                    StatisticScope.RELATIVE_VOLATILITY,
                    row["country"],
                    variable,
                    Variable.GDP,
                    estimate,
                )
            )
    table = (
        table.with_columns(
            (pl.col("y") * 100).round(policy.publication_digits),
            (pl.col("nx") * 100).round(policy.publication_digits),
            *(
                pl.when(pl.col("y") > 0)
                .then(pl.col(symbol) / pl.col("y"))
                .otherwise(None)
                .round(policy.publication_digits)
                for symbol in ("c", "x", "g", "n", "z")
            ),
        )
        .select("country", "y", "nx", "c", "x", "g", "n", "z")
        .sort("country")
    )
    return table, statuses


def build_usa_correlation_matrix(
    results: dict[Variable, VariableResult],
) -> pl.DataFrame:
    table = pl.DataFrame(schema={"country": pl.String})
    for variable in VARIABLES:
        matrix = results[variable].correlation
        name = "solow" if variable == "solow_residuals" else variable
        table = full_join(table, matrix.select("country", pl.col("USA").alias(name)))
    return table


def build_within_country_correlations(
    panel: pl.DataFrame, policy: Thesis2015Policy
) -> tuple[pl.DataFrame, list[StatisticAssessment]]:
    rows: list[dict[str, str | float | None]] = []
    statuses = []
    columns = {
        Variable.GDP: "gdp",
        Variable.CONSUMPTION: "cons",
        Variable.INVESTMENT: "inv",
        Variable.GOVERNMENT: "gov",
        Variable.NET_EXPORTS: "net",
        Variable.EMPLOYMENT: "emp",
        Variable.SOLOW: "sol",
    }
    for (country,), data in panel.group_by("location", maintain_order=True):
        wide = data.pivot(on="variable", index="time", values="filtered")
        gdp = (
            data.filter(pl.col("variable") == Variable.GDP)
            .select("filtered")
            .with_columns(pl.col("filtered").shift().alias("lag"))
        )
        auto = pairwise_correlation(gdp, "filtered", "lag")
        row: dict[str, str | float | None] = {
            "country": str(country),
            "autocorrelation": estimate_value(auto, policy.publication_digits),
        }
        statuses.append(
            StatisticAssessment(
                StatisticScope.AUTOCORRELATION, str(country), "gdp", "lag", auto
            )
        )
        for variable, column in columns.items():
            result = pairwise_correlation(wide, "gdp", variable)
            row[column] = estimate_value(result, policy.publication_digits)
            statuses.append(
                StatisticAssessment(
                    StatisticScope.WITHIN_COUNTRY, str(country), "gdp", variable, result
                )
            )
        rows.append(row)
    return pl.DataFrame(
        rows,
        schema_overrides={
            column: pl.Float64 for column in ("autocorrelation", *columns.values())
        },
    ).sort("country"), statuses


def type_one_quantile(values: list[float], probability: float) -> float:
    """R quantile(type=1): inverse empirical CDF, including endpoint handling."""
    if not values or not 0 <= probability <= 1:
        raise ValueError("Quantiles require nonempty data and probability in [0, 1]")
    return sorted(values)[max(0, math.ceil(len(values) * probability) - 1)]


def build_average_cross_country_correlations(
    results: dict[Variable, VariableResult], policy: Thesis2015Policy
) -> tuple[pl.DataFrame, list[StatisticAssessment]]:
    rows: list[dict[str, str | float | None]] = []
    statuses = []
    for variable, symbol in SYMBOLS.items():
        matrix = results[variable].correlation
        values = correlation_pairs(matrix)["correlation"].drop_nulls().to_list()
        usa = matrix.filter(pl.col("country") != "USA")["USA"].drop_nulls().to_list()
        for label, sample in (("Mean", values), ("USA Mean", usa)):
            estimate: Estimate = (
                Estimated(mean(sample), len(sample))
                if sample
                else Unavailable(UnavailableReason.INSUFFICIENT_OVERLAP, 0)
            )
            statuses.append(
                StatisticAssessment(
                    StatisticScope.CROSS_COUNTRY_SUMMARY,
                    variable,
                    label,
                    "country_pairs",
                    estimate,
                )
            )
        rows.append(
            {
                # Exact accumulation avoids double rounding from sum()/len(). This
                # matches R's extended-precision mean at CSV's 15-digit precision.
                "Variable": symbol,
                "Mean": mean(values) if values else None,
                "USA Mean": mean(usa) if usa else None,
                **{
                    f"{probability * 100:g}%": (
                        type_one_quantile(values, probability) if values else None
                    )
                    for probability in policy.probabilities
                },
            }
        )
    return pl.DataFrame(
        rows,
        schema_overrides={
            column: pl.Float64
            for column in (
                "Mean",
                "USA Mean",
                *(f"{p * 100:g}%" for p in policy.probabilities),
            )
        },
    ), statuses


def analyze(inputs: ValidatedInputs) -> AnalysisResult:
    """Pure core: all inputs and methodology are supplied explicitly."""
    panel, initial_timespan = build_analysis_panel(inputs)
    variables, statuses = build_variable_results(panel, inputs.policy)
    within, within_status = build_within_country_correlations(panel, inputs.policy)
    standard_deviations, volatility_status = build_standard_deviations(
        variables, inputs.policy
    )
    averages, summary_status = build_average_cross_country_correlations(
        variables, inputs.policy
    )
    return AnalysisResult(
        panel,
        MappingProxyType(variables),
        ThesisTables(
            timespan=build_timespan(variables),
            standard_deviations=standard_deviations,
            within_country_correlations=within,
            usa_correlation_matrix=build_usa_correlation_matrix(variables),
            average_cross_country_correlations=averages,
        ),
        initial_timespan,
        tuple(statuses + within_status + volatility_status + summary_status),
    )
