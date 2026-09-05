# BKK International Business Cycle

This repository contains the R code and data for the bachelor thesis:

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

Use Nix:

```sh
nix run .
```

Check that the exported thesis tables still match the committed reference artifacts:

```sh
nix run .#check
```

Build the thesis PDF from the generated tables and figures:

```sh
nix run .#paper
```

Lint the LaTeX source:

```sh
nix run .#lint-tex
```

For an interactive R environment with all required packages:

```sh
nix develop
```

## Layout

- `R/main.R`: main reproduction script.
- `R/run_analysis.R`: list-based analysis pipeline.
- `R/helpers.R`: shared HP-filter, correlation, standard-deviation and timespan helpers.
- `scripts/export_results.R`: exports Tables 3-7 to `output/tables/`.
- `scripts/compare_results.R`: compares generated tables against `reference/tables/`.
- `data/raw/oecd/`: OECD CSV inputs.
- `data/raw/fred/`: FRED employment CSV inputs.
- `reference/tables/`: committed regression artifacts.
- `output/tables/`: generated table outputs.
- `output/figures/`: generated figures, ignored by Git.
- `paper/`: organized LaTeX thesis source.

## Main Result Objects

After sourcing `R/main.R`, use `results$tables`:

- `results$tables$timespan`: Table 3.
- `results$tables$standard_deviations`: Table 4.
- `results$tables$within_country_correlations`: Table 5.
- `results$tables$usa_correlation_matrix`: Table 6.
- `results$tables$average_cross_country_correlations`: Table 7.

`R/results.R` prints the central result objects.

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
standard library. The existing analysis remains in R.

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
