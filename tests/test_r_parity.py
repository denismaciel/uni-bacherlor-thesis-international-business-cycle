"""Optional independent R oracle; see README for generating it."""

import os
from pathlib import Path

import numpy as np
import polars as pl
import pytest
from polars.testing import assert_frame_equal

from bkk_business_cycle.application import run_analysis
from bkk_business_cycle.analysis import AnalysisResult
from bkk_business_cycle.domain import VARIABLES

ORACLE = os.environ.get("BKK_R_ORACLE")
pytestmark = pytest.mark.skipif(
    ORACLE is None,
    reason="Set BKK_R_ORACLE to the directory from scripts/export_r_oracle.R",
)


def test_full_panel_and_all_variable_statistics_match_r() -> None:
    assert ORACLE is not None
    root = Path(ORACLE)
    results = run_analysis(Path(__file__).resolve().parents[1] / "data/raw")
    assert isinstance(results, AnalysisResult)
    reference = pl.read_csv(root / "panel.csv")
    keys = ["variable", "location", "time", "subject"]
    assert_frame_equal(results.panel.select(keys), reference.select(keys))
    for column in ("value", "filtered"):
        np.testing.assert_allclose(
            results.panel[column].to_numpy(),
            reference[column].to_numpy(),
            rtol=0,
            atol=1e-10,
        )
    for variable in VARIABLES:
        result = results.variable_results[variable]
        matrix = pl.read_csv(root / f"{variable}_correlation.csv").rename(
            {"": "country"}
        )
        assert_frame_equal(result.correlation, matrix, check_exact=True)
        stdv = pl.read_csv(root / f"{variable}_stdv.csv")
        assert result.stdv["country"].to_list() == stdv["country"].to_list()
        np.testing.assert_allclose(
            result.stdv["stdv"].to_numpy(),
            stdv.to_series(1).to_numpy(),
            rtol=0,
            atol=1e-10,
        )
    assert_frame_equal(
        results.employment_initial_timespan,
        pl.read_csv(root / "employment_initial_timespan.csv"),
    )
