HP_FILTER_LAMBDA <- 1600
CAPITAL_SHARE <- 0.36
GDP_SUBJECT <- "Gross domestic product - expenditure approach"

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

cross_country_correlation <- function(data, value_col = "filtered") {
  panel <- subset(data, select = c("location", "TIME", value_col))
  names(panel)[names(panel) == value_col] <- "value"

  correlation_matrix <- panel %>%
    pivot_wider(names_from = location, values_from = value, names_sort = TRUE) %>%
    select(-TIME) %>%
    cor(., use = "pairwise.complete.obs")

  round(correlation_matrix, 3)
}

usa_correlations <- function(correlation_matrix) {
  correlation_matrix["USA",]
}

standard_deviation_by_country <- function(data, value_col = "filtered", output_col = "stdv") {
  rows <- lapply(unique(data$location), function(country) {
    data.frame(
      country = country,
      value = sd(data[data$location == country, value_col]),
      stringsAsFactors = FALSE
    )
  })

  result <- do.call(rbind, rows)
  names(result)[2] <- output_col
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
  data <- raw_data
  colnames(data)[1] <- "location"
  data$Value <- log(data$Value)
  data$TIME <- as.ordered(data$TIME)
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
  c(mean(values), mean(usa_correlation[!usa_entries]), quantile(values, prob = probabilities, type = 1))
}
