export_extension <- function(results, output) {
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  for (name in setdiff(names(results), "config")) {
    utils::write.csv(results[[name]], file.path(output, paste0(name, ".csv")), row.names = FALSE, na = "")
  }
  dput(results$config, file = file.path(output, "config.R"))
  writeLines(capture.output(sessionInfo()), file.path(output, "session-info.txt"))
  extension_figures(results, output)
  extension_report(results, output)
}

extension_figures <- function(results, output) {
  labels <- c(hp1600 = "HP (1600)", growth = "Quarterly log growth", hamilton = "Hamilton (h=8, p=4)")
  colors <- c(hp1600 = "#245A81", growth = "#B55435", hamilton = "#44774A")
  grDevices::pdf(file.path(output, "figures.pdf"), width = 10, height = 6, title = "BKK empirical extension")
  on.exit(grDevices::dev.off())
  graphics::par(mar = c(6, 4, 3, 1))
  rolling <- results$rolling
  dates <- quarter_number(rolling$end) / 4
  graphics::plot(range(dates), range(c(0, rolling$gap)), type = "n", xlab = "Window ending year",
                 ylab = "Mean correlation gap (output minus consumption)",
                 main = "Quantity anomaly: rolling 40-quarter windows")
  limits <- graphics::par("usr")
  graphics::rect(2020, limits[3], 2022, limits[4], col = "#EEEEEE", border = NA)
  graphics::abline(h = 0, col = "grey50", lty = 2)
  for (method in names(labels)) {
    rows <- rolling[rolling$method == method, ]
    graphics::lines(quarter_number(rows$end) / 4, rows$gap, col = colors[[method]], lwd = 2)
  }
  graphics::legend("topright", labels, col = colors, lty = 1, lwd = 2, bty = "n", cex = 0.8)
  graphics::mtext("Descriptive overlapping windows; filters fitted only through each endpoint. Grey: 2020-2021.", side = 1, line = 4.5, cex = 0.7)

  graphics::par(mfrow = c(1, 3), mar = c(4, 4, 3, 1), pty = "s")
  for (method in names(labels)) {
    pairs <- results$pairs[results$pairs$period == "full_common" & results$pairs$method == method, ]
    graphics::plot(pairs$consumption_correlation, pairs$output_correlation, pch = 19, col = colors[[method]],
                   xlim = c(-0.4, 1), ylim = c(-0.4, 1), xlab = "Consumption correlation", ylab = "Output correlation",
                   main = labels[[method]], cex.main = 0.9)
    graphics::abline(a = 0, b = 1, lty = 2)
    graphics::mtext(paste(sum(pairs$gap > 0), "of 45 pairs above diagonal"), side = 3, line = 0.2, cex = 0.7)
  }

  graphics::par(mfrow = c(1, 1), mar = c(5, 11, 3, 1), pty = "m")
  rows <- results$summary
  positions <- rev(seq_len(nrow(rows)))
  graphics::plot(range(c(0, rows$gap_lower, rows$gap_upper)), range(positions) + c(-0.5, 0.5), type = "n",
                 yaxt = "n", ylab = "", xlab = "Mean pairwise correlation gap (95% conditional bootstrap interval)",
                 main = "Period and transformation sensitivity")
  graphics::abline(v = 0, lty = 2, col = "grey50")
  graphics::axis(2, at = positions, labels = paste(rows$period, labels[rows$method], sep = ": "), las = 1, cex.axis = 0.7)
  graphics::segments(rows$gap_lower, positions, rows$gap_upper, positions, col = colors[rows$method], lwd = 2)
  graphics::points(rows$gap, positions, pch = 19, col = colors[rows$method])
}

