from dataclasses import replace
from pathlib import Path

import polars as pl
import pytest

from bkk_business_cycle.analysis import (
    AnalysisResult,
    analyze,
    pairwise_correlation,
    build_standard_deviations,
)
from bkk_business_cycle.application import run_analysis
from bkk_business_cycle.cli import (
    ArtifactSelection,
    ReferenceAction,
    execute,
    parse_plan,
)
from bkk_business_cycle.domain import (
    Estimated,
    Unavailable,
    UnavailableReason,
    Variable,
    TableId,
    THESIS_2015,
    StatisticScope,
)
from bkk_business_cycle.export import (
    Artifact,
    CellFormat,
    ReferenceStatus,
    TABLE_SPECS,
    compare_references,
    csv_text,
    latex_cell,
    render_tables,
)
from bkk_business_cycle.figure_data import build_figure_data
from bkk_business_cycle.inputs import InvalidInputs, load_inputs

ROOT = Path(__file__).resolve().parents[1]


@pytest.fixture(scope="module")
def result() -> AnalysisResult:
    result = run_analysis(ROOT / "data/raw")
    assert isinstance(result, AnalysisResult)
    return result


@pytest.mark.parametrize(
    ("data", "expected"),
    [
        (
            pl.DataFrame({"a": [1.0, 2.0]}),
            Unavailable(UnavailableReason.SERIES_ABSENT, 0),
        ),
        (
            pl.DataFrame({"a": [1.0, None], "b": [None, 2.0]}),
            Unavailable(UnavailableReason.INSUFFICIENT_OVERLAP, 0),
        ),
        (
            pl.DataFrame({"a": [1.0, None], "b": [2.0, 3.0]}),
            Unavailable(UnavailableReason.INSUFFICIENT_OVERLAP, 1),
        ),
        (
            pl.DataFrame({"a": [1.0, 1.0], "b": [2.0, 3.0]}),
            Unavailable(UnavailableReason.ZERO_VARIANCE, 2),
        ),
    ],
)
def test_correlation_unavailability_is_explicit(
    data: pl.DataFrame, expected: Unavailable
) -> None:
    assert pairwise_correlation(data, "a", "b") == expected


def test_nonfinite_values_are_contract_errors() -> None:
    with pytest.raises(ValueError, match="Nonfinite"):
        pairwise_correlation(
            pl.DataFrame({"a": [1.0, float("nan")], "b": [2.0, 3.0]}), "a", "b"
        )


def test_core_keeps_numeric_columns_and_absence_reasons(result: AnalysisResult) -> None:
    table = result.tables.within_country_correlations
    assert all(
        dtype == pl.Float64 for name, dtype in table.schema.items() if name != "country"
    )
    unavailable = [
        a
        for a in result.assessments
        if a.context == "CHE"
        and a.right == Variable.EMPLOYMENT
        and a.scope == StatisticScope.WITHIN_COUNTRY
    ]
    assert len(unavailable) == 1
    assert unavailable[0].estimate == Unavailable(UnavailableReason.SERIES_ABSENT, 0)


def test_zero_gdp_volatility_has_named_result(result: AnalysisResult) -> None:
    variables = dict(result.variable_results)
    gdp = variables[Variable.GDP]
    variables[Variable.GDP] = replace(
        gdp, stdv=gdp.stdv.with_columns(pl.lit(0.0).alias("stdv"))
    )
    table, assessments = build_standard_deviations(variables, THESIS_2015)
    assert table["c"].null_count() == table.height
    assert all(isinstance(item.estimate, Unavailable) for item in assessments)
    assert any(
        item.estimate
        == Unavailable(
            UnavailableReason.ZERO_VARIANCE,
            variables[Variable.CONSUMPTION]
            .series.filter(pl.col("location") == "USA")
            .height,
        )
        for item in assessments
        if item.context == "USA" and item.left == Variable.CONSUMPTION
    )


def test_named_columns_survive_reordering(result: AnalysisResult) -> None:
    table = result.tables.timespan
    spec = TABLE_SPECS[TableId.TIMESPAN]
    assert csv_text(table, spec) == csv_text(
        table.select(reversed(table.columns)), spec
    )


def test_rendering_uses_declared_types_not_text_guessing() -> None:
    assert latex_cell("001", CellFormat.TEXT) == "001"
    assert latex_cell("2015-Q1", CellFormat.QUARTER) == "2015:1"
    assert latex_cell(0.70, CellFormat.QUOTED_NUMBER) == "0.7"
    assert latex_cell(None, CellFormat.NUMBER) == ""
    with pytest.raises(ValueError):
        latex_cell("0.70", CellFormat.NUMBER)


def test_reference_comparison_returns_all_outcomes() -> None:
    artifacts = (
        Artifact("match.csv", b'"x"\n1\n'),
        Artifact("different.csv", b'"x"\n2\n'),
        Artifact("missing.csv", b'"x"\n3\n'),
    )
    report = compare_references(
        artifacts, {"match.csv": artifacts[0].content, "different.csv": b'"x"\n1\n'}
    )
    assert [comparison.status for comparison in report.comparisons] == [
        ReferenceStatus.MATCH,
        ReferenceStatus.DIFFERENT,
        ReferenceStatus.MISSING_REFERENCE,
    ]
    assert "-1\n+2\n" in report.comparisons[1].difference
    assert not report.matches
    assert not compare_references((), {}).matches


