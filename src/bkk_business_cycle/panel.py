"""Pure panel transformations under the explicit reproduction policy."""

import numpy as np
import numpy.typing as npt
import polars as pl
from scipy.linalg import solveh_banded

from .domain import (
    STANDARD_VARIABLES,
    GDP_SUBJECT,
    KEYS,
    THESIS_2015,
    EmploymentSplice,
    ValidatedInputs,
    Variable,
)

HP_LAMBDA = THESIS_2015.hp_lambda


def timespan_by_country(data: pl.DataFrame) -> pl.DataFrame:
    return (
        data.group_by("location", maintain_order=True)
        .agg(
            pl.col("time").max().alias("last_observation"),
            pl.col("time").min().alias("first_observation"),
        )
        .rename({"location": "country"})
    )


def employment_sources(
    raw: ValidatedInputs, rule: EmploymentSplice
) -> tuple[pl.DataFrame, pl.DataFrame]:
    oecd = (
        raw.oecd[Variable.EMPLOYMENT]
        .filter(
            (pl.col("subject_code") == "LFEMTTTT")
            & (pl.col("location") == rule.country)
        )
        .select(*KEYS, "value")
    )
    fred = raw.fred[rule.country]
    if rule.index_reference_quarter is not None:
        reference = float(
            oecd.filter(pl.col("time") == rule.index_reference_quarter)["value"].item()
        )
        fred = fred.with_columns(pl.col("value") * reference / 100)
    return fred, oecd


def splice_employment_series(
    fred: pl.DataFrame,
    oecd: pl.DataFrame,
    rule: EmploymentSplice,
) -> pl.DataFrame:
    # R full_join keeps FRED rows, then appends unmatched OECD rows. Do not sort:
    # the original France head(-5) and HP filter both depend on this order.
    splice = (
        fred.rename({"value": "fred_value"})
        .join(
            oecd.select("time", pl.col("value").alias("oecd_value")),
            on="time",
            how="full",
            coalesce=True,
            maintain_order="left_right",
            validate="1:1",
        )
        .filter(pl.col("time") <= rule.end_quarter)
    )
    switch = splice.filter(pl.col("time") == rule.switch_quarter)
    factor = float(switch["fred_value"].item()) / float(switch["oecd_value"].item())
    return splice.select(
        pl.lit(rule.country).alias("location"),
        "time",
        pl.when(pl.col("time") <= rule.switch_quarter)
        .then(pl.col("fred_value"))
        .otherwise(pl.col("oecd_value") * factor)
        .alias("value"),
    )


def hp_cycle(
    values: npt.NDArray[np.float64], smoothing: float = HP_LAMBDA
) -> npt.NDArray[np.float64]:
    """Two-sided HP cycle, solving (I + lambda D'D) trend = values."""
    if values.ndim != 1 or len(values) < 3 or not np.isfinite(values).all():
        raise ValueError("HP filter requires at least three finite observations")
    if not np.isfinite(smoothing) or smoothing < 0:
        raise ValueError("HP smoothing must be finite and nonnegative")
    # Lower diagonals of I + lambda D'D. Accumulation also handles n=3.
    n = len(values)
    bands = np.zeros((3, n))
    bands[0] = 1
    bands[0, :-2] += smoothing
    bands[0, 1:-1] += 4 * smoothing
    bands[0, 2:] += smoothing
    bands[1, :-2] -= 2 * smoothing
    bands[1, 1:-1] -= 2 * smoothing
    bands[2, :-2] = smoothing
    trend = solveh_banded(bands, values, lower=True)
    return values - trend


def add_hp_filter(panel: pl.DataFrame, smoothing: float = HP_LAMBDA) -> pl.DataFrame:
    indexed = panel.with_row_index("_row")
    groups = indexed.partition_by(["variable", "location"], maintain_order=True)
    return (
        pl.concat(
            [
                group.with_columns(
                    pl.Series(
                        "filtered", hp_cycle(group["value"].to_numpy(), smoothing)
                    )
                )
                for group in groups
            ]
        )
        .sort("_row")
        .drop("_row")
    )


def build_analysis_panel(raw: ValidatedInputs) -> tuple[pl.DataFrame, pl.DataFrame]:
    parts = [
        raw.oecd[variable].select(
            pl.lit(variable).alias("variable"),
            *KEYS,
            "subject",
            pl.col("value").log(),
        )
        for variable in STANDARD_VARIABLES
    ]
    net = raw.oecd[Variable.NET_EXPORTS]
    exports = net.filter(pl.col("subject") == "Exports of goods and services")
    imports = net.filter(pl.col("subject") == "Imports of goods and services")
    net_panel = (
        exports.select(*KEYS, pl.col("value").alias("exports"))
        .join(
            imports.select(*KEYS, pl.col("value").alias("imports")),
            on=KEYS,
            validate="1:1",
            maintain_order="left",
        )
        .join(
            net.filter(pl.col("subject") == GDP_SUBJECT).select(
                *KEYS, pl.col("value").alias("gdp")
            ),
            on=KEYS,
            how="left",
            validate="1:1",
            maintain_order="left",
        )
        .select(
            pl.lit("net_exports").alias("variable"),
            *KEYS,
            pl.lit("net_exports").alias("subject"),
            ((pl.col("exports") - pl.col("imports")) / pl.col("gdp")).alias("value"),
        )
    )
    parts.append(net_panel)
    employment = raw.oecd[Variable.EMPLOYMENT].filter(
        pl.col("subject_code") == "LFEMTTTT"
    )
    initial_timespan = timespan_by_country(employment)
    emp_parts = [
        employment.filter(
            ~pl.col("location").is_in(
                [
                    *raw.policy.employment_exclusions,
                    *(rule.country for rule in raw.policy.splices),
                ]
            )
        ).select(*KEYS, "value")
    ]
    for rule in raw.policy.splices:
        fred, oecd = employment_sources(raw, rule)
        spliced = splice_employment_series(fred, oecd, rule)
        if rule.drop_tail_rows:
            spliced = spliced.head(spliced.height - rule.drop_tail_rows)
        emp_parts.append(spliced)
    parts.append(
        pl.concat(emp_parts).select(
            pl.lit("employment").alias("variable"),
            *KEYS,
            pl.lit("employment").alias("subject"),
            pl.col("value").log(),
        )
    )
    base = pl.concat(parts)
    solow = (
        base.filter(pl.col("variable").is_in(["gdp", "employment"]))
        .pivot(
            on="variable",
            index=KEYS,
            values="value",
        )
        .drop_nulls(["gdp", "employment"])
        .sort(KEYS)
        .select(
            pl.lit("solow_residuals").alias("variable"),
            *KEYS,
            pl.lit("solow_residuals").alias("subject"),
            (
                pl.col("gdp") - (1 - raw.policy.capital_share) * pl.col("employment")
            ).alias("value"),
        )
    )
    panel = pl.concat([base, solow])
    if panel.select(pl.struct("variable", *KEYS).is_duplicated().any()).item():
        raise ValueError("Duplicate variable/country/quarter in the analysis panel")
    return add_hp_filter(panel, raw.policy.hp_lambda), initial_timespan
