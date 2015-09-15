colnames(net)[1] <- "location"
names(net)
head(net)
tail(net)
unique(net$Subject)
net$TIME <- as.ordered(net$TIME)


exp <- (net[net$Subject == "Exports of goods and services",])
imp <- (net[net$Subject == "Imports of goods and services",])
gdp.cp <- (net[net$Subject == "Gross domestic product - expenditure approach",])
length(exp$Value)
length(imp$Value)
length(gdp$Value)


net <- cbind(exp, exp$Value - imp$Value)
str(net)
colnames(net)[ncol(net)] <- "Net Exports"


a <- subset(net, select = c("location","TIME", "Net Exports"))
b <- subset(gdp.cp, select = c("location","TIME", "Value"))  

head(a)
head(b)
colnames(b)[3] <- "GDP"

#Merge into a data frame GDP and Net Exports
z <- merge(a,b, by = c("location","TIME"), all= TRUE)
names(z)

# #there are four NAs
# sum(is.na(z))
# c <- which(is.na(z$Net))
# #remove NAs 
# z <- z[-c,]
# #check if there are still NA
# sum(is.na(z))

net <- cbind(z, z$Net/z$GDP)
head(net)
#Name Net Exports as "filtered" so the same code can be used 
colnames(net)[ncol(net)] <- "Value"
str(net)


#HP Filter
filtered <- c()
for (i in unique(net$location)) {
  a <- hpfilter(net[net$location == i,]$Value, type = "lambda", freq = 1600)
  filtered <- append(filtered, a$cycle)
}

net <- cbind(net,filtered)
head(net)

########################

##### Calculate the Cross-Correlation Matrix #####
panel <- subset(net, select = c("location", "TIME", "filtered"))
str(panel)

netcor <- panel %>%
  spread(location, filtered) %>%
  select(-TIME) %>%
  cor(., use = "pairwise.complete.obs")

netcor <- round(netcor, 3)
netcor

#Correlation of USA with other countries
usa.netcor <- netcor["USA",]


##Statistics about the correlation matrix (Off-Diagonal)
mean(netcor[row(netcor)!=col(netcor)])
max(netcor[row(netcor)!=col(netcor)])
#which is the maximum correlation
netcor == max(netcor[row(netcor)!=col(netcor)])


#### Standard Deviation within Countries

sd(net[net$location == "USA",]$filtered)

net.stdv <- c()
country <- c()
for (i in unique(net$location)){
  a <- sd(net[net$location == i,]$filtered)
  net.stdv <- append(net.stdv, a)
  x <- print(i)
  country <- c(country,x)
}

country
net.stdv
net.stdv <- data.frame(country,net.stdv)




#When does the data start for each location?

net.timespan <- c()
for (i in unique(net$location)){
  a <- net[net$location == i,]
  x <- rbind(as.character(max(a$TIME)), as.character(min(a$TIME)))
  y <- as.character(unique(a$location))
  z <- c(as.character(y),x)
  net.timespan <- rbind(net.timespan,z)
}
colnames(net.timespan) <- c("location", "Last Observation", "First Observation")

net.timespan
