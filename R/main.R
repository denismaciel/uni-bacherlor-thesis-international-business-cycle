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
usa.correlation.matrix <- cbind(usa.gdpcor, usa.concor,usa.invcor, usa.govcor, usa.netcor)
rownames(usa.correlation.matrix)
# merge to include Employment and Solow Residuals
a <- cbind(usa.empcor, usa.solcor)
usa.correlation.matrix <- merge(usa.correlation.matrix, a, by = 0, all = TRUE)
usa.correlation.matrix


#### RATIO OF STANDARD DEVIATIONS to that of y (except for nx)
standard.deviations <- data.frame(gdp.stdv, con.stdv[,2], 
                                  inv.stdv[,2], gov.stdv[,2])
standard.deviations <- merge(standard.deviations, net.stdv, by = "country")
#merge with Employment and Solow (both countries don't have EU15 and CHE for these two countries)
standard.deviations <- merge(standard.deviations, merge(emp.stdv,sol.stdv), all = TRUE) 
colnames(standard.deviations) <- c("Country", "y", "c", "x",
                                   "g", "nx", "n", "z")
standard.deviations[-1] <- standard.deviations[-1]*100
#net exports st dev are reported without dividing by gdp's
standard.deviations$c <- standard.deviations$c/standard.deviations$y
standard.deviations$x <- standard.deviations$x/standard.deviations$y
standard.deviations$g <- standard.deviations$g/standard.deviations$y
standard.deviations$n <- standard.deviations$n/standard.deviations$y
standard.deviations$z <- standard.deviations$z/standard.deviations$y
standard.deviations[-1] <- round(standard.deviations[-1],2)
#reorder tables to place output near net exports as in BKK
standard.deviations <- standard.deviations[,c("Country", "y","nx","c", "x",
                                                "g", "n", "z")]

### TIMESPAN ### 
timespan <- cbind(gdp.timespan, con.timespan[,-1], inv.timespan[,-1], gov.timespan[,-1], 
                  net.timespan[,-1])
timespan
#merge to include Employment 
timespan<- merge(timespan, emp.timespan, by = "Country", all = TRUE)


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

gdp.subject <- "Gross domestic product - expenditure approach"
table5.subjects <- c(
  gdp = gdp.subject,
  cons = "Private final consumption expenditure",
  inv = "Gross fixed capital formation",
  gov = "General government final consumption expenditure",
  net = "Net Exports"
)

cor.with.gdp <- c()
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
  
  z <- c(as.character(unique(a$location)), autocor, b[gdp.subject, table5.subjects])
  
  cor.with.gdp <- rbind(cor.with.gdp, z)
}
colnames(cor.with.gdp)[1:2] <- c("Country", "Autorcorrelation")
colnames(cor.with.gdp)[3:ncol(cor.with.gdp)] <- names(table5.subjects)
cor.with.gdp


## Part 2: Employment and Solow Residual don't include CHE and EU15, so that their 
# correlations must be calculated seprately.
empX <- cbind(emp, rep("civilian employment", nrow(emp)))
colnames(empX)[ncol(empX)] <- "Subject"
solX <- cbind(sol, rep("Solow Residulas", nrow(sol)))
colnames(solX)[ncol(solX)] <- "Subject"
table5.labor.subjects <- c(
  gdp = gdp.subject,
  emp = "civilian employment",
  sol = "Solow Residulas"
)

gdpX <- gdp[gdp$location != "CHE" & gdp$location != "EU15",]

df <- rbind(gdpX[c("location", "TIME", "Subject", "filtered")],
            empX[c("location", "TIME", "Subject", "filtered")], 
            solX[c("location", "TIME", "Subject", "filtered")])
                   
cor.with.gdp2 <- c()
for (i in unique(df$location)) {
  a <- gdp[gdp$location == i,]
  c <- gdp[gdp$location == i,]$filtered
  
  a <- df[df$location ==i,]
  b <- pivot_wider(a, names_from = Subject, values_from = filtered) %>%
    select(-TIME, -location)
  
  b <- cor(b, use = "pairwise.complete.obs")
  b <- round(b,2)
  
  z <- c(as.character(unique(a$location)), b[gdp.subject, table5.labor.subjects])
  
  cor.with.gdp2 <- rbind(cor.with.gdp2, z)
}

#exclude correlation with gdp
cor.with.gdp2 <- cor.with.gdp2[,-2]
#name first row
colnames(cor.with.gdp2)[1] <- "Country"
colnames(cor.with.gdp2)[2:ncol(cor.with.gdp2)] <- c("emp", "sol")
#merge Part 1 with Part 2
cor.with.gdp.def <- merge(cor.with.gdp,cor.with.gdp2, by = "Country", all = TRUE)


source("R/average_correlations.R")