def test_reference_comparison_is_byte_exact() -> None:
    assert not compare_references(
        (Artifact("test.csv", b"a\n"),), {"test.csv": b"a\r\n"}
    ).matches


@pytest.mark.parametrize(
    ("argv", "selection", "action"),
    [
        ([], ArtifactSelection.TABLES, ReferenceAction.SKIP),
        (["check"], ArtifactSelection.NONE, ReferenceAction.COMPARE),
        (
            ["check", "--write-tables"],
            ArtifactSelection.TABLES,
            ReferenceAction.COMPARE,
        ),
        (["check", "--figures"], ArtifactSelection.ALL, ReferenceAction.COMPARE),
        (["run", "--figures"], ArtifactSelection.ALL, ReferenceAction.SKIP),
        (["figures"], ArtifactSelection.FIGURES, ReferenceAction.SKIP),
    ],
)
def test_execution_plan_makes_effects_explicit(
    argv: list[str], selection: ArtifactSelection, action: ReferenceAction
) -> None:
    plan = parse_plan(argv)
    assert plan.artifacts == selection
    assert plan.reference_action == action


def test_check_is_read_only_and_invalid_input_is_reported(tmp_path: Path) -> None:
    output = tmp_path / "output"
    plan = parse_plan(
        [
            "check",
            "--data-dir",
            str(ROOT / "data/raw"),
            "--reference-dir",
            str(ROOT / "reference/tables"),
            "--output-dir",
            str(output),
        ]
    )
    assert execute(plan) == 0
    assert not output.exists()
    assert execute(replace(plan, data_dir=tmp_path / "missing")) == 2
    assert not output.exists()


def test_failed_check_prevents_requested_writes(tmp_path: Path) -> None:
    plan = parse_plan(
        [
            "check",
            "--write-tables",
            "--data-dir",
            str(ROOT / "data/raw"),
            "--reference-dir",
            str(tmp_path / "missing"),
            "--output-dir",
            str(tmp_path / "output"),
        ]
    )
    assert execute(plan) == 1
    assert not plan.output_dir.exists()


def test_figures_and_tables_share_one_load(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    inputs = load_inputs(ROOT / "data/raw")
    assert not isinstance(inputs, InvalidInputs)
    calls = []

    def loader(path: Path):
        calls.append(path)
        return inputs

    def renderer(data, output: Path) -> None:
        assert data.usa_gdp.height > 0
        assert len(data.employment) == 3

    monkeypatch.setattr("bkk_business_cycle.cli.load_inputs", loader)
    monkeypatch.setattr("bkk_business_cycle.figures.export_figures", renderer)
    assert execute(parse_plan(["run", "--figures", "--output-dir", str(tmp_path)])) == 0
    assert calls == [Path("data/raw")]
    assert len(list((tmp_path / "tables").iterdir())) == 10


def test_pure_pipeline_works_without_filesystem_reads(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    inputs = load_inputs(ROOT / "data/raw")
    assert not isinstance(inputs, InvalidInputs)
    before = inputs.oecd[Variable.GDP].clone()

    def forbidden(*args, **kwargs):
        raise AssertionError("Unexpected read in functional core")

    monkeypatch.setattr(pl, "read_csv", forbidden)
    monkeypatch.setattr(Path, "read_bytes", forbidden)
    result = analyze(inputs)
    assert len(render_tables(result)) == 10
    assert build_figure_data(result, inputs).gdp_consumption.height == 55
    assert inputs.oecd[Variable.GDP].equals(before)


def test_summary_without_country_pairs_has_explicit_unavailable_status(
    result: AnalysisResult,
) -> None:
    from bkk_business_cycle.analysis import (
        build_average_cross_country_correlations,
        correlation_pairs,
    )

    matrix = pl.DataFrame({"country": ["USA"], "USA": [1.0]})
    assert correlation_pairs(matrix).schema == {
        "left": pl.String,
        "right": pl.String,
        "correlation": pl.Float64,
    }
    variables = {
        variable: replace(value, correlation=matrix)
        for variable, value in result.variable_results.items()
    }
    summary, assessments = build_average_cross_country_correlations(
        variables, THESIS_2015
    )
    assert summary["Mean"].null_count() == len(variables)
    assert all(
        item.estimate == Unavailable(UnavailableReason.INSUFFICIENT_OVERLAP, 0)
        for item in assessments
    )


def test_zero_smoothing_preserves_numeric_missing_result_contract() -> None:
    inputs = load_inputs(ROOT / "data/raw", replace(THESIS_2015, hp_lambda=0))
    assert not isinstance(inputs, InvalidInputs)
    result = analyze(inputs)
    table = result.tables.within_country_correlations
    assert table["gdp"].dtype == pl.Float64
    assert table["gdp"].null_count() == table.height
    assert len(render_tables(result)) == 10
    assert any(
        isinstance(item.estimate, Unavailable)
        and item.estimate.reason == UnavailableReason.ZERO_VARIANCE
        for item in result.assessments
    )
