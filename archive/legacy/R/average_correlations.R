

#To define the quantiles
a <- c(0.0,0.1,0.25,0.4,0.5,0.6,0.75,0.9,1.0)

###Ouput
x <- gdpcor  
x[lower.tri(x)] <- NA
diag(x) <- NA
x <- as.vector(x)
x <- x[order(x)]
x <- x[!is.na(x)]
mean_gdpcor <- mean(x)
sum_gdpcor <-  quantile(x, prob = a, type = 1)
e <- names(usa_gdpcor) %in% c("USA")
mean_usa_cor <- mean(usa_gdpcor[!e])

sum_gdpcor <- c(mean_gdpcor, mean_usa_cor, sum_gdpcor)


#Consumption
x <- concor  
x[lower.tri(x)] <- NA
diag(x) <- NA
x <- as.vector(x)
x <- x[order(x)]
x <- x[!is.na(x)]
mean_concor <- mean(x)
sum_concor <-  quantile(x, prob = a, type = 1)
e <- names(usa_concor) %in% c("USA")
mean_usa_cor <- mean(usa_concor[!e])

sum_concor <- c(mean_concor, mean_usa_cor, sum_concor)

#Investment
x <- invcor  
x[lower.tri(x)] <- NA
diag(x) <- NA
x <- as.vector(x)
x <- x[order(x)]
x <- x[!is.na(x)]
mean_invcor <- mean(x)
sum_invcor <-  quantile(x, prob = a, type = 1)
e <- names(usa_invcor) %in% c("USA")
mean_usa_cor <- mean(usa_invcor[!e])

sum_invcor <- c(mean_invcor, mean_usa_cor, sum_invcor)

#Government
x <- govcor  
x[lower.tri(x)] <- NA
diag(x) <- NA
x <- as.vector(x)
x <- x[order(x)]
x <- x[!is.na(x)]
mean_govcor <- mean(x)
sum_govcor <-  quantile(x, prob = a, type = 1)
e <- names(usa_govcor) %in% c("USA")
mean_usa_cor <- mean(usa_govcor[!e])

sum_govcor <- c(mean_govcor, mean_usa_cor, sum_govcor)

#Net Expots
x <- netcor  
x[lower.tri(x)] <- NA
diag(x) <- NA
x <- as.vector(x)
x <- x[order(x)]
x <- x[!is.na(x)]
mean_netcor <- mean(x)
sum_netcor <-  quantile(x, prob = a, type = 1)
e <- names(usa_netcor) %in% c("USA")
mean_usa_cor <- mean(usa_netcor[!e])

sum_netcor <- c(mean_netcor, mean_usa_cor, sum_netcor)

#Employment
x <- empcor  
x[lower.tri(x)] <- NA
diag(x) <- NA
x <- as.vector(x)
x <- x[order(x)]
x <- x[!is.na(x)]
mean_empcor <- mean(x)
sum_empcor <-  quantile(x, prob = a, type = 1)
e <- names(usa_empcor) %in% c("USA")
mean_usa_cor <- mean(usa_empcor[!e])
sum_empcor <- c(mean_empcor, mean_usa_cor, sum_empcor)

#Solow Residual
x <- solcor  
x[lower.tri(x)] <- NA
diag(x) <- NA
x <- as.vector(x)
x <- x[order(x)]
x <- x[!is.na(x)]
mean_solcor <- mean(x)
sum_solcor <-  quantile(x, prob = a, type = 1)
e <- names(usa_solcor) %in% c("USA")
mean_usa_cor <- mean(usa_solcor[!e])
sum_solcor <- c(mean_solcor, mean_usa_cor, sum_solcor)

#### Merge the results

average_cross_country_correlations <- rbind(sum_gdpcor, sum_concor, sum_invcor, sum_govcor, 
                 sum_netcor, sum_empcor, sum_solcor)
colnames(average_cross_country_correlations)[1:2] <- c("Mean", "USA Mean")
rownames(average_cross_country_correlations) <- c("y", "c", "x", "g", "nx", "n", "z")

average_cross_country_correlations

xtable(average_cross_country_correlations)
