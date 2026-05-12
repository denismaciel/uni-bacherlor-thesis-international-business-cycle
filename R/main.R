# install.packages("mFilter")
# install.packages("dplyr")
# install.packages("tidyr")
# install.packages(xtable)
# install.packages(ggplot2)
# install.packages(zoo)

suppressPackageStartupMessages({
  library(mFilter)
  library(dplyr)
  library(tidyr)
  library(xtable)
  library(ggplot2)
  library(zoo)
})

dir.create("output/figures", recursive = TRUE, showWarnings = FALSE)

gdp <- read.csv("data/raw/oecd/gdp.csv")
con <- read.csv("data/raw/oecd/consumption.csv")
inv <- read.csv("data/raw/oecd/investment.csv")
gov <- read.csv("data/raw/oecd/government.csv")
net <- read.csv("data/raw/oecd/net_exports.csv")
emp <- read.csv("data/raw/oecd/employment.csv")

source("R/variables/gdp.R")
source("R/variables/consumption.R")
source("R/variables/investment.R")
source("R/variables/government.R")
source("R/variables/net_exports.R")
source("R/variables/employment.R")
source("R/variables/solow_residuals.R")

#### USA correlation matrix ####
usa_correlation_matrix <- cbind(usa_gdpcor, usa_concor,usa_invcor, usa_govcor, usa_netcor)
rownames(usa_correlation_matrix)
# merge to include Employment and Solow Residuals
a <- cbind(usa_empcor, usa_solcor)
usa_correlation_matrix <- merge(usa_correlation_matrix, a, by = 0, all = TRUE)
usa_correlation_matrix


#### RATIO OF STANDARD DEVIATIONS to that of y (except for nx)
standard_deviations <- data.frame(gdp_stdv, con_stdv[,2], 
                                  inv_stdv[,2], gov_stdv[,2])
standard_deviations <- merge(standard_deviations, net_stdv, by = "country")
#merge with Employment and Solow (both countries don't have EU15 and CHE for these two countries)
standard_deviations <- merge(standard_deviations, merge(emp_stdv,sol_stdv), all = TRUE) 
colnames(standard_deviations) <- c("Country", "y", "c", "x",
                                   "g", "nx", "n", "z")
standard_deviations[-1] <- standard_deviations[-1]*100
#net exports st dev are reported without dividing by gdp's
standard_deviations$c <- standard_deviations$c/standard_deviations$y
standard_deviations$x <- standard_deviations$x/standard_deviations$y
standard_deviations$g <- standard_deviations$g/standard_deviations$y
standard_deviations$n <- standard_deviations$n/standard_deviations$y
standard_deviations$z <- standard_deviations$z/standard_deviations$y
standard_deviations[-1] <- round(standard_deviations[-1],2)
#reorder tables to place output near net exports as in BKK
standard_deviations <- standard_deviations[,c("Country", "y","nx","c", "x",
                                                "g", "n", "z")]

### TIMESPAN ### 
timespan <- cbind(gdp_timespan, con_timespan[,-1], inv_timespan[,-1], gov_timespan[,-1], 
                  net_timespan[,-1])
timespan
#merge to include Employment 
timespan<- merge(timespan, emp_timespan, by = "Country", all = TRUE)


#### Correlation of other Variables with GDP for each country

#Include the column "Subject" in Net Exports, Employment and Solow Residual
netX <- cbind(net, rep("Net Exports", nrow(net)))
colnames(netX)[ncol(netX)] <- "Subject"

#Part 1
df <- rbind (gdp[c("location", "TIME", "Subject", "filtered")], 
             con[c("location", "TIME", "Subject", "filtered")],
             inv[c("location", "TIME", "Subject", "filtered")],
             gov[c("location", "TIME", "Subject", "filtered")],
             netX[c("location", "TIME", "Subject", "filtered")])

gdp_subject <- "Gross domestic product - expenditure approach"
table5_subjects <- c(
  gdp = gdp_subject,
  cons = "Private final consumption expenditure",
  inv = "Gross fixed capital formation",
  gov = "General government final consumption expenditure",
  net = "Net Exports"
)

core_with_gdp_correlations <- c()
for (i in unique(df$location)) {
  a <- gdp[gdp$location == i,]
  c <- gdp[gdp$location == i,]$filtered
  autocor <- cor(c, lag(c,1), use = "pairwise.complete" )
  autocor <- round(autocor, 2)
  
  a <- df[df$location ==i,]
  b <- pivot_wider(a, names_from = Subject, values_from = filtered) %>%
    select(-TIME, -location)
  
  b <- cor(b, use = "pairwise.complete.obs")
  b <- round(b,2)
  
  z <- c(as.character(unique(a$location)), autocor, b[gdp_subject, table5_subjects])
  
  core_with_gdp_correlations <- rbind(core_with_gdp_correlations, z)
}
colnames(core_with_gdp_correlations)[1:2] <- c("Country", "Autorcorrelation")
colnames(core_with_gdp_correlations)[3:ncol(core_with_gdp_correlations)] <- names(table5_subjects)
core_with_gdp_correlations


## Part 2: Employment and Solow Residual don't include CHE and EU15, so that their 
# correlations must be calculated seprately.
empX <- cbind(emp, rep("civilian employment", nrow(emp)))
colnames(empX)[ncol(empX)] <- "Subject"
solX <- cbind(sol, rep("Solow Residulas", nrow(sol)))
colnames(solX)[ncol(solX)] <- "Subject"
table5_labor_subjects <- c(
  gdp = gdp_subject,
  emp = "civilian employment",
  sol = "Solow Residulas"
)

gdpX <- gdp[gdp$location != "CHE" & gdp$location != "EU15",]

df <- rbind(gdpX[c("location", "TIME", "Subject", "filtered")],
            empX[c("location", "TIME", "Subject", "filtered")], 
            solX[c("location", "TIME", "Subject", "filtered")])
                   
within_country_labor_correlations <- c()
for (i in unique(df$location)) {
  a <- gdp[gdp$location == i,]
  c <- gdp[gdp$location == i,]$filtered
  
  a <- df[df$location ==i,]
  b <- pivot_wider(a, names_from = Subject, values_from = filtered) %>%
    select(-TIME, -location)
  
  b <- cor(b, use = "pairwise.complete.obs")
  b <- round(b,2)
  
  z <- c(as.character(unique(a$location)), b[gdp_subject, table5_labor_subjects])
  
  within_country_labor_correlations <- rbind(within_country_labor_correlations, z)
}

#exclude correlation with gdp
within_country_labor_correlations <- within_country_labor_correlations[,-2]
#name first row
colnames(within_country_labor_correlations)[1] <- "Country"
colnames(within_country_labor_correlations)[2:ncol(within_country_labor_correlations)] <- c("emp", "sol")
#merge Part 1 with Part 2
within_country_correlations <- merge(core_with_gdp_correlations,within_country_labor_correlations, by = "Country", all = TRUE)


source("R/average_correlations.R")
