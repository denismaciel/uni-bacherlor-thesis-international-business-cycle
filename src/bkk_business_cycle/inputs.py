"""CSV boundary: decode, normalize and validate before entering the core."""

from dataclasses import dataclass
from pathlib import Path
from types import MappingProxyType
from collections.abc import Mapping

import polars as pl

from .domain import (
    GDP_SUBJECT,
    KEYS,
    SOURCE_VARIABLES,
    STANDARD_VARIABLES,
    THESIS_2015,
    Thesis2015Policy,
    ValidatedInputs,
    Variable,
)


@dataclass(frozen=True)
class InputIssue:
    source: str
    message: str
    country: str | None = None
    quarter: str | None = None


@dataclass(frozen=True)
class InvalidInputs:
    issues: tuple[InputIssue, ...]


type InputResult = ValidatedInputs | InvalidInputs

SUBJECTS = {
    Variable.GDP: ("B1_GE", GDP_SUBJECT),
    Variable.CONSUMPTION: ("P31S14_S15", "Private final consumption expenditure"),
    Variable.INVESTMENT: ("P51", "Gross fixed capital formation"),
    Variable.GOVERNMENT: ("P3S13", "General government final consumption expenditure"),
}
RENAME = {
    "LOCATION": "location",
    "TIME": "time",
    "SUBJECT": "subject_code",
    "Subject": "subject",
    "Value": "value",
}


