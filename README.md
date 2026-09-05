# BKK International Business Cycle

This repository contains the Python/Polars analysis, original R implementation,
and data for the bachelor thesis:

> Backus, Kehoe and Kydland (1993) - International Business Cycles: Theory and Evidence - Have the conclusions changed?

## Provenance Note

The thesis was originally submitted at Humboldt-Universitaet zu Berlin on
September 5, 2015, as shown on the submitted PDF title page. That original PDF
is kept in this repository as:

`Denis Maciel - Backus, Kehoe and Kydland (1993) - International Business Cycles: Theory and Evidence - Have the conclusions changed? .pdf`

In May 2026, the repository was revisited and revamped with Codex. The goal of
that work was engineering reproducibility: add a Nix-based R and LaTeX
environment, reorganize the R analysis into a clearer pipeline, add regression
checks for the generated thesis tables, modernize the LaTeX project structure,
and remove legacy archive code that was no longer part of the maintained
workflow. The revamp was not intended to materially change the thesis
conclusions. The changes from the submitted version to the current
reproducible repository are traceable through this repository's Git history.

## Running

Python 3.14.3 and dependencies are managed by uv:

```sh
uv sync --locked
uv run bkk-business-cycle run             # Export Tables 3–7 as CSV and LaTeX
uv run bkk-business-cycle check           # Require exact reference CSV matches
uv run bkk-business-cycle run --figures   # Also render all seven thesis figures
uv run ty check
uv run pytest
```

Run from the repository root, or supply `--data-dir`, `--output-dir`, and
`--reference-dir`. `uv run python -m bkk_business_cycle` also runs the analysis.
Add dependencies with `uv add <package>`; build the package with `uv build`.
`check` is read-only. Use `check --write-tables` to export after a match, or
`check --figures` to export both tables and figures after a match.

Nix wrappers use the same Python pipeline:

```sh
nix run .          # Export tables
nix run .#check    # Compare tables against references
nix run .#paper    # Check/export tables and figures, then compile the thesis PDF
nix run .#lint-tex # Lint the LaTeX source
```

uv installs Python and dependencies on the first run; `uv.lock` fixes dependency
versions. `nix develop` provides uv plus the original R and LaTeX environments.

## Python analysis

```python
from pathlib import Path
from bkk_business_cycle import InvalidInputs, Variable, analyze, load_inputs

inputs = load_inputs(Path("data/raw"))
if isinstance(inputs, InvalidInputs):
    print(inputs.issues)
else:
    results = analyze(inputs)  # Pure: no filesystem reads
    results.tables.standard_deviations  # Polars DataFrame
    results.panel                      # Logged/ratio values and HP cycles
    results.series[Variable.GDP]
    results.correlations[Variable.GDP]
    results.statistic_status            # Availability reasons and sample counts
```

Polars handles CSV ingestion, joins, reshaping, and statistics. NumPy/SciPy solve
the HP filter's banded linear system; Matplotlib renders the figures. No pandas
or R runtime is needed for the Python analysis.

`load_inputs` returns `ValidatedInputs | InvalidInputs`; `analyze` accepts only
validated data. The `run_analysis(path)` convenience adapter performs both steps
and returns `AnalysisResult | InvalidInputs`. See
[Python architecture](docs/python-architecture.md) for the boundary contracts,
explicit methodology and unavailable-statistic results.

The port preserves the original inputs, row ordering, employment splice at
2011-Q4, France's final-five-row truncation, HP lambda of 1600, capital share of
0.36, sample standard deviations, and pairwise-complete correlations. Cross-country
correlations are rounded to three decimals **before** computing means and R
type-1 quantiles. CSV export reproduces R's quoting and numeric formatting.
All five publication CSVs match the committed R references byte for byte.
Figure data and filenames are preserved; Matplotlib's appearance differs from R.

## Verify against R

The original R code remains an independent validation baseline. To compare the
entire panel, all seven correlation matrices, unrounded standard deviations,
and initial employment timespans:

```sh
nix shell .#default -c Rscript scripts/export_r_oracle.R /tmp/bkk-r-oracle
BKK_R_ORACLE=/tmp/bkk-r-oracle uv run pytest
```

Panel values and unrounded standard deviations use absolute tolerance `1e-10`
(zero relative tolerance); identifiers, row order, correlation matrices, and
publication CSVs must match exactly. The optional R test is skipped when
`BKK_R_ORACLE` is unset; the five reference-table checks always run.

The migration check covered all 16,128 panel rows: maximum absolute differences
were `4.98e-14` for input transformations, `4.13e-12` for HP cycles, and
`2.65e-13` for standard deviations. All seven correlation matrices matched
exactly. LaTeX tables matched apart from the generator comment.

## Layout

