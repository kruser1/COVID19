# COVID19

<h2>COVID-19: Early Signs</h2>
 A project for analyzing the likelihood of coronavirus presence in a state prior to the date of the first confirmed case. Project details below.

<h3>File description:</h3>

**states-forecasts-95-pi.pdf** - Has plots of all states in our dataset. Plots show forecasted **rILI-** using a 95% prediction interval, observed data, and the date of the state's first confirmed case of COVID-19. Does not include Florida, New Jersey, or Rhode Island due to lack of data.

**states-forecast-99-pi.pdf** - Has plots of all states in our dataset. Plots show forecasted **rILI-** using a 99% prediction interval, observed data, and the date of the state's first confirmed case of COVID-19. Does not include Florida, New Jersey, or Rhode Island due to lack of data.

**state-data-2020-03-20.csv** - Holds data related to influenza-like illness by state. Data is pulled from https://github.com/reichlab/ncov/tree/master/analyses/ili-data.

**state-data-2020-03-20-ROUNDED.csv** - Same data as *state-data-2020-03-20.csv* except the column **rili_minus** is rounded to three decimal places to build models quicker.

**region-data-2020-03-20.csv** - Holds data related to influenza-like illness by region. Data is pulled from https://github.com/reichlab/ncov/tree/master/analyses/ili-data.

**region-data-2020-03-20-ROUNDED.csv** - Same data as *region-data-2020-03-20.csv* except the column **rili_minus** is rounded to three decimal places to build models quicker.

**states-first-confirmed.csv** - Holds the date of each state's first confirmed case of COVID-19. Source: https://www.nytimes.com/interactive/2020/03/21/us/coronavirus-us-cases-spread.html on 3/22/2020.

**ili-timeseries.R** - The R file to reproduce the forecasts.

**states-and-regions-rili-forecast.RData** - Loads the R workspace for the project.

<h3>Disclaimer</h3>

I do not have domain expertise in anything related to epidemiology. This analysis may very well be tainted by my lack of knowledge in this field. If you have domain knowledge and find something incorrect or misleading, please email me at ryan.kruse9@gmail.com.


<h3>Project Details</h3>

The goal of this project is to use the metric **rILI-** to identify states in the United States that are more likely to have had coronavirus before any cases were confirmed there. As described by Reich et. al [here](https://github.com/reichlab/ncov/blob/master/analyses/ili-labtest-report.pdf), **rILI-** is a value that measures the amount of influenza-like illness that are not attributable to influenza. It comes from CDC's Influenza-like Illness Surveillance Network (ILINet), which basically tracks the number of doctors office visits where patients had a fever and at least one other flu-like symptom (such as cough or sore throat) and proceeded to test negative for flu or any other known cause.

A higher **rILI-** indicates more people have flu-like symptoms with an unknown cause. Therefore, a higher **rILI-** may provide evidence for the presence of some other virus, such as the 2019 coronavirus.

This project uses time series analysis and forecasting to predict states' **rILI-** for the weeks from November 17, 2019 until now. Currently, November 17, 2019 is widely believed to be the earliest date the first human could have had COVID-19. The predictions were based on time series data from Week 40 of 2010 until Week 47 of 2019 (which ended on November 17). For each state, we constructed 95% and 99% prediction intervals based on an ETS model using R's **forecast** package. We chose ETS over ARIMA after comparing the two's performance on a train/test split, but we expect both would produce similar forecasted prediction intervals.

![Alabama's rILI- 99% P.I.](Alabama-rILI-99.png)

Above, we see the plot for Alabama. The black data line is the weekly observed data before November 17, 2019. The red line is the weekly observed data after November 17, 2019. The gray area to the right shows our forecasted 99% prediction interval. Based on the data prior to November 17, 2019 (and under the same circumstances), we expect 99% of  data points after November 17, 2019 to be in the gray area (our 99% prediction interval). If the observed data points fall outside of our prediction interval, then we have strong evidence the circumstances have changed and something fishy is going on. This does not seem to be the case for Alabama as all the observed data points are comfortably within the prediction intervals.

Maine is a different story...

![Maine's rILI- 99% P.I.](Maine-rILI-99.png)

Before jumping to conclusions, it's important to keep in mind that there are **many** potential caveats. For example, it's possible some these people in Maine were seeing a lot about coronavirus on the news and started going to the doctor in December 2019 when they previously wouldn't have. It's also possible that some other non-flu, non-COVID-19 illness swept through Maine in late 2019.

However, Maine's observed data is consistently and significantly outside of the 99% prediction interval, which provides strong evidence that *something* was going on starting in December 2019, two and a half months before the state's first confirmed case of COVID-19. This analysis doesn't prove anything, but it may provide motivation for further research into when COVID-19 actually spread to Maine and other states. It's impossible to know for certain in the absence of more data.
