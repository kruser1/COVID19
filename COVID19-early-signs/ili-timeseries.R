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
library(stats)

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
  freq = 365.25/7
  shift = 1/freq #shift x axis back because data is by start of week instead of end
  shift
  for (loc in states) {
    title = paste(loc, "99% Confidence Forecast of rILI-*")
    subtitle = "*rILI-: a metric indicating the rate and amount of people seeking\ncare for flu-like symptoms and test negative for flu"
    #f = ets_forecasts_all[[loc]]
    f = tbats_forecasts_all[[loc]]
    a = observed_all[[loc]]
    xlabels=c("\nJanuary\n2019","April\n2019","July\n2019","October\n2019","January\n2020","April\n2020")
    plot(f, xlim=c(2018.9,2020.2),ylim=c(0,max(a)), main=title, sub=subtitle, fcol=NULL,ylab="rILI-",xaxt="none")
    axis(1, at=xax,labels=xlabels, line=.25, col="white")
    axis(1,at=xax,labels=FALSE)
    lines(tail(a,16), col='red',lwd=1)
    lines(head(a,477), col='black') #run as safety to ensure we are using the correct data
    legend(2018.9,max(a)*.97, legend=c("Before Nov 17, 2019","After Nov 17, 2019"), col=c("black","red"), lty=c(1,1), cex=.7, bg='lightgray')
    d = subset(dates, dates$state==loc, select=c(first_case_date))
    dd = decimal_date(ymd(d[1,1])) - shift
    d = ymd(d[1,1])
    abline(v=dd, col="black",lwd=2, lty=c(2))
    text(dd-.01, max(a)*.89, paste("First\nConfirmed\nCase",format(d, format="%B %d, %Y"),sep="\n"),font=2, cex=.6, adj=c(1))
  }
  #save to file
  dev.off()
}

mape <- function(actual,pred) {
  mape <- mean(abs((actual - pred)/actual))*100
  return(mape)
}

getForecasts <- function(series,h) {
  fc = hash()
  print("naive")
  fc[['naive']] = naive(series,h=h)
  print("es")
  fc[['exp_smooth']] = ses(series,h=h)
  print("holt")
  fc[['holt']] = holt(series, h=h)
  print("arima")
  m= auto.arima(series)
  fc[['arima']] = forecast(m, h=h)
  print("tbats")
  m = tbats(series)
  fc[['tbats']] = forecast(m, h=h)
  print("stlf")
  fc[['stlf']] = stlf(series,h=h)
  return(fc)
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
# 4) build forecasts using TBATS and write to PDF
#NOTE: change path variable for your own computer
#NOTE: can change code to use ETS, ARIMA, or other forecasting methods if desired

#make list of all locations with data
states = unique(dat$region)
removeList = c("Florida", "New York City","New Jersey","Rhode Island",
               "District of Columbia","New Hampshire",
               "Puerto Rico","Virgin Islands")
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
tbats_forecasts_all = hash()
observed_all = hash()
for (state in states) {
  #let test set be the last 48 points of 'before' set
  print(state)
  d = get_data(state, dat)
  before = d[['before']]
  temp_all = d[['all']]
  #temp_ets = forecast(before, h=16, level=c(99)) #forecast the 16 weeks after Nov 17, 2019 - use 99% prediction interval
  temp_tbats = tbats(before)
  temp_forecast = forecast(temp_tbats, h=16, level=c(99.9))
  tbats_forecasts_all[[state]] = temp_forecast
  #ets_forecasts_all[[state]] = temp_ets #add forecasts to hash to allow additional plotting, if desired
  observed_all[[state]] = temp_all #add all observed data to hash to allow additional plotting, if desired
}

plot(tbats_forecasts_all[['South Dakota']], ylim=c(0,5),fcol=NULL,  xlim=c(2014,2020),
     main="South Dakota 6 Year Plot and 99.9% Prediction Interval", ylab="rILI-")
lines(observed_all[['South Dakota']],col='black')
plot(observed_all[['South Dakota']])

for (state in states) {
  print(state)
  print(tail(tbats_forecasts_all[[state]]))
}

#save to PDF (change path)
path = "C:\\Users\\Kruse\\Documents\\GitHub\\COVID19\\COVID19-early-signs\\state-forecasts-99-9-pi.pdf"
forecasts_to_pdf(dat,states, path)

######################################################
#code for testing various forecasting models and selecting the best based on 
  # ... the model's MAPE in predicting the 16 weeks before November 17, 2019

states_mapes = hash()
for (state in c("Minnesota","California","Delaware","Colorado","Iowa","Georgia","South Dakota",
               "Pennsylvania","Tennessee","Maryland","Hawaii","Alabama")) {
  #let test set be the last 48 points of 'before' set
  print(state)
  d = get_data(state, dat)
  before = d[['before']]
  trainSet = head(before,461)
  f = getForecasts(trainSet, 16)
  testSet = tail(before,16)
  mapes = hash()
  for (x in keys(f)) {
    df_f = as.data.frame(f[[x]])
    mapes[[x]] = mape(testSet, df_f$`Point Forecast`)
  }
  states_mapes[[state]] = mapes
}
mapes = hash()
for (x in keys(f)) {
  print(x)
  df_f = as.data.frame(f[[x]])
  print(df_f$'Point Forecast')
  mapes[[x]] = mape(testSet, df_f$`Point Forecast`)
}
for (state in keys(states_mapes)) {
  print(state)
  print(states_mapes[[state]])
}

#######################################################
#further validation of forecasts to address multiple comparisons
#using 99.9% prediction intervals, we expect 0.1% of our observed
  # ... data to fall outside of the intervals
  # ... We see 30/736 outside of the intervals
  # ... We expected to see .736 outside
out = 0
total = 0
for (state in states) {
  for (row in 1:nrow(comp)) {
    comp = data.frame(1:16)
    comp[['upper']] = tbats_forecasts_all[[state]]$upper
    comp[['observed']] = tail(observed_all[[state]],16)
    if (comp[row,3] > comp[row,2]) {
      out = out + 1
    }
    total = total + 1
  }
}
print(paste("total data points predicted:",total))
print(paste("data points outside of prediction interval:",out))
print(paste("expected data points outside of interval:",total*.001))

binom.test(out,total,p=.001,alternative = "greater")

#because our data likely violates a necessary assumption of
  # ... binomial test (independent data points), we run another test
  # ... limiting each state to a maximum of one success (very conservative)

out = 0
total = 0
for (state in states) {
  already = FALSE
  for (row in 1:nrow(comp)) {
    comp = data.frame(1:16)
    comp[['upper']] = tbats_forecasts_all[[state]]$upper
    comp[['observed']] = tail(observed_all[[state]],16)
    if (comp[row,3] > comp[row,2] && already == FALSE) {
      out = out + 1
      already = TRUE
    }
    total = total + 1
  }
  #total = total + 1
}
print(paste("total states predicted:",total))
print(paste("states outside of prediction interval:",out))
print(paste("expected data poins outside of interval:",total*.001))
binom.test(out,total,p=.001,alternative = "greater")



