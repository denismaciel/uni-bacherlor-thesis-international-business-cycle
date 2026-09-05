"""Independent R fixtures plus scientific invariants for the Python extension."""

from pathlib import Path

import numpy as np
import polars as pl
import pytest

from bkk_business_cycle.extension.data import balanced_panel, quarter_number, validate_panel, window
from bkk_business_cycle.extension.domain import Config, Method, Panel
from bkk_business_cycle.extension.inputs import load_inputs
from bkk_business_cycle.extension.random import block_indices, r_mt19937, sample_index
from bkk_business_cycle.extension.statistics import bootstrap, mean_moments

ROOT = Path(__file__).resolve().parents[1]
ORACLE = ROOT / "reference/extension_oracle"


@pytest.fixture(scope="module")
def inputs():
    return load_inputs(ROOT, Config())


@pytest.fixture(scope="module")
def levels(inputs):
    return balanced_panel(inputs.current)


def test_all_r_random_streams_and_block_indices_match_exactly():
    samples = pl.read_csv(ORACLE / "random_indices.csv")
    for (seed, n), group in samples.partition_by("seed", "n", as_dict=True).items():
        generator = r_mt19937(seed)
        np.testing.assert_array_equal([sample_index(generator, n) for _ in range(group.height)], group["index"].to_numpy())
    np.testing.assert_array_equal(block_indices(111, 8, 99, 20260905), pl.read_csv(ORACLE / "block_indices.csv").to_numpy())


@pytest.mark.parametrize("method", list(Method))
@pytest.mark.parametrize("vintage", ["current", "original"])
def test_transformations_and_nondefault_bootstrap_match_r(inputs, method, vintage):
    source = inputs.current if vintage == "current" else inputs.original
    levels = balanced_panel(source, quarter_number("1996-Q1"), None if vintage == "current" else quarter_number("2015-Q1"))
    sample = window(levels, method, int(levels.quarters[0]) + 11, int(levels.quarters[-1]))
    expected = pl.read_csv(ORACLE / "transformed.csv").filter((pl.col("vintage") == vintage) & (pl.col("method") == method))
    for i, country in enumerate(sample.countries):
        rows = expected.filter(pl.col("country") == country).sort("time")
        np.testing.assert_array_equal(sample.quarters, [quarter_number(t) for t in rows["time"]])
        np.testing.assert_allclose(sample.output[:, i], rows["output"].to_numpy(), atol=1e-10, rtol=0)
        np.testing.assert_allclose(sample.consumption[:, i], rows["consumption"].to_numpy(), atol=1e-10, rtol=0)
    boot = bootstrap(sample, Config(repetitions=99, seed=42))
    expected_boot = pl.read_csv(ORACLE / "bootstrap_99_seed42.csv").filter((pl.col("vintage") == vintage) & (pl.col("method") == method)).sort("statistic")
    for actual, field in ((boot.point, "point"), (boot.lower, "lower"), (boot.upper, "upper")):
        np.testing.assert_allclose(actual, expected_boot[field].to_numpy(), atol=1e-9, rtol=0)


def test_alignment_validation(inputs, levels):
    shuffled = balanced_panel(inputs.current.sample(fraction=1, shuffle=True, seed=42))
    np.testing.assert_array_equal(levels.output, shuffled.output)
    assert levels.output.shape == (122, 10)
    with pytest.raises(ValueError, match="Duplicate"):
        validate_panel(pl.concat([inputs.current, inputs.current.head(1)]))
    missing = inputs.current.filter(~((pl.col("location") == "USA") & (pl.col("variable") == "gdp") & (pl.col("time") == "2000-Q1")))
    with pytest.raises(ValueError, match="Internal missing"):
        validate_panel(missing)
    with pytest.raises(ValueError, match="outside balanced"):
        balanced_panel(inputs.current, quarter_number("1995-Q1"))


@pytest.mark.parametrize("method", list(Method))
def test_scaling_and_future_observations_do_not_change_period_estimates(levels, method):
    first, end = int(levels.quarters[0]) + 11, quarter_number("2019-Q4")
    sample = window(levels, method, first, end)
    scaled = Panel(levels.quarters, levels.countries, levels.output + np.log(1000), levels.consumption + np.log(17))
    np.testing.assert_allclose(mean_moments(sample), mean_moments(window(scaled, method, first, end)), atol=1e-9, rtol=0)
    output = levels.output.copy()
    output[levels.quarters > end] = 1000
    changed = Panel(levels.quarters, levels.countries, output, levels.consumption)
    np.testing.assert_array_equal(sample.output, window(changed, method, first, end).output)


def test_joint_resampling_and_vintage_covariance(levels):
    sample = window(levels, Method.GROWTH, int(levels.quarters[0]) + 11, int(levels.quarters[-1]))
    identical = Panel(sample.quarters, sample.countries, sample.output, sample.output)
    config = Config(repetitions=99)
    result = bootstrap(identical, config)
    np.testing.assert_array_equal(result.point[2:], 0)
    np.testing.assert_array_equal(result.upper[2:], 0)
    difference = bootstrap(sample, config, other=sample)
    np.testing.assert_array_equal(difference.lower, 0)
    np.testing.assert_array_equal(difference.upper, 0)
