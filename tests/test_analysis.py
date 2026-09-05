from pathlib import Path

import numpy as np
import polars as pl
import pytest

from bkk_business_cycle.analysis import AnalysisResult, pairwise_correlation, run_analysis, type_one_quantile
from bkk_business_cycle.export import TABLE_FILES, check_reference, export_tables
from bkk_business_cycle.panel import hp_cycle, splice_employment_series

ROOT = Path(__file__).resolve().parents[1]


@pytest.fixture(scope="session")
def results() -> AnalysisResult:
    return run_analysis(ROOT / "data/raw")


def test_all_publication_tables_exactly_match_r(results: AnalysisResult, tmp_path: Path) -> None:
    check_reference(results, ROOT / "reference/tables")
    export_tables(results, tmp_path)
    for stem in TABLE_FILES.values():
        assert (tmp_path / f"{stem}.csv").read_bytes() == (ROOT / "reference/tables" / f"{stem}.csv").read_bytes()
        assert r"\begin{tabular}" in (tmp_path / f"{stem}.tex").read_text()


@pytest.mark.parametrize("size", [3, 4, 30])
@pytest.mark.parametrize("smoothing", [0.0, 1600.0])
def test_hp_banded_solver_against_dense_objective(size: int, smoothing: float) -> None:
    values = np.random.default_rng(13).normal(size=size)
    difference = np.diff(np.eye(size), n=2, axis=0)
    expected = values - np.linalg.solve(np.eye(size) + smoothing * difference.T @ difference, values)
    np.testing.assert_allclose(hp_cycle(values, smoothing), expected, rtol=0, atol=1e-11)


def test_hp_removes_linear_trend() -> None:
    np.testing.assert_allclose(hp_cycle(np.linspace(1, 10, 100)), 0, atol=1e-10)


@pytest.mark.parametrize("values", [[], [1.0, 2.0], [1.0, np.nan, 3.0], [1.0, np.inf, 3.0]])
def test_hp_rejects_invalid_series(values: list[float]) -> None:
    with pytest.raises(ValueError):
        hp_cycle(np.array(values))


def test_pairwise_missing_values_do_not_drop_other_pairs() -> None:
    data = pl.DataFrame({"a": [1.0, 2.0, 3.0, None], "b": [2.0, 4.0, None, 5.0], "c": [None, 5.0, 1.0, 7.0]})
    assert pairwise_correlation(data, "a", "b") == pytest.approx(1)
    assert pairwise_correlation(data, "a", "c") == pytest.approx(-1)


@pytest.mark.parametrize(("probability", "expected"), [(0, 1), (0.1, 1), (0.25, 1), (0.4, 2), (0.5, 2), (0.75, 3), (1, 4)])
def test_r_type_one_quantiles(probability: float, expected: float) -> None:
    assert type_one_quantile([4, 1, 3, 2], probability) == expected


def test_splice_switch_factor_and_original_full_join_order() -> None:
    fred = pl.DataFrame({"time": ["2011-Q3", "2011-Q4"], "value": [90.0, 100.0]})
    oecd = pl.DataFrame({"time": ["2011-Q2", "2011-Q4", "2012-Q1", "2015-Q2"], "value": [40.0, 50.0, 55.0, 60.0]})
    result = splice_employment_series(fred, oecd, "GBR")
    assert result["time"].to_list() == ["2011-Q3", "2011-Q4", "2011-Q2", "2012-Q1"]
    assert result["value"].to_list() == [90.0, 100.0, None, 110.0]


def test_france_truncation_and_labor_country_coverage(results: AnalysisResult) -> None:
    france = results.series["employment"].filter(pl.col("location") == "FRA")
    assert france["time"].max() == "2013-Q4"
    assert not set(results.series["employment"]["location"]) & {"CHE", "EA19", "EU15"}
    assert results.panel.select(pl.struct("variable", "location", "time").is_duplicated().any()).item() is False
