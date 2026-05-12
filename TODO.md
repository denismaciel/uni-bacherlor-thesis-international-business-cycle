# TODO

## Reproducibility

- [x] Fix Table 5 construction so correlations are selected by column name, not by `spread()` column position. Current R/tidyr output used to mismatch the PDF because the GDP row was inferred positionally.
- [x] Add a lightweight check that generated Tables 3-7 match the thesis PDF values after rounding.
- [x] Add a Nix dev environment for running the code reproducibly.

## Structure

- [x] Move R scripts into `R/`.
- [x] Move variable scripts into `R/variables/`.
- [x] Move figure scripts into `R/figures/`.
- [x] Move raw CSV files into `data/raw/oecd/` and `data/raw/fred/`.
- [x] Move generated figures into `output/figures/`.
- [x] Update `README.md` after paths are stable.
- [x] Stop legacy scripts from writing `fraemployment.png`, `gbremployment.png`, and `itaemployment.png` into the repo root.

## Cleanup

- [x] Replace repeated HP-filter and correlation code with small helper functions.
- [x] Reduce global side effects in `R/main.R`.
- [x] Remove or archive exploratory scripts/files that are not part of reproduction.
