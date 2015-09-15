plot(gdp[gdp$location == "USA",]$filtered)

x <- hpfilter(gdp[gdp$location == "USA",]$Value, type ="lambda", freq =1600)
str(x)

x$xname <- "Logged GDP of the United States"
plot(x)



png(filename="filteredgdp.png", width=2600, height=2000, res = 300)
plot(x)
dev.off()