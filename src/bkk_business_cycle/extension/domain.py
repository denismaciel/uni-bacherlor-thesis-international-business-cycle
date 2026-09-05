"""Explicit data and result contracts for the research extension."""

from dataclasses import dataclass
from enum import StrEnum
from collections.abc import Mapping

import numpy as np
import numpy.typing as npt
import polars as pl

type FloatArray = npt.NDArray[np.float64]
type IntArray = npt.NDArray[np.int64]

COUNTRIES = ("AUS", "AUT", "CAN", "CHE", "DEU", "FRA", "GBR", "ITA", "JPN", "USA")
SNAPSHOT = "2026-09-05T221752Z"


class Method(StrEnum):
    HP = "hp1600"
    GROWTH = "growth"
    HAMILTON = "hamilton"


class Table(StrEnum):
    SUMMARY = "summary"
    PAIRS = "pairs"
    BLOCK = "block_sensitivity"
    ROLLING = "rolling"
    CONTEXT = "context_sensitivity"
    YEAR = "year_influence"
    EPISODES = "episode_diagnostics"
    VINTAGE = "vintage_comparison"
    VINTAGE_SERIES = "vintage_series"


@dataclass(frozen=True)
class Config:
    snapshot: str = SNAPSHOT
    repetitions: int = 1999
    seed: int = 20260905

    def __post_init__(self) -> None:
        if isinstance(self.repetitions, bool) or not isinstance(self.repetitions, int) or self.repetitions < 99:
            raise ValueError("Use at least 99 bootstrap replications")
        if isinstance(self.seed, bool) or not isinstance(self.seed, int) or not -(2**31) < self.seed < 2**31:
            raise ValueError("Seed must be a non-missing R signed integer")


@dataclass(frozen=True)
class Panel:
    quarters: IntArray
    countries: tuple[str, ...]
    output: FloatArray
    consumption: FloatArray

    def take(self, indices: npt.ArrayLike) -> Panel:
        index = np.asarray(indices)
        return Panel(self.quarters[index], self.countries, self.output[index], self.consumption[index])


@dataclass(frozen=True)
class Inputs:
    current: pl.DataFrame
    original: pl.DataFrame


@dataclass(frozen=True)
class Bootstrap:
    point: FloatArray
    lower: FloatArray
    upper: FloatArray


@dataclass(frozen=True)
class Result:
    tables: Mapping[Table, pl.DataFrame]
    config: Config
    level_start: int
    common_start: int
    end: int
