"""Joint time-block inference conditional on the fitted transformations."""

import numpy as np

from .domain import Bootstrap, Config, FloatArray, Panel
from .random import block_indices


def pair_values(panel: Panel) -> FloatArray:
    if panel.output.shape != panel.consumption.shape or panel.output.ndim != 2 or panel.output.shape[1] != len(panel.countries):
        raise ValueError("Output and consumption dimensions differ")
    if not np.isfinite(panel.output).all() or not np.isfinite(panel.consumption).all():
        raise ValueError("Non-finite transformed data")
    if np.any(np.std(panel.output, axis=0) == 0) or np.any(np.std(panel.consumption, axis=0) == 0):
        raise ValueError("Zero-variance series")
    pairs = np.triu_indices(len(panel.countries), 1)
    output = np.corrcoef(panel.output, rowvar=False)[pairs]
    consumption = np.corrcoef(panel.consumption, rowvar=False)[pairs]
    return np.column_stack((output, consumption, output - consumption))


def mean_moments(panel: Panel) -> FloatArray:
    return pair_values(panel).mean(axis=0)


def bootstrap(panel: Panel, config: Config, length: int = 8, other: Panel | None = None) -> Bootstrap:
    if other is not None and (not np.array_equal(panel.quarters, other.quarters) or panel.countries != other.countries):
        raise ValueError("Vintage comparison requires identical countries and dates")
    if len(panel.quarters) < max(40, 4 * length):
        raise ValueError("Window too short for selected bootstrap block")
    def statistic(source: Panel) -> FloatArray:
        pairs = pair_values(source)
        return np.concatenate((pairs.mean(axis=0), pairs[:, 2]))
    point = statistic(panel)
    if other is not None:
        point -= statistic(other)
    indices = block_indices(len(panel.quarters), length, config.repetitions, config.seed)
    draws = np.array([
        statistic(panel.take(index)) if other is None else statistic(panel.take(index)) - statistic(other.take(index))
        for index in indices
    ])
    limits = np.quantile(draws, (0.025, 0.975), axis=0, method="linear")
    return Bootstrap(point, limits[0], limits[1])
