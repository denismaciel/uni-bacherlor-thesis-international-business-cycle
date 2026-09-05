from dataclasses import replace
from pathlib import Path

import polars as pl
import pytest

from bkk_business_cycle.domain import (
    SOURCE_VARIABLES,
    THESIS_2015,
    ValidatedInputs,
    Variable,
)
from bkk_business_cycle.inputs import InvalidInputs, load_inputs, parse_inputs

ROOT = Path(__file__).resolve().parents[1]


@pytest.fixture(scope="module")
def csv_frames() -> tuple[dict[Variable, pl.DataFrame], dict[str, pl.DataFrame]]:
    return (
        {
            variable: pl.read_csv(
                ROOT / f"data/raw/oecd/{variable}.csv", infer_schema=False
            )
            for variable in SOURCE_VARIABLES
        },
        {
            rule.country: pl.read_csv(
                ROOT / f"data/raw/fred/{rule.country.lower()}_employment.csv",
                infer_schema=False,
            )
            for rule in THESIS_2015.splices
        },
    )


def test_missing_files_return_contextual_issues(tmp_path: Path) -> None:
    result = load_inputs(tmp_path)
    assert isinstance(result, InvalidInputs)
    assert len(result.issues) == 9
    assert result.issues[0].source == "oecd/gdp.csv"


@pytest.mark.parametrize(
    ("column", "value", "message"),
    [
        ("TIME", "2015-Q5", "Invalid country or quarter"),
        ("TIME", None, "Invalid country or quarter"),
        ("LOCATION", "?", "Invalid country or quarter"),
        ("Value", "0", "Expected finite positive level"),
        ("Value", "-1", "Expected finite positive level"),
        ("Value", "NaN", "Expected finite positive level"),
        ("Value", "inf", "Expected finite positive level"),
        ("Value", "oops", "Expected finite positive level"),
        ("FREQUENCY", "A", "Unexpected measure or frequency"),
        ("MEASURE", "CPCARSA", "Unexpected measure or frequency"),
        ("Unit Code", "EUR", "Unexpected unit or scale"),
        ("PowerCode Code", "3", "Unexpected unit or scale"),
        ("SUBJECT", "P6", "Unexpected economic subject"),
    ],
)
def test_bad_oecd_row_is_rejected_before_analysis(
    csv_frames: tuple[dict[Variable, pl.DataFrame], dict[str, pl.DataFrame]],
    column: str,
    value: str | None,
    message: str,
) -> None:
    oecd, fred = csv_frames
    modified = dict(oecd)
    modified[Variable.GDP] = pl.concat(
        [
            oecd[Variable.GDP]
            .head(1)
            .with_columns(pl.lit(value, dtype=pl.String).alias(column)),
            oecd[Variable.GDP].slice(1),
        ]
    )
    result = parse_inputs(modified, fred)
    assert isinstance(result, InvalidInputs)
    assert any(
        issue.source == "oecd/gdp.csv" and issue.message == message
        for issue in result.issues
    )


@pytest.mark.parametrize(
    "mutation",
    [
        "missing_column",
        "duplicate",
        "gap",
        "reordered",
        "missing_anchor",
        "zero_anchor",
        "missing_denominator",
    ],
)
def test_structural_input_failures(
    csv_frames: tuple[dict[Variable, pl.DataFrame], dict[str, pl.DataFrame]],
    mutation: str,
) -> None:
    originals, fred = csv_frames
    oecd = dict(originals)
    gdp = oecd[Variable.GDP]
    match mutation:
        case "missing_column":
            oecd[Variable.GDP] = gdp.drop("Value")
        case "duplicate":
            oecd[Variable.GDP] = pl.concat([gdp, gdp.head(1)])
        case "gap":
            oecd[Variable.GDP] = pl.concat([gdp.head(1), gdp.slice(2)])
        case "reordered":
            oecd[Variable.GDP] = gdp.reverse()
        case "missing_anchor" | "zero_anchor":
            employment = oecd[Variable.EMPLOYMENT]
            anchor = (
                (pl.col("LOCATION") == "FRA")
                & (pl.col("TIME") == "2005-Q2")
                & (pl.col("SUBJECT") == "LFEMTTTT")
            )
            oecd[Variable.EMPLOYMENT] = (
                employment.filter(~anchor)
                if mutation == "missing_anchor"
                else employment.with_columns(
                    pl.when(anchor)
                    .then(pl.lit("0"))
                    .otherwise(pl.col("Value"))
                    .alias("Value")
                )
            )
        case "missing_denominator":
            net = oecd[Variable.NET_EXPORTS]
            oecd[Variable.NET_EXPORTS] = net.filter(
                ~((pl.col("SUBJECT") == "B1_GE") & (pl.col("TIME") == "1960-Q1"))
            )
    result = parse_inputs(oecd, fred)
    assert isinstance(result, InvalidInputs)
    assert result.issues


@pytest.mark.parametrize("date", ["not-a-date", "2011-11-01", "2011-10-02"])
def test_fred_dates_must_be_quarter_starts(
    csv_frames: tuple[dict[Variable, pl.DataFrame], dict[str, pl.DataFrame]], date: str
) -> None:
    oecd, originals = csv_frames
    fred = dict(originals)
    fred["GBR"] = pl.concat(
        [
            fred["GBR"].head(1).with_columns(pl.lit(date).alias("DATE")),
            fred["GBR"].slice(1),
        ]
    )
    result = parse_inputs(oecd, fred)
    assert isinstance(result, InvalidInputs)
    assert any(
        issue.message == "Expected quarter-start date" for issue in result.issues
    )


def test_validating_does_not_mutate_sources(
    csv_frames: tuple[dict[Variable, pl.DataFrame], dict[str, pl.DataFrame]],
) -> None:
    oecd, fred = csv_frames
    before = oecd[Variable.GDP].clone()
    result = parse_inputs(oecd, fred)
    assert isinstance(result, ValidatedInputs)
    assert oecd[Variable.GDP].equals(before)
    assert result.policy == THESIS_2015
    assert result.oecd[Variable.GDP]["value"].dtype == pl.Float64


@pytest.mark.parametrize("value", [-1.0, float("nan"), float("inf")])
def test_invalid_policy_cannot_enter_core(value: float) -> None:
    with pytest.raises(ValueError):
        replace(THESIS_2015, hp_lambda=value)
