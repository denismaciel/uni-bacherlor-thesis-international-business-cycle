series_from_panel <- function(panel, variable_name) {
  panel |>
    filter(.data[[variable_col]] == .env$variable_name) |>
    transmute(
      location = .data[[location_col]],
      time = as.ordered(.data[[time_col]]),
      subject = .data[[subject_col]],
      value = value,
      filtered = .data[[filtered_col]]
    )
}

build_variable_results <- function(panel, employment_initial_timespan = NULL) {
  variable_results <- lapply(names(std_dev_columns), function(variable) {
    series <- series_from_panel(panel, variable)
    correlation <- cross_country_correlation(series)
    list(
      series = series,
      correlation = correlation,
      usa_correlation = usa_correlations(correlation),
      stdv = standard_deviation_by_country(series, output_col = std_dev_columns[[variable]]),
      timespan = timespan_by_country(series)
    )
  })
  names(variable_results) <- names(std_dev_columns)

  variable_results$employment$initial_timespan <- employment_initial_timespan
  variable_results
}

build_standard_deviations <- function(results) {
  standard_deviations <- tibble::tibble(
    results$gdp$stdv,
    con_stdv = results$consumption$stdv$con_stdv,
    inv_stdv = results$investment$stdv$inv_stdv,
    gov_stdv = results$government$stdv$gov_stdv
  )
  employment_solow <- full_join(
    results$employment$stdv,
    results$solow_residuals$stdv,
    by = "country"
  )
  standard_deviations <- standard_deviations |>
    full_join(results$net_exports$stdv, by = "country") |>
    full_join(employment_solow, by = "country") |>
    arrange(country)
  colnames(standard_deviations) <- c("country", "y", "c", "x", "g", "nx", "n", "z")
  standard_deviations[-1] <- standard_deviations[-1] * 100
  standard_deviations$c <- standard_deviations$c / standard_deviations$y
  standard_deviations$x <- standard_deviations$x / standard_deviations$y
  standard_deviations$g <- standard_deviations$g / standard_deviations$y
  standard_deviations$n <- standard_deviations$n / standard_deviations$y
  standard_deviations$z <- standard_deviations$z / standard_deviations$y
  standard_deviations[-1] <- round(standard_deviations[-1], 2)
  standard_deviations[, c("country", "y", "nx", "c", "x", "g", "n", "z")]
}

build_timespan <- function(results) {
  prefixed_timespan <- function(timespan, prefix) {
    timespan |>
      rename(
        !!paste0(prefix, "_last") := last_observation,
        !!paste0(prefix, "_first") := first_observation
      )
  }

  prefixed_timespan(results$gdp$timespan, "gdp") |>
    full_join(prefixed_timespan(results$consumption$timespan, "consumption"), by = "country") |>
    full_join(prefixed_timespan(results$investment$timespan, "investment"), by = "country") |>
    full_join(prefixed_timespan(results$government$timespan, "government"), by = "country") |>
    full_join(prefixed_timespan(results$net_exports$timespan, "net_exports"), by = "country") |>
    full_join(prefixed_timespan(results$employment$timespan, "employment"), by = "country") |>
    arrange(country)
}

build_usa_correlation_matrix <- function(results) {
  usa_correlation_matrix <- tibble::tibble(
    country = names(results$gdp$usa_correlation),
    gdp = as.numeric(results$gdp$usa_correlation),
    consumption = as.numeric(results$consumption$usa_correlation),
    investment = as.numeric(results$investment$usa_correlation),
    government = as.numeric(results$government$usa_correlation),
    net_exports = as.numeric(results$net_exports$usa_correlation)
  )
  employment_solow <- tibble::tibble(
    country = names(results$employment$usa_correlation),
    employment = as.numeric(results$employment$usa_correlation),
    solow = as.numeric(results$solow_residuals$usa_correlation)
  )
  full_join(usa_correlation_matrix, employment_solow, by = "country")
}

