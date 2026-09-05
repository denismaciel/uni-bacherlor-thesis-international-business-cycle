"""Imperative adapters: filesystem reads/writes around the pure analysis core."""

from pathlib import Path

from .analysis import AnalysisResult, analyze
from .inputs import InvalidInputs, load_inputs
from .export import Artifact, ReferenceReport, compare_references, render_tables


def run_analysis(
    data_dir: Path | str = Path("data/raw"),
) -> AnalysisResult | InvalidInputs:
    inputs = load_inputs(Path(data_dir))
    return inputs if isinstance(inputs, InvalidInputs) else analyze(inputs)


def write_artifacts(artifacts: tuple[Artifact, ...], output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for artifact in artifacts:
        (output_dir / artifact.filename).write_bytes(artifact.content)


def read_references(
    artifacts: tuple[Artifact, ...], reference_dir: Path
) -> dict[str, bytes]:
    references = {}
    for artifact in artifacts:
        if artifact.filename.endswith(".csv"):
            try:
                references[artifact.filename] = (
                    reference_dir / artifact.filename
                ).read_bytes()
            except FileNotFoundError:
                pass  # Absence is represented by MISSING_REFERENCE in the report.
    return references


def check_reference(results: AnalysisResult, reference_dir: Path) -> ReferenceReport:
    artifacts = render_tables(results)
    return compare_references(artifacts, read_references(artifacts, reference_dir))


def export_tables(results: AnalysisResult, output_dir: Path) -> None:
    write_artifacts(render_tables(results), output_dir)
