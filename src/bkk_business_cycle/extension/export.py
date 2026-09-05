"""Extension artifacts from computed Python results, never copied from R."""

from dataclasses import asdict
import hashlib
import json
from pathlib import Path
import platform
from importlib.metadata import version

import polars as pl

from .data import quarter_text
from .domain import Method, Result, Table
from .inputs import input_paths
from .parity import ABSOLUTE_TOLERANCE, Comparison


def markdown_table(frame: pl.DataFrame) -> list[str]:
    def cell(value: object) -> str:
        if value is None:
            return "—"
        if isinstance(value, float):
            return f"{value:.3f}"
        return str(value)
    return ["| " + " | ".join(frame.columns) + " |", "| " + " | ".join("---" for _ in frame.columns) + " |",
            *("| " + " | ".join(map(cell, row)) + " |" for row in frame.iter_rows())]


def research_report(result: Result) -> str:
    tables = result.tables
    lines = ["# International business cycles: Python research extension", "",
             "Independent Python computation of the R extension. Exploratory results, not a causal analysis or a completed paper.", "",
             f"Snapshot: `{result.config.snapshot}`. Ten countries, 45 equally weighted unordered pairs.",
             f"Balanced log levels: {quarter_text(result.level_start)}–{quarter_text(result.end)}. "
             f"All methods evaluated from {quarter_text(result.common_start)} to retain identical dates after Hamilton's 11 initial quarters.", "",
             "## Period estimates", "", "Gap = mean output correlation minus mean consumption correlation.", ""]
    lines += markdown_table(tables[Table.SUMMARY].select("period", "method", "quarters", "output_correlation", "consumption_correlation", "gap", "gap_lower", "gap_upper", "positive_pairs"))
    lines += ["", "## Crisis and sample-composition diagnostics", "",
              "Descriptive only. Crisis exclusions drop already-transformed observations; they do not remove a shock's influence on other dates or estimate a counterfactual.", ""]
    lines += markdown_table(tables[Table.EPISODES].select("method", "diagnostic", "quarters", "output_correlation", "consumption_correlation", "gap"))
    lines += ["", "## Original versus current vintage and measurement", "",
              "Identical countries, level history and evaluation dates. Changes combine revisions and measurement differences, not pure revisions.", ""]
    lines += markdown_table(tables[Table.VINTAGE])
    lines += ["", "## Method and interpretation", "",
              "- HP uses log levels and lambda=1600; growth uses first differences of logs; Hamilton regresses x[t] on an intercept and x[t-8] through x[t-11].",
              "- Filters use the balanced history only through each evaluation endpoint, then the requested dates are selected. Post-thesis/rolling windows retain preceding history. HP is two-sided within that context; Hamilton coefficients use the whole context.",
              f"- Joint circular blocks: {result.config.repetitions:,} draws, seed {result.config.seed}, baseline block length 8 quarters. All 20 series use identical row indices; vintage comparisons also share the indices across vintages.",
              "- R-compatible Mersenne-Twister initialization and Rejection sampling reproduce the actual R resamples. NumPy's ordinary seed/choice combination would not do so. Percentiles use R type-7/NumPy linear interpolation.",
              "- Percentile intervals are conditional on fitted transformations; filters are not refitted within bootstrap samples. Trend/parameter uncertainty is omitted and within-window stationarity is assumed. Crises and nonstationarity can undermine coverage.",
              "- Block lengths 4/8/12 are exported; unsupported intervals are missing when fewer than 40 quarters or four blocks fit. Pair intervals are pointwise, not simultaneous; positive-pair counts are descriptive.",
              "- Periods overlap. Their intervals are not tests of between-period changes. Growth and detrended-level correlations measure different objects.",
              "- Rolling windows contain 40 quarters, overlap heavily, and can change because an old crisis exits. They carry no confidence bands.",
              "- context_sensitivity.csv fixes evaluation dates while changing the filter endpoint; year_influence.csv drops a year's already-transformed observations. Neither is a historical real-time vintage experiment.",
              "- Consumption includes NPISH expenditure. No population adjustment, consumption-services reconstruction or causal risk-sharing interpretation is imposed. Recent provisional observations remain included.",
              "- A small full-sample gap does not establish permanent disappearance of the anomaly or improved risk sharing. Crisis composition, filtering and the short post-2021 window require further investigation.", "",
              "## Reproducibility", "",
              "All nine CSV tables are calculated in Python. config.json records settings, input MD5/SHA-256 fingerprints, package versions and implementation SHA-256 fingerprints. figures.pdf is rendered from these results.",
              "The optional parity report checks every numeric cell against R with absolute tolerance 1e-9 and zero relative tolerance; labels, counts, row order and missing-value masks must match. Figures match data, not PDF bytes or rendering style.", "",
              "References: [Hamilton](https://www.nber.org/papers/w23429), "
              "[R time-series bootstrap documentation](https://stat.ethz.ch/R-manual/R-patched/RHOME/library/boot/html/tsboot.html), "
              "[OECD source](https://www.oecd.org/en/data/datasets/gdp-and-non-financial-accounts.html)."]
    return "\n".join(lines) + "\n"


