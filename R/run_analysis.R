source("R/helpers.R")
source("R/input.R")
source("R/analysis.R")
source("R/panel.R")
source("R/thesis_tables.R")

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
