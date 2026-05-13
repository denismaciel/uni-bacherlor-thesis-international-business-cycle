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
