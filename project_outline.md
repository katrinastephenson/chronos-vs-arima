# Zero-shot AI forecasting versus ARIMA on two banking series

Working title. Outline approved 2026-11-16.

## 1. Introduction

- Question: can a pretrained AI forecasting model, used with no fitting, forecast weekly banking series as well as a classical ARIMA model fitted to each series?
- Models: Chronos-2 (Amazon's time series foundation model) and ARIMA (the course method, Shumway & Stoffer Chapter 3).
- Data: the 30-year fixed mortgage rate and total deposits at US commercial banks, both weekly from FRED.

## 2. Motivation

- Why these series: banks forecast rates and deposit balances routinely for planning, and both series are public.
- Why this comparison: ARIMA needs an analyst to difference the series, choose orders, and estimate coefficients for each series. A foundation model claims to skip all of that. If it forecasts as well, that changes how much effort a forecast takes; if it doesn't, the classical method earns its effort.
- Why two series: they behave differently. The mortgage rate wanders with no steady trend, and deposits trend upward, so one result doesn't stand in for the other.

## 3. Methods

### 3.1 Data

Both series are weekly and were downloaded from FRED (Federal Reserve Bank of St. Louis). We use data from January 2000 onward.

- 30-year mortgage rate: one number per week, the average interest rate (in percent) on new 30-year fixed-rate home loans in the US that week. The file has two columns: the date and the rate.
- Commercial bank deposits: one number per week, the total dollars held in deposit accounts (checking, savings, CDs) at all US commercial banks, in billions. The file has two columns: the date and the total.

| | 30-year mortgage rate | Commercial bank deposits |
|---|---|---|
| FRED series ID | MORTGAGE30US | DPSACBW027SBOG |
| Full name | 30-Year Fixed Rate Mortgage Average in the United States | Deposits, All Commercial Banks |
| Original source | Freddie Mac, Primary Mortgage Market Survey | Federal Reserve Board, H.8 release (Assets and Liabilities of Commercial Banks in the United States) |
| Units | Percent | Billions of US dollars |
| Frequency | Weekly, published Thursdays | Weekly, level as of Wednesday |
| Seasonal adjustment | Not seasonally adjusted | Seasonally adjusted |
| File | data/MORTGAGE30US.csv | data/Deposits.csv |
| Full file covers | 1971-04-02 to 2026-11-12 | 1973-01-03 to 2026-11-04 |
| Weeks used (from Jan 2000) | 1,402 (2000-01-07 to 2026-11-12) | 1,401 (2000-01-05 to 2026-11-04) |
| Range since 2000 | Low 2.65 (Jan 2021), high 8.64 (May 2000) | 3,466 (Jan 2000) to 19,862 (Nov 2026) |
| Range in the test period | 5.98 to 7.40 | 17,813 to 19,862 |
| Behavior | Wanders up and down with no steady trend | Trends upward over the whole period |

Notes on the data:

- No missing weeks in either series from 2000 onward.
- The mortgage survey changed its method in November 2022, so values before and after are not measured in exactly the same way.
- The mortgage release day shifts around holidays. The Chronos notebook places each series on an even 7-day grid for the model, but all saved results use the original FRED dates.

### 3.2 Evaluation design

- The last 104 weeks of each series are the test period. Everything before is history only.
- The test period is cut into 8 back-to-back windows of 13 weeks (8 x 13 = 104). The windows do not overlap.
- For each window, a model sees all the data from January 2000 up to the origin (the last week before the window) and forecasts the next 13 weeks. It sees nothing after the origin.
- After a window is scored, its 13 actual values are added to the history for the next window. The history grows by 13 weeks each time. Earlier forecasts are never fed back in.
- Every model (Chronos-2, ARIMA, naive) is run on the same 8 origins, so the forecasts line up row for row.
- Result: 8 x 13 = 104 forecast errors per model per series. All metrics are computed over those 104.

### 3.3 Forecast windows

Dates are original FRED dates. The same list is in output/evaluation_windows.csv.

30-year mortgage rate (MORTGAGE30US)

| Window | History used | Weeks of history | Origin (last week seen) | Forecast weeks |
|---|---|---|---|---|
| 1 | 2000-01-07 to 2024-11-14 | 1,298 | 2024-11-14 | 2024-11-21 to 2025-02-13 |
| 2 | 2000-01-07 to 2025-02-13 | 1,311 | 2025-02-13 | 2025-02-20 to 2025-05-15 |
| 3 | 2000-01-07 to 2025-05-15 | 1,324 | 2025-05-15 | 2025-05-22 to 2025-08-14 |
| 4 | 2000-01-07 to 2025-08-14 | 1,337 | 2025-08-14 | 2025-08-21 to 2025-11-13 |
| 5 | 2000-01-07 to 2025-11-13 | 1,350 | 2025-11-13 | 2025-11-20 to 2026-02-12 |
| 6 | 2000-01-07 to 2026-02-12 | 1,363 | 2026-02-12 | 2026-02-19 to 2026-05-14 |
| 7 | 2000-01-07 to 2026-05-14 | 1,376 | 2026-05-14 | 2026-05-21 to 2026-08-13 |
| 8 | 2000-01-07 to 2026-08-13 | 1,389 | 2026-08-13 | 2026-08-20 to 2026-11-12 |

Deposits, all commercial banks (DPSACBW027SBOG)

| Window | History used | Weeks of history | Origin (last week seen) | Forecast weeks |
|---|---|---|---|---|
| 1 | 2000-01-05 to 2024-11-06 | 1,297 | 2024-11-06 | 2024-11-13 to 2025-02-05 |
| 2 | 2000-01-05 to 2025-02-05 | 1,310 | 2025-02-05 | 2025-02-12 to 2025-05-07 |
| 3 | 2000-01-05 to 2025-05-07 | 1,323 | 2025-05-07 | 2025-05-14 to 2025-08-06 |
| 4 | 2000-01-05 to 2025-08-06 | 1,336 | 2025-08-06 | 2025-08-13 to 2025-11-05 |
| 5 | 2000-01-05 to 2025-11-05 | 1,349 | 2025-11-05 | 2025-11-12 to 2026-02-04 |
| 6 | 2000-01-05 to 2026-02-04 | 1,362 | 2026-02-04 | 2026-02-11 to 2026-05-06 |
| 7 | 2000-01-05 to 2026-05-06 | 1,375 | 2026-05-06 | 2026-05-13 to 2026-08-05 |
| 8 | 2000-01-05 to 2026-08-05 | 1,388 | 2026-08-05 | 2026-08-12 to 2026-11-04 |

### 3.4 Models

Chronos-2 (Katrina)

- Model: amazon/chronos-2, a pretrained time series foundation model with about 119 million parameters. Run on a laptop CPU.
- Zero-shot: no parameter is estimated from our data. At each origin the history is passed in as input and the model returns a forecast.
- Inside the model: the history is standardized, cut into patches of 16 observations, passed through a transformer, and the model outputs quantiles for each of the 13 future weeks. The forecast is converted back to the original units.
- Point forecast: the median (50th percentile). 80% prediction interval: 10th to 90th percentile.
- Nothing changes between windows except the length of the history.
- Notebook: chronos_forecasts.ipynb. Run on 2026-11-22.

ARIMA (partner)

- Work on each series separately, on the original scale.
- Identify the model on the history before the first origin (window 1 history): plot the series, difference if needed, read the ACF and PACF, and choose (p, d, q). Shumway & Stoffer Chapter 3.
- Check the residuals of the chosen model (residual ACF, Ljung-Box test).
- At each of the 8 origins, re-estimate the coefficients on the history in the table above and forecast 13 weeks.
- Point forecast: the ARIMA forecast. 80% prediction interval: forecast plus or minus 1.28 standard errors.
- To decide: keep the same (p, d, q) for all 8 windows and only re-estimate the coefficients (simpler), or re-select the orders at each origin.
- Save the forecasts with the same columns as output/forecasts_chronos.csv: series, model, window, origin, timestamp, h, actual, forecast, lo80, hi80. Here h is the number of weeks ahead (1 to 13).

Naive baseline

- The last observed value at the origin, carried forward for all 13 weeks. No interval.
- This is the benchmark both models have to beat.

### 3.5 Metrics

With error = actual minus forecast, over the 104 test weeks of a series:

- MAE: the average absolute error, in the units of the series.
- RMSE: the square root of the average squared error, in the units of the series. Penalizes large misses more than MAE.
- Relative MAE: the model's MAE divided by the naive MAE. Below 1 means the model beat "no change".
- 80% coverage: the share of actual values that fell inside the model's 80% prediction interval. An 80% prediction interval should contain about 80% of them.

## 4. Findings / Results

To be filled in once both notebooks have run.

- Accuracy table: one row per model per series, with the four metrics.
- Forecast plots: each model's eight forecasts against the actual values, for each series.
- Interval comparison: whether each model's 80% prediction intervals were too narrow, too wide, or about right.
- Where they differ: which stretches each model handled well or badly, such as turning points in rates.

## 5. Discussion

- Who won, and by how much: against each other and against naive, separately for each series.
- Effort versus accuracy: what ARIMA required from the analyst compared with what Chronos required.
- Interpretability: ARIMA gives coefficients you can read and test; Chronos does not.
- Limitations: only two series, one horizon, and eight windows; part of the test period may overlap Chronos's training data; the mortgage survey changed method in November 2022.

## 6. Conclusion

- Answer to the question: one paragraph, based on the results.
- Next steps: what a fuller study would add, such as more series or other horizons.

## References

Chronos-2

1. Ansari, A. F., Shchur, O., Küken, J., Auer, A., Han, B., Mercado, P., et al. (2025). Chronos-2: From univariate to universal forecasting. arXiv preprint arXiv:2510.15821. https://arxiv.org/abs/2510.15821
2. Ansari, A. F., Stella, L., Turkmen, C., Zhang, X., Mercado, P., Shen, H., et al. (2024). Chronos: Learning the language of time series. Transactions on Machine Learning Research. https://arxiv.org/abs/2403.07815
3. Amazon. amazon/chronos-2 pretrained weights and configuration, Hugging Face. Parameter count and patch size as read from the model in our run.

ARIMA

4. Shumway, R. H., and Stoffer, D. S. (2025). Time Series Analysis and Its Applications: With R Examples (5th ed.). Springer. Chapter 3, ARIMA Models. https://doi.org/10.1007/978-3-031-70584-7
5. Box, G. E. P., Jenkins, G. M., Reinsel, G. C., and Ljung, G. M. (2015). Time Series Analysis: Forecasting and Control (5th ed.). Wiley.
6. Ljung, G. M., and Box, G. E. P. (1978). On a measure of lack of fit in time series models. Biometrika, 65(2), 297-303.
7. R Core Team. R: A Language and Environment for Statistical Computing. R Foundation for Statistical Computing, Vienna. Models fitted with arima() in the stats package.

Data

8. Freddie Mac. 30-Year Fixed Rate Mortgage Average in the United States [MORTGAGE30US]. Retrieved from FRED, Federal Reserve Bank of St. Louis, November 2026. https://fred.stlouisfed.org/series/MORTGAGE30US
9. Board of Governors of the Federal Reserve System (US). Deposits, All Commercial Banks [DPSACBW027SBOG]. Retrieved from FRED, Federal Reserve Bank of St. Louis, November 2026. https://fred.stlouisfed.org/series/DPSACBW027SBOG

## How the work flows

1. Katrina runs the Chronos notebook (chronos_forecasts.ipynb), which produces the forecasts, metrics, and the list of forecast dates in the output folder. Done 2026-11-22.
2. Partner runs ARIMA on those same dates (output/evaluation_windows.csv) and saves her forecasts in the same column format as output/forecasts_chronos.csv.
3. The two forecast files are combined into the results table and plots.
4. The report and the 10-minute slides are written from this outline.

## Evaluation settings

| Item | Setting |
|---|---|
| Series | MORTGAGE30US and DPSACBW027SBOG (weekly, FRED) |
| History start | 2000-01-01 |
| Test period | Last 104 weeks of each series (Nov 2024 to Nov 2026) |
| Horizon | 13 weeks |
| Forecast start dates | 8, spaced 13 weeks apart |
| Scale | Original units (percent, $ billions) |
| Point forecast | Chronos median; ARIMA forecast |
| Interval | 80% (10th to 90th percentile) |
| Metrics | MAE, RMSE, MAE relative to naive, 80% prediction interval coverage |
| Baseline | Naive (last value carried forward) |
