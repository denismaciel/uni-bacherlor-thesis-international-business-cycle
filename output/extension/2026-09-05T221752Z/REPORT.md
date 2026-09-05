# International business cycles: empirical extension

Exploratory results, not a completed paper or a causal analysis.

Snapshot: `2026-09-05T221752Z`. Ten individual countries; 45 equally weighted unordered pairs.
Balanced log levels: 1996-Q1 to 2026-Q2.
Common evaluation dates: 1998-Q4 to 2026-Q2. All methods lose the first 11 quarters so Hamilton's initialization does not change the comparison sample.

## First findings

Across the three transformations, the mean gap ranges from 0.248 to 0.287 before the pandemic, compared with 0.004 to 0.036 in the full sample.
This makes sample composition and common crisis movements promising research questions. It does not establish that the anomaly has permanently disappeared or that international risk sharing improved.
Read the crisis exclusions and filter-context diagnostics alongside this comparison: rolling windows can change when old crises exit, and later observations can alter fitted historical cycles.

## Correlation gap by period

Gap = mean pairwise output correlation minus mean pairwise consumption correlation. Positive values indicate the quantity anomaly.

| Period | Method | Quarters | Output | Consumption | Gap | 95% interval | Positive pairs |
|---|---|---:|---:|---:|---:|---|---:|
| full_common | hp1600 | 111 | 0.801 | 0.797 | 0.004 | [-0.041, 0.193] | 23/45 |
| full_common | growth | 111 | 0.804 | 0.768 | 0.036 | [-0.031, 0.277] | 30/45 |
| full_common | hamilton | 111 | 0.707 | 0.702 | 0.004 | [-0.074, 0.241] | 24/45 |
| pre_pandemic | hp1600 | 85 | 0.644 | 0.377 | 0.267 | [0.100, 0.348] | 37/45 |
| pre_pandemic | growth | 85 | 0.439 | 0.191 | 0.248 | [0.026, 0.360] | 37/45 |
| pre_pandemic | hamilton | 85 | 0.572 | 0.285 | 0.287 | [0.088, 0.377] | 38/45 |
| thesis_overlap | hp1600 | 66 | 0.680 | 0.387 | 0.292 | [0.173, 0.379] | 37/45 |
| thesis_overlap | growth | 66 | 0.465 | 0.201 | 0.264 | [0.010, 0.376] | 38/45 |
| thesis_overlap | hamilton | 66 | 0.572 | 0.306 | 0.266 | [0.113, 0.364] | 37/45 |
| post_thesis | hp1600 | 45 | 0.905 | 0.874 | 0.031 | [-0.138, 0.071] | 33/45 |
| post_thesis | growth | 45 | 0.888 | 0.823 | 0.065 | [-0.150, 0.117] | 41/45 |
| post_thesis | hamilton | 45 | 0.837 | 0.864 | -0.027 | [-0.127, 0.039] | 18/45 |

## Crisis and window-composition diagnostics

These estimates are descriptive only. Exclusions remove already-transformed dates; they do not remove those shocks' effects on other dates or estimate a counterfactual.
Between-crises and after-2021 estimates use contiguous windows with filters fitted only through their endpoints.

| Diagnostic | Method | Quarters | Output | Consumption | Gap |
|---|---|---:|---:|---:|---:|
| between_crises | hp1600 | 40 | 0.254 | 0.179 | 0.075 |
| after_2021 | hp1600 | 18 | 0.553 | 0.737 | -0.184 |
| excluding_2008_2009 | hp1600 | 103 | 0.800 | 0.802 | -0.002 |
| excluding_2020_2021 | hp1600 | 103 | 0.675 | 0.610 | 0.064 |
| excluding_both | hp1600 | 95 | 0.594 | 0.594 | -0.001 |
| between_crises | growth | 40 | 0.133 | 0.101 | 0.033 |
| after_2021 | growth | 18 | 0.046 | 0.308 | -0.262 |
| excluding_2008_2009 | growth | 103 | 0.816 | 0.774 | 0.042 |
| excluding_2020_2021 | growth | 103 | 0.407 | 0.216 | 0.191 |
| excluding_both | growth | 95 | 0.203 | 0.174 | 0.029 |
| between_crises | hamilton | 40 | 0.593 | 0.205 | 0.388 |
| after_2021 | hamilton | 18 | 0.843 | 0.704 | 0.139 |
| excluding_2008_2009 | hamilton | 103 | 0.699 | 0.716 | -0.016 |
| excluding_2020_2021 | hamilton | 103 | 0.633 | 0.530 | 0.103 |
| excluding_both | hamilton | 95 | 0.585 | 0.520 | 0.064 |

## Original versus current vintage and measurement

