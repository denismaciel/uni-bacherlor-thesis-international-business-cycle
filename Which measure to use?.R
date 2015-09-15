
measurefull <- read.csv("gdp-measure-choice.csv")

#[1] CARSA      CPCARSA    CQR        CQRSA      DNBSA      DOBSA      LNBQR      LNBQRSA   
#[9] VIXOBSA    VOBARSA    VPVOBARSA  LNBARSA    HCPCARSA   HVPVOBARSA
unique(measurefull$MEASURE)

#Exclusion for full time span
measurefull <- measurefull[measurefull$MEASURE != "CQR",]
measurefull <-measurefull[measurefull$MEASURE != "LNBQR",]

# #Exclusion for BKK time span
# measurefull <- measurefull[measurefull$MEASURE != "CQR",]
# measurefull <- measurefull[measurefull$MEASURE != "CQRSA",]
# measurefull <-measurefull[measurefull$MEASURE != "DNBSA",]
# measurefull <-measurefull[measurefull$MEASURE != "DOBSA",]
# measurefull <-measurefull[measurefull$MEASURE != "LNBQR",]
# measurefull <-measurefull[measurefull$MEASURE != "LNBQRSA",]
# measurefull <-measurefull[measurefull$MEASURE != "VIXOBSA",]
# measurefull <-measurefull[measurefull$MEASURE != "LNBARSA",]
# measurefull <-measurefull[measurefull$MEASURE != "HCPCARSA",]
# measurefull <-measurefull[measurefull$MEASURE != "HVPVOBARSA",]

names(measurefull)
measurefull$Value <- log(measurefull$Value)

#LOOP
j <- c()
for (x in unique(measurefull$MEASURE)) {
  
  df <- measurefull[measurefull$MEASURE == x,]
  
#   ###### BKK time span? #####
#   df$TIME <- as.ordered(df$TIME)
#   df <- df[df$TIME >= "1970-Q1" & df$TIME <= "1990-Q2",]
  
  
  
  # Apply HP-Filter #
  filtered <- c()
  for (i in unique(df$Country)) {
    a <- hpfilter(df[df$Country == i,]$Value, type = "lambda", freq = 1600)
    filtered <- append(filtered, a$cycle)
  }
  
  
  df <- cbind(df,filtered)
  rm(filtered)
  
  ##### Calculate the Cross-Correlation Matrix #####
  panel <- subset(df, select = c("X...LOCATION", "TIME", "filtered"))
  str(panel)
  
  cordf <- panel %>%
    spread(X...LOCATION, filtered) %>%
    select(-TIME) %>%
    cor(., use = "pairwise.complete.obs")
  
  cordf <- round(cordf, 3)
  
  
  #Correlation of USA with other countries
  a <- cordf["USA",]
  str(a)
  a <- t(as.matrix(a))
  rownames(a) <- as.character(unique(df$MEASURE))
  
  j <- rbind(j,a)
  
}
j
xtable(j)
