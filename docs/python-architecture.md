# Python reproduction architecture

The Python package reproduces the original 2015 analysis. Its compatibility
contract is the five committed CSV tables plus the independent R panel and
statistics exported by `scripts/export_r_oracle.R`.

## Flow

```text
CSV files -> load_inputs / parse_inputs -> ValidatedInputs | InvalidInputs
ValidatedInputs -> analyze -> AnalysisResult
AnalysisResult -> render_tables -> tuple[Artifact, ...]
Artifacts + reference bytes -> compare_references -> ReferenceReport
AnalysisResult + the same inputs -> build_figure_data -> FigureData
```

`application.py` and `cli.py` handle filesystem access and process output.
`figures.py` owns Matplotlib rendering through explicit Figure instances, with
no global pyplot state or import-time backend selection. The analysis, table
rendering, reference comparison, and figure-data preparation perform no I/O.

## Input contract

`inputs.py` reads source CSV fields as strings, then validates and normalizes
OECD and FRED schemas. It checks subjects, measures, units, scale, quarter
formats, positive log inputs and GDP denominators, finite trade flows,
uniqueness, source ordering, quarterly continuity, splice anchors, the USA
benchmark, and sufficient GDP/employment overlap. Excluded Swiss employment
history may have gaps; it is not passed to the filter.

Failure returns `InvalidInputs` containing source/country/quarter diagnostics.
Success returns `ValidatedInputs` with only the normalized columns needed by
the core. Those DataFrames must be treated as immutable; mapping containers are
read-only, but Polars frames are not deeply frozen. Pure transforms create new
frames. Callers supplying in-memory source frames use `parse_inputs` to obtain
the same validation contract.

## Methodology and result types

`domain.py` declares `Variable`, `TableId`, `ThesisTables`, and the named
`Thesis2015Policy`. The policy records the source-row ordering convention,
country exclusions, employment splice/reference dates and tail truncation,
HP lambda, capital share, sample-standard-deviation convention, pairwise
missingness, correlation precision, and inverse-empirical-CDF quantiles.

The policy is specific to the reproduction; unsupported conventions fail at
construction instead of being silently ignored. A new research methodology
should receive its own explicit policy and validation contract.

Correlations return `Estimated(value, observations)` or
`Unavailable(reason, observations)`. Reasons distinguish absent series,
insufficient overlap, and zero variance. Relative-volatility estimates also
record unavailable denominators. `AnalysisResult.assessments` retains these
results; `statistic_status` provides a Polars view for inspection. Numeric table
columns stay numeric, and publication maps unavailable values to blank cells.

Unexpected nonfinite values inside the numerical core are contract errors,
not a fourth form of missing data.

## Publication and comparisons

Each table has named source-column mappings and explicit cell formats in
`TABLE_SPECS`. Reordering a DataFrame cannot silently relabel its columns.
CSV quoting of numeric values in Table 5 is a publication policy, not a reason
to store numerical analysis as strings. LaTeX formatting never attempts to
parse arbitrary text as a number.

`render_tables` returns bytes in `Artifact` values before any files are written.
`compare_references` accepts reference bytes and returns every table's `MATCH`,
`DIFFERENT`, or `MISSING_REFERENCE` outcome, including text differences. The
shell decides exit codes and whether to write outputs.

## CLI effects

Arguments are parsed into `ExecutionPlan`, with named artifact selection and
reference action. The ordinary command-line flags remain convenient booleans
only at the argument boundary.

| Command | Compare references | Write tables | Write figures |
| --- | --- | --- | --- |
| `run` | No | Yes | No |
| `run --figures` | No | Yes | Yes |
| `figures` | No | No | Yes |
| `check` | Yes | No | No |
| `check --write-tables` | Yes | After a match | No |
| `check --figures` | Yes | After a match | After a match |

One input load supplies both tables and figures. A failed check prevents all
requested writes. Exit codes: 0 success, 1 reference mismatch/missing reference,
2 invalid inputs or arguments, 3 filesystem failure.

## Verification

```sh
uv run ty check
uv run pytest
uv run bkk-business-cycle check
nix shell .#default -c Rscript scripts/export_r_oracle.R /tmp/bkk-r-oracle
BKK_R_ORACLE=/tmp/bkk-r-oracle uv run pytest
```

Tests cover malformed sources, explicit unavailable states, policy validation,
column-order independence, exact publication bytes, read-only checks, failed
check write prevention, one-load execution, and a core that runs with filesystem
reads disabled. The R test compares every panel row and variable's statistics.
