source("R/extension_data.R")
source("R/extension_statistics.R")

run_extension <- function(snapshot = extension_snapshot, repetitions = 1999L, seed = 20260905L) {
  current <- read_current_extension(snapshot)
  original <- read_original_extension()
  levels <- balanced_extension(current)
  first <- min(levels$quarter) + 11L # Same Hamilton-compatible dates for every method.
  last <- max(levels$quarter)
  methods <- c("hp1600", "growth", "hamilton")
  periods <- data.frame(
    period = c("full_common", "pre_pandemic", "thesis_overlap", "post_thesis"),
    first = c(first, first, first, quarter_number("2015-Q2")),
    last = c(last, quarter_number("2019-Q4"), quarter_number("2015-Q1"), last)
  )
  summaries <- pairs <- block_sensitivity <- list()
  for (i in seq_len(nrow(periods))) {
    for (method in methods) {
      period <- periods[i, ]
      message("Estimating ", period$period, "/", method)
      sample <- extension_window(levels, method, period$first, period$last)
      result <- summarize_extension(sample, repetitions, seed = seed)
      label <- data.frame(period = period$period, method = method)
      summaries[[length(summaries) + 1L]] <- cbind(label, result$summary)
      pairs[[length(pairs) + 1L]] <- cbind(label, result$pairs)
      for (block in c(4L, 8L, 12L)) {
        supported <- nrow(sample$y) >= max(40L, 4L * block)
        boot <- if (!supported) NULL else if (block == 8L) {
          list(lower = c(NA, NA, result$summary$gap_lower), upper = c(NA, NA, result$summary$gap_upper))
        } else bootstrap_extension(sample, repetitions, block, seed)
        block_sensitivity[[length(block_sensitivity) + 1L]] <- cbind(label, data.frame(
          block_length = block, quarters = nrow(sample$y), gap = result$summary$gap,
          lower = if (supported) boot$lower[3] else NA_real_,
          upper = if (supported) boot$upper[3] else NA_real_,
          status = if (supported) "estimated" else "fewer_than_four_blocks",
          repetitions = if (supported) repetitions else 0L
        ))
      }
    }
  }

  rolling <- context_sensitivity <- influence <- episodes <- list()
  for (method in methods) {
    for (end in seq.int(first + 39L, last)) {
      sample <- extension_window(levels, method, end - 39L, end)
      moments <- mean_moments(sample)
      rolling[[length(rolling) + 1L]] <- data.frame(
        method = method, start = quarter_text(end - 39L), end = quarter_text(end), quarters = 40L,
        output_correlation = moments[1], consumption_correlation = moments[2], gap = moments[3], row.names = NULL
      )
    }
    for (end in c(quarter_number("2015-Q1"), quarter_number("2019-Q4"), last - 4L)) {
      truncated <- mean_moments(extension_window(levels, method, first, end))
      full <- mean_moments(extension_window(levels, method, first, end, context_end = last))
      context_sensitivity[[length(context_sensitivity) + 1L]] <- data.frame(
        method = method, start = quarter_text(first), end = quarter_text(end),
        truncated_gap = truncated[3], full_context_gap = full[3], difference = full[3] - truncated[3], row.names = NULL
      )
    }
    full_sample <- extension_window(levels, method, first, last)
    diagnostics <- list(
      between_crises = c(quarter_number("2010-Q1"), quarter_number("2019-Q4")),
      after_2021 = c(quarter_number("2022-Q1"), last)
    )
    for (name in c(names(diagnostics), "excluding_2008_2009", "excluding_2020_2021", "excluding_both")) {
      if (name %in% names(diagnostics)) {
        window <- diagnostics[[name]]
        sample <- extension_window(levels, method, window[1], window[2])
        context_end <- window[2]
      } else {
        years <- full_sample$quarter %/% 4L
        omit <- switch(name, excluding_2008_2009 = 2008:2009, excluding_2020_2021 = 2020:2021,
                       excluding_both = c(2008:2009, 2020:2021))
        keep <- !years %in% omit
        sample <- full_sample
        sample$quarter <- sample$quarter[keep]
        sample$y <- sample$y[keep, , drop = FALSE]
        sample$c <- sample$c[keep, , drop = FALSE]
        context_end <- last
      }
      moments <- mean_moments(sample)
      episodes[[length(episodes) + 1L]] <- data.frame(
        method = method, diagnostic = name, quarters = nrow(sample$y),
        filter_context_end = quarter_text(context_end), output_correlation = moments[1],
        consumption_correlation = moments[2], gap = moments[3], inference = "descriptive_only", row.names = NULL
      )
    }
    for (year in 1999:2025) {
      # Delete already-transformed observations, never filter across a joined gap.
      keep <- full_sample$quarter %/% 4L != year
      sample <- full_sample
      sample$y <- sample$y[keep, , drop = FALSE]
      sample$c <- sample$c[keep, , drop = FALSE]
      moments <- mean_moments(sample)
      influence[[length(influence) + 1L]] <- data.frame(
        method = method, omitted_year = year, quarters = sum(keep),
        gap = moments[3], change_from_full = moments[3] - mean_moments(full_sample)[3], row.names = NULL
      )
    }
  }

  old_levels <- balanced_extension(original)
  overlap_start <- max(min(old_levels$quarter), min(levels$quarter))
  overlap_end <- min(max(old_levels$quarter), max(levels$quarter))
  old <- balanced_extension(original, quarter_text(overlap_start), quarter_text(overlap_end))
  new <- balanced_extension(current, quarter_text(overlap_start), quarter_text(overlap_end))
  vintage <- list()
  for (method in methods) {
    old_sample <- extension_window(old, method, overlap_start + 11L, overlap_end)
    new_sample <- extension_window(new, method, overlap_start + 11L, overlap_end)
    difference <- bootstrap_extension(new_sample, repetitions, seed = seed, other = old_sample)
    vintage[[length(vintage) + 1L]] <- data.frame(
      method = method, start = quarter_text(overlap_start + 11L), end = quarter_text(overlap_end),
      quarters = nrow(old_sample$y), original_gap = mean_moments(old_sample)[3],
      current_gap = mean_moments(new_sample)[3], difference = difference$point[3],
      difference_lower = difference$lower[3], difference_upper = difference$upper[3],
      block_length = 8L, repetitions = repetitions, row.names = NULL
    )
  }
  vintage_series <- list()
  for (variable in c("y", "c")) {
    for (j in seq_along(levels$countries)) {
      old_growth <- diff(old[[variable]][, j]) * 100
      new_growth <- diff(new[[variable]][, j]) * 100
      vintage_series[[length(vintage_series) + 1L]] <- data.frame(
        location = levels$countries[j], variable = if (variable == "y") "gdp" else "consumption",
        start = quarter_text(overlap_start + 1L), end = quarter_text(overlap_end), quarters = length(old_growth),
        growth_correlation = stats::cor(old_growth, new_growth),
        rms_growth_difference_pp = sqrt(mean((new_growth - old_growth)^2)),
        max_abs_growth_difference_pp = max(abs(new_growth - old_growth))
      )
    }
  }
  inputs <- c(
    file.path("data/processed/oecd", snapshot, "panel.csv"),
    file.path("data/raw/oecd", c("gdp.csv", "consumption.csv"))
  )
  list(
    summary = do.call(rbind, summaries), pairs = do.call(rbind, pairs),
    block_sensitivity = do.call(rbind, block_sensitivity), rolling = do.call(rbind, rolling),
    context_sensitivity = do.call(rbind, context_sensitivity), year_influence = do.call(rbind, influence),
    episode_diagnostics = do.call(rbind, episodes),
    vintage_comparison = do.call(rbind, vintage), vintage_series = do.call(rbind, vintage_series),
    config = list(
      snapshot = snapshot, countries = levels$countries, methods = methods,
      level_start = quarter_text(min(levels$quarter)), common_start = quarter_text(first), end = quarter_text(last),
      periods = periods, repetitions = repetitions, seed = seed,
      block_lengths = c(4L, 8L, 12L), rolling_quarters = 40L,
      bootstrap = "joint circular time blocks of transformed observations; conditional percentile intervals",
      filter_context = "balanced start through each evaluation endpoint; truncate before transformation",
      input_md5 = tools::md5sum(inputs)
    )
  )
}
