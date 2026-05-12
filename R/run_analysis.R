source("R/helpers.R")

load_raw_data <- function(data_dir = "data/raw") {
  read_data <- function(path) {
    as.data.frame(read_csv(path, show_col_types = FALSE))
  }

  list(
    gdp = read_data(file.path(data_dir, "oecd/gdp.csv")),
    consumption = read_data(file.path(data_dir, "oecd/consumption.csv")),
    investment = read_data(file.path(data_dir, "oecd/investment.csv")),
    government = read_data(file.path(data_dir, "oecd/government.csv")),
    net_exports = read_data(file.path(data_dir, "oecd/net_exports.csv")),
    employment = read_data(file.path(data_dir, "oecd/employment.csv")),
    fred_employment = list(
      gbr = read_data(file.path(data_dir, "fred/gbr_employment.csv")),
      ita = read_data(file.path(data_dir, "fred/ita_employment.csv")),
      fra = read_data(file.path(data_dir, "fred/fra_employment.csv"))
    )
  )
}

process_net_exports <- function(raw_net_exports, gdp_series) {
  net <- normalize_oecd_location(raw_net_exports)
  net[[TIME_COL]] <- as.ordered(net[[TIME_COL]])

  exports <- net[net$Subject == "Exports of goods and services",]
  imports <- net[net$Subject == "Imports of goods and services",]
  gdp_current_prices <- net[net$Subject == GDP_SUBJECT,]

  exports$`Net Exports` <- exports[[VALUE_COL]] - imports[[VALUE_COL]]
  net_exports <- subset(exports, select = c(LOCATION_COL, TIME_COL, "Net Exports"))
  gdp <- subset(gdp_current_prices, select = c(LOCATION_COL, TIME_COL, VALUE_COL))
  names(gdp)[names(gdp) == VALUE_COL] <- "GDP"

  net <- merge(net_exports, gdp, by = c(LOCATION_COL, TIME_COL), all = TRUE)
  net[[VALUE_COL]] <- net$`Net Exports` / net$GDP
  net <- apply_hp_filter_by_country(net)

  list(
    series = net,
    correlation = cross_country_correlation(net),
    usa_correlation = usa_correlations(cross_country_correlation(net)),
    stdv = standard_deviation_by_country(net, output_col = "net_stdv"),
    timespan = timespan_by_country(net)
  )
}

format_fred_quarters <- function(data) {
  data[[TIME_COL]] <- as.yearqtr(data[[TIME_COL]], format = "%Y-%m-%d")
  data[[TIME_COL]] <- as.character(data[[TIME_COL]])
  substr(data[[TIME_COL]], 5, 5) <- "-"
  data[[TIME_COL]] <- as.ordered(data[[TIME_COL]])
  data
}

splice_employment_series <- function(splice, country, switch_time, end_time) {
  splice <- splice[splice[[TIME_COL]] <= end_time,]
  splice[[LOCATION_COL]] <- country

  switch_row <- splice[splice[[TIME_COL]] == switch_time,]
  splice_factor <- switch_row$fred_value / switch_row$oecd_value
  splice$oecd_value <- splice_factor * splice$oecd_value
  splice[[VALUE_COL]] <- ifelse(
    splice[[TIME_COL]] <= switch_time,
    splice$fred_value,
    splice$oecd_value
  )

  splice[c(LOCATION_COL, TIME_COL, VALUE_COL)]
}

