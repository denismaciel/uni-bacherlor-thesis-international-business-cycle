"""Named contracts and the fixed methodology of the 2015 reproduction."""

from dataclasses import dataclass
from enum import StrEnum
import math
import re
from collections.abc import Mapping

import polars as pl


class Variable(StrEnum):
    GDP = "gdp"
    CONSUMPTION = "consumption"
    INVESTMENT = "investment"
    GOVERNMENT = "government"
    NET_EXPORTS = "net_exports"
    EMPLOYMENT = "employment"
    SOLOW = "solow_residuals"


VARIABLES = tuple(Variable)
STANDARD_VARIABLES = (
    Variable.GDP,
    Variable.CONSUMPTION,
    Variable.INVESTMENT,
    Variable.GOVERNMENT,
)
SOURCE_VARIABLES = (*STANDARD_VARIABLES, Variable.NET_EXPORTS, Variable.EMPLOYMENT)
TIMESPAN_VARIABLES = SOURCE_VARIABLES
SYMBOLS = {
    Variable.GDP: "y",
    Variable.CONSUMPTION: "c",
    Variable.INVESTMENT: "x",
    Variable.GOVERNMENT: "g",
    Variable.NET_EXPORTS: "nx",
    Variable.EMPLOYMENT: "n",
    Variable.SOLOW: "z",
}
GDP_SUBJECT = "Gross domestic product - expenditure approach"
KEYS = ["location", "time"]


class TableId(StrEnum):
    TIMESPAN = "timespan"
    STANDARD_DEVIATIONS = "standard_deviations"
    WITHIN_COUNTRY = "within_country_correlations"
    USA = "usa_correlation_matrix"
    AVERAGE = "average_cross_country_correlations"


@dataclass(frozen=True)
class ThesisTables:
    timespan: pl.DataFrame
    standard_deviations: pl.DataFrame
    within_country_correlations: pl.DataFrame
    usa_correlation_matrix: pl.DataFrame
    average_cross_country_correlations: pl.DataFrame

    def items(self) -> tuple[tuple[TableId, pl.DataFrame], ...]:
        return (
            (TableId.TIMESPAN, self.timespan),
            (TableId.STANDARD_DEVIATIONS, self.standard_deviations),
            (TableId.WITHIN_COUNTRY, self.within_country_correlations),
            (TableId.USA, self.usa_correlation_matrix),
            (TableId.AVERAGE, self.average_cross_country_correlations),
        )

    def __getitem__(self, key: TableId) -> pl.DataFrame:
        return dict(self.items())[key]


@dataclass(frozen=True)
class EmploymentSplice:
    country: str
    switch_quarter: str = "2011-Q4"
    end_quarter: str = "2015-Q1"
    drop_tail_rows: int = 0
    index_reference_quarter: str | None = None

    def __post_init__(self) -> None:
        quarters = (self.switch_quarter, self.end_quarter, self.index_reference_quarter)
        if any(
            q is not None and re.fullmatch(r"\d{4}-Q[1-4]", q) is None for q in quarters
        ):
            raise ValueError("Splice policy requires canonical quarters")
        if self.switch_quarter > self.end_quarter or self.drop_tail_rows < 0:
            raise ValueError("Invalid splice interval or tail truncation")


class ObservationOrder(StrEnum):
    SOURCE_ROWS = "source_rows"


class QuantileMethod(StrEnum):
    INVERSE_EMPIRICAL_CDF = "inverse_empirical_cdf"


class MissingPairs(StrEnum):
    PAIRWISE_COMPLETE = "pairwise_complete"


@dataclass(frozen=True)
class Thesis2015Policy:
    """Fixed compatibility policy, not an arbitrary research configuration."""

    hp_lambda: float = 1600.0
    capital_share: float = 0.36
    correlation_digits: int = 3
    publication_digits: int = 2
    sample_ddof: int = 1
    observation_order: ObservationOrder = ObservationOrder.SOURCE_ROWS
    missing_pairs: MissingPairs = MissingPairs.PAIRWISE_COMPLETE
    quantile_method: QuantileMethod = QuantileMethod.INVERSE_EMPIRICAL_CDF
    probabilities: tuple[float, ...] = (0.0, 0.1, 0.25, 0.4, 0.5, 0.6, 0.75, 0.9, 1.0)
    employment_exclusions: tuple[str, ...] = ("CHE", "EA19")
    splices: tuple[EmploymentSplice, ...] = (
        EmploymentSplice("GBR"),
        EmploymentSplice("ITA"),
        EmploymentSplice("FRA", drop_tail_rows=5, index_reference_quarter="2005-Q2"),
    )

    def __post_init__(self) -> None:
        if not math.isfinite(self.hp_lambda) or self.hp_lambda < 0:
            raise ValueError("HP lambda must be finite and nonnegative")
        if not math.isfinite(self.capital_share) or not 0 <= self.capital_share <= 1:
            raise ValueError("Capital share must be in [0, 1]")
        if (
            self.correlation_digits < 0
            or self.publication_digits < 0
            or self.sample_ddof != 1
        ):
            raise ValueError(
                "Invalid precision or unsupported standard-deviation convention"
            )
        if self.probabilities != (0.0, 0.1, 0.25, 0.4, 0.5, 0.6, 0.75, 0.9, 1.0):
            raise ValueError(
                "Thesis publication requires the original probability grid"
            )
        if len({rule.country for rule in self.splices}) != len(self.splices):
            raise ValueError("Duplicate employment splice policy")
        if (
            self.observation_order != ObservationOrder.SOURCE_ROWS
            or self.missing_pairs != MissingPairs.PAIRWISE_COMPLETE
            or self.quantile_method != QuantileMethod.INVERSE_EMPIRICAL_CDF
        ):
            raise ValueError("Unsupported reproduction convention")


THESIS_2015 = Thesis2015Policy()


@dataclass(frozen=True)
class ValidatedInputs:
    oecd: Mapping[Variable, pl.DataFrame]
    fred: Mapping[str, pl.DataFrame]
    policy: Thesis2015Policy


class UnavailableReason(StrEnum):
    SERIES_ABSENT = "series_absent"
    INSUFFICIENT_OVERLAP = "insufficient_overlap"
    ZERO_VARIANCE = "zero_variance"


@dataclass(frozen=True)
class Estimated:
    value: float
    observations: int


@dataclass(frozen=True)
class Unavailable:
    reason: UnavailableReason
    observations: int


type Estimate = Estimated | Unavailable


class StatisticScope(StrEnum):
    CROSS_COUNTRY = "cross_country"
    WITHIN_COUNTRY = "within_country"
    AUTOCORRELATION = "autocorrelation"
    RELATIVE_VOLATILITY = "relative_volatility"
    CROSS_COUNTRY_SUMMARY = "cross_country_summary"


@dataclass(frozen=True)
class StatisticAssessment:
    scope: StatisticScope
    context: str
    left: str
    right: str
    estimate: Estimate
