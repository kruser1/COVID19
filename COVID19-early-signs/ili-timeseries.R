#ili-timeseries.R
#NOTE: locations with unusable rILI- data: FL, NYC, NJ, RI

# TODO: Shift data so points show up on end of given week instead of beginning

# 1) load libarries

library(forecast)
library(ggplot2)
library(hash)
library(lubridate)
library(tseries)
library(imputeTS)

#####################################################
# 2) load data - DATA SOURCE: https://github.com/reichlab/ncov/tree/master/analyses/ili-data (3/21/2020)
# rounded rili_minus column in effort to speed up model building w/o losing much accuracy (rounded in Excel before loading)
#NOTE: Need to replace file location for your own computer

# load state data
dat <- read.table("C:\\Users\\Kruse\\Desktop\\ILI Time Series\\state-data-2020-03-20-ROUNDED.csv",header=TRUE,sep=",",fill=TRUE)

# load region data
#dat <- read.table("C:\\Users\\Kruse\\Desktop\\ILI Time Series\\region-data-2020-03-20-ROUNDED.csv",header=TRUE,sep=",",fill=TRUE)

#load dates of first confirmed case for each state - DATA SOURCE: https://www.nytimes.com/interactive/2020/03/21/us/coronavirus-us-cases-spread.html on 3/22/2020
dates <- read.table("C:\\Users\\Kruse\\Desktop\\ILI Time Series\\state-first-confirmed.csv",fileEncoding="UTF-8-BOM",header=TRUE,sep=",",fill=TRUE)

####################################################
# 3) run functions

#return model for given location based on data before November 17, 2019
# ... November 17 is widely believed to be the earliest coronavirus could have infected first human in China
get_location_model <- function(data,loc) {
  print(loc)
  dataLoc <- subset(data,data$region == loc, select=c(year, week, rili_minus))
  dataLoc <- dataLoc[order(dataLoc$year,dataLoc$week),]
  dataLocbefore = subset(dataLoc, (year<2019 & year>2010) | (year == 2019 & week < 48) | (year==2010 & week>39))
  freq = 365.25/7
  tsLoc <- ts(dataLoc['rili_minus'], frequency = freq, start=c(2010,40))
  tsLocBefore <- ts(dataLocbefore['rili_minus'], frequency = freq, start=c(2010,40))
  tsLoBefore_clean = na_interpolation(tsLoBefore)
  tempMod = auto.arima(tsLocBefore)
  return(tempMod)
}

get_data <- function(location, data) {
  result = hash()
  datLoc <- subset(data,dat$region == location, select=c(year, week, rili_minus))
  datLoc <- subset(datLoc, (week>39 & year==2010) | (year>2010))
  datLoc <- datLoc[order(datLoc$year,datLoc$week),]
  datLocbefore = subset(datLoc, (year<2019 & year>2010) | (year == 2019 & week < 48) | (year==2010 & week>39))
  freq = 365.25/7
  tsLoBefore <- ts(datLocbefore['rili_minus'], frequency = freq, start=c(2010,40))
  tsLoBefore = na_interpolation(tsLoBefore)
  observedData <- ts(datLoc['rili_minus'], frequency = freq, start=c(2010,40))
  observedData <- na_interpolation(observedData)
  result[['before']] = tsLoBefore
  result[['all']] = observedData
  return(result)
}

#plot forecasts and safe to PDF
forecasts_to_pdf <- function(data, states, fileloc) {
  path = fileloc
  pdf(file=path)
  par(mfrow=c(2,1))
  for (loc in states) {
    title = paste(loc, "99% Confidence Forecast of rILI-*")
    subtitle = "*rILI-: a metric indicating the rate and amount of people seeking\ncare for flu-like symptoms and test negative for flu"
    f = ets_forecasts_all[[loc]]
    a = observed_all[[loc]]
    xax = c(2019,2019.25,2019.5, 2019.75,2020,2020.25)
    xlabels=c("\nJanuary\n2019","April\n2019","July\n2019","October\n2019","January\n2020","April\n2020")
    plot(f, xlim=c(2018.9,2020.2),ylim=c(0,max(a)), main=title, sub=subtitle, fcol=NULL,ylab="rILI-",xaxt="none")
    axis(1, at=xax,labels=xlabels, line=.25, col="white")
    axis(1,at=xax,labels=FALSE)
    lines(tail(a,16), col='red',lwd=1)
    lines(head(a,477), col='black') #run as safety to ensure we are using the correct data
    legend(2018.9,max(a)*.97, legend=c("Before Nov 17, 2019","After Nov 17, 2019"), col=c("black","red"), lty=c(1,1), cex=.7, bg='lightgray')
    d = subset(dates, dates$state==loc, select=c(first_case_date))
    dd = decimal_date(ymd(d[1,1]))
    d = ymd(d[1,1])
    abline(v=dd, col="black",lwd=2, lty=c(2))
    text(dd-.01, max(a)*.89, paste("First\nConfirmed\nCase",format(d, format="%B %d, %Y"),sep="\n"),font=2, cex=.6, adj=c(1))
  }
  #save to file
  dev.off()
}

