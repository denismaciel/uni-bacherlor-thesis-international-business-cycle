

#use only one measurement
emp <- emp[emp$SUBJECT =="LFEMTTTT",]
unique(emp$SUBJECT)
colnames(emp)[1] <- "location"
unique(emp$location)
emp$TIME <- as.ordered(emp$TIME)

#create table to check that many series are too short
emp.timespan1 <- c()
for (i in unique(emp$location)){
  a <- emp[emp$location == i,]
  x <- rbind(as.character(max(a$TIME)), as.character(min(a$TIME)))
  y <- as.character(unique(a$location))
  z <- c(as.character(y),x)
  emp.timespan1 <- rbind(emp.timespan1,z)
}
colnames(emp.timespan1) <- c("Country", "Last Observation", "First Observation")
emp.timespan1


##### Great Britain #### 

#load data from St. Louis FED
gbr.emp <- read.csv("GBREMPTOTQPSMEI.csv")
colnames(gbr.emp) <- c("TIME", "Value") 
#subset OECD data
gbr.emp2 <- emp[emp$location == "GBR",]
gbr.emp2 <- gbr.emp2[c("location", "TIME", "Value")]

#format index time
gbr.emp$TIME <- as.yearqtr(gbr.emp$TIME, format = "%Y-%m-%d")
gbr.emp$TIME <- as.character(gbr.emp$TIME)
substr(gbr.emp$TIME,5,5) <- "-"
gbr.emp$TIME <- as.ordered(gbr.emp$TIME)
min(gbr.emp$TIME)

gbr.merge <-  merge(gbr.emp, gbr.emp2, by = c("TIME"), all = TRUE)
gbr.merge$location <- "GBR" 

#Plot the series to compare their similiratiy
gbremp.plot <- ggplot(gbr.merge, aes(TIME, y = value, color = variable)) + 
  geom_point(aes(y = Value.x, col = "Main Economic Indicators")) + 
  geom_point(aes(y = Value.y, col = "Short-Term Labour Market Statistics")) +
  ylab("People employed (in Thousands)")+
  xlab("Quarters")
#print
png(filename="gbremployment.png", width=2600, height=2000, res = 300)
plot(gbremp.plot)
dev.off()

#take average of two columns and add it to the data set
Value <- rowMeans(cbind(gbr.merge$Value.x, gbr.merge$Value.y), na.rm = TRUE)
gbr.merge <- cbind(gbr.merge, Value)
head(gbr.merge)

gbr.emp.def <- gbr.merge[c("location", "TIME", "Value")]


##### Italy #### 

#load data from St. Louis FED
ita.emp <- read.csv("ITAEMPTOTQPSMEI.csv")
colnames(ita.emp) <- c("TIME", "Value") 
#subset OECD data
ita.emp2 <- emp[emp$location == "ITA",]
ita.emp2 <- ita.emp2[c("location", "TIME", "Value")]

#format index time
ita.emp$TIME <- as.yearqtr(ita.emp$TIME, format = "%Y-%m-%d")
ita.emp$TIME <- as.character(ita.emp$TIME)
substr(ita.emp$TIME,5,5) <- "-"
ita.emp$TIME <- as.ordered(ita.emp$TIME)
min(ita.emp$TIME)


ita.merge <-  merge(ita.emp, ita.emp2, by = c("TIME"), all = TRUE)
ita.merge$location <- "ITA" 
                    
                    
#Plot the series to compare their similiratiy
itaemp.plot <- ggplot(ita.merge, aes(TIME, y = value, color = variable)) + 
  geom_point(aes(y = Value.x, col = "Main Economic Indicators")) + 
  geom_point(aes(y = Value.y, col = "Short-Term Labour Market Statistics")) +
  ylab("People employed (in Thousands)")+
  xlab("Quarters")
#print
png(filename="itaemployment.png", width=2600, height=2000, res = 300)
plot(itaemp.plot)
dev.off()

#take average of two columns and add it to the data set
Value <- rowMeans(cbind(ita.merge$Value.x, ita.merge$Value.y), na.rm = TRUE)
ita.merge <- cbind(ita.merge, Value)
head(ita.merge)

ita.emp.def <- ita.merge[c("location", "TIME", "Value")]


##### France #### 