extension_report <- function(results, output) {
  number <- function(x) sprintf("%.3f", x)
  config <- results$config
  full <- results$summary[results$summary$period == "full_common", ]
  before <- results$summary[results$summary$period == "pre_pandemic", ]
  lines <- c(
    "# International business cycles: empirical extension", "",
    "Exploratory results, not a completed paper or a causal analysis.", "",
    paste0("Snapshot: `", config$snapshot, "`. Ten individual countries; 45 equally weighted unordered pairs."),
    paste0("Balanced log levels: ", config$level_start, " to ", config$end, "."),
    paste0("Common evaluation dates: ", config$common_start, " to ", config$end,
           ". All methods lose the first 11 quarters so Hamilton's initialization does not change the comparison sample."), "",
    "## First findings", "",
    paste0("Across the three transformations, the mean gap ranges from ", number(min(before$gap)), " to ",
           number(max(before$gap)), " before the pandemic, compared with ", number(min(full$gap)), " to ",
           number(max(full$gap)), " in the full sample."),
    "This makes sample composition and common crisis movements promising research questions. It does not establish that the anomaly has permanently disappeared or that international risk sharing improved.",
    "Read the crisis exclusions and filter-context diagnostics alongside this comparison: rolling windows can change when old crises exit, and later observations can alter fitted historical cycles.", "",
    "## Correlation gap by period", "",
    "Gap = mean pairwise output correlation minus mean pairwise consumption correlation. Positive values indicate the quantity anomaly.", "",
    "| Period | Method | Quarters | Output | Consumption | Gap | 95% interval | Positive pairs |",
    "|---|---|---:|---:|---:|---:|---|---:|"
  )
  for (i in seq_len(nrow(results$summary))) {
    row <- results$summary[i, ]
    lines <- c(lines, paste0("| ", row$period, " | ", row$method, " | ", row$quarters, " | ",
      number(row$output_correlation), " | ", number(row$consumption_correlation), " | ", number(row$gap), " | [",
      number(row$gap_lower), ", ", number(row$gap_upper), "] | ", row$positive_pairs, "/45 |"))
  }
  lines <- c(lines, "", "## Crisis and window-composition diagnostics", "",
    "These estimates are descriptive only. Exclusions remove already-transformed dates; they do not remove those shocks' effects on other dates or estimate a counterfactual.",
    "Between-crises and after-2021 estimates use contiguous windows with filters fitted only through their endpoints.", "",
    "| Diagnostic | Method | Quarters | Output | Consumption | Gap |",
    "|---|---|---:|---:|---:|---:|")
  for (i in seq_len(nrow(results$episode_diagnostics))) {
    row <- results$episode_diagnostics[i, ]
    lines <- c(lines, paste0("| ", row$diagnostic, " | ", row$method, " | ", row$quarters, " | ",
      number(row$output_correlation), " | ", number(row$consumption_correlation), " | ", number(row$gap), " |"))
  }
  lines <- c(lines, "", "## Original versus current vintage and measurement", "",
    "Both vintages use identical countries, raw-history start/end, transformation and evaluation dates.",
    "The comparison combines statistical revisions, source-methodology changes and measurement differences; it does not isolate pure revisions.", "",
    "| Method | Dates | Original gap | Current gap | Change | Paired 95% interval |",
    "|---|---|---:|---:|---:|---|")
  for (i in seq_len(nrow(results$vintage_comparison))) {
    row <- results$vintage_comparison[i, ]
    lines <- c(lines, paste0("| ", row$method, " | ", row$start, " to ", row$end, " | ", number(row$original_gap),
      " | ", number(row$current_gap), " | ", number(row$difference), " | [", number(row$difference_lower), ", ",
      number(row$difference_upper), "] |"))
  }
  lines <- c(lines, "", "## Interpretation and limits", "",
    "- Full-sample, pre-pandemic and post-thesis samples overlap. Their intervals are not tests of changes between periods.",
    "- Growth correlations and detrended-level correlations measure different objects. Method disagreement is substantive, not a reason to choose the preferred result.",
    "- No claim of a statistically identified crisis effect: period comparisons mix shocks, integration, revisions and measurement changes.",
    "- National-currency volume levels are not compared across countries. Log transformations remove constant currency/unit scaling; they do not remove methodological differences.",
    "- Consumption includes NPISH and uses expenditure rather than an explicitly measured consumption-services flow. Population adjustment and consumption categories remain future work.",
    "- Ten advanced economies do not establish a worldwide result. No European aggregate is counted alongside its members.",
    "- Recent provisional values remain included with their flags in the input data. Endpoint truncation below is not a historical real-time vintage experiment.", "",
    "## Estimation protocol", "",
    "- No pairwise deletion: every pair and both variables use exactly the same dates in a specification. Duplicate dates, internal gaps and invalid levels fail loudly.",
    "- HP: log levels, lambda=1600. Growth: first difference of log levels. Hamilton: regress log x[t] on an intercept and log x[t-8] through log x[t-11].",
    "- Filters are fitted on the balanced history from 1996-Q1 through the evaluation endpoint, then the evaluation dates are selected. Earlier history is retained for post-thesis/rolling windows. HP is two-sided inside that context; Hamilton coefficients use the entire context.",
    paste0("- Bootstrap: ", config$repetitions, " replications; seed ", config$seed,
           "; circular blocks of 8 quarters, resampling all 20 transformed series jointly. The vintage difference resamples both vintages with the same indices."),
    "- Reported percentile intervals are conditional on the fitted transformations. Filters are not re-estimated in each bootstrap draw; trend/parameter uncertainty is not included. Dependence is approximated within blocks, with stationarity within the analysis window assumed.",
    "- Nonstationarity and exceptional crises can undermine bootstrap coverage. These intervals are exploratory, not definitive publication-grade inference. Block-length sensitivity (4/8/12) is exported; intervals are omitted when fewer than 40 quarters or four block lengths fit.",
    "- Pair intervals in pairs.csv are pointwise, not simultaneous; there is no multiple-testing correction. The positive-pair count is descriptive and pairs are not independent observations.",
    "- Rolling estimates use 40 quarters and no confidence bands. Neighbouring estimates overlap heavily.",
    "- A rolling-window change can occur when an old crisis exits the window, not only when a new shock enters it. Compare episode_diagnostics.csv before attributing a decline to COVID.",
    "- context_sensitivity.csv holds evaluation dates fixed while changing the filter endpoint. It exposes contamination from subsequent observations and endpoint revisions.",
    "- year_influence.csv omits one year's already-transformed observations. It never re-filters concatenated gaps; remaining HP/Hamilton values can still reflect the omitted year's influence. It is a leverage diagnostic, not a pandemic counterfactual.", "",
    "## Outputs", "",
    "- summary.csv, pairs.csv: period estimates and baseline conditional intervals.",
    "- block_sensitivity.csv: alternative block lengths and unsupported-window flags.",
    "- rolling.csv, figures.pdf: rolling estimates, pair scatterplots and period comparisons.",
    "- context_sensitivity.csv, year_influence.csv: endpoint and exceptional-year diagnostics.",
    "- episode_diagnostics.csv: between-crisis/post-2021 windows and exclusion of 2008-2009, 2020-2021 or both; descriptive only.",
    "- vintage_comparison.csv: paired changes on matching samples.",
    "- vintage_series.csv: correlation and RMS differences of old/new quarterly log growth, by country and variable (percentage points).",
    "- config.R, session-info.txt: settings, input MD5 fingerprints and R environment. The raw collection's manifest separately records SHA-256 checksums.", "",
    "## References", "",
    "- Hamilton, Why You Should Never Use the Hodrick-Prescott Filter: https://www.nber.org/papers/w23429",
    "- R boot documentation and references on time-series block resampling: https://stat.ethz.ch/R-manual/R-patched/RHOME/library/boot/html/tsboot.html",
    "- OECD source: https://www.oecd.org/en/data/datasets/gdp-and-non-financial-accounts.html", ""
  )
  writeLines(lines, file.path(output, "REPORT.md"))
}