- `src/bkk_business_cycle/domain.py`: named methodology, variables, tables, and result states.
- `src/bkk_business_cycle/inputs.py`: CSV parsing and boundary validation.
- `src/bkk_business_cycle/panel.py`: pure employment splicing, Solow residuals, HP filtering.
- `src/bkk_business_cycle/analysis.py`: country statistics and Tables 3–7.
- `src/bkk_business_cycle/export.py`: publication CSV/LaTeX export and reference checks.
- `src/bkk_business_cycle/figure_data.py`: pure preparation of figure datasets.
- `src/bkk_business_cycle/figures.py`: seven thesis figures.
- `src/bkk_business_cycle/application.py`: filesystem adapters.
- `docs/python-architecture.md`: contracts, methodology, and command effects.
- `tests/`: numerical checks, exact publication regression tests, optional R parity test.
- `R/`: original R implementation plus the separate empirical research extension.
- `scripts/export_r_oracle.R`: independent R intermediate results for parity checks.
- `data/raw/oecd/`: original OECD CSV inputs.
- `data/raw/fred/`: original FRED employment CSV inputs.
- `reference/tables/`: committed R regression artifacts.
- `output/tables/`: generated table outputs.
- `output/figures/`: generated figures, ignored by Git.
- `paper/`: LaTeX thesis source.

## Research extension in R

The extension analyzes the current OECD snapshot while retaining both original
thesis implementations. Run from the repository root:

```sh
nix run .#check-extension
nix run .#extension
# Optional explicit snapshot and number of bootstrap replications:
nix run .#extension -- 2026-09-05T221752Z 1999
# Independently check serialized growth-correlation results:
nix shell .#default -c Rscript scripts/check_extension_outputs.R
```

The default run uses 1,999 joint circular time-block bootstrap draws, a fixed
seed, ten countries and 45 unordered pairs. It compares HP cycles, quarterly
log growth and Hamilton residuals on identical dates; reports four periods;
and compares the original/current vintages on a matching sample. Additional
outputs cover 40-quarter rolling estimates, block lengths, filter endpoints and
individual years' influence. Conditional intervals are exploratory: they do
not include filter-estimation uncertainty or identify causal crisis effects.

Results are in `output/extension/2026-09-05T221752Z/`: start with `REPORT.md`
and the three-page `figures.pdf`. CSV tables retain unrounded estimates.
`config.R` records settings and input fingerprints; `session-info.txt` records
the R environment. Running with different settings overwrites derived outputs
for that snapshot; use Git commits to preserve reviewed research runs.

`R/extension_data.R` handles validation and transformations;
`R/extension_statistics.R` handles pair estimates and joint uncertainty;
`R/extension_run.R` defines the comparisons; `R/extension_export.R` generates
the report and figures. `scripts/check_extension.R` checks date alignment,
scaling invariance, filter timing and bootstrap dependence/reproducibility.

All methods use 1998-Q4 onward because the balanced raw history begins in
1996-Q1 and Hamilton needs 11 initial quarters. Historical-vintage comparisons
combine revisions and measurement changes; they are not pure revision effects.

## Data

### Current OECD collection

Collect a new, dated snapshot of the ten individual thesis countries (excluding
the overlapping EU aggregate):

```sh
uv run --no-project python scripts/collect_oecd.py
```

This downloads full available quarterly histories for real GDP, household and
NPISH consumption, government consumption, and gross fixed capital formation;
plus current-price GDP, exports and imports. The downloader uses only Python's
standard library. Collection does not change either thesis reproduction pipeline.

- `data/raw/oecd_snapshots/<UTC timestamp>/`: untouched OECD CSV responses,
  SDMX structure/code lists, and a manifest with request URLs, retrieval times,
  response headers and SHA-256 hashes.
- `data/processed/oecd/<UTC timestamp>/panel.csv`: sorted, unfiltered long panel
  with source measurement metadata and observation flags.
- `data/processed/oecd/<UTC timestamp>/coverage.csv`: all 70 series' dates,
  gaps, observation counts and status summaries.
- `data/processed/oecd/<UTC timestamp>/COVERAGE.md`: readable coverage and
  measurement limitations.

Raw snapshots are never overwritten. Rebuild derived files offline and verify
raw checksums with:

```sh
uv run --no-project python scripts/collect_oecd.py --rebuild data/raw/oecd_snapshots/<UTC-timestamp>
uv run --no-project python -m unittest discover -s scripts -p 'test_collect_oecd.py'
```

The normalized panel can be read directly with `readr::read_csv()` in R.
It is deliberately separate from `R/main.R` and the original thesis inputs.
Real values are national-currency chain-linked volumes, not the original
fixed-PPP dollar measure. Values remain in the units specified by `unit_mult`;
quarterly levels are not annualized. For net exports/GDP, join the three nominal
series by country and quarter and verify their currency and scale before
calculating `(exports_nominal - imports_nominal) / gdp_nominal`.

Do not append the new observations to old-vintage data. Use the full new vintage
for extension analysis, and compare vintages on their overlapping dates to
assess revisions. Latest observations may be provisional, and country histories
need substantive break/definition review before publication. No interpolation,
filtering, currency conversion or automatic splicing is performed.

Source: [OECD quarterly national accounts](https://www.oecd.org/en/data/datasets/gdp-and-non-financial-accounts.html),
[API documentation](https://www.oecd.org/en/data/insights/data-explainers/2024/09/api.html).

### Original thesis inputs

OECD National Accounts:

- `data/raw/oecd/consumption.csv`
- `data/raw/oecd/employment.csv`
- `data/raw/oecd/gdp.csv`
- `data/raw/oecd/government.csv`
- `data/raw/oecd/investment.csv`
- `data/raw/oecd/net_exports.csv`
- `data/raw/oecd/gdp_measure_choice.csv`

FRED/OECD Main Economic Indicators:

- `data/raw/fred/fra_employment.csv`
- `data/raw/fred/gbr_employment.csv`
- `data/raw/fred/ita_employment.csv`
