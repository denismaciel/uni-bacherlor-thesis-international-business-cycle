

#use only one measurement
emp <- emp[emp$SUBJECT =="LFEMTTTT",]
unique(emp$SUBJECT)
colnames(emp)[1] <- "location"
unique(emp$location)
emp$TIME <- as.ordered(emp$TIME)

#create table to check that many series are too short
emp_timespan_initial <- c()
for (i in unique(emp$location)){
  a <- emp[emp$location == i,]
  x <- rbind(as.character(max(a$TIME)), as.character(min(a$TIME)))
  y <- as.character(unique(a$location))
  z <- c(as.character(y),x)
  emp_timespan_initial <- rbind(emp_timespan_initial,z)
}
colnames(emp_timespan_initial) <- c("Country", "Last Observation", "First Observation")
emp_timespan_initial


##### Great Britain #### 

#load data from St. Louis FED
gbr_emp_fred <- read.csv("data/raw/fred/gbr_employment.csv")
colnames(gbr_emp_fred) <- c("TIME", "Value") 
#subset OECD data
gbr_emp_oecd <- emp[emp$location == "GBR",]
gbr_emp_oecd <- gbr_emp_oecd[c("location", "TIME", "Value")]

#format index time
gbr_emp_fred$TIME <- as.yearqtr(gbr_emp_fred$TIME, format = "%Y-%m-%d")
gbr_emp_fred$TIME <- as.character(gbr_emp_fred$TIME)
substr(gbr_emp_fred$TIME,5,5) <- "-"
gbr_emp_fred$TIME <- as.ordered(gbr_emp_fred$TIME)
min(gbr_emp_fred$TIME)

gbr_employment_splice <-  merge(gbr_emp_fred, gbr_emp_oecd, by = c("TIME"), all = TRUE)
gbr_employment_splice$location <- "GBR" 

#Plot the series to compare their similiratiy
gbr_employment_plot <- ggplot(gbr_employment_splice, aes(TIME, y = value, color = variable)) + 
  geom_point(aes(y = Value.x, col = "Main Economic Indicators")) + 
  geom_point(aes(y = Value.y, col = "Short-Term Labour Market Statistics")) +
  ylab("People employed (in Thousands)")+
  xlab("Quarters")
#print
png(filename="output/figures/gbremployment.png", width=2600, height=2000, res = 300)
plot(gbr_employment_plot)
dev.off()

#Chaining 
gbr_employment_splice
factor <- gbr_employment_splice[171,2]/gbr_employment_splice[171,4]
gbr_employment_splice[,4] <- factor*gbr_employment_splice[,4]
Value <- c(gbr_employment_splice[1:171,2], gbr_employment_splice[172:184,4])

gbr_employment_splice <- cbind(gbr_employment_splice, Value)

gbr_emp_def <- gbr_employment_splice[c("location", "TIME", "Value")]



##### Italy #### 

#load data from St. Louis FED
ita_emp_fred <- read.csv("data/raw/fred/ita_employment.csv")
colnames(ita_emp_fred) <- c("TIME", "Value") 
#subset OECD data
ita_emp_oecd <- emp[emp$location == "ITA",]
ita_emp_oecd <- ita_emp_oecd[c("location", "TIME", "Value")]

#format index time
ita_emp_fred$TIME <- as.yearqtr(ita_emp_fred$TIME, format = "%Y-%m-%d")
ita_emp_fred$TIME <- as.character(ita_emp_fred$TIME)
substr(ita_emp_fred$TIME,5,5) <- "-"
ita_emp_fred$TIME <- as.ordered(ita_emp_fred$TIME)
min(ita_emp_fred$TIME)


ita_employment_splice <-  merge(ita_emp_fred, ita_emp_oecd, by = c("TIME"), all = TRUE)
ita_employment_splice$location <- "ITA" 
                    
                    
#Plot the series to compare their similiratiy
ita_employment_plot <- ggplot(ita_employment_splice, aes(TIME, y = value, color = variable)) + 
  geom_point(aes(y = Value.x, col = "Main Economic Indicators")) + 
  geom_point(aes(y = Value.y, col = "Short-Term Labour Market Statistics")) +
  ylab("People employed (in Thousands)")+
  xlab("Quarters")
#print
png(filename="output/figures/itaemployment.png", width=2600, height=2000, res = 300)
plot(ita_employment_plot)
dev.off()

