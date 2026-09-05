"""Compare independently computed extension tables without rounding estimates."""

from dataclasses import dataclass
from collections.abc import Mapping

import numpy as np
import polars as pl

from .domain import Table

ABSOLUTE_TOLERANCE = 1e-9


@dataclass(frozen=True)
class Comparison:
    table: str
    matches: bool
    numeric_values: int
    max_absolute_error: float
    detail: str


def compare_tables(actual: Mapping[Table, pl.DataFrame], reference: Mapping[Table, pl.DataFrame]) -> tuple[Comparison, ...]:
    reports = []
    for table in Table:
        if table not in actual or table not in reference:
            reports.append(Comparison(table.value, False, 0, 0, "Missing table"))
            continue
        frame, expected = actual[table], reference[table]
        if frame.columns != expected.columns or frame.shape != expected.shape:
            reports.append(Comparison(table.value, False, 0, 0, "Columns or dimensions differ"))
            continue
        count, maximum = 0, 0.0
        failures = []
        for column in frame.columns:
            left, right = frame[column], expected[column]
            if not left.is_null().equals(right.is_null()):
                failures.append(f"{column}: missing-value mask")
                continue
            if left.dtype.is_numeric() and right.dtype.is_numeric():
                a, b = left.drop_nulls().to_numpy(), right.drop_nulls().to_numpy()
                count += len(a)
                if not np.isfinite(a).all() or not np.isfinite(b).all():
                    failures.append(f"{column}: non-finite estimates")
                    continue
                error = float(np.max(np.abs(a - b))) if len(a) else 0.0
                maximum = max(maximum, error)
                tolerance = 0.0 if left.dtype.is_integer() and right.dtype.is_integer() else ABSOLUTE_TOLERANCE
                if error > tolerance:
                    failures.append(f"{column}: error {error:.3g} exceeds {tolerance}")
            elif left.to_list() != right.to_list():
                failures.append(f"{column}: exact values differ")
        reports.append(Comparison(table.value, not failures, count, maximum, "; ".join(failures) if failures else "Matched"))
    return tuple(reports)
