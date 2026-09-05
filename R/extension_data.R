# Separate empirical extension: the submitted-thesis pipeline is unchanged.
extension_countries <- c("AUS", "AUT", "CAN", "CHE", "DEU", "FRA", "GBR", "ITA", "JPN", "USA")
extension_snapshot <- "2026-09-05T221752Z"

quarter_number <- function(period) {
  if (anyNA(period) || any(!grepl("^[0-9]{4}-Q[1-4]$", period))) {
    stop("Invalid quarterly dates")
  }
  as.integer(substr(period, 1, 4)) * 4L + as.integer(substr(period, 7, 7)) - 1L
}

quarter_text <- function(number) {
  paste0(number %/% 4L, "-Q", number %% 4L + 1L)
}

validate_extension_panel <- function(panel, countries = extension_countries) {
  required <- c("location", "time", "variable", "value")
  if (!all(required %in% names(panel))) stop("Missing panel columns")
  panel <- panel[panel$location %in% countries & panel$variable %in% c("gdp", "consumption"), ]
  if (anyNA(panel[required]) || any(!is.finite(panel$value)) || any(panel$value <= 0)) {
    stop("Missing, non-finite or non-positive levels")
  }
  panel$quarter <- quarter_number(panel$time)
  keys <- paste(panel$location, panel$variable, panel$quarter)
  if (anyDuplicated(keys)) stop("Duplicate country-variable-quarter observations")
  expected <- as.vector(outer(countries, c("gdp", "consumption"), paste))
  groups <- split(panel, paste(panel$location, panel$variable))
  if (!setequal(names(groups), expected)) stop("Missing country-variable series")
  for (group in groups) {
    dates <- sort(group$quarter)
    if (any(diff(dates) != 1L)) stop("Internal missing quarter: ", group$location[1], "/", group$variable[1])
  }
  panel[order(panel$location, panel$variable, panel$quarter), ]
}

read_current_extension <- function(snapshot = extension_snapshot) {
  path <- file.path("data/processed/oecd", snapshot, "panel.csv")
  panel <- read.csv(path, stringsAsFactors = FALSE)
  core <- panel[panel$variable %in% c("gdp", "consumption"), ]
  checks <- c(unit_measure = "XDC", price_base = "L", adjustment = "Y", transformation = "N")
  for (field in names(checks)) {
    if (anyNA(core[[field]]) || any(core[[field]] != checks[[field]])) stop("Unexpected measurement: ", field)
  }
  for (group in split(core, paste(core$location, core$variable))) {
    for (field in c("currency", "unit_mult", "reference_year", "series_key")) {
      if (anyNA(group[[field]]) || length(unique(group[[field]])) != 1L) stop("Measurement varies: ", field)
    }
  }
  validate_extension_panel(core)
}

read_original_extension <- function() {
  panels <- lapply(c("gdp", "consumption"), function(variable) {
    raw <- read.csv(file.path("data/raw/oecd", paste0(variable, ".csv")), fileEncoding = "UTF-8-BOM")
    if (any(raw$MEASURE != "VPVOBARSA") || any(raw$FREQUENCY != "Q")) stop("Unexpected original measure")
    data.frame(location = raw$LOCATION, time = raw$TIME, variable = variable, value = raw$Value)
  })
  validate_extension_panel(do.call(rbind, panels))
}

balanced_extension <- function(panel, start = NULL, end = NULL, countries = extension_countries) {
  panel <- validate_extension_panel(panel, countries)
  groups <- split(panel$quarter, paste(panel$location, panel$variable))
  available_start <- max(vapply(groups, min, numeric(1)))
  available_end <- min(vapply(groups, max, numeric(1)))
  first <- if (is.null(start)) available_start else quarter_number(start)
  last <- if (is.null(end)) available_end else quarter_number(end)
  if (first < available_start || last > available_end || first > last) stop("Requested window outside balanced coverage")
  quarters <- seq.int(first, last)
  countries <- sort(countries)
  matrices <- lapply(c("gdp", "consumption"), function(variable) {
    values <- vapply(countries, function(country) {
      series <- panel[panel$location == country & panel$variable == variable, ]
      series$value[match(quarters, series$quarter)]
    }, numeric(length(quarters)))
    if (anyNA(values)) stop("Unbalanced panel")
    log(values)
  })
  list(quarter = quarters, countries = countries, y = matrices[[1]], c = matrices[[2]])
}

transform_extension <- function(levels, method) {
  transform_one <- function(values) {
    if (method == "hp1600") return(as.numeric(mFilter::hpfilter(values, freq = 1600, type = "lambda")$cycle))
    if (method == "growth") return(c(NA_real_, diff(values)))
    if (method != "hamilton") stop("Unknown transformation")
    # x[t] = intercept + b0*x[t-8] + ... + b3*x[t-11] + residual[t].
    if (length(values) < 20L) stop("Insufficient Hamilton history")
    targets <- seq.int(12L, length(values))
    design <- cbind(1, vapply(8:11, function(lag) values[targets - lag], numeric(length(targets))))
    fit <- stats::lm.fit(design, values[targets])
    if (fit$rank < ncol(design)) stop("Rank-deficient Hamilton regression")
    c(rep(NA_real_, 11L), fit$residuals)
  }
  result <- levels
  result$y <- apply(levels$y, 2, transform_one)
  result$c <- apply(levels$c, 2, transform_one)
  result
}

slice_extension <- function(panel, first, last) {
  keep <- panel$quarter >= first & panel$quarter <= last
  if (sum(keep) < 3L) stop("Insufficient observations")
  result <- panel
  result$quarter <- panel$quarter[keep]
  result$y <- panel$y[keep, , drop = FALSE]
  result$c <- panel$c[keep, , drop = FALSE]
  if (any(!is.finite(result$y)) || any(!is.finite(result$c))) stop("Incomplete transformed window")
  result
}

extension_window <- function(levels, method, first, last, context_end = last) {
  # Truncate before estimating filters: no observations after the period endpoint.
  context <- slice_extension(levels, min(levels$quarter), context_end)
  slice_extension(transform_extension(context, method), first, last)
}
