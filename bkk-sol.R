emp$filtered
str(emp)

gdpz <- subset(gdp, select = c("location", "TIME", "Value"))
empz <- subset(emp, select = c("location", "TIME", "Value")) 


nrow(gdpz)
nrow(empz)
nrow(a)
nrow(b)


sol <- merge(gdpz, empz, by = c("location", "TIME"))



head(sol)

colnames(sol)[3:4] <- c("gdp", "labor")


Value <- sol$gdp - (1-0.36)*sol$labor   
sol <- cbind(sol, Value)

filtered <- c()
for (i in unique(sol$location)) {
  a <- hpfilter(sol[sol$location == i,]$Value, type = "lambda", freq = 1600)
  filtered <- append(filtered, a$cycle)
}

sol <- cbind(sol,filtered)
str(sol)



##### Calculate the Cross-Correlation Matrix #####
panel <- subset(sol, select = c("location", "TIME", "filtered"))
str(panel)

solcor <- panel %>%
  spread(location, filtered) %>%
  select(-TIME) %>%
  cor(., use = "pairwise.complete.obs")

solcor <- round(solcor, 3)
solcor

#Correlation of USA with other countries
usa.solcor <- solcor["USA",]

#### Standard Deviation within Countries
sd(sol[sol$location == "USA",]$filtered)

sol.stdv <- c()
country <- c()
for (i in unique(sol$location)){
  a <- sd(sol[sol$location == i,]$filtered)
  sol.stdv <- append(sol.stdv, a)
  x <- print(i)
  country <- c(country,x)
}

country
sol.stdv
sol.stdv <- data.frame(country,sol.stdv)






