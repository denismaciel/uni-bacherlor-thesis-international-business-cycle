x <- gdpcor  
x[lower.tri(x)] <- NA
diag(x) <- NA
a <- as.data.frame(as.table(x)) 
a <- na.omit(a)

x <- concor  
x[lower.tri(x)] <- NA
diag(x) <- NA
b <- as.data.frame(as.table(x)) 
b <- na.omit(b)

c <- merge(a, b,  by = c("Var1", "Var2"))
colnames(c)[3:4] <- c("gdp", "con")
dummy <- c$gdp >= c$con
c <- cbind(c, dummy)

  

gdpcon.plot <- ggplot(c, aes(con, gdp, color = dummy, cex.lab = 2)) +
                      geom_point(size = 5) + 
                      xlim(0,1) + ylim(0,1) +
                      ylab("Output Correlation")+
                      xlab("Consumption Correlation") + 
                      geom_abline(intercept = 0, slope = 1) +
                      theme(axis.text=element_text(size=20),
                            axis.title=element_text(size=20,face="bold"), 
                            legend.position="none")

png(filename="gdpco.plot.png", width=2600, height=2000, res = 300)
plot(gdpcon.plot)
dev.off()
