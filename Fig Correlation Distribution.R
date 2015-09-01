######GDP #####

x <- gdpcor

x[lower.tri(x)] <- NA
diag(x) <- NA

df <- subset(as.data.frame(as.table(x), responseName = 'Corr'),!is.na(Corr))
df <- df[order(df$Corr),]

gdpcor.plot <- ggplot(df, aes(x=1:nrow(df), y=Corr, col= Var2=='USA')) + geom_point(size= 4) +
        scale_color_discrete(name ="Country", labels=c("Other Countries", "USA")) +    
#        labs(title = "Distribution of Output Correlations across Countries") +
        ylab("Correlation Magnitude") +
        xlab("Correlations in Ascending Order") +
        theme(plot.title = element_text(size = rel(1.5)))
gdpcor.plot


####Consumtpion####  
x <- concor

x[lower.tri(x)] <- NA
diag(x) <- NA

df <- subset(as.data.frame(as.table(x), responseName = 'Corr'),!is.na(Corr))
df <- df[order(df$Corr),]

concor.plot <- ggplot(df, aes(x=1:nrow(df), y=Corr, col= Var2=='USA')) + geom_point(size= 4) +
  scale_color_discrete(name ="Country", labels=c("Other Countries", "USA")) +    
#  labs(title = "Distribution of Consumption Correlations across Countries") +
  ylab("Correlation Magnitude") +
  xlab("Correlations in Ascending Order") +
  theme(plot.title = element_text(size = rel(1.5)))
concor.plot

png(filename="concor.png", width=2600, height=2000, res = 300)
plot(concor.plot)
dev.off()

png(filename="gdpcor.png", width=2600, height=2000, res = 300)
plot(gdpcor.plot)
dev.off()