process_employment <- function(raw_employment, fred_employment, output_figures = FALSE) {
  emp <- normalize_oecd_location(raw_employment)
  emp <- emp[emp$SUBJECT == "LFEMTTTT",]
  emp[[TIME_COL]] <- as.ordered(emp[[TIME_COL]])

  emp_timespan_initial <- timespan_by_country(emp)

  gbr_emp_fred <- fred_employment$gbr
  names(gbr_emp_fred) <- c(TIME_COL, VALUE_COL)
  gbr_emp_oecd <- emp[emp$location == "GBR", c(LOCATION_COL, TIME_COL, VALUE_COL)]
  gbr_emp_fred <- format_fred_quarters(gbr_emp_fred)
  gbr_employment_splice <- merge(gbr_emp_fred, gbr_emp_oecd, by = TIME_COL, all = TRUE)
  names(gbr_employment_splice)[names(gbr_employment_splice) == "Value.x"] <- "fred_value"
  names(gbr_employment_splice)[names(gbr_employment_splice) == "Value.y"] <- "oecd_value"
  gbr_emp_def <- splice_employment_series(gbr_employment_splice, "GBR", "2011-Q4", "2015-Q1")

  ita_emp_fred <- fred_employment$ita
  names(ita_emp_fred) <- c(TIME_COL, VALUE_COL)
  ita_emp_oecd <- emp[emp$location == "ITA", c(LOCATION_COL, TIME_COL, VALUE_COL)]
  ita_emp_fred <- format_fred_quarters(ita_emp_fred)
  ita_employment_splice <- merge(ita_emp_fred, ita_emp_oecd, by = TIME_COL, all = TRUE)
  names(ita_employment_splice)[names(ita_employment_splice) == "Value.x"] <- "fred_value"
  names(ita_employment_splice)[names(ita_employment_splice) == "Value.y"] <- "oecd_value"
  ita_emp_def <- splice_employment_series(ita_employment_splice, "ITA", "2011-Q4", "2015-Q1")

  fra_emp_fred <- fred_employment$fra
  names(fra_emp_fred) <- c(TIME_COL, VALUE_COL)
  fra_emp_oecd <- emp[emp$location == "FRA", c(LOCATION_COL, TIME_COL, VALUE_COL)]
  fra_reference_value <- fra_emp_oecd[fra_emp_oecd$TIME == "2005-Q2",]$Value
  fra_emp_fred$Value <- fra_emp_fred$Value * fra_reference_value / 100
  fra_emp_fred <- format_fred_quarters(fra_emp_fred)
  fra_employment_splice <- merge(fra_emp_fred, fra_emp_oecd, by = TIME_COL, all = TRUE)
  names(fra_employment_splice)[names(fra_employment_splice) == "Value.x"] <- "fred_value"
  names(fra_employment_splice)[names(fra_employment_splice) == "Value.y"] <- "oecd_value"
  fra_emp_def <- splice_employment_series(fra_employment_splice, "FRA", "2011-Q4", "2015-Q1")
  fra_emp_def <- head(fra_emp_def, -5)

  emp_base <- subset(
    emp,
    emp$location != "GBR" & emp$location != "FRA" & emp$location != "ITA" &
      emp$location != "CHE" & emp$location != "EA19",
    select = c("location", "TIME", "Value")
  )

  emp <- rbind(emp_base, gbr_emp_def, ita_emp_def, fra_emp_def)
  emp_timespan <- timespan_by_country(emp)
  emp$Value <- log(emp$Value)
  emp <- apply_hp_filter_by_country(emp)

  list(
    series = emp,
    correlation = cross_country_correlation(emp),
    usa_correlation = usa_correlations(cross_country_correlation(emp)),
    stdv = standard_deviation_by_country(emp, output_col = "emp_stdv"),
    timespan = emp_timespan,
    initial_timespan = emp_timespan_initial
  )
}

