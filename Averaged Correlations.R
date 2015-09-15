

#To define the quantiles
a <- c(0.0,0.1,0.25,0.4,0.5,0.6,0.75,0.9,1.0)

###Ouput
x <- gdpcor  
x[lower.tri(x)] <- NA
diag(x) <- NA
x <- as.vector(x)
x <- x[order(x)]
x <- x[!is.na(x)]
mean.gdpcor <- mean(x)
sum.gdpcor <-  quantile(x, prob = a, type = 1)
e <- names(usa.gdpcor) %in% c("USA")
mean.usacor <- mean(usa.gdpcor[!e])

sum.gdpcor <- c(mean.gdpcor, mean.usacor, sum.gdpcor)


#Consumption
x <- concor  
x[lower.tri(x)] <- NA
diag(x) <- NA
x <- as.vector(x)
x <- x[order(x)]
x <- x[!is.na(x)]
mean.concor <- mean(x)
sum.concor <-  quantile(x, prob = a, type = 1)
e <- names(usa.concor) %in% c("USA")
mean.usacor <- mean(usa.concor[!e])

sum.concor <- c(mean.concor, mean.usacor, sum.concor)

#Investment
x <- invcor  
x[lower.tri(x)] <- NA
diag(x) <- NA
x <- as.vector(x)
x <- x[order(x)]
x <- x[!is.na(x)]
mean.invcor <- mean(x)
sum.invcor <-  quantile(x, prob = a, type = 1)
e <- names(usa.invcor) %in% c("USA")
mean.usacor <- mean(usa.invcor[!e])

sum.invcor <- c(mean.invcor, mean.usacor, sum.invcor)

#Government
x <- govcor  
x[lower.tri(x)] <- NA
diag(x) <- NA
x <- as.vector(x)
x <- x[order(x)]
x <- x[!is.na(x)]
mean.govcor <- mean(x)
sum.govcor <-  quantile(x, prob = a, type = 1)
e <- names(usa.govcor) %in% c("USA")
mean.usacor <- mean(usa.govcor[!e])

sum.govcor <- c(mean.govcor, mean.usacor, sum.govcor)

#Net Expots
x <- netcor  
x[lower.tri(x)] <- NA
diag(x) <- NA
x <- as.vector(x)
x <- x[order(x)]
x <- x[!is.na(x)]
mean.netcor <- mean(x)
sum.netcor <-  quantile(x, prob = a, type = 1)
e <- names(usa.netcor) %in% c("USA")
mean.usacor <- mean(usa.netcor[!e])

sum.netcor <- c(mean.netcor, mean.usacor, sum.netcor)

#Employment
x <- empcor  
x[lower.tri(x)] <- NA
diag(x) <- NA
x <- as.vector(x)
x <- x[order(x)]
x <- x[!is.na(x)]
mean.empcor <- mean(x)
sum.empcor <-  quantile(x, prob = a, type = 1)
e <- names(usa.empcor) %in% c("USA")
mean.usacor <- mean(usa.empcor[!e])
sum.empcor <- c(mean.empcor, mean.usacor, sum.empcor)

#Solow Residual
x <- solcor  
x[lower.tri(x)] <- NA
diag(x) <- NA
x <- as.vector(x)
x <- x[order(x)]
x <- x[!is.na(x)]
mean.solcor <- mean(x)
sum.solcor <-  quantile(x, prob = a, type = 1)
e <- names(usa.solcor) %in% c("USA")
mean.usacor <- mean(usa.solcor[!e])
sum.solcor <- c(mean.solcor, mean.usacor, sum.solcor)

#### Merge the results

sum.cor <- rbind(sum.gdpcor, sum.concor, sum.invcor, sum.govcor, 
                 sum.netcor, sum.empcor, sum.solcor)
colnames(sum.cor)[1:2] <- c("Mean", "USA Mean")
rownames(sum.cor) <- c("y", "c", "x", "g", "nx", "n", "z")

sum.cor

xtable(sum.cor)
