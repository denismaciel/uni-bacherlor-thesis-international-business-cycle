"""All nine committed R result tables are a mandatory independent oracle."""

from pathlib import Path

import polars as pl
import pytest

from bkk_business_cycle.extension.analysis import analyze
from bkk_business_cycle.extension.domain import Config, Table
from bkk_business_cycle.extension.inputs import load_inputs
from bkk_business_cycle.extension.export import export_results
from bkk_business_cycle.extension.parity import compare_tables

ROOT = Path(__file__).resolve().parents[1]


@pytest.fixture(scope="module")
def results():
    config = Config()
    return analyze(load_inputs(ROOT, config), config)


def test_every_default_estimate_and_interval_matches_independent_r(results):
    references = {table: pl.read_csv(ROOT / "output/extension" / results.config.snapshot / f"{table.value}.csv") for table in Table}
    reports = compare_tables(results.tables, references)
    assert len(reports) == 9
    assert all(report.matches for report in reports), reports


def test_parity_rejects_changed_estimates_labels_missing_rows_and_nulls(results):
    references = dict(results.tables)
    for changed in (
        references[Table.SUMMARY].with_columns(pl.col("gap") + 0.001),
        references[Table.SUMMARY].with_columns(pl.lit("wrong").alias("period")),
        references[Table.SUMMARY].head(11),
        references[Table.SUMMARY].with_columns(pl.lit(None).cast(pl.Float64).alias("gap")),
    ):
        reference = references | {Table.SUMMARY: changed}
        assert not compare_tables(results.tables, reference)[0].matches
    assert not all(c.matches for c in compare_tables(results.tables, {}))


def test_serialized_results_preserve_r_parity(results, tmp_path):
    export_results(results, ROOT, tmp_path)
    actual = {table: pl.read_csv(tmp_path / f"{table.value}.csv", infer_schema_length=None) for table in Table}
    reference = {table: pl.read_csv(ROOT / "output/extension" / results.config.snapshot / f"{table.value}.csv") for table in Table}
    assert all(c.matches for c in compare_tables(actual, reference))
    assert (tmp_path / "REPORT.md").is_file()
    assert (tmp_path / "config.json").is_file()
