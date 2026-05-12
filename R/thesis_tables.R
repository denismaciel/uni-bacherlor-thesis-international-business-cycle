series_from_panel <- function(panel, variable_name) {
  panel %>%
    filter(.data[[VARIABLE_COL]] == .env$variable_name) %>%
    transmute(
      location = .data[[LOCATION_COL]],
      TIME = as.ordered(.data[[TIME_COL]]),
      Subject = .data[[SUBJECT_COL]],
      Value = value,
      filtered = .data[[FILTERED_COL]]
    ) %>%
    as.data.frame()
}

build_variable_results <- function(panel, employment_initial_timespan = NULL) {
  variable_results <- lapply(names(STD_DEV_COLUMNS), function(variable) {
    series <- series_from_panel(panel, variable)
    correlation <- cross_country_correlation(series)
    list(
      series = series,
      correlation = correlation,
      usa_correlation = usa_correlations(correlation),
      stdv = standard_deviation_by_country(series, output_col = STD_DEV_COLUMNS[[variable]]),
      timespan = timespan_by_country(series)
    )
  })
  names(variable_results) <- names(STD_DEV_COLUMNS)

  variable_results$employment$initial_timespan <- employment_initial_timespan
  variable_results
}

build_standard_deviations <- function(results) {
  standard_deviations <- data.frame(
    results$gdp$stdv,
    con_stdv = results$consumption$stdv$con_stdv,
    inv_stdv = results$investment$stdv$inv_stdv,
    gov_stdv = results$government$stdv$gov_stdv
  )
  standard_deviations <- merge(standard_deviations, results$net_exports$stdv, by = "country")
  standard_deviations <- merge(
    standard_deviations,
    merge(results$employment$stdv, results$solow_residuals$stdv),
    all = TRUE
  )
  colnames(standard_deviations) <- c("Country", "y", "c", "x", "g", "nx", "n", "z")
  standard_deviations[-1] <- standard_deviations[-1] * 100
  standard_deviations$c <- standard_deviations$c / standard_deviations$y
  standard_deviations$x <- standard_deviations$x / standard_deviations$y
  standard_deviations$g <- standard_deviations$g / standard_deviations$y
  standard_deviations$n <- standard_deviations$n / standard_deviations$y
  standard_deviations$z <- standard_deviations$z / standard_deviations$y
  standard_deviations[-1] <- round(standard_deviations[-1], 2)
  standard_deviations[, c("Country", "y", "nx", "c", "x", "g", "n", "z")]
}

build_timespan <- function(results) {
  timespan_without_country <- function(timespan) {
    timespan[c("Last Observation", "First Observation")]
  }

  timespan <- data.frame(
    results$gdp$timespan,
    timespan_without_country(results$consumption$timespan),
    timespan_without_country(results$investment$timespan),
    timespan_without_country(results$government$timespan),
    timespan_without_country(results$net_exports$timespan),
    check.names = FALSE
  )
  merge(timespan, results$employment$timespan, by = "Country", all = TRUE)
}

build_usa_correlation_matrix <- function(results) {
  usa_correlation_matrix <- data.frame(
    gdp = results$gdp$usa_correlation,
    consumption = results$consumption$usa_correlation,
    investment = results$investment$usa_correlation,
    government = results$government$usa_correlation,
    net_exports = results$net_exports$usa_correlation
  )
  employment_solow <- data.frame(
    employment = results$employment$usa_correlation,
    solow = results$solow_residuals$usa_correlation
  )
  merge(usa_correlation_matrix, employment_solow, by = 0, all = TRUE)
}

build_within_country_correlations <- function(results) {
  gdp <- results$gdp$series
  consumption <- results$consumption$series
  investment <- results$investment$series
  government <- results$government$series
  net_exports <- results$net_exports$series
  employment <- results$employment$series
  solow <- results$solow_residuals$series

  net_exports_x <- mutate(net_exports, Subject = "Net Exports")
  core_data <- bind_series_rows(
    gdp[c("location", "TIME", "Subject", "filtered")],
    consumption[c("location", "TIME", "Subject", "filtered")],
    investment[c("location", "TIME", "Subject", "filtered")],
    government[c("location", "TIME", "Subject", "filtered")],
    net_exports_x[c("location", "TIME", "Subject", "filtered")]
  )

  table5_subjects <- c(
    gdp = GDP_SUBJECT,
    cons = "Private final consumption expenditure",
    inv = "Gross fixed capital formation",
    gov = "General government final consumption expenditure",
    net = "Net Exports"
  )

  core_rows <- lapply(unique(core_data$location), function(country) {
    country_gdp <- gdp[gdp$location == country,]$filtered
    autocorrelation <- round(cor(country_gdp, lag(country_gdp, 1), use = "pairwise.complete"), 2)
    country_data <- core_data[core_data$location == country,]
    wide_data <- pivot_wider(country_data, names_from = Subject, values_from = filtered) %>%
      select(-TIME, -location)
    correlations <- round(cor(wide_data, use = "pairwise.complete.obs"), 2)
    correlation_values <- as.list(as.character(correlations[GDP_SUBJECT, table5_subjects]))
    names(correlation_values) <- names(table5_subjects)
    data.frame(
      Country = as.character(country),
      Autorcorrelation = as.character(autocorrelation),
      correlation_values,
      check.names = FALSE
    )
  })
  core_with_gdp_correlations <- bind_rows(core_rows)

  employment_x <- mutate(employment, Subject = "civilian employment")
  solow_x <- mutate(solow, Subject = "Solow Residulas")
  gdp_x <- gdp[gdp$location != "CHE" & gdp$location != "EU15",]
  labor_data <- bind_series_rows(
    gdp_x[c("location", "TIME", "Subject", "filtered")],
    employment_x[c("location", "TIME", "Subject", "filtered")],
    solow_x[c("location", "TIME", "Subject", "filtered")]
  )
  table5_labor_subjects <- c(
    gdp = GDP_SUBJECT,
    emp = "civilian employment",
    sol = "Solow Residulas"
  )
  labor_rows <- lapply(unique(labor_data$location), function(country) {
    country_data <- labor_data[labor_data$location == country,]
    wide_data <- pivot_wider(country_data, names_from = Subject, values_from = filtered) %>%
      select(-TIME, -location)
    correlations <- round(cor(wide_data, use = "pairwise.complete.obs"), 2)
    data.frame(
      Country = as.character(country),
      emp = as.character(correlations[GDP_SUBJECT, table5_labor_subjects[["emp"]]]),
      sol = as.character(correlations[GDP_SUBJECT, table5_labor_subjects[["sol"]]]),
      check.names = FALSE
    )
  })
  within_country_labor_correlations <- bind_rows(labor_rows)

  merge(core_with_gdp_correlations, within_country_labor_correlations, by = "Country", all = TRUE)
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
      z = summarize_cross_country_correlations(results$solow_residuals$correlation, results$solow_residuals$usa_correlation)
    )
  )
  average_cross_country_correlations
}
