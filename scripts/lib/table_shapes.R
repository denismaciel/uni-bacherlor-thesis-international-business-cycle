publication_timespan_table <- function(timespan) {
  table <- timespan[c(
    "country",
    "gdp_last", "gdp_first",
    "consumption_last", "consumption_first",
    "investment_last", "investment_first",
    "government_last", "government_first",
    "net_exports_last", "net_exports_first",
    "employment_last", "employment_first"
  )]
  names(table) <- c(
    "Country",
    "GDP Last", "GDP First",
    "Consumption Last", "Consumption First",
    "Investment Last", "Investment First",
    "Government Last", "Government First",
    "Net Exports Last", "Net Exports First",
    "Employment Last", "Employment First"
  )
  table
}

publication_standard_deviations_table <- function(standard_deviations) {
  rename(standard_deviations, Country = country)
}

publication_within_country_correlations_table <- function(within_country_correlations) {
  rename(
    within_country_correlations,
    Country = country,
    Autocorrelation = autocorrelation
  )
}

publication_usa_correlations_csv_table <- function(usa_correlation_matrix) {
  table <- usa_correlation_matrix
  names(table) <- c(
    "Country",
    "usa.gdpcor",
    "usa.concor",
    "usa.invcor",
    "usa.govcor",
    "usa.netcor",
    "usa.empcor",
    "usa.solcor"
  )
  table
}

publication_usa_correlations_latex_table <- function(usa_correlations_csv_table) {
  table <- usa_correlations_csv_table
  names(table) <- c("Country", "y", "c", "x", "g", "nx", "n", "z")
  table[table$Country != "USA", ]
}

publication_average_correlations_table <- function(average_cross_country_correlations) {
  table <- data.frame(
    Variable = rownames(average_cross_country_correlations),
    average_cross_country_correlations,
    row.names = NULL,
    check.names = FALSE
  )
  names(table)[names(table) == "mean"] <- "Mean"
  names(table)[names(table) == "usa_mean"] <- "USA Mean"
  table
}

build_publication_tables <- function(results) {
  usa_correlations_csv <- publication_usa_correlations_csv_table(
    results$tables$usa_correlation_matrix
  )

  list(
    timespan = publication_timespan_table(results$tables$timespan),
    standard_deviations = publication_standard_deviations_table(
      results$tables$standard_deviations
    ),
    within_country_correlations = publication_within_country_correlations_table(
      results$tables$within_country_correlations
    ),
    usa_correlations_csv = usa_correlations_csv,
    usa_correlations_latex = publication_usa_correlations_latex_table(usa_correlations_csv),
    average_cross_country_correlations = publication_average_correlations_table(
      results$tables$average_cross_country_correlations
    )
  )
}