def parse_inputs(
    oecd_csv: Mapping[Variable, pl.DataFrame],
    fred_csv: Mapping[str, pl.DataFrame],
    policy: Thesis2015Policy = THESIS_2015,
) -> InputResult:
    issues: list[InputIssue] = []
    oecd: dict[Variable, pl.DataFrame] = {}
    fred: dict[str, pl.DataFrame] = {}

    def reject_rows(
        source: str, data: pl.DataFrame, condition: pl.Expr, message: str
    ) -> None:
        for row in (
            data.filter(condition.fill_null(True)).head(10).iter_rows(named=True)
        ):
            issues.append(
                InputIssue(source, message, row.get("location"), row.get("time"))
            )

    for variable in SOURCE_VARIABLES:
        source = f"oecd/{variable}.csv"
        data = oecd_csv.get(variable)
        required = {*RENAME, "MEASURE", "FREQUENCY", "Unit Code", "PowerCode Code"}
        if data is None or not required.issubset(data.columns):
            issues.append(InputIssue(source, "Missing source or required OECD columns"))
            continue
        data = data.rename(RENAME).with_columns(
            pl.col("value").cast(pl.Float64, strict=False),
            pl.col("time", "location").cast(pl.String),
        )
        if data.is_empty():
            issues.append(InputIssue(source, "Empty source"))
            continue
        measure = (
            "VPVOBARSA"
            if variable in STANDARD_VARIABLES
            else "CPCARSA"
            if variable == Variable.NET_EXPORTS
            else "STSA"
        )
        reject_rows(
            source,
            data,
            (pl.col("MEASURE") != measure) | (pl.col("FREQUENCY") != "Q"),
            "Unexpected measure or frequency",
        )
        unit, scale = ("PER", "3") if variable == Variable.EMPLOYMENT else ("USD", "6")
        reject_rows(
            source,
            data,
            (pl.col("Unit Code") != unit)
            | (pl.col("PowerCode Code").cast(pl.String) != scale),
            "Unexpected unit or scale",
        )
        if variable in SUBJECTS:
            code, subject = SUBJECTS[variable]
            reject_rows(
                source,
                data,
                (pl.col("subject_code") != code) | (pl.col("subject") != subject),
                "Unexpected economic subject",
            )
        reject_rows(
            source,
            data,
            ~pl.col("time").str.contains(r"^\d{4}-Q[1-4]$")
            | ~pl.col("location").str.contains(r"^[A-Z0-9]{3,4}$"),
            "Invalid country or quarter",
        )
        # Logs and GDP denominators require positive levels. Trade flows are
        # not logged, so zero exports/imports are valid observations.
        invalid_level = ~pl.col("value").is_finite() | (pl.col("value") <= 0)
        if variable == Variable.NET_EXPORTS:
            invalid_level = (
                ~pl.col("value").is_finite()
                | (pl.col("value") < 0)
                | ((pl.col("subject_code") == "B1_GE") & (pl.col("value") == 0))
            )
        reject_rows(source, data, invalid_level, "Expected finite positive level")
        reject_rows(
            source,
            data,
            pl.struct(*KEYS, "subject_code").is_duplicated(),
            "Duplicate country/quarter/subject",
        )
        oecd[variable] = data

    for rule in policy.splices:
        source = f"fred/{rule.country.lower()}_employment.csv"
        data = fred_csv.get(rule.country)
        if data is None or not {"DATE", "VALUE"}.issubset(data.columns):
            issues.append(
                InputIssue(
                    source, "Missing source or required FRED columns", rule.country
                )
            )
            continue
        data = data.select(
            pl.col("DATE").cast(pl.String).alias("time"),
            pl.col("VALUE").cast(pl.Float64, strict=False).alias("value"),
            pl.lit(rule.country).alias("location"),
        )
        date = pl.col("time").str.to_date("%Y-%m-%d", strict=False)
        reject_rows(
            source,
            data,
            date.is_null()
            | (date.dt.day() != 1)
            | ~date.dt.month().is_in([1, 4, 7, 10]),
            "Expected quarter-start date",
        )
        data = data.with_columns(
            (date.dt.strftime("%Y-Q") + date.dt.quarter().cast(pl.String)).alias("time")
        )
        reject_rows(
            source,
            data,
            ~pl.col("value").is_finite() | (pl.col("value") <= 0),
            "Expected finite positive employment",
        )
        reject_rows(source, data, pl.col("time").is_duplicated(), "Duplicate quarter")
        fred[rule.country] = data.select("time", "value")
    if issues:
        return InvalidInputs(tuple(issues))

    def anchor(data: pl.DataFrame, source: str, country: str, quarter: str) -> None:
        rows = data.filter(pl.col("time") == quarter)
        if rows.height != 1:
            issues.append(
                InputIssue(
                    source,
                    "Expected exactly one splice/reference observation",
                    country,
                    quarter,
                )
            )

    def check_calendar(source: str, data: pl.DataFrame, groups: list[str]) -> None:
        quarter_index = pl.col("time").str.slice(0, 4).cast(pl.Int32) * 4 + pl.col(
            "time"
        ).str.slice(6, 1).cast(pl.Int32)
        step = quarter_index.diff().over(groups) if groups else quarter_index.diff()
        # First observation is intentionally exempt; all subsequent observations
        # must advance one quarter, without silently reordering source rows.
        reject_rows(
            source,
            data,
            (step != 1).fill_null(False),
            "Quarterly gap or out-of-order source rows",
        )

    for variable, data in oecd.items():
        selected = (
            data.filter(~pl.col("location").is_in(policy.employment_exclusions))
            if variable == Variable.EMPLOYMENT
            else data
        )
        check_calendar(f"oecd/{variable}.csv", selected, ["location", "subject_code"])
    for country, data in fred.items():
        check_calendar(
            f"fred/{country.lower()}_employment.csv",
            data.with_columns(pl.lit(country).alias("location")),
            [],
        )

    employment = oecd[Variable.EMPLOYMENT].filter(pl.col("subject_code") == "LFEMTTTT")
    if employment.is_empty():
        issues.append(
            InputIssue(
                "oecd/employment.csv", "Missing total employment subject LFEMTTTT"
            )
        )
    effective_employment = [
        employment.filter(
            ~pl.col("location").is_in(
                [
                    *policy.employment_exclusions,
                    *(rule.country for rule in policy.splices),
                ]
            )
        ).select(KEYS)
    ]
    for rule in policy.splices:
        country = employment.filter(pl.col("location") == rule.country)
        anchor(country, "oecd/employment.csv", rule.country, rule.switch_quarter)
        anchor(
            fred[rule.country],
            f"fred/{rule.country.lower()}_employment.csv",
            rule.country,
            rule.switch_quarter,
        )
        if rule.index_reference_quarter:
            anchor(
                country,
                "oecd/employment.csv",
                rule.country,
                rule.index_reference_quarter,
            )
        # Every selected segment must exist; full_join must not introduce a gap.
        before = fred[rule.country].filter(pl.col("time") <= rule.switch_quarter)
        after = country.filter(
            (pl.col("time") > rule.switch_quarter)
            & (pl.col("time") <= rule.end_quarter)
        )
        earlier_oecd = country.filter(pl.col("time") <= rule.switch_quarter).join(
            before, on="time", how="anti"
        )
        if not earlier_oecd.is_empty():
            issues.append(
                InputIssue(
                    "oecd/employment.csv",
                    "OECD history has no FRED splice counterpart",
                    rule.country,
                )
            )
        selected_keys = (
            pl.concat([before.select("time"), after.select("time")])
            .with_columns(pl.lit(rule.country).alias("location"))
            .select(KEYS)
        )
        if rule.drop_tail_rows:
            selected_keys = selected_keys.head(
                max(0, selected_keys.height - rule.drop_tail_rows)
            )
        check_calendar("employment splice", selected_keys, ["location"])
        effective_employment.append(selected_keys)
        if before.height + after.height - rule.drop_tail_rows < 3:
            issues.append(
                InputIssue(
                    "oecd/employment.csv",
                    "Spliced series too short for HP filter",
                    rule.country,
                )
            )

    net = oecd[Variable.NET_EXPORTS]
    subjects = {
        "P6": "Exports of goods and services",
        "P7": "Imports of goods and services",
        "B1_GE": GDP_SUBJECT,
    }
    reject_rows(
        "oecd/net_exports.csv",
        net,
        ~pl.col("subject_code").is_in(list(subjects)),
        "Unexpected net-export subject",
    )
    for code, subject in subjects.items():
        selected = net.filter(pl.col("subject_code") == code)
        if selected.is_empty():
            issues.append(InputIssue("oecd/net_exports.csv", f"Missing subject {code}"))
        reject_rows(
            "oecd/net_exports.csv",
            selected,
            pl.col("subject") != subject,
            "Unexpected subject label",
        )
    exports = net.filter(pl.col("subject_code") == "P6").select(KEYS)
    imports = net.filter(pl.col("subject_code") == "P7").select(KEYS)
    gdp = net.filter(pl.col("subject_code") == "B1_GE").select(KEYS)
    if not exports.equals(imports):
        issues.append(
            InputIssue(
                "oecd/net_exports.csv",
                "Export/import source order differs from the R reproduction contract",
            )
        )
    if not exports.join(gdp, on=KEYS, how="anti").is_empty():
        issues.append(InputIssue("oecd/net_exports.csv", "Missing GDP denominator"))

    for variable, data in oecd.items():
        selected = (
            data.filter(pl.col("subject_code") == "LFEMTTTT")
            if variable == Variable.EMPLOYMENT
            else data
        )
        if "USA" not in selected["location"].to_list():
            issues.append(InputIssue(f"oecd/{variable}.csv", "Missing USA benchmark"))
        for row in (
            selected.group_by("location", "subject_code")
            .len()
            .filter(pl.col("len") < 3)
            .iter_rows(named=True)
        ):
            issues.append(
                InputIssue(
                    f"oecd/{variable}.csv",
                    "Series too short for HP filter",
                    row["location"],
                )
            )
    labor_keys = pl.concat(effective_employment)
    gdp_keys = oecd[Variable.GDP].select(KEYS)
    overlap = labor_keys.join(gdp_keys, on=KEYS, how="inner").group_by("location").len()
    for country in labor_keys["location"].unique().to_list():
        count = overlap.filter(pl.col("location") == country)
        if count.is_empty() or count["len"].item() < 3:
            issues.append(
                InputIssue(
                    "gdp/employment",
                    "Fewer than three overlapping quarters for Solow residuals",
                    country,
                )
            )
    if issues:
        return InvalidInputs(tuple(issues))
    normalized = {
        variable: data.select("location", "time", "subject_code", "subject", "value")
        for variable, data in oecd.items()
    }
    return ValidatedInputs(MappingProxyType(normalized), MappingProxyType(fred), policy)


def load_inputs(data_dir: Path, policy: Thesis2015Policy = THESIS_2015) -> InputResult:
    oecd: dict[Variable, pl.DataFrame] = {}
    fred: dict[str, pl.DataFrame] = {}
    issues: list[InputIssue] = []

    def read(relative: str) -> pl.DataFrame | None:
        try:
            return pl.read_csv(data_dir / relative, infer_schema=False, null_values=".")
        except (OSError, pl.exceptions.PolarsError) as error:
            issues.append(InputIssue(relative, str(error)))
            return None

    for variable in SOURCE_VARIABLES:
        data = read(f"oecd/{variable}.csv")
        if data is not None:
            oecd[variable] = data
    for rule in policy.splices:
        data = read(f"fred/{rule.country.lower()}_employment.csv")
        if data is not None:
            fred[rule.country] = data
    return InvalidInputs(tuple(issues)) if issues else parse_inputs(oecd, fred, policy)
