# Correlation of USA variables with other countries'
usa_correlation_matrix
xtable(usa_correlation_matrix)

#Averaged Correlations across all countries, USA Mean Correlations and quantiles
average_cross_country_correlations
xtable(average_cross_country_correlations)

#Within-country Correlation between GDP and all other variables 
within_country_correlations
xtable(within_country_correlations)

#Standard Deviations for each country
standard_deviations 
xtable(standard_deviations)

#Correlation Matrices between all countries for the following variables
gdpcor #output
concor #consumption
invcor #investment
govcor #government spending
netcor #net exports
empcor #civilian employment
solcor #solow residuals

# Table showing when the series starts and ends for each country
timespan
xtable(timespan)


#Plots of time series of civilian employment
gbr_employment_plot #plot of the two time series for UK
ita_employment_plot #plot of the two time series for Italy
fra_employment_plot #plot of the two time series for France




