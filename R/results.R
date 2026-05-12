# Correlation of USA variables with other countries'
usa.correlation.matrix
xtable(usa.correlation.matrix)

#Averaged Correlations across all countries, USA Mean Correlations and quantiles
sum.cor
xtable(sum.cor)

#Within-country Correlation between GDP and all other variables 
cor.with.gdp.def
xtable(cor.with.gdp.def)

#Standard Deviations for each country
standard.deviations 
xtable(standard.deviations)

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
gbremp.plot #plot of the two time series for UK
itaemp.plot #plot of the two time series for Italy
fraemp.plot #plot of the two time series for France




