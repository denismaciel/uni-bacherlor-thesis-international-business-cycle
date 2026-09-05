"""Parse an execution plan, then orchestrate the imperative shell."""

import argparse
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path
import sys

from .analysis import analyze
from .application import read_references, write_artifacts
from .export import ReferenceStatus, compare_references, render_tables
from .figure_data import build_figure_data
from .inputs import InvalidInputs, load_inputs


class Command(StrEnum):
    RUN = "run"
    CHECK = "check"
    FIGURES = "figures"


class ArtifactSelection(StrEnum):
    NONE = "none"
    TABLES = "tables"
    FIGURES = "figures"
    ALL = "all"


class ReferenceAction(StrEnum):
    SKIP = "skip"
    COMPARE = "compare"


@dataclass(frozen=True)
class ExecutionPlan:
    data_dir: Path
    output_dir: Path
    reference_dir: Path
    artifacts: ArtifactSelection
    reference_action: ReferenceAction


def parse_plan(argv: list[str] | None = None) -> ExecutionPlan:
    parser = argparse.ArgumentParser(
        description="Reproduce the BKK thesis analysis using Polars"
    )
    parser.add_argument(
        "command", type=Command, choices=list(Command), nargs="?", default=Command.RUN
    )
    parser.add_argument("--data-dir", type=Path, default=Path("data/raw"))
    parser.add_argument("--output-dir", type=Path, default=Path("output"))
    parser.add_argument("--reference-dir", type=Path, default=Path("reference/tables"))
    parser.add_argument(
        "--figures",
        action="store_true",
        help="Also write figures; with check, write tables and figures after a match",
    )
    parser.add_argument(
        "--write-tables",
        action="store_true",
        help="Write tables after a successful check",
    )
    args = parser.parse_args(argv)
    command = Command(args.command)
    if args.write_tables and command != Command.CHECK:
        parser.error("--write-tables applies only to check")
    if command == Command.FIGURES:
        selection = ArtifactSelection.FIGURES
    elif args.figures:
        selection = ArtifactSelection.ALL
    elif command == Command.RUN or args.write_tables:
        selection = ArtifactSelection.TABLES
    else:
        selection = ArtifactSelection.NONE
    return ExecutionPlan(
        args.data_dir,
        args.output_dir,
        args.reference_dir,
        selection,
        ReferenceAction.COMPARE if command == Command.CHECK else ReferenceAction.SKIP,
    )


def execute(plan: ExecutionPlan) -> int:
    inputs = load_inputs(plan.data_dir)
    if isinstance(inputs, InvalidInputs):
        for issue in inputs.issues:
            context = "/".join(
                item for item in (issue.country, issue.quarter) if item is not None
            )
            print(f"{issue.source} {context}: {issue.message}", file=sys.stderr)
        return 2
    results = analyze(inputs)
    artifacts = render_tables(results)
    if plan.reference_action == ReferenceAction.COMPARE:
        report = compare_references(
            artifacts, read_references(artifacts, plan.reference_dir)
        )
        if not report.matches:
            for comparison in report.comparisons:
                if comparison.status != ReferenceStatus.MATCH:
                    print(
                        f"{comparison.filename}: {comparison.status}\n{comparison.difference}",
                        file=sys.stderr,
                    )
            return 1
        print("All five exported thesis tables exactly match reference artifacts.")
    if plan.artifacts in (ArtifactSelection.TABLES, ArtifactSelection.ALL):
        write_artifacts(artifacts, plan.output_dir / "tables")
        print(
            f"Exported tables to {plan.output_dir / 'tables'} ({results.panel.height:,} panel rows)."
        )
    if plan.artifacts in (ArtifactSelection.FIGURES, ArtifactSelection.ALL):
        from .figures import export_figures

        export_figures(build_figure_data(results, inputs), plan.output_dir / "figures")
        print(f"Exported seven figures to {plan.output_dir / 'figures'}.")
    return 0


def main() -> None:
    plan = parse_plan()
    try:
        code = execute(plan)
    except OSError as error:
        print(f"Filesystem error: {error}", file=sys.stderr)
        code = 3
    raise SystemExit(code)
