# OECD QNA collection coverage

Snapshot: `2026-09-05T221752Z`.

13,634 observations; 70 series; 10 individual countries.
GDP/consumption common endpoint overlap: **1996-Q1 to 2026-Q2**.
All seven variables' common endpoint overlap: **2002-Q1 to 2026-Q2**.
Series with internal missing quarters: **0** (see coverage.csv).

| Country | GDP first | GDP latest | Consumption first | Consumption latest |
|---|---|---|---|---|
| AUS | 1959-Q3 | 2026-Q2 | 1959-Q3 | 2026-Q2 |
| AUT | 1995-Q1 | 2026-Q2 | 1995-Q1 | 2026-Q2 |
| CAN | 1961-Q1 | 2026-Q2 | 1981-Q1 | 2026-Q2 |
| CHE | 1980-Q1 | 2026-Q2 | 1980-Q1 | 2026-Q2 |
| DEU | 1991-Q1 | 2026-Q2 | 1991-Q1 | 2026-Q2 |
| FRA | 1980-Q1 | 2026-Q2 | 1980-Q1 | 2026-Q2 |
| GBR | 1955-Q1 | 2026-Q2 | 1995-Q1 | 2026-Q2 |
| ITA | 1996-Q1 | 2026-Q2 | 1996-Q1 | 2026-Q2 |
| JPN | 1994-Q1 | 2026-Q2 | 1994-Q1 | 2026-Q2 |
| USA | 1947-Q1 | 2026-Q2 | 1947-Q1 | 2026-Q2 |

## Measurement and interpretation

Real series: chain-linked volumes (L), national currency (XDC), calendar and seasonally adjusted (Y), quarterly levels (N).
Consumption includes households and NPISH (S1M); government is S13; GDP and fixed investment are S1.
Nominal GDP, exports and imports use current prices (V), with the same frequency/adjustment/transformation.
Values retain OECD units: multiply by 10^unit_mult for currency units. Do not compare national-currency levels across countries.
No logs, filtering, interpolation, splicing, annualization or currency conversion have been applied.
The original thesis uses fixed-PPP dollar volume estimates and annualized levels. These are not identical definitions; constant scaling does not affect log cycles, but methodological revisions can.
Do not append this vintage to the 2015 files. Compare old and new vintages on overlapping dates, then analyze the new vintage's full history.
Observation status flags are retained (including reported breaks/provisional estimates where present). Full code lists and provider attributes are preserved in the raw snapshot.
The overlap is an availability summary, not a claim that structural breaks or cross-country measurement differences have been resolved.
Employment, hours, population and consumption by durability are not included in this collection.

Source: https://www.oecd.org/en/data/datasets/gdp-and-non-financial-accounts.html
API: https://www.oecd.org/en/data/insights/data-explainers/2024/09/api.html