process_solow_residuals <- function(gdp_series, employment_series, capital_share = CAPITAL_SHARE) {
  gdp <- subset(gdp_series, select = c(LOCATION_COL, TIME_COL, VALUE_COL))
  emp <- subset(employment_series, select = c(LOCATION_COL, TIME_COL, VALUE_COL))
  sol <- merge(gdp, emp, by = c(LOCATION_COL, TIME_COL))
  names(sol)[names(sol) == "Value.x"] <- "gdp"
  names(sol)[names(sol) == "Value.y"] <- "labor"
  sol$Value <- sol$gdp - (1 - capital_share) * sol$labor
  sol <- apply_hp_filter_by_country(sol)

  list(
    series = sol,
    correlation = cross_country_correlation(sol),
    usa_correlation = usa_correlations(cross_country_correlation(sol)),
    stdv = standard_deviation_by_country(sol, output_col = "sol_stdv")
  )
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

  net_exports_x <- cbind(net_exports, rep("Net Exports", nrow(net_exports)))
  colnames(net_exports_x)[ncol(net_exports_x)] <- "Subject"
  core_data <- rbind(
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
    c(as.character(country), autocorrelation, correlations[GDP_SUBJECT, table5_subjects])
  })
  core_with_gdp_correlations <- do.call(rbind, core_rows)
  colnames(core_with_gdp_correlations)[1:2] <- c("Country", "Autorcorrelation")
  colnames(core_with_gdp_correlations)[3:ncol(core_with_gdp_correlations)] <- names(table5_subjects)

  employment_x <- cbind(employment, rep("civilian employment", nrow(employment)))
  colnames(employment_x)[ncol(employment_x)] <- "Subject"
  solow_x <- cbind(solow, rep("Solow Residulas", nrow(solow)))
  colnames(solow_x)[ncol(solow_x)] <- "Subject"
  gdp_x <- gdp[gdp$location != "CHE" & gdp$location != "EU15",]
  labor_data <- rbind(
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
    c(as.character(country), correlations[GDP_SUBJECT, table5_labor_subjects])
  })
  within_country_labor_correlations <- do.call(rbind, labor_rows)
  within_country_labor_correlations <- within_country_labor_correlations[, -2]
  colnames(within_country_labor_correlations)[1] <- "Country"
  colnames(within_country_labor_correlations)[2:ncol(within_country_labor_correlations)] <- c("emp", "sol")

  merge(core_with_gdp_correlations, within_country_labor_correlations, by = "Country", all = TRUE)
}

build_average_cross_country_correlations <- function(results) {
  average_cross_country_correlations <- rbind(
    summarize_cross_country_correlations(results$gdp$correlation, results$gdp$usa_correlation),
    summarize_cross_country_correlations(results$consumption$correlation, results$consumption$usa_correlation),
    summarize_cross_country_correlations(results$investment$correlation, results$investment$usa_correlation),
    summarize_cross_country_correlations(results$government$correlation, results$government$usa_correlation),
    summarize_cross_country_correlations(results$net_exports$correlation, results$net_exports$usa_correlation),
    summarize_cross_country_correlations(results$employment$correlation, results$employment$usa_correlation),
    summarize_cross_country_correlations(results$solow_residuals$correlation, results$solow_residuals$usa_correlation)
  )
  colnames(average_cross_country_correlations)[1:2] <- c("Mean", "USA Mean")
  rownames(average_cross_country_correlations) <- c("y", "c", "x", "g", "nx", "n", "z")
  average_cross_country_correlations
}

run_analysis <- function(data_dir = "data/raw", output_figures = FALSE) {
  raw_data <- load_raw_data(data_dir)

  variable_results <- list(
    gdp = process_standard_variable(raw_data$gdp, "gdp_stdv"),
    consumption = process_standard_variable(raw_data$consumption, "con_stdv"),
    investment = process_standard_variable(raw_data$investment, "inv_stdv"),
    government = process_standard_variable(raw_data$government, "gov_stdv")
  )
  variable_results$net_exports <- process_net_exports(raw_data$net_exports, variable_results$gdp$series)
  variable_results$employment <- process_employment(raw_data$employment, raw_data$fred_employment, output_figures)
  variable_results$solow_residuals <- process_solow_residuals(
    variable_results$gdp$series,
    variable_results$employment$series
  )

  tables <- list(
    timespan = build_timespan(variable_results),
    standard_deviations = build_standard_deviations(variable_results),
    within_country_correlations = build_within_country_correlations(variable_results),
    usa_correlation_matrix = build_usa_correlation_matrix(variable_results),
    average_cross_country_correlations = build_average_cross_country_correlations(variable_results)
  )

  list(
    tables = tables,
    series = lapply(variable_results, `[[`, "series"),
    correlations = lapply(variable_results, `[[`, "correlation"),
    variable_results = variable_results
  )
}
