"""Pure publication formatting and reference comparison."""

from dataclasses import dataclass
from enum import StrEnum
from collections.abc import Mapping
import difflib
import math

import polars as pl

from .analysis import AnalysisResult
from .domain import TableId


class CellFormat(StrEnum):
    TEXT = "text"
    QUARTER = "quarter"
    NUMBER = "number"
    QUOTED_NUMBER = "quoted_number"


@dataclass(frozen=True)
class ColumnSpec:
    source: str
    label: str
    format: CellFormat


@dataclass(frozen=True)
class TableSpec:
    filename: str
    columns: tuple[ColumnSpec, ...]
    latex_alignment: str


COUNTRY = ColumnSpec("country", "Country", CellFormat.TEXT)
TABLE_SPECS = {
    TableId.TIMESPAN: TableSpec(
        "table_3_timespan",
        (
            COUNTRY,
            *(
                ColumnSpec(
                    f"{variable}_{bound}", f"{title} {label}", CellFormat.QUARTER
                )
                for variable, title in (
                    ("gdp", "GDP"),
                    ("consumption", "Consumption"),
                    ("investment", "Investment"),
                    ("government", "Government"),
                    ("net_exports", "Net Exports"),
                    ("employment", "Employment"),
                )
                for bound, label in (("last", "Last"), ("first", "First"))
            ),
        ),
        "l *{12}{c}",
    ),
    TableId.STANDARD_DEVIATIONS: TableSpec(
        "table_4_standard_deviations",
        (
            COUNTRY,
            *(
                ColumnSpec(symbol, symbol, CellFormat.NUMBER)
                for symbol in ("y", "nx", "c", "x", "g", "n", "z")
            ),
        ),
        "l *{7}{S[table-format=1.3]}",
    ),
    TableId.WITHIN_COUNTRY: TableSpec(
        "table_5_within_country_correlations",
        (
            COUNTRY,
            ColumnSpec("autocorrelation", "Autocorrelation", CellFormat.QUOTED_NUMBER),
            *(
                ColumnSpec(name, name, CellFormat.QUOTED_NUMBER)
                for name in ("gdp", "cons", "inv", "gov", "net", "emp", "sol")
            ),
        ),
        "l *{8}{S[table-format=-1.3]}",
    ),
    TableId.USA: TableSpec(
        "table_6_us_correlations",
        (
            COUNTRY,
            *(
                ColumnSpec(source, label, CellFormat.NUMBER)
                for source, label in (
                    ("gdp", "usa.gdpcor"),
                    ("consumption", "usa.concor"),
                    ("investment", "usa.invcor"),
                    ("government", "usa.govcor"),
                    ("net_exports", "usa.netcor"),
                    ("employment", "usa.empcor"),
                    ("solow", "usa.solcor"),
                )
            ),
        ),
        "l *{7}{S[table-format=-1.3]}",
    ),
    TableId.AVERAGE: TableSpec(
        "table_7_average_cross_country_correlations",
        (
            ColumnSpec("Variable", "Variable", CellFormat.TEXT),
            *(
                ColumnSpec(name, name, CellFormat.NUMBER)
                for name in (
                    "Mean",
                    "USA Mean",
                    "0%",
                    "10%",
                    "25%",
                    "40%",
                    "50%",
                    "60%",
                    "75%",
                    "90%",
                    "100%",
                )
            ),
        ),
        "l *{11}{S[table-format=-1.3]}",
    ),
}
TABLE_FILES = {name: spec.filename for name, spec in TABLE_SPECS.items()}
USA_LATEX = TableSpec(
    TABLE_SPECS[TableId.USA].filename,
    (
        COUNTRY,
        *(
            ColumnSpec(source, label, CellFormat.NUMBER)
            for source, label in (
                ("gdp", "y"),
                ("consumption", "c"),
                ("investment", "x"),
                ("government", "g"),
                ("net_exports", "nx"),
                ("employment", "n"),
                ("solow", "z"),
            )
        ),
    ),
    TABLE_SPECS[TableId.USA].latex_alignment,
)


@dataclass(frozen=True)
class Artifact:
    filename: str
    content: bytes


def quote(text: str) -> str:
    return '"' + text.replace('"', '""') + '"'


def number_text(value: object, *, digits: int | None = None) -> str:
    if not isinstance(value, (float, int)) or not math.isfinite(value):
        raise ValueError(
            "Publication numeric column violates its finite-number contract"
        )
    number = round(value, digits) if digits is not None else value
    if number == 0:
        return "0"
    return (
        format(number, ".15g")
        if digits is None
        else f"{number:.{digits}f}".rstrip("0").rstrip(".")
    )


