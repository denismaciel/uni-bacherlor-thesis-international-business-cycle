rm(k, x, y, z, country, usa, matrix)

### FOR USA ONLY
usa_lag_matrix <- c()
for (i in unique(gdp$location)) {
  
  usa <-  gdp[gdp$location == "USA"  & gdp$TIME >= "1961-Q2" & gdp$TIME <= "2014-Q4",]$filtered
  k <-    gdp[gdp$location == i & gdp$TIME >=  "1961-Q2" & gdp$TIME <= "2014-Q4",]$filtered
    matrix <- ccf(usa, k, type = "correlation")
    matrix <- data.frame(matrix$acf, matrix$lag)
    colnames(matrix) <- c("cor", "lag")
    
    x <- print(matrix$lag[which(matrix$cor == max(matrix$cor))])
    y <- print(max(matrix$cor))
    country <- print(i)
    z <- c(country, x ,y)
    
    usa_lag_matrix <- rbind(usa_lag_matrix, z)
    
  }


can <- gdp[gdp$location == "CAN"  & gdp$TIME >= "1961-Q2" & gdp$TIME <= "2014-Q4",]$filtered
h <- str(ccf(usa, can , type = "correlation"))


h$lag 



### FOR ALL COUNTRIES

gdp_lag_matrix <- c()
for (i in unique(gdp$location)) {

usa <-  gdp[gdp$location == i  & gdp$TIME >= "1961-Q2" & gdp$TIME <= "2014-Q4",]$filtered

for (u in unique(gdp$location)) {
k <-    gdp[gdp$location == u & gdp$TIME >=  "1961-Q2" & gdp$TIME <= "2014-Q4",]$filtered
matrix <- ccf(usa, k, type = "correlation")
matrix <- data.frame(matrix$acf, matrix$lag)
colnames(matrix) <- c("cor", "lag")

x <- print(matrix$lag[which(matrix$cor == max(matrix$cor))])
y <- print(max(matrix$cor))
country <- c(print(i), print(u))
z <- c(country, x ,y)

gdp_lag_matrix <- rbind(gdp_lag_matrix, z)

}}

colnames(gdp_lag_matrix) <- c("country1", "country2", "lag", "cor")

str(gdp_lag_matrix)

gdp_lag_matrix <- data.frame(gdp_lag_matrix)
rownames(gdp_lag_matrix) <- c()              
g <- as.data.frame(gdp_lag_matrix)

str(g)
g$cor <- as.numeric(as.character(g$cor))
g$lag <- as.numeric(as.character(g$lag))

#remove correlation of each country with itself
g <- g[g$country1 != g$country2,]
#mantain only one of USA-AUT and AUT-USA
g <- g[(duplicated(g$cor)),]

table(g$lag)
mean(g$cor)

