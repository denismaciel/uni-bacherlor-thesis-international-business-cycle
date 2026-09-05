# International business cycles: Python research extension

Independent Python computation of the R extension. Exploratory results, not a causal analysis or a completed paper.

Snapshot: `2026-09-05T221752Z`. Ten countries, 45 equally weighted unordered pairs.
Balanced log levels: 1996-Q1–2026-Q2. All methods evaluated from 1998-Q4 to retain identical dates after Hamilton's 11 initial quarters.

## Period estimates

Gap = mean output correlation minus mean consumption correlation.

| period | method | quarters | output_correlation | consumption_correlation | gap | gap_lower | gap_upper | positive_pairs |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| full_common | hp1600 | 111 | 0.801 | 0.797 | 0.004 | -0.041 | 0.193 | 23 |
| full_common | growth | 111 | 0.804 | 0.768 | 0.036 | -0.031 | 0.277 | 30 |
| full_common | hamilton | 111 | 0.707 | 0.702 | 0.004 | -0.074 | 0.241 | 24 |
| pre_pandemic | hp1600 | 85 | 0.644 | 0.377 | 0.267 | 0.100 | 0.348 | 37 |
| pre_pandemic | growth | 85 | 0.439 | 0.191 | 0.248 | 0.026 | 0.360 | 37 |
| pre_pandemic | hamilton | 85 | 0.572 | 0.285 | 0.287 | 0.088 | 0.377 | 38 |
| thesis_overlap | hp1600 | 66 | 0.680 | 0.387 | 0.292 | 0.173 | 0.379 | 37 |
| thesis_overlap | growth | 66 | 0.465 | 0.201 | 0.264 | 0.010 | 0.376 | 38 |
| thesis_overlap | hamilton | 66 | 0.572 | 0.306 | 0.266 | 0.113 | 0.364 | 37 |
| post_thesis | hp1600 | 45 | 0.905 | 0.874 | 0.031 | -0.138 | 0.071 | 33 |
| post_thesis | growth | 45 | 0.888 | 0.823 | 0.065 | -0.150 | 0.117 | 41 |
| post_thesis | hamilton | 45 | 0.837 | 0.864 | -0.027 | -0.127 | 0.039 | 18 |

## Crisis and sample-composition diagnostics

Descriptive only. Crisis exclusions drop already-transformed observations; they do not remove a shock's influence on other dates or estimate a counterfactual.

| method | diagnostic | quarters | output_correlation | consumption_correlation | gap |
| --- | --- | --- | --- | --- | --- |
| hp1600 | between_crises | 40 | 0.254 | 0.179 | 0.075 |
| hp1600 | after_2021 | 18 | 0.553 | 0.737 | -0.184 |
| hp1600 | excluding_2008_2009 | 103 | 0.800 | 0.802 | -0.002 |
| hp1600 | excluding_2020_2021 | 103 | 0.675 | 0.610 | 0.064 |
| hp1600 | excluding_both | 95 | 0.594 | 0.594 | -0.001 |
| growth | between_crises | 40 | 0.133 | 0.101 | 0.033 |
| growth | after_2021 | 18 | 0.046 | 0.308 | -0.262 |
| growth | excluding_2008_2009 | 103 | 0.816 | 0.774 | 0.042 |
| growth | excluding_2020_2021 | 103 | 0.407 | 0.216 | 0.191 |
| growth | excluding_both | 95 | 0.203 | 0.174 | 0.029 |
| hamilton | between_crises | 40 | 0.593 | 0.205 | 0.388 |
| hamilton | after_2021 | 18 | 0.843 | 0.704 | 0.139 |
| hamilton | excluding_2008_2009 | 103 | 0.699 | 0.716 | -0.016 |
| hamilton | excluding_2020_2021 | 103 | 0.633 | 0.530 | 0.103 |
| hamilton | excluding_both | 95 | 0.585 | 0.520 | 0.064 |

## Original versus current vintage and measurement

Identical countries, level history and evaluation dates. Changes combine revisions and measurement differences, not pure revisions.

| method | start | end | quarters | original_gap | current_gap | difference | difference_lower | difference_upper | block_length | repetitions |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| hp1600 | 1998-Q4 | 2015-Q1 | 66 | 0.352 | 0.292 | -0.059 | -0.104 | 0.008 | 8 | 1999 |
| growth | 1998-Q4 | 2015-Q1 | 66 | 0.325 | 0.264 | -0.062 | -0.100 | -0.020 | 8 | 1999 |
| hamilton | 1998-Q4 | 2015-Q1 | 66 | 0.296 | 0.266 | -0.031 | -0.057 | 0.012 | 8 | 1999 |

## Method and interpretation

- HP uses log levels and lambda=1600; growth uses first differences of logs; Hamilton regresses x[t] on an intercept and x[t-8] through x[t-11].
- Filters use the balanced history only through each evaluation endpoint, then the requested dates are selected. Post-thesis/rolling windows retain preceding history. HP is two-sided within that context; Hamilton coefficients use the whole context.
- Joint circular blocks: 1,999 draws, seed 20260905, baseline block length 8 quarters. All 20 series use identical row indices; vintage comparisons also share the indices across vintages.
- R-compatible Mersenne-Twister initialization and Rejection sampling reproduce the actual R resamples. NumPy's ordinary seed/choice combination would not do so. Percentiles use R type-7/NumPy linear interpolation.
- Percentile intervals are conditional on fitted transformations; filters are not refitted within bootstrap samples. Trend/parameter uncertainty is omitted and within-window stationarity is assumed. Crises and nonstationarity can undermine coverage.
- Block lengths 4/8/12 are exported; unsupported intervals are missing when fewer than 40 quarters or four blocks fit. Pair intervals are pointwise, not simultaneous; positive-pair counts are descriptive.
- Periods overlap. Their intervals are not tests of between-period changes. Growth and detrended-level correlations measure different objects.
- Rolling windows contain 40 quarters, overlap heavily, and can change because an old crisis exits. They carry no confidence bands.
- context_sensitivity.csv fixes evaluation dates while changing the filter endpoint; year_influence.csv drops a year's already-transformed observations. Neither is a historical real-time vintage experiment.
- Consumption includes NPISH expenditure. No population adjustment, consumption-services reconstruction or causal risk-sharing interpretation is imposed. Recent provisional observations remain included.
- A small full-sample gap does not establish permanent disappearance of the anomaly or improved risk sharing. Crisis composition, filtering and the short post-2021 window require further investigation.

## Reproducibility

All nine CSV tables are calculated in Python. config.json records settings, input MD5/SHA-256 fingerprints, package versions and implementation SHA-256 fingerprints. figures.pdf is rendered from these results.
The optional parity report checks every numeric cell against R with absolute tolerance 1e-9 and zero relative tolerance; labels, counts, row order and missing-value masks must match. Figures match data, not PDF bytes or rendering style.

References: [Hamilton](https://www.nber.org/papers/w23429), [R time-series bootstrap documentation](https://stat.ethz.ch/R-manual/R-patched/RHOME/library/boot/html/tsboot.html), [OECD source](https://www.oecd.org/en/data/datasets/gdp-and-non-financial-accounts.html).
