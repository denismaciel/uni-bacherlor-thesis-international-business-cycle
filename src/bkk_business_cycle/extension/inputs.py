"""Filesystem adapters for extension inputs; original-vintage files stay intact."""

from pathlib import Path

import polars as pl

from .data import validate_current, validate_panel
from .domain import Config, Inputs


def input_paths(root: Path, config: Config) -> tuple[Path, ...]:
    return (root / "data/processed/oecd" / config.snapshot / "panel.csv",
            root / "data/raw/oecd/gdp.csv", root / "data/raw/oecd/consumption.csv")


def load_inputs(root: Path, config: Config) -> Inputs:
    current_path, *original_paths = input_paths(root, config)
    current = validate_current(pl.read_csv(current_path, infer_schema_length=None))
    originals = []
    for variable, path in zip(("gdp", "consumption"), original_paths, strict=True):
        raw = pl.read_csv(path, infer_schema_length=None)
        if not (raw["MEASURE"] == "VPVOBARSA").all() or not (raw["FREQUENCY"] == "Q").all():
            raise ValueError("Unexpected original measure")
        originals.append(raw.select(pl.col("LOCATION").alias("location"), pl.col("TIME").alias("time"),
                                    pl.lit(variable).alias("variable"), pl.col("Value").alias("value")))
    return Inputs(current, validate_panel(pl.concat(originals)))
