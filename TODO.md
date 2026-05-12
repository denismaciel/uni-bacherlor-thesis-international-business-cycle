# TODO

## Reproducibility

- [ ] Fix Table 5 construction so correlations are selected by column name, not by `spread()` column position. Current R/tidyr output for `cor.with.gdp.def` does not match the PDF because the GDP row is inferred positionally.
- [ ] Add a lightweight check that generated Tables 3-7 match the thesis PDF values after rounding.
- [x] Add a Nix dev environment for running the code reproducibly.

## Structure

- [ ] Move R scripts into `R/`.
- [ ] Move variable scripts into `R/variables/`.
- [ ] Move figure scripts into `R/figures/`.
- [ ] Move raw CSV files into `data/raw/oecd/` and `data/raw/fred/`.
- [ ] Move generated figures into `output/figures/`.
- [ ] Update `README.md` after paths are stable.

## Cleanup

- [ ] Replace repeated HP-filter and correlation code with small helper functions.
- [ ] Reduce global side effects in `+Code.R`.
- [ ] Remove or archive exploratory scripts/files that are not part of reproduction.
