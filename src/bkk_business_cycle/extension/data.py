"""Validation, balanced samples and transformations; no filesystem access."""

import re

import numpy as np
import polars as pl

from ..panel import hp_cycle
from .domain import COUNTRIES, FloatArray, Method, Panel


def quarter_number(period: str) -> int:
    if not re.fullmatch(r"[0-9]{4}-Q[1-4]", period):
        raise ValueError(f"Invalid quarterly date: {period}")
    return int(period[:4]) * 4 + int(period[-1]) - 1


def quarter_text(number: int) -> str:
    return f"{number // 4}-Q{number % 4 + 1}"


def validate_panel(panel: pl.DataFrame, countries: tuple[str, ...] = COUNTRIES) -> pl.DataFrame:
    required = ("location", "time", "variable", "value")
    if not set(required) <= set(panel.columns):
        raise ValueError("Missing panel columns")
    core = panel.filter(pl.col("location").is_in(countries) & pl.col("variable").is_in(("gdp", "consumption")))
    if any(core.select(required).null_count().row(0)) or not core["value"].is_finite().all() or (core["value"] <= 0).any():
        raise ValueError("Missing, non-finite or non-positive levels")
    core = core.with_columns(pl.Series("quarter", [quarter_number(t) for t in core["time"]]))
    if core.select(pl.struct("location", "variable", "quarter").is_duplicated().any()).item():
        raise ValueError("Duplicate country-variable-quarter observations")
    groups = core.partition_by("location", "variable", as_dict=True)
    if set(groups) != {(country, variable) for country in countries for variable in ("gdp", "consumption")}:
        raise ValueError("Missing country-variable series")
    for key, group in groups.items():
        if np.any(np.diff(np.sort(group["quarter"].to_numpy())) != 1):
            raise ValueError(f"Internal missing quarter: {key}")
    return core.sort("location", "variable", "quarter")


def validate_current(panel: pl.DataFrame) -> pl.DataFrame:
    core = panel.filter(pl.col("variable").is_in(("gdp", "consumption")))
    for field, value in {"unit_measure": "XDC", "price_base": "L", "adjustment": "Y", "transformation": "N"}.items():
        if field not in core.columns or core[field].null_count() or not (core[field] == value).all():
            raise ValueError(f"Unexpected measurement: {field}")
    for group in core.partition_by("location", "variable"):
        for field in ("currency", "unit_mult", "reference_year", "series_key"):
            if field not in group.columns or group[field].null_count() or group[field].n_unique() != 1:
                raise ValueError(f"Measurement varies: {field}")
    return validate_panel(core)


def balanced_panel(panel: pl.DataFrame, start: int | None = None, end: int | None = None,
                   countries: tuple[str, ...] = COUNTRIES) -> Panel:
    core = validate_panel(panel, countries)
    groups = core.partition_by("location", "variable", as_dict=True)
    available_start = max(int(g["quarter"].to_numpy().min()) for g in groups.values())
    available_end = min(int(g["quarter"].to_numpy().max()) for g in groups.values())
    first = available_start if start is None else start
    last = available_end if end is None else end
    if first < available_start or last > available_end or first > last:
        raise ValueError("Requested window outside balanced coverage")
    quarters = np.arange(first, last + 1, dtype=np.int64)
    countries = tuple(sorted(countries))
    matrices = [np.column_stack([
        np.log(groups[country, variable].filter(pl.col("quarter").is_between(first, last)).sort("quarter")["value"].to_numpy())
        for country in countries
    ]) for variable in ("gdp", "consumption")]
    return Panel(quarters, countries, matrices[0], matrices[1])


def transform(panel: Panel, method: Method) -> Panel:
    def one(values: FloatArray) -> FloatArray:
        if method == Method.HP:
            return hp_cycle(values, 1600.0)
        if method == Method.GROWTH:
            return np.concatenate(([np.nan], np.diff(values)))
        if method != Method.HAMILTON:
            raise ValueError("Unknown transformation")
        if len(values) < 20:
            raise ValueError("Insufficient Hamilton history")
        targets = np.arange(11, len(values))
        design = np.column_stack([np.ones(len(targets)), *(values[targets - lag] for lag in range(8, 12))])
        coefficients, _, rank, _ = np.linalg.lstsq(design, values[targets], rcond=1e-7)
        if rank < design.shape[1]:
            raise ValueError("Rank-deficient Hamilton regression")
        return np.concatenate((np.full(11, np.nan), values[targets] - design @ coefficients))
    return Panel(panel.quarters, panel.countries,
                 np.column_stack([one(x) for x in panel.output.T]),
                 np.column_stack([one(x) for x in panel.consumption.T]))


def slice_panel(panel: Panel, first: int, last: int) -> Panel:
    keep = (panel.quarters >= first) & (panel.quarters <= last)
    if np.sum(keep) < 3:
        raise ValueError("Insufficient observations")
    result = panel.take(keep)
    if not np.isfinite(result.output).all() or not np.isfinite(result.consumption).all():
        raise ValueError("Incomplete transformed window")
    return result


def window(levels: Panel, method: Method, first: int, last: int, context_end: int | None = None) -> Panel:
    context = slice_panel(levels, int(levels.quarters.min()), last if context_end is None else context_end)
    return slice_panel(transform(context, method), first, last)
