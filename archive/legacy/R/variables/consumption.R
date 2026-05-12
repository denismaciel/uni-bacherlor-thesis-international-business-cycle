colnames(con)[1] <- "location"
head(con,4)
names(con)
#we should have only one measurment
levels(con$MEASURE)


#take the log of the variable
con$Value <- log(con$Value)
#order the quarters, so 1991-Q2 < 1991-Q4
con$TIME <- as.ordered(con$TIME)
# time span
max(con$TIME)
min(con$TIME)


# ###### BKK time span? #####
# con <- con[con$TIME >= "1970-Q1" & con$TIME <= "1990-Q2",]


##### Apply HP-Filter #####
filtered <- c()
for (i in unique(con$location)) {
  a <- hpfilter(con[con$location == i,]$Value, type = "lambda", freq = 1600)
  filtered <- append(filtered, a$cycle)
}

con <- cbind(con,filtered)


##### Calculate the Cross-Correlation Matrix #####
panel <- subset(con, select = c("location", "TIME", "filtered"))
str(panel)

concor <- panel %>%
  pivot_wider(names_from = location, values_from = filtered, names_sort = TRUE) %>%
  select(-TIME) %>%
  cor(., use = "pairwise.complete.obs")

concor <- round(concor, 3)
concor

#Correlation of USA with other countries
usa_concor <- concor["USA",]


##Statistics about the correlation matrix (Off-Diagonal)
mean(concor[row(concor)!=col(concor)])
max(concor[row(concor)!=col(concor)])
#which is the maximum correlation
concor == max(concor[row(concor)!=col(concor)])


#### Standard Deviation within Countries

sd(con[con$location == "USA",]$filtered)

con_stdv <- c()
country <- c()
for (i in unique(con$location)){
  a <- sd(con[con$location == i,]$filtered)
  con_stdv <- append(con_stdv, a)
  x <- print(i)
  country <- c(country,x)
}

country
con_stdv
con_stdv <- data.frame(country,con_stdv)


#When does the data start for each country?

con_timespan <- c()
for (i in unique(con$location)){
  a <- con[con$location == i,]
  x <- rbind(as.character(max(a$TIME)), as.character(min(a$TIME)))
  y <- as.character(unique(a$location))
  z <- c(as.character(y),x)
  con_timespan <- rbind(con_timespan,z)
}
colnames(con_timespan) <- c("Country", "Last Observation", "First Observation")

con_timespan


