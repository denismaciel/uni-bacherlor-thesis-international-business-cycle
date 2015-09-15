getwd()
#setwd("/Users/Denis//Dropbox//6. Semester//B Thesis//Data")
#setwd("C:/Users/Denis Pinto Maciel/Dropbox/6. Semester/B Thesis/+Data")

# install.packages("plm")
# install.packages("mFilter")
# install.packages("dplyr")
# install.packages("tidyr")
# 
# library(mFilter)
# library(plm)
# library(dplyr)
# library(tidyr)
# library(xtable)

# gdp
# con
# inv
# gov
# nex

#### inv ####

colnames(inv)[1] <- "location"
head(inv,4)
names(inv)
#we should have only one measurment
levels(inv$MEASURE)


#take the log of the variable
inv$Value <- log(inv$Value)
#order the quarters, so 1991-Q2 < 1991-Q4
inv$TIME <- as.ordered(inv$TIME)
# time span
max(inv$TIME)
min(inv$TIME)


# ###### BKK time span? #####
# inv <- inv[inv$TIME >= "1970-Q1" & inv$TIME <= "1990-Q2",]


##### Apply HP-Filter #####
filtered <- c()
for (i in unique(inv$location)) {
  a <- hpfilter(inv[inv$location == i,]$Value, type = "lambda", freq = 1600)
  filtered <- append(filtered, a$cycle)
}

inv <- cbind(inv,filtered)


##### Calculate the Cross-Correlation Matrix #####
panel <- subset(inv, select = c("location", "TIME", "filtered"))
str(panel)

invcor <- panel %>%
  spread(location, filtered) %>%
  select(-TIME) %>%
  cor(., use = "pairwise.complete.obs")

invcor <- round(invcor, 3)
invcor

#Correlation of USA with other countries
usa.invcor <- invcor["USA",]


##Statistics about the correlation matrix (Off-Diagonal)
mean(invcor[row(invcor)!=col(invcor)])
max(invcor[row(invcor)!=col(invcor)])
#which is the maximum correlation
invcor == max(invcor[row(invcor)!=col(invcor)])


#### Standard Deviation within Countries

sd(inv[inv$location == "USA",]$filtered)

inv.stdv <- c()
country <- c()
for (i in unique(inv$location)){
  a <- sd(inv[inv$location == i,]$filtered)
  inv.stdv <- append(inv.stdv, a)
  x <- print(i)
  country <- c(country,x)
}

country
inv.stdv
inv.stdv <- data.frame(country,inv.stdv)


#When does the data start for each country?

inv.timespan <- c()
for (i in unique(inv$location)){
  a <- inv[inv$location == i,]
  x <- rbind(as.character(max(a$TIME)), as.character(min(a$TIME)))
  y <- as.character(unique(a$location))
  z <- c(as.character(y),x)
  inv.timespan <- rbind(inv.timespan,z)
}
colnames(inv.timespan) <- c("Country", "Last Observation", "First Observation")

inv.timespan