build_within_country_correlations <- function(results) {
  gdp <- results$gdp$series
  consumption <- results$consumption$series
  investment <- results$investment$series
  government <- results$government$series
  net_exports <- results$net_exports$series
  employment <- results$employment$series
  solow <- results$solow_residuals$series

  net_exports_x <- mutate(net_exports, subject = "net_exports")
  core_data <- bind_series_rows(
    gdp[c("location", "time", "subject", "filtered")],
    consumption[c("location", "time", "subject", "filtered")],
    investment[c("location", "time", "subject", "filtered")],
    government[c("location", "time", "subject", "filtered")],
    net_exports_x[c("location", "time", "subject", "filtered")]
  )

  table5_subjects <- c(
    gdp = gdp_subject,
    cons = "Private final consumption expenditure",
    inv = "Gross fixed capital formation",
    gov = "General government final consumption expenditure",
    net = "net_exports"
  )

  core_rows <- lapply(unique(core_data$location), function(country) {
    country_gdp <- gdp[gdp$location == country, ]$filtered
    autocorrelation <- round(cor(country_gdp, lag(country_gdp, 1), use = "pairwise.complete"), 2)
    country_data <- core_data[core_data$location == country, ]
    wide_data <- pivot_wider(country_data, names_from = subject, values_from = filtered) |>
      select(-time, -location)
    correlations <- round(cor(wide_data, use = "pairwise.complete.obs"), 2)
    correlation_values <- as.list(as.character(correlations[gdp_subject, table5_subjects]))
    names(correlation_values) <- names(table5_subjects)
    tibble::tibble(
      country = as.character(country),
      autocorrelation = as.character(autocorrelation),
      !!!correlation_values
    )
  })
  core_with_gdp_correlations <- bind_rows(core_rows)

  employment_x <- mutate(employment, subject = "employment")
  solow_x <- mutate(solow, subject = "solow_residuals")
  gdp_x <- gdp[gdp$location != "CHE" & gdp$location != "EU15", ]
  labor_data <- bind_series_rows(
    gdp_x[c("location", "time", "subject", "filtered")],
    employment_x[c("location", "time", "subject", "filtered")],
    solow_x[c("location", "time", "subject", "filtered")]
  )
  table5_labor_subjects <- c(
    gdp = gdp_subject,
    emp = "employment",
    sol = "solow_residuals"
  )
  labor_rows <- lapply(unique(labor_data$location), function(country) {
    country_data <- labor_data[labor_data$location == country, ]
    wide_data <- pivot_wider(country_data, names_from = subject, values_from = filtered) |>
      select(-time, -location)
    correlations <- round(cor(wide_data, use = "pairwise.complete.obs"), 2)
    tibble::tibble(
      country = as.character(country),
      emp = as.character(correlations[gdp_subject, table5_labor_subjects[["emp"]]]),
      sol = as.character(correlations[gdp_subject, table5_labor_subjects[["sol"]]])
    )
  })
  within_country_labor_correlations <- bind_rows(labor_rows)

  full_join(core_with_gdp_correlations, within_country_labor_correlations, by = "country") |>
    arrange(country)
}

build_average_cross_country_correlations <- function(results) {
  average_cross_country_correlations <- do.call(
    rbind,
    list(
      y = summarize_cross_country_correlations(results$gdp$correlation, results$gdp$usa_correlation),
      c = summarize_cross_country_correlations(results$consumption$correlation, results$consumption$usa_correlation),
      x = summarize_cross_country_correlations(results$investment$correlation, results$investment$usa_correlation),
      g = summarize_cross_country_correlations(results$government$correlation, results$government$usa_correlation),
      nx = summarize_cross_country_correlations(results$net_exports$correlation, results$net_exports$usa_correlation),
      n = summarize_cross_country_correlations(results$employment$correlation, results$employment$usa_correlation),
      z = summarize_cross_country_correlations(
        results$solow_residuals$correlation,
        results$solow_residuals$usa_correlation
      )
    )
  )
  average_cross_country_correlations
}
