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
  pivot_wider(names_from = location, values_from = filtered, names_sort = TRUE) %>%
  select(-TIME) %>%
  cor(., use = "pairwise.complete.obs")

govcor <- round(govcor, 3)
govcor

#Correlation of USA with other countries
usa_govcor <- govcor["USA",]


##Statistics about the correlation matrix (Off-Diagonal)
mean(govcor[row(govcor)!=col(govcor)])
max(govcor[row(govcor)!=col(govcor)])
#which is the maximum correlation
govcor == max(govcor[row(govcor)!=col(govcor)])


#### Standard Deviation within Countries

sd(gov[gov$location == "USA",]$filtered)

gov_stdv <- c()
country <- c()
for (i in unique(gov$location)){
  a <- sd(gov[gov$location == i,]$filtered)
  gov_stdv <- append(gov_stdv, a)
  x <- print(i)
  country <- c(country,x)
}

country
gov_stdv
gov_stdv <- data.frame(country,gov_stdv)


#When does the data start for each country?

gov_timespan <- c()
for (i in unique(gov$location)){
  a <- gov[gov$location == i,]
  x <- rbind(as.character(max(a$TIME)), as.character(min(a$TIME)))
  y <- as.character(unique(a$location))
  z <- c(as.character(y),x)
  gov_timespan <- rbind(gov_timespan,z)
}
colnames(gov_timespan) <- c("Country", "Last Observation", "First Observation")

gov_timespan