# TODO

## LaTeX Improvements

- [x] Split the preamble out of `paper/main.tex` into `paper/preamble.tex`.
- [x] Replace manual page geometry with the `geometry` package.
- [x] Replace `\renewcommand{\baselinestretch}{2}` with `setspace` and `\doublespacing`.
- [x] Remove dead template comments and commented-out old generated table blocks.
- [x] Stop using `\nocite{*}`.
- [x] Move generated table captions, labels, and floats into LaTeX.
- [x] Make R generate only `tabular` fragments for the paper.
- [x] Modernize tables with `booktabs`.
- [x] Use `siunitx` for generated numeric table columns.
- [x] Standardize generated table and figure paths through macros.
- [x] Replace scale-based generated figure sizing with width-based sizing.
- [x] Add `microtype`.
- [x] Add `cleveref` and convert the main table, figure, and section references.
- [x] Add explicit `hyperref` PDF metadata and link setup.
- [x] Clean bibliography metadata by removing BibDesk-specific fields, normalizing DOI fields, and preferring HTTPS URLs.
- [x] Replace bare prose URLs in footnotes with `\url{...}`.
- [x] Move from the base `article` class to KOMA `scrartcl`, preserving the section-based thesis structure instead of forcing report-style chapters.
- [x] Add a `chktex` lint target to the flake.
