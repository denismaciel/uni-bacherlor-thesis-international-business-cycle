source("R/extension_data.R")
source("R/extension_statistics.R")

expect_error <- function(expression, pattern) {
  error <- tryCatch({ force(expression); NULL }, error = identity)
  if (is.null(error) || !grepl(pattern, conditionMessage(error))) stop("Expected error: ", pattern)
}

current <- read_current_extension()
levels <- balanced_extension(current)
stopifnot(identical(range(quarter_text(levels$quarter)), c("1996-Q1", "2026-Q2")))
stopifnot(nrow(levels$y) == 122L, ncol(levels$y) == 10L)
set.seed(42)
shuffled <- balanced_extension(current[sample.int(nrow(current)), ])
stopifnot(identical(levels, shuffled))
expect_error(validate_extension_panel(rbind(current, current[1, ])), "Duplicate")
interior <- which(current$location == "USA" & current$variable == "gdp" & current$time == "2000-Q1")
expect_error(validate_extension_panel(current[-interior, ]), "Internal missing")
expect_error(balanced_extension(current, start = "1995-Q1"), "outside balanced")
expect_error(quarter_number("2000-Q5"), "Invalid quarterly")
stopifnot(quarter_number("2000-Q1") - quarter_number("1999-Q4") == 1L)

first <- min(levels$quarter) + 11L
for (method in c("hp1600", "growth", "hamilton")) {
  transformed <- extension_window(levels, method, first, max(levels$quarter))
  shifted <- levels
  shifted$y <- sweep(shifted$y, 2, log(seq_len(10) * 1000), "+")
  shifted$c <- sweep(shifted$c, 2, log(seq_len(10) * 37), "+")
  scaled <- extension_window(shifted, method, first, max(levels$quarter))
  stopifnot(isTRUE(all.equal(pair_moments(transformed)$gap, pair_moments(scaled)$gap, tolerance = 1e-7)))
  stopifnot(nrow(pair_moments(transformed)) == 45L)
  identical_series <- transformed
  identical_series$c <- identical_series$y
  result <- bootstrap_extension(identical_series, repetitions = 99L)
  stopifnot(all(abs(result$point[-(1:2)]) < 1e-12), all(abs(result$lower[-(1:2)]) < 1e-12))
  # A future perturbation cannot affect a filter fitted to a truncated context.
  end <- quarter_number("2019-Q4")
  perturbed <- levels
  perturbed$y[perturbed$quarter > end, ] <- 100
  stopifnot(identical(extension_window(levels, method, first, end), extension_window(perturbed, method, first, end)))
}

# Hamilton residuals are orthogonal to the actual 8-to-11-quarter regressors.
hamilton <- transform_extension(levels, "hamilton")
stopifnot(all(is.na(hamilton$y[1:11, ])), all(is.finite(hamilton$y[-(1:11), ])))
for (lag in 8:11) {
  predictor <- levels$y[(12:nrow(levels$y)) - lag, 1]
  stopifnot(abs(sum(predictor * hamilton$y[-(1:11), 1])) < 1e-7)
}

# Circular blocks preserve adjacency within blocks, including the wrap boundary.
indices <- circular_block_indices(111L, 8L)
within_block <- which(seq_along(indices)[-1] %% 8L != 1L)
stopifnot(length(indices) == 111L, all(indices >= 1L & indices <= 111L))
stopifnot(all((diff(indices)[within_block] %% 111L) == 1L))
panel <- extension_window(levels, "growth", first, max(levels$quarter))
seed_before <- .Random.seed
a <- bootstrap_extension(panel, repetitions = 99L, other = panel)
b <- bootstrap_extension(panel, repetitions = 99L, other = panel)
stopifnot(identical(a, b), identical(seed_before, .Random.seed), all(a$point == 0), all(a$upper == 0))
expect_error(bootstrap_extension(slice_extension(panel, first, first + 20L), repetitions = 99L), "too short")
expect_error(pair_moments(list(y = panel$y * 0, c = panel$c, countries = panel$countries)), "Zero-variance")
message("Extension checks passed: alignment, missing dates, scaling, filter timing, paired bootstrap and RNG reproducibility.")