#Chaining 
factor <- ita_employment_splice[212,2]/ita_employment_splice[212,4]
ita_employment_splice[,4] <- factor*ita_employment_splice[,4]
Value <- c(ita_employment_splice[1:212,2], ita_employment_splice[213:225,4])

ita_employment_splice <- cbind(ita_employment_splice, Value)

ita_emp_def <- ita_employment_splice[c("location", "TIME", "Value")]


##### France #### 

#load data from St. Louis FED
fra_emp_fred <- read.csv("data/raw/fred/fra_employment.csv")
colnames(fra_emp_fred) <- c("TIME", "Value") 
#subset OECD data
fra_emp_oecd <- emp[emp$location == "FRA",]
fra_emp_oecd <- fra_emp_oecd[c("location", "TIME", "Value")]

a <- fra_emp_oecd[fra_emp_oecd$TIME == "2005-Q2",]$Value
fra_emp_fred$Value <- fra_emp_fred$Value*a/100

#format index time
fra_emp_fred$TIME <- as.yearqtr(fra_emp_fred$TIME, format = "%Y-%m-%d")
fra_emp_fred$TIME <- as.character(fra_emp_fred$TIME)
substr(fra_emp_fred$TIME,5,5) <- "-"
fra_emp_fred$TIME <- as.ordered(fra_emp_fred$TIME)
min(fra_emp_fred$TIME)

fra_employment_splice <-  merge(fra_emp_fred, fra_emp_oecd, by = c("TIME"), all = TRUE)
fra_employment_splice$location <- "FRA" 

#Plot the series to compare their similiratiy
fra_employment_plot <- ggplot(fra_employment_splice, aes(TIME, y = value, color = variable)) + 
  geom_point(aes(y = Value.x, col = "Main Economic Indicators")) + 
  geom_point(aes(y = Value.y, col = "Short-Term Labour Market Statistics")) +
  ylab("People employed (in Thousands)")+
  xlab("Quarters")
#print
png(filename="output/figures/fraemployment.png", width=2600, height=2000, res = 300)
plot(fra_employment_plot)
dev.off()


#Chaining 
fra_employment_splice
factor <- fra_employment_splice[136,2]/fra_employment_splice[136,4]
fra_employment_splice[,4] <- factor*fra_employment_splice[,4]
Value <- c(fra_employment_splice[1:136,2], fra_employment_splice[137:149,4])
fra_employment_splice <- cbind(fra_employment_splice, Value)

fra_emp_def <- fra_employment_splice[c("location", "TIME", "Value")]

#Exclude last five observations because they seem wrong
fra_emp_def <- head(fra_emp_def, -5)
#check how it looks like now
qplot(fra_emp_def$TIME, fra_emp_def$Value) 

fra_emp_def



#### NEW DATA SET ####
#we remove CHE and EU19 because of the small amount of data. And add the expanded
#series for Italy, France and Great Britain
c <- subset(emp, emp$location != "GBR" & emp$location != "FRA" & emp$location != "ITA" &
            emp$location != "CHE" & emp$location != "EA19" ,
            select = c("location", "TIME", "Value"))
unique(c$location)

emp <- rbind(c, gbr_emp_def, ita_emp_def, fra_emp_def)
unique(emp$location)

#Get new Time Frame with expanded series
emp_timespan <- c()
for (i in unique(emp$location)){
  a <- emp[emp$location == i,]
  x <- rbind(as.character(max(a$TIME)), as.character(min(a$TIME)))
  y <- as.character(unique(a$location))
  z <- c(as.character(y),x)
  emp_timespan <- rbind(emp_timespan,z)
}
colnames(emp_timespan) <- c("Country", "Last Observation", "First Observation")
emp_timespan



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
  pivot_wider(names_from = location, values_from = filtered, names_sort = TRUE) %>%
  select(-TIME) %>%
  cor(., use = "pairwise.complete.obs")

empcor <- round(empcor, 3)
empcor

#Correlation of USA with other countries
usa_empcor <- empcor["USA",]

#### Standard Deviation within Countries
sd(emp[emp$location == "USA",]$filtered)


emp_stdv <- c()
country <- c()
for (i in unique(emp$location)){
  a <- sd(emp[emp$location == i,]$filtered)
  emp_stdv <- append(emp_stdv, a)
  x <- print(i)
  country <- c(country,x)
}

country
emp_stdv
emp_stdv <- data.frame(country,emp_stdv)
