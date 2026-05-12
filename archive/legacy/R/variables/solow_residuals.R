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
  pivot_wider(names_from = location, values_from = filtered, names_sort = TRUE) %>%
  select(-TIME) %>%
  cor(., use = "pairwise.complete.obs")

solcor <- round(solcor, 3)
solcor

#Correlation of USA with other countries
usa_solcor <- solcor["USA",]

#### Standard Deviation within Countries
sd(sol[sol$location == "USA",]$filtered)

sol_stdv <- c()
country <- c()
for (i in unique(sol$location)){
  a <- sd(sol[sol$location == i,]$filtered)
  sol_stdv <- append(sol_stdv, a)
  x <- print(i)
  country <- c(country,x)
}

country
sol_stdv
sol_stdv <- data.frame(country,sol_stdv)






