source("R/helpers.R")

load_raw_data <- function(data_dir = "data/raw") {
  list(
    gdp = read.csv(file.path(data_dir, "oecd/gdp.csv")),
    consumption = read.csv(file.path(data_dir, "oecd/consumption.csv")),
    investment = read.csv(file.path(data_dir, "oecd/investment.csv")),
    government = read.csv(file.path(data_dir, "oecd/government.csv")),
    net_exports = read.csv(file.path(data_dir, "oecd/net_exports.csv")),
    employment = read.csv(file.path(data_dir, "oecd/employment.csv")),
    fred_employment = list(
      gbr = read.csv(file.path(data_dir, "fred/gbr_employment.csv")),
      ita = read.csv(file.path(data_dir, "fred/ita_employment.csv")),
      fra = read.csv(file.path(data_dir, "fred/fra_employment.csv"))
    )
  )
}

process_net_exports <- function(raw_net_exports, gdp_series) {
  net <- raw_net_exports
  colnames(net)[1] <- "location"
  net$TIME <- as.ordered(net$TIME)

  exports <- net[net$Subject == "Exports of goods and services",]
  imports <- net[net$Subject == "Imports of goods and services",]
  gdp_current_prices <- net[net$Subject == GDP_SUBJECT,]

  net <- cbind(exports, exports$Value - imports$Value)
  colnames(net)[ncol(net)] <- "Net Exports"

  net_exports <- subset(net, select = c("location", "TIME", "Net Exports"))
  gdp <- subset(gdp_current_prices, select = c("location", "TIME", "Value"))
  colnames(gdp)[3] <- "GDP"

  net <- merge(net_exports, gdp, by = c("location", "TIME"), all = TRUE)
  net <- cbind(net, net$Net / net$GDP)
  colnames(net)[ncol(net)] <- "Value"
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
  data$TIME <- as.yearqtr(data$TIME, format = "%Y-%m-%d")
  data$TIME <- as.character(data$TIME)
  substr(data$TIME, 5, 5) <- "-"
  data$TIME <- as.ordered(data$TIME)
  data
}

process_employment <- function(raw_employment, fred_employment, output_figures = FALSE) {
  emp <- raw_employment
  emp <- emp[emp$SUBJECT == "LFEMTTTT",]
  colnames(emp)[1] <- "location"
  emp$TIME <- as.ordered(emp$TIME)

  emp_timespan_initial <- timespan_by_country(emp)

  gbr_emp_fred <- fred_employment$gbr
  colnames(gbr_emp_fred) <- c("TIME", "Value")
  gbr_emp_oecd <- emp[emp$location == "GBR", c("location", "TIME", "Value")]
  gbr_emp_fred <- format_fred_quarters(gbr_emp_fred)
  gbr_employment_splice <- merge(gbr_emp_fred, gbr_emp_oecd, by = c("TIME"), all = TRUE)
  gbr_employment_splice$location <- "GBR"
  gbr_employment_factor <- gbr_employment_splice[171, 2] / gbr_employment_splice[171, 4]
  gbr_employment_splice[,4] <- gbr_employment_factor * gbr_employment_splice[,4]
  gbr_employment_splice$Value <- c(gbr_employment_splice[1:171,2], gbr_employment_splice[172:184,4])
  gbr_emp_def <- gbr_employment_splice[c("location", "TIME", "Value")]

  ita_emp_fred <- fred_employment$ita
  colnames(ita_emp_fred) <- c("TIME", "Value")
  ita_emp_oecd <- emp[emp$location == "ITA", c("location", "TIME", "Value")]
  ita_emp_fred <- format_fred_quarters(ita_emp_fred)
  ita_employment_splice <- merge(ita_emp_fred, ita_emp_oecd, by = c("TIME"), all = TRUE)
  ita_employment_splice$location <- "ITA"
  ita_employment_factor <- ita_employment_splice[212, 2] / ita_employment_splice[212, 4]
  ita_employment_splice[,4] <- ita_employment_factor * ita_employment_splice[,4]
  ita_employment_splice$Value <- c(ita_employment_splice[1:212,2], ita_employment_splice[213:225,4])
  ita_emp_def <- ita_employment_splice[c("location", "TIME", "Value")]

  fra_emp_fred <- fred_employment$fra
  colnames(fra_emp_fred) <- c("TIME", "Value")
  fra_emp_oecd <- emp[emp$location == "FRA", c("location", "TIME", "Value")]
  fra_reference_value <- fra_emp_oecd[fra_emp_oecd$TIME == "2005-Q2",]$Value
  fra_emp_fred$Value <- fra_emp_fred$Value * fra_reference_value / 100
  fra_emp_fred <- format_fred_quarters(fra_emp_fred)
  fra_employment_splice <- merge(fra_emp_fred, fra_emp_oecd, by = c("TIME"), all = TRUE)
  fra_employment_splice$location <- "FRA"
  fra_employment_factor <- fra_employment_splice[136, 2] / fra_employment_splice[136, 4]
  fra_employment_splice[,4] <- fra_employment_factor * fra_employment_splice[,4]
  fra_employment_splice$Value <- c(fra_employment_splice[1:136,2], fra_employment_splice[137:149,4])
  fra_emp_def <- fra_employment_splice[c("location", "TIME", "Value")]
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
  gdp <- subset(gdp_series, select = c("location", "TIME", "Value"))
  emp <- subset(employment_series, select = c("location", "TIME", "Value"))
  sol <- merge(gdp, emp, by = c("location", "TIME"))
  colnames(sol)[3:4] <- c("gdp", "labor")
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
    results$consumption$stdv[,2],
    results$investment$stdv[,2],
    results$government$stdv[,2]
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
  timespan <- cbind(
    results$gdp$timespan,
    results$consumption$timespan[, -1],
    results$investment$timespan[, -1],
    results$government$timespan[, -1],
    results$net_exports$timespan[, -1]
  )
  merge(timespan, results$employment$timespan, by = "Country", all = TRUE)
}

build_usa_correlation_matrix <- function(results) {
  usa_correlation_matrix <- cbind(
    results$gdp$usa_correlation,
    results$consumption$usa_correlation,
    results$investment$usa_correlation,
    results$government$usa_correlation,
    results$net_exports$usa_correlation
  )
  employment_solow <- cbind(
    results$employment$usa_correlation,
    results$solow_residuals$usa_correlation
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
