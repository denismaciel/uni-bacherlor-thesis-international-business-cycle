suppressPackageStartupMessages({
  library(xtable)
})

source("R/main.R")

# Correlation of USA variables with other countries'
results$tables$usa_correlation_matrix
xtable(results$tables$usa_correlation_matrix)

# Averaged correlations across all countries, USA mean correlations and quantiles
results$tables$average_cross_country_correlations
xtable(results$tables$average_cross_country_correlations)

# Within-country correlation between GDP and all other variables
results$tables$within_country_correlations
xtable(results$tables$within_country_correlations)

# Standard deviations for each country
results$tables$standard_deviations
xtable(results$tables$standard_deviations)

# Correlation matrices between all countries
results$correlations$gdp
results$correlations$consumption
results$correlations$investment
results$correlations$government
results$correlations$net_exports
results$correlations$employment
results$correlations$solow_residuals

# Table showing when the series starts and ends for each country
results$tables$timespan
xtable(results$tables$timespan)
