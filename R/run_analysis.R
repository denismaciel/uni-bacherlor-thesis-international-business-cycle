source("R/helpers.R")
source("R/input.R")
source("R/analysis.R")
source("R/panel.R")
source("R/thesis_tables.R")

run_analysis <- function(data_dir = "data/raw", output_figures = FALSE) {
  raw_data <- load_raw_data(data_dir)
  panel_data <- build_analysis_panel(raw_data)
  variable_results <- build_variable_results(
    panel_data$panel,
    panel_data$employment_initial_timespan
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
    panel = panel_data$panel,
    series = lapply(variable_results, `[[`, "series"),
    correlations = lapply(variable_results, `[[`, "correlation"),
    variable_results = variable_results
  )
}
