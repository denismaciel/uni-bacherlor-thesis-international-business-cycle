######GDP #####

x <- gdpcor

x[lower.tri(x)] <- NA
diag(x) <- NA

df <- subset(as.data.frame(as.table(x), responseName = 'Corr'),!is.na(Corr))
df <- df[order(df$Corr),]

gdp_correlation_distribution_plot <- ggplot(df, aes(x=1:nrow(df), y=Corr, col= Var2=='USA')) + geom_point(size= 4) +
        scale_color_discrete(name ="Country", labels=c("Other Countries", "USA")) +    
#        labs(title = "Distribution of Output Correlations across Countries") +
        ylab("Correlation Magnitude") +
        xlab("Correlations in Ascending Order") +
        theme(plot.title = element_text(size = rel(1.5)))
gdp_correlation_distribution_plot


####Consumtpion####  
x <- concor

x[lower.tri(x)] <- NA
diag(x) <- NA

df <- subset(as.data.frame(as.table(x), responseName = 'Corr'),!is.na(Corr))
df <- df[order(df$Corr),]

consumption_correlation_distribution_plot <- ggplot(df, aes(x=1:nrow(df), y=Corr, col= Var2=='USA')) + geom_point(size= 4) +
  scale_color_discrete(name ="Country", labels=c("Other Countries", "USA")) +    
#  labs(title = "Distribution of Consumption Correlations across Countries") +
  ylab("Correlation Magnitude") +
  xlab("Correlations in Ascending Order") +
  theme(plot.title = element_text(size = rel(1.5)))
consumption_correlation_distribution_plot

png(filename="output/figures/concor.png", width=2600, height=2000, res = 300)
plot(consumption_correlation_distribution_plot)
dev.off()

png(filename="output/figures/gdpcor.png", width=2600, height=2000, res = 300)
plot(gdp_correlation_distribution_plot)
dev.off()
