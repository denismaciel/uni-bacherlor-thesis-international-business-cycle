# BKK International Business Cycle

This repository contains the R code and data for the bachelor thesis:

> Backus, Kehoe and Kydland (1993) - International Business Cycles: Theory and Evidence - Have the conclusions changed?

## Running

Use Nix:

```sh
nix run .
```

Check that the exported thesis tables still match the committed reference artifacts:

```sh
nix run .#check
```

For an interactive R environment with all required packages:

```sh
nix develop
```

## Layout

- `R/main.R`: main reproduction script.
- `R/variables/`: variable-specific transformations.
- `R/figures/`: figure scripts.
- `scripts/export_results.R`: exports Tables 3-7 to `output/tables/`.
- `scripts/compare_results.R`: compares generated tables against `reference/tables/`.
- `data/raw/oecd/`: OECD CSV inputs.
- `data/raw/fred/`: FRED employment CSV inputs.
- `reference/tables/`: committed regression artifacts.
- `output/tables/`: generated table outputs.
- `output/figures/`: generated figures, ignored by Git.

## Main Result Objects

After sourcing `R/main.R`, the most relevant objects are:

- `timespan`: Table 3.
- `standard.deviations`: Table 4.
- `cor.with.gdp.def`: Table 5.
- `usa.correlation.matrix`: Table 6.
- `sum.cor`: Table 7.

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