Both vintages use identical countries, raw-history start/end, transformation and evaluation dates.
The comparison combines statistical revisions, source-methodology changes and measurement differences; it does not isolate pure revisions.

| Method | Dates | Original gap | Current gap | Change | Paired 95% interval |
|---|---|---:|---:|---:|---|
| hp1600 | 1998-Q4 to 2015-Q1 | 0.352 | 0.292 | -0.059 | [-0.104, 0.008] |
| growth | 1998-Q4 to 2015-Q1 | 0.325 | 0.264 | -0.062 | [-0.100, -0.020] |
| hamilton | 1998-Q4 to 2015-Q1 | 0.296 | 0.266 | -0.031 | [-0.057, 0.012] |

## Interpretation and limits

- Full-sample, pre-pandemic and post-thesis samples overlap. Their intervals are not tests of changes between periods.
- Growth correlations and detrended-level correlations measure different objects. Method disagreement is substantive, not a reason to choose the preferred result.
- No claim of a statistically identified crisis effect: period comparisons mix shocks, integration, revisions and measurement changes.
- National-currency volume levels are not compared across countries. Log transformations remove constant currency/unit scaling; they do not remove methodological differences.
- Consumption includes NPISH and uses expenditure rather than an explicitly measured consumption-services flow. Population adjustment and consumption categories remain future work.
- Ten advanced economies do not establish a worldwide result. No European aggregate is counted alongside its members.
- Recent provisional values remain included with their flags in the input data. Endpoint truncation below is not a historical real-time vintage experiment.

## Estimation protocol

- No pairwise deletion: every pair and both variables use exactly the same dates in a specification. Duplicate dates, internal gaps and invalid levels fail loudly.
- HP: log levels, lambda=1600. Growth: first difference of log levels. Hamilton: regress log x[t] on an intercept and log x[t-8] through log x[t-11].
- Filters are fitted on the balanced history from 1996-Q1 through the evaluation endpoint, then the evaluation dates are selected. Earlier history is retained for post-thesis/rolling windows. HP is two-sided inside that context; Hamilton coefficients use the entire context.
- Bootstrap: 1999 replications; seed 20260905; circular blocks of 8 quarters, resampling all 20 transformed series jointly. The vintage difference resamples both vintages with the same indices.
- Reported percentile intervals are conditional on the fitted transformations. Filters are not re-estimated in each bootstrap draw; trend/parameter uncertainty is not included. Dependence is approximated within blocks, with stationarity within the analysis window assumed.
- Nonstationarity and exceptional crises can undermine bootstrap coverage. These intervals are exploratory, not definitive publication-grade inference. Block-length sensitivity (4/8/12) is exported; intervals are omitted when fewer than 40 quarters or four block lengths fit.
- Pair intervals in pairs.csv are pointwise, not simultaneous; there is no multiple-testing correction. The positive-pair count is descriptive and pairs are not independent observations.
- Rolling estimates use 40 quarters and no confidence bands. Neighbouring estimates overlap heavily.
- A rolling-window change can occur when an old crisis exits the window, not only when a new shock enters it. Compare episode_diagnostics.csv before attributing a decline to COVID.
- context_sensitivity.csv holds evaluation dates fixed while changing the filter endpoint. It exposes contamination from subsequent observations and endpoint revisions.
- year_influence.csv omits one year's already-transformed observations. It never re-filters concatenated gaps; remaining HP/Hamilton values can still reflect the omitted year's influence. It is a leverage diagnostic, not a pandemic counterfactual.

## Outputs

- summary.csv, pairs.csv: period estimates and baseline conditional intervals.
- block_sensitivity.csv: alternative block lengths and unsupported-window flags.
- rolling.csv, figures.pdf: rolling estimates, pair scatterplots and period comparisons.
- context_sensitivity.csv, year_influence.csv: endpoint and exceptional-year diagnostics.
- episode_diagnostics.csv: between-crisis/post-2021 windows and exclusion of 2008-2009, 2020-2021 or both; descriptive only.
- vintage_comparison.csv: paired changes on matching samples.
- vintage_series.csv: correlation and RMS differences of old/new quarterly log growth, by country and variable (percentage points).
- config.R, session-info.txt: settings, input MD5 fingerprints and R environment. The raw collection's manifest separately records SHA-256 checksums.

## References

- Hamilton, Why You Should Never Use the Hodrick-Prescott Filter: https://www.nber.org/papers/w23429
- R boot documentation and references on time-series block resampling: https://stat.ethz.ch/R-manual/R-patched/RHOME/library/boot/html/tsboot.html
- OECD source: https://www.oecd.org/en/data/datasets/gdp-and-non-financial-accounts.html