#load data from St. Louis FED
fra.emp <- read.csv("FRAEMPTOTQISMEI.csv")
colnames(fra.emp) <- c("TIME", "Value") 
#subset OECD data
fra.emp2 <- emp[emp$location == "FRA",]
fra.emp2 <- fra.emp2[c("location", "TIME", "Value")]

a <- fra.emp2[fra.emp2$TIME == "2005-Q2",]$Value
fra.emp$Value <- fra.emp$Value*a/100

#format index time
fra.emp$TIME <- as.yearqtr(fra.emp$TIME, format = "%Y-%m-%d")
fra.emp$TIME <- as.character(fra.emp$TIME)
substr(fra.emp$TIME,5,5) <- "-"
fra.emp$TIME <- as.ordered(fra.emp$TIME)
min(fra.emp$TIME)

fra.merge <-  merge(fra.emp, fra.emp2, by = c("TIME"), all = TRUE)
fra.merge$location <- "FRA" 

#Plot the series to compare their similiratiy
fraemp.plot <- ggplot(fra.merge, aes(TIME, y = value, color = variable)) + 
  geom_point(aes(y = Value.x, col = "Main Economic Indicators")) + 
  geom_point(aes(y = Value.y, col = "Short-Term Labour Market Statistics")) +
  ylab("People employed (in Thousands)")+
  xlab("Quarters")
#print
png(filename="fraemployment.png", width=2600, height=2000, res = 300)
plot(fraemp.plot)
dev.off()
  
#take average of two columns and add it to the data set
Value <- rowMeans(cbind(fra.merge$Value.x, fra.merge$Value.y), na.rm = TRUE)
fra.merge <- cbind(fra.merge, Value)
head(fra.merge)

fra.emp.def <- fra.merge[c("location", "TIME", "Value")]
#Exclude last five observations because they seem wrong
fra.emp.def <- head(fra.emp.def, -5)
#check how it looks like now
qplot(fra.emp.def$TIME, fra.emp.def$Value) 

fra.emp.def


#### NEW DATA SET ####
#we remove CHE and EU19 because of the small amount of data. And add the expanded
#series for Italy, France and Great Britain
c <- subset(emp, emp$location != "GBR" & emp$location != "FRA" & emp$location != "ITA" &
            emp$location != "CHE" & emp$location != "EA19" ,
            select = c("location", "TIME", "Value"))
unique(c$location)

emp <- rbind(c, gbr.emp.def, ita.emp.def, fra.emp.def)
unique(emp$location)

#Get new Time Frame with expanded series
emp.timespan <- c()
for (i in unique(emp$location)){
  a <- emp[emp$location == i,]
  x <- rbind(as.character(max(a$TIME)), as.character(min(a$TIME)))
  y <- as.character(unique(a$location))
  z <- c(as.character(y),x)
  emp.timespan <- rbind(emp.timespan,z)
}
colnames(emp.timespan) <- c("Country", "Last Observation", "First Observation")
emp.timespan



#### Real Code ####


#take the log of the variable
emp$Value <- log(emp$Value)


# ###### BKK time span? #####
# emp <- emp[emp$TIME >= "1970-Q1" & emp$TIME <= "1990-Q2",]


##### Apply HP-Filter #####
filtered <- c()
for (i in unique(emp$location)) {
  a <- hpfilter(emp[emp$location == i,]$Value, type = "lambda", freq = 1600)
  filtered <- append(filtered, a$cycle)
}

emp <- cbind(emp,filtered)


##### Calculate the Cross-Correlation Matrix #####
panel <- subset(emp, select = c("location", "TIME", "filtered"))
str(panel)

empcor <- panel %>%
  spread(location, filtered) %>%
  select(-TIME) %>%
  cor(., use = "pairwise.complete.obs")

empcor <- round(empcor, 3)
empcor

#Correlation of USA with other countries
usa.empcor <- empcor["USA",]

#### Standard Deviation within Countries
sd(emp[emp$location == "USA",]$filtered)


emp.stdv <- c()
country <- c()
for (i in unique(emp$location)){
  a <- sd(emp[emp$location == i,]$filtered)
  emp.stdv <- append(emp.stdv, a)
  x <- print(i)
  country <- c(country,x)
}

country
emp.stdv
emp.stdv <- data.frame(country,emp.stdv)
