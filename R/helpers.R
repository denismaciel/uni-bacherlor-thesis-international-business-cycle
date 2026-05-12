HP_FILTER_LAMBDA <- 1600
CAPITAL_SHARE <- 0.36
GDP_SUBJECT <- "Gross domestic product - expenditure approach"
LOCATION_COL <- "location"
OECD_LOCATION_COL <- "LOCATION"
TIME_COL <- "TIME"
VALUE_COL <- "Value"
FILTERED_COL <- "filtered"

normalize_oecd_location <- function(data) {
  if (OECD_LOCATION_COL %in% names(data)) {
    data <- rename(data, !!LOCATION_COL := all_of(OECD_LOCATION_COL))
  }
  data
}

bind_series_rows <- function(...) {
  parts <- lapply(list(...), function(part) {
    part[[TIME_COL]] <- as.character(part[[TIME_COL]])
    part
  })
  result <- bind_rows(parts)
  result[[TIME_COL]] <- as.ordered(result[[TIME_COL]])
  result
}

apply_hp_filter_by_country <- function(data, value_col = "Value", country_col = "location", lambda = HP_FILTER_LAMBDA) {
  filtered <- c()

  for (country in unique(data[[country_col]])) {
    country_values <- data[data[[country_col]] == country, value_col]
    hp_filter <- hpfilter(country_values, type = "lambda", freq = lambda)
    filtered <- append(filtered, hp_filter$cycle)
  }

  data$filtered <- filtered
  data
}

cross_country_correlation <- function(data, value_col = FILTERED_COL) {
  panel <- subset(data, select = c(LOCATION_COL, TIME_COL, value_col))
  panel <- rename(panel, value = all_of(value_col))

  correlation_matrix <- panel %>%
    pivot_wider(names_from = all_of(LOCATION_COL), values_from = value, names_sort = TRUE) %>%
    select(-all_of(TIME_COL)) %>%
    cor(., use = "pairwise.complete.obs")

  round(correlation_matrix, 3)
}

usa_correlations <- function(correlation_matrix) {
  correlation_matrix["USA",]
}

standard_deviation_by_country <- function(data, value_col = FILTERED_COL, output_col = "stdv") {
  rows <- lapply(unique(data[[LOCATION_COL]]), function(country) {
    data.frame(
      country = country,
      value = sd(data[data[[LOCATION_COL]] == country, value_col]),
      stringsAsFactors = FALSE
    )
  })

  result <- do.call(rbind, rows)
  result <- rename(result, !!output_col := value)
  result
}

timespan_by_country <- function(data, country_col = "location") {
  rows <- lapply(unique(data[[country_col]]), function(country) {
    country_data <- data[data[[country_col]] == country,]
    data.frame(
      Country = as.character(country),
      `Last Observation` = as.character(max(country_data$TIME)),
      `First Observation` = as.character(min(country_data$TIME)),
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, rows)
}

process_standard_variable <- function(raw_data, stdv_col) {
  data <- normalize_oecd_location(raw_data)
  data[[VALUE_COL]] <- log(data[[VALUE_COL]])
  data[[TIME_COL]] <- as.ordered(data[[TIME_COL]])
  data <- apply_hp_filter_by_country(data)

  list(
    series = data,
    correlation = cross_country_correlation(data),
    usa_correlation = usa_correlations(cross_country_correlation(data)),
    stdv = standard_deviation_by_country(data, output_col = stdv_col),
    timespan = timespan_by_country(data)
  )
}

summarize_cross_country_correlations <- function(correlation_matrix, usa_correlation) {
  probabilities <- c(0.0, 0.1, 0.25, 0.4, 0.5, 0.6, 0.75, 0.9, 1.0)

  upper_triangle <- correlation_matrix
  upper_triangle[lower.tri(upper_triangle)] <- NA
  diag(upper_triangle) <- NA

  values <- as.vector(upper_triangle)
  values <- values[order(values)]
  values <- values[!is.na(values)]

  usa_entries <- names(usa_correlation) %in% c("USA")
  c(
    Mean = mean(values),
    `USA Mean` = mean(usa_correlation[!usa_entries]),
    quantile(values, prob = probabilities, type = 1)
  )
}
