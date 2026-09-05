# Typst thesis edition

A modern, editable edition of the 2015 bachelor's thesis. Entry point: `main.typ`;
compiled document: `thesis.pdf`. Run commands from the repository root:

```sh
nix run .#paper-typst
nix run .#check-typst
```

The build uses the repository's pinned Typst 0.14.2, its embedded Libertinus
Serif/math fonts, and pinned DejaVu Sans fonts. System fonts and remote Typst
packages are not needed. Committed SVG assets make compilation independent of
R, Python and the network once the Nix dependencies have been cached.

To regenerate the vector charts from the original archived data:

```sh
uv run --locked python scripts/render_typst_figures.py
nix run .#paper-typst
```

The renderer consumes the existing pure `build_figure_data` analysis interface.
It changes appearance, not filtering, sample selection or correlation estimates.
Employment curves use the original sources before splicing, as in the thesis.
SVGs have fixed IDs and no creation timestamps. The renderer does not write the
R/Python table outputs or the 2026 extension outputs.

## Content and provenance

- Prose was converted from the LaTeX files at **`9bef204`**, before concurrent
  editorial revisions. All five chapters, the measurement/employment appendix,
  abstract, acknowledgements and declaration are retained. This is a separate
  editable edition; later LaTeX changes do not automatically propagate.
- Citations use Typst's built-in Chicago author-date style and native links.
  `references.bib` retains the original bibliography records; the original empty
  key `:1995aa` is renamed `Cooley:1995aa` for valid reference syntax.
- Tables 4–7 in `data/publication-tables.json` were transcribed from the submitted
  PDF in the repository root (printed pages 14, 15, 18 and 20). Historical BKK
  parentheses and ACZ brackets are retained. They had been omitted by the newer
  generated LaTeX tables despite still being mentioned in the prose.
- The published numbers are retained, including small differences from the
  present reproduction: Italian employment volatility `.48` versus `.49`, French
  employment/output correlation `.58` versus `.59`, and French/US employment
  correlation `.16` versus `.171` before rounding. This document is not a new
  empirical run. The submitted PDF's unconventional `(.-37)` and `(.-19)` signs
  are also retained rather than silently reinterpreted.
- Table 3 uses the committed original-sample timespan CSV, with first–last
  intervals instead of paired last/first columns. Tables 1, 2, 8 and 9 retain
  values from the committed LaTeX source. Table 1's two original panels are
  reorganized into three readable panels; Table 9 is transposed.
- The 2026 research extension is **not inserted into the 2015 thesis**. Its
  results remain in `output/extension/` and `output/extension-python/`.
- The title page retains the original author, institution, supervisor, degree
  and submission date. PDF creation metadata identifies this 2026 edition.

`template.typ` holds typography and reusable native tables/figures. The individual
`chapters/*.typ` files can be edited directly. `data/migration-counts.json` records
source section/footnote counts; `check-typst` checks those counts, all 13 labelled
figure/table elements, publication table shapes and selected legacy values.
Compilation also resolves bibliography entries and cross-references. These checks
are coverage checks, not a claim of byte-identical prose or visual facsimile.

Relevant Typst documentation: [citations and bibliography](https://typst.app/docs/reference/model/bibliography/),
[tables](https://typst.app/docs/reference/model/table/),
[figures](https://typst.app/docs/reference/model/figure/).