def csv_cell(value: object, kind: CellFormat) -> str:
    if value is None:
        return ""
    match kind:
        case CellFormat.TEXT | CellFormat.QUARTER:
            if not isinstance(value, str):
                raise ValueError("Publication text column violates its string contract")
            return quote(value)
        case CellFormat.NUMBER:
            return number_text(value)
        case CellFormat.QUOTED_NUMBER:
            return quote(number_text(value))


def csv_text(table: pl.DataFrame, spec: TableSpec) -> str:
    ordered = table.select(column.source for column in spec.columns)
    return "\n".join(
        [
            ",".join(quote(column.label) for column in spec.columns),
            *(
                ",".join(
                    csv_cell(value, column.format)
                    for value, column in zip(row, spec.columns, strict=True)
                )
                for row in ordered.iter_rows()
            ),
            "",
        ]
    )


def latex_escape(text: str) -> str:
    replacements = {
        "\\": r"\textbackslash{}",
        **{char: "\\" + char for char in "#$%&_{}"},
    }
    return "".join(replacements.get(char, char) for char in text)


def latex_cell(value: object, kind: CellFormat) -> str:
    if value is None:
        return ""
    if kind in (CellFormat.NUMBER, CellFormat.QUOTED_NUMBER):
        return number_text(value, digits=3)
    if not isinstance(value, str):
        raise ValueError("Publication text column violates its string contract")
    return latex_escape(
        value.replace("-Q", ":") if kind == CellFormat.QUARTER else value
    )


def latex_text(table: pl.DataFrame, spec: TableSpec) -> str:
    headers = [
        latex_escape(column.label)
        if column.format in (CellFormat.TEXT, CellFormat.QUARTER)
        else r"\multicolumn{1}{c}{" + latex_escape(column.label) + "}"
        for column in spec.columns
    ]
    rows = [
        " & ".join(
            latex_cell(value, column.format)
            for value, column in zip(row, spec.columns, strict=True)
        )
        for row in table.select(column.source for column in spec.columns).iter_rows()
    ]
    end_row = " " + chr(92) * 2
    return "\n".join(
        [
            "% Generated by bkk-business-cycle. Do not edit by hand.",
            r"\begin{tabular}{" + spec.latex_alignment + "}",
            r"\toprule",
            " & ".join(headers) + end_row,
            r"\midrule",
            *(row + end_row for row in rows),
            r"\bottomrule",
            r"\end{tabular}",
            "",
        ]
    )


def render_tables(results: AnalysisResult) -> tuple[Artifact, ...]:
    artifacts = []
    for name, table in results.tables.items():
        spec = TABLE_SPECS[name]
        artifacts.append(
            Artifact(spec.filename + ".csv", csv_text(table, spec).encode())
        )
        latex_table = (
            table.filter(pl.col("country") != "USA") if name == TableId.USA else table
        )
        latex_spec = USA_LATEX if name == TableId.USA else spec
        artifacts.append(
            Artifact(
                spec.filename + ".tex", latex_text(latex_table, latex_spec).encode()
            )
        )
    return tuple(artifacts)


class ReferenceStatus(StrEnum):
    MATCH = "match"
    DIFFERENT = "different"
    MISSING_REFERENCE = "missing_reference"


@dataclass(frozen=True)
class TableComparison:
    filename: str
    status: ReferenceStatus
    difference: str = ""


@dataclass(frozen=True)
class ReferenceReport:
    comparisons: tuple[TableComparison, ...]

    @property
    def matches(self) -> bool:
        return bool(self.comparisons) and all(
            item.status == ReferenceStatus.MATCH for item in self.comparisons
        )


def compare_references(
    artifacts: tuple[Artifact, ...], references: Mapping[str, bytes]
) -> ReferenceReport:
    comparisons = []
    for artifact in artifacts:
        if not artifact.filename.endswith(".csv"):
            continue
        expected = references.get(artifact.filename)
        if expected is None:
            comparisons.append(
                TableComparison(artifact.filename, ReferenceStatus.MISSING_REFERENCE)
            )
        elif expected == artifact.content:
            comparisons.append(
                TableComparison(artifact.filename, ReferenceStatus.MATCH)
            )
        else:
            difference = "".join(
                difflib.unified_diff(
                    expected.decode("utf-8", errors="replace").splitlines(True),
                    artifact.content.decode().splitlines(True),
                    fromfile="reference",
                    tofile="computed",
                )
            )
            comparisons.append(
                TableComparison(
                    artifact.filename, ReferenceStatus.DIFFERENT, difference
                )
            )
    return ReferenceReport(tuple(comparisons))
