# Chronos-2 vs ARIMA on two banking series

Final project for STA 6857 (Time Series), Fall 2026, by Katrina Stephenson and Som Chavanachat.

Question: can a pretrained forecasting model (Chronos-2), used with no fitting, forecast two weekly banking series as well as ARIMA models identified by hand?

Presentation page: https://katrinastephenson.github.io/chronos-vs-arima/

## Design

- Series: 30-year mortgage rate (MORTGAGE30US) and deposits at all commercial banks (DPSACBW027SBOG), weekly, from FRED, January 2000 to November 2026.
- Test period: the last 104 weeks of each series, split into 8 non-overlapping 13-week windows.
- At each window both models see the full history up to the origin and forecast the next 13 weeks.
- Benchmark: naive forecast (last value carried forward).
- Metrics: MAE, RMSE, MAE relative to naive, 80% interval coverage.

Full details are in `project_outline.md`.

## Files

| File | What it is |
|---|---|
| `index.html` | Presentation page (self-contained) |
| `project_outline.md` | Project outline, data description, forecast windows |
| `chronos_forecasts.ipynb` | Chronos-2 forecasts and metrics (Python) |
| `arima_forecasts.R`, `arima_forecasts.Rmd` | ARIMA identification, diagnostics, forecasts (R) |
| `data/` | The two FRED series as downloaded |
| `output/` | Forecasts, metrics, evaluation windows, and plots from both models |

## Results (104 test weeks per series)

| Series | Model | MAE | MAE / naive | 80% coverage |
|---|---|---|---|---|
| Mortgage rate (percentage points) | Chronos-2 | 0.173 | 0.96 | 0.81 |
| | ARIMA(2,1,0) | 0.178 | 0.98 | 0.92 |
| | Naive | 0.181 | 1.00 | |
| Deposits ($ billions) | Chronos-2 | 138.2 | 1.01 | 0.88 |
| | ARIMA(6,1,0) with drift | 67.6 | 0.49 | 0.93 |
| | Naive | 137.1 | 1.00 | |

## References

- Ansari, A. F., et al. (2025). Chronos-2: From Univariate to Universal Forecasting. arXiv:2510.15821.
- Shumway, R. H., and Stoffer, D. S. Time Series Analysis and Its Applications, 5th ed.
- FRED, Federal Reserve Bank of St. Louis: MORTGAGE30US and DPSACBW027SBOG.
