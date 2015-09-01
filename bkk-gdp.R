#### GDP ####

colnames(gdp)[1] <- "location"
head(gdp,4)
names(gdp)
#we should have only one measurment
levels(gdp$MEASURE)


#take the log of the variable
gdp$Value <- log(gdp$Value)
#order the quarters, so 1991-Q2 < 1991-Q4
gdp$TIME <- as.ordered(gdp$TIME)
# time span
max(gdp$TIME)
min(gdp$TIME)


# ###### BKK time span? #####
# gdp <- gdp[gdp$TIME >= "1970-Q1" & gdp$TIME <= "1990-Q2",]


##### Apply HP-Filter #####
filtered <- c()
for (i in unique(gdp$location)) {
  a <- hpfilter(gdp[gdp$location == i,]$Value, type = "lambda", freq = 1600)
  filtered <- append(filtered, a$cycle)
}

gdp <- cbind(gdp,filtered)


##### Calculate the Cross-Correlation Matrix #####
panel <- subset(gdp, select = c("location", "TIME", "filtered"))
str(panel)

gdpcor <- panel %>%
  spread(location, filtered) %>%
  select(-TIME) %>%
  cor(., use = "pairwise.complete.obs")

gdpcor <- round(gdpcor, 3)
gdpcor

#Correlation of USA with other countries
usa.gdpcor <- gdpcor["USA",]


##Statistics about the correlation matrix (Off-Diagonal)
mean(gdpcor[row(gdpcor)!=col(gdpcor)])
max(gdpcor[row(gdpcor)!=col(gdpcor)])
#which is the maximum correlation
gdpcor == max(gdpcor[row(gdpcor)!=col(gdpcor)])


#### Standard Deviation within Countries

sd(gdp[gdp$location == "USA",]$filtered)

gdp.stdv <- c()
country <- c()
for (i in unique(gdp$location)){
  a <- sd(gdp[gdp$location == i,]$filtered)
  gdp.stdv <- append(gdp.stdv, a)
  x <- print(i)
  country <- c(country,x)
}

country
gdp.stdv
gdp.stdv <- data.frame(country,gdp.stdv)


#When does the data start for each country?

gdp.timespan <- c()
for (i in unique(gdp$location)){
  a <- gdp[gdp$location == i,]
  x <- rbind(as.character(max(a$TIME)), as.character(min(a$TIME)))
  y <- as.character(unique(a$location))
  z <- c(as.character(y),x)
  gdp.timespan <- rbind(gdp.timespan,z)
}
colnames(gdp.timespan) <- c("Country", "Last Observation", "First Observation")

gdp.timespan