compare_arima_ets <- function(trainSet, testSet) {
  tempmodel = auto.arima(trainSet)
  f2 = forecast(tempmodel, h=32)
  print(accuracy(f2,testSet))
  f3 = forecast(trainSet, h=32)
  print(accuracy(f3,testSet))
  results = hash()
  results[['arima']] = f2
  results[['ets']] = f3
  return(results)
}

#assumes arima_forecasts and ets_forecasts are already defined AND have the same states
# ... AND are provided as parameters
see_arima_ets_comparisons <- function(arima, ets, data) {
  keys = keys(arima)
  for (key in keys) {
    print(key)
    d = get_data(key, data)
    before = d[['before']]
    testSet = tail(before,32)
    print(accuracy(arima[[key]], testSet))
    print(accuracy(ets[[key]], testSet))
  }
}

######################################################
# 4) build forecasts and write to PDF
#NOTE: change path variable for your own computer

#make list of all locations with data
states = unique(dat$region)
removeList = c("Florida", "New York City","New Jersey","Rhode Island")
index = 1
for (s in states) {
  if (s %in% removeList) {
    #states[index] <- NULL
    states = states[-index]
  }
  else{
    index = index + 1
  }
}

ets_forecasts_all = hash()
observed_all = hash()
for (state in states) {
  #let test set be the last 48 points of 'before' set
  print(state)
  d = get_data(state, dat)
  before = d[['before']]
  temp_all = d[['all']]
  temp_ets = forecast(before, h=16, level=c(99)) #forecast the 16 weeks after Nov 17, 2019 - use 99% prediction interval
  ets_forecasts_all[[state]] = temp_ets #add forecasts to hash to allow additional plotting, if desired
  observed_all[[state]] = temp_all #add all observed data to hash to allow additional plotting, if desired
}

#save to PDF (change path)
path = "C:\\Users\\Kruse\\Desktop\\ILI Time Series\\state-forecasts.pdf"
forecasts_to_pdf(dat,states, path)

######################################################
#code for testing auto.arima vs ETS
#conclusion: some states are forecasted better using different methods, prediction intervals are similar
  # ... MAPE/MASE were generally better for ETS, so we move forward with ETS

d = get_data("California", dat)
before = d[['before']]
trainSet = head(before,429)
testSet = tail(before,48)
allData = d[['all']]
lines(allData,col='red')

#pick 12 random states to compare forecasting methods
arima_forecasts = hash()
ets_forecasts = hash()
for (state in c("Minnesota","California","Delaware","Colorado","Iowa","Georgia","South Dakota",
                "Pennsylvania","Tennessee","Maryland","Hawaii","Alabama")) {
  #let test set be the last 48 points of 'before' set
  print(state)
  d = get_data(state, dat)
  before = d[['before']]
  trainSet = head(before,445)
  testSet = tail(before,32)
  allData = d[['all']]
  results = compare_arima_ets(trainSet,testSet)
  arima_forecasts[[state]] = results[['arima']]
  ets_forecasts[[state]] = results[['ets']]
}

#plot comparison
  #arima better: MN, CA, PE
  #ets better: CO, IA, GA, SD, TE
  #about same: DE (both bad but PI are fine), MD (both bad but PI are fine), HI (both bad but PI fine), AL (both good)
#MAPE/MASE comparison
  #arima better: MN, PE, CA, AL
  #ets better: SD, TE, MD (bad), IA, HI, GA, DE, CO

#see plots of arima and ETS
loc = "Alabama"
par(mfrow=c(1,1))
d = get_data(loc, dat)
allData = head(d[['all']],477)
plot(arima_forecasts[[loc]])
lines(allData,col='red')
plot(ets_forecasts[[loc]])
lines(allData,col='red')

#######################################################
