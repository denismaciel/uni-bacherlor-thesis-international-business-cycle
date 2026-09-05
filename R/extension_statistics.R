pair_moments <- function(panel) {
  if (!identical(dim(panel$y), dim(panel$c)) || ncol(panel$y) != length(panel$countries)) {
    stop("Output and consumption dimensions differ")
  }
  if (any(!is.finite(panel$y)) || any(!is.finite(panel$c))) stop("Non-finite transformed data")
  if (any(apply(panel$y, 2, sd) == 0) || any(apply(panel$c, 2, sd) == 0)) stop("Zero-variance series")
  pairs <- utils::combn(seq_along(panel$countries), 2)
  indices <- cbind(pairs[1, ], pairs[2, ])
  output <- stats::cor(panel$y)[indices]
  consumption <- stats::cor(panel$c)[indices]
  data.frame(
    country_i = panel$countries[pairs[1, ]], country_j = panel$countries[pairs[2, ]],
    output_correlation = output, consumption_correlation = consumption,
    gap = output - consumption
  )
}

mean_moments <- function(panel) {
  pairs <- pair_moments(panel)
  c(output = mean(pairs$output_correlation), consumption = mean(pairs$consumption_correlation), gap = mean(pairs$gap))
}

circular_block_indices <- function(n, block_length) {
  if (block_length < 1L || block_length != as.integer(block_length) || block_length >= n) stop("Invalid block length")
  starts <- sample.int(n, ceiling(n / block_length), replace = TRUE)
  indices <- unlist(lapply(starts, function(start) ((start - 1L + seq_len(block_length) - 1L) %% n) + 1L))
  indices[seq_len(n)]
}

bootstrap_extension <- function(panel, repetitions = 1999L, block_length = 8L, seed = 20260905L, other = NULL) {
  if (repetitions < 99L || repetitions != as.integer(repetitions)) stop("Use at least 99 bootstrap replications")
  if (!is.null(other) && (!identical(panel$quarter, other$quarter) || !identical(panel$countries, other$countries))) {
    stop("Vintage comparison requires identical countries and dates")
  }
  if (nrow(panel$y) < max(40L, 4L * block_length)) stop("Window too short for selected bootstrap block")
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) old_seed <- get(".Random.seed", envir = .GlobalEnv)
  old_kind <- RNGkind()
  on.exit({
    do.call(RNGkind, as.list(old_kind))
    if (had_seed) assign(".Random.seed", old_seed, envir = .GlobalEnv) else rm(".Random.seed", envir = .GlobalEnv)
  })
  set.seed(seed, kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection")
  statistic <- function(sample) c(mean_moments(sample), pair_moments(sample)$gap)
  resample <- function(source, indices) {
    source$y <- source$y[indices, , drop = FALSE]
    source$c <- source$c[indices, , drop = FALSE]
    source
  }
  point <- statistic(panel)
  if (!is.null(other)) point <- point - statistic(other)
  draws <- replicate(repetitions, {
    indices <- circular_block_indices(nrow(panel$y), block_length)
    value <- statistic(resample(panel, indices))
    if (!is.null(other)) value <- value - statistic(resample(other, indices))
    value
  })
  limits <- t(apply(draws, 1, stats::quantile, probs = c(0.025, 0.975), names = FALSE))
  list(point = point, lower = limits[, 1], upper = limits[, 2], repetitions = repetitions,
       block_length = block_length, seed = seed)
}

summarize_extension <- function(panel, repetitions = 1999L, block_length = 8L, seed = 20260905L) {
  pairs <- pair_moments(panel)
  boot <- bootstrap_extension(panel, repetitions, block_length, seed)
  summary <- data.frame(
    start = quarter_text(min(panel$quarter)), end = quarter_text(max(panel$quarter)),
    quarters = length(panel$quarter), countries = length(panel$countries), pairs = nrow(pairs),
    output_correlation = boot$point[1], consumption_correlation = boot$point[2],
    gap = boot$point[3], gap_lower = boot$lower[3], gap_upper = boot$upper[3],
    positive_pairs = sum(pairs$gap > 0), median_gap = stats::median(pairs$gap),
    block_length = block_length, repetitions = repetitions, seed = seed, row.names = NULL
  )
  pairs$gap_lower <- boot$lower[-(1:3)]
  pairs$gap_upper <- boot$upper[-(1:3)]
  list(summary = summary, pairs = pairs)
}
