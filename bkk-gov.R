#### gov ####

colnames(gov)[1] <- "location"
head(gov,4)
names(gov)
#we should have only one measurment
levels(gov$MEASURE)


#take the log of the variable
gov$Value <- log(gov$Value)
#order the quarters, so 1991-Q2 < 1991-Q4
gov$TIME <- as.ordered(gov$TIME)
# time span
max(gov$TIME)
min(gov$TIME)


# ###### BKK time span? #####
# gov <- gov[gov$TIME >= "1970-Q1" & gov$TIME <= "1990-Q2",]


##### Apply HP-Filter #####
filtered <- c()
for (i in unique(gov$location)) {
  a <- hpfilter(gov[gov$location == i,]$Value, type = "lambda", freq = 1600)
  filtered <- append(filtered, a$cycle)
}

gov <- cbind(gov,filtered)


##### Calculate the Cross-Correlation Matrix #####
panel <- subset(gov, select = c("location", "TIME", "filtered"))
str(panel)

govcor <- panel %>%
  spread(location, filtered) %>%
  select(-TIME) %>%
  cor(., use = "pairwise.complete.obs")

govcor <- round(govcor, 3)
govcor

#Correlation of USA with other countries
usa.govcor <- govcor["USA",]


##Statistics about the correlation matrix (Off-Diagonal)
mean(govcor[row(govcor)!=col(govcor)])
max(govcor[row(govcor)!=col(govcor)])
#which is the maximum correlation
govcor == max(govcor[row(govcor)!=col(govcor)])


#### Standard Deviation within Countries

sd(gov[gov$location == "USA",]$filtered)

gov.stdv <- c()
country <- c()
for (i in unique(gov$location)){
  a <- sd(gov[gov$location == i,]$filtered)
  gov.stdv <- append(gov.stdv, a)
  x <- print(i)
  country <- c(country,x)
}

country
gov.stdv
gov.stdv <- data.frame(country,gov.stdv)


#When does the data start for each country?

gov.timespan <- c()
for (i in unique(gov$location)){
  a <- gov[gov$location == i,]
  x <- rbind(as.character(max(a$TIME)), as.character(min(a$TIME)))
  y <- as.character(unique(a$location))
  z <- c(as.character(y),x)
  gov.timespan <- rbind(gov.timespan,z)
}
colnames(gov.timespan) <- c("Country", "Last Observation", "First Observation")

gov.timespan