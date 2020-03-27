h1n1data <- read.table("C:\\Users\\Kruse\\Documents\\GitHub\\COVID19\\COVID19-vs-H1N1\\h1n1-2009cases-deaths.csv",header=TRUE,sep=",",fill=TRUE)
coviddata <- read.table("C:\\Users\\Kruse\\Documents\\GitHub\\COVID19\\COVID19-vs-H1N1\\total-deaths-covid-19.csv",header=TRUE,sep=",",fill=TRUE)
coviddata$Death = coviddata$Total.confirmed.deaths
US_h1n1 = subset(data, Country=="United States of America" | Country=="United States of America*")
US_covid = subset(coviddata, Entity=="United States", select=c("Total.confirmed.deaths","Date"))
US_h1n1 = US_h1n1[order(as.Date(US_h1n1$Update.Time, format="%m/%d/%Y")),]
US_covid = US_covid[order(as.Date(US_covid$Date, format="%d/%m/%Y")),]
US_h1n1[['index']] = seq(1,length(US_h1n1$Deaths))
US_covid[['index']] = seq(1,length(US_covid$Total.confirmed.deaths))

getShift <- function(d, num) {
  for (x in seq(1,length(d))) {
    if (d[[x]] >= num) {
      shift = x
      return(shift)
    } 
  }
  return(-1)
}

getCOVIDData <- function(country, d) {
  cdata = subset(d, Entity==country, select=c("Total.confirmed.deaths","Date"))
  cdata = cdata[order(as.Date(cdata$Date, format="%d/%m/%Y")),]
  cdata[['index']] = seq(1,length(US_covid$Total.confirmed.deaths))
  return(cdata)
}

plotCountry <- function(d) {
  d = ts(d)
  d$index = d$index - getShift(d$Deaths)
  plot(d$index, d$Deaths)
}
  


US_h1n1$index = US_h1n1$index - getShift(US_h1n1$Deaths,10)
US_covid$index = US_covid$index - getShift(US_covid$Total.confirmed.deaths,10)
head(US_h1n1)
head(US_covid)

ts(US_covid['Total.confirmed.deaths'])

plot(US_covid$index, US_covid$Total.confirmed.deaths, xlim = c(0, 31),type="l")
head(US_covid)
US_covid[[1]]
head(US_covid)
plot(ts(US_covid['Total.confirmed.deaths']))
axis(1,at=seq(1,length(US_covid$Total.confirmed.deaths)), labels=US_covid$Date)
head(US_covid[1])

for (x in seq(1,length(US_covid['Total.confirmed.deaths']))) {
  print(x)
}

length(US_covid$Date)