def export_results(result: Result, root: Path, output: Path) -> None:
    output.mkdir(parents=True, exist_ok=True)
    for table, frame in result.tables.items():
        frame.write_csv(output / f"{table.value}.csv", float_precision=17)
    fingerprints = {str(path.relative_to(root)): {"md5": hashlib.md5(path.read_bytes()).hexdigest(),
                    "sha256": hashlib.sha256(path.read_bytes()).hexdigest()} for path in input_paths(root, result.config)}
    source_paths = [*Path(__file__).parent.glob("*.py"), Path(__file__).parents[1] / "panel.py", Path(__file__).parents[1] / "plot_style.py"]
    configuration = asdict(result.config) | {
        "countries": list(result.tables[Table.PAIRS]["country_i"].append(result.tables[Table.PAIRS]["country_j"]).unique().sort()),
        "methods": [m.value for m in Method], "level_start": quarter_text(result.level_start),
        "common_start": quarter_text(result.common_start), "end": quarter_text(result.end),
        "block_lengths": [4, 8, 12], "rolling_quarters": 40,
        "periods": result.tables[Table.SUMMARY].select("period", "start", "end").unique(maintain_order=True).to_dicts(),
        "random_generator": "R MT19937 / Rejection, independent NumPy-backed implementation",
        "quantile": "linear / R type 7", "bootstrap": "joint circular time blocks of fitted transformed series",
        "filter_context": "balanced start through each evaluation endpoint",
        "inputs": fingerprints,
        "implementation_sha256": {str(path.relative_to(Path(__file__).parents[2])): hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted(source_paths)},
        "environment": {"python": platform.python_version(), **{name: version(name) for name in ("numpy", "scipy", "polars", "matplotlib")}},
    }
    (output / "config.json").write_text(json.dumps(configuration, indent=2) + "\n")
    (output / "REPORT.md").write_text(research_report(result))


def export_parity(comparisons: tuple[Comparison, ...], reference: Path, output: Path) -> None:
    output.mkdir(parents=True, exist_ok=True)
    frame = pl.DataFrame([asdict(comparison) for comparison in comparisons])
    frame.write_csv(output / "parity.csv", float_precision=17)
    maximum = max(c.max_absolute_error for c in comparisons)
    lines = ["# Python/R extension parity", "", f"R reference directory: `{reference}`.",
             f"All tables matched: **{all(c.matches for c in comparisons)}**.",
             f"Numeric cells compared: **{sum(c.numeric_values for c in comparisons):,}**.",
             f"Maximum absolute difference: **{maximum:.3e}** (tolerance {ABSOLUTE_TOLERANCE:g}, relative tolerance zero).",
             "Labels, counts, order and null masks must match exactly. All interval endpoints and point estimates are compared.", ""]
    lines += markdown_table(frame.drop("max_absolute_error"))
    (output / "PARITY.md").write_text("\n".join(lines) + "\n")
