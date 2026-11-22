# =============================================================================
# ARIMA forecasts for the Chronos-2 vs ARIMA comparison
#   Series : MORTGAGE30US (30-year mortgage rate) and DPSACBW027SBOG (deposits)
#   Design : 8 non-overlapping 13-week windows over the last 104 weeks,
#            expanding history from Jan 2000 (see output/evaluation_windows.csv)
#   Method : Shumway & Stoffer Ch. 3 -- identify on window-1 history,
#            check residuals, then re-estimate coefficients at each origin.
#
# Uses base R only (stats + graphics). Run from the project folder:
#   Rscript arima_forecasts.R
#
# Inputs : data/MORTGAGE30US.csv, data/Deposits.csv, output/evaluation_windows.csv
# Outputs: output/forecasts_arima.csv       (same columns as forecasts_chronos.csv)
#          output/forecasts_naive.csv
#          output/metrics_arima_naive.csv
#          output/arima_model_summary.txt
#          output/arima_identification_<series>.png
#          output/arima_residuals_<series>.png
#          output/arima_forecasts_<series>.png
# =============================================================================

# ---- Settings ---------------------------------------------------------------
HISTORY_START <- as.Date("2000-01-01")
H             <- 13          # forecast horizon (weeks)
Z80           <- qnorm(0.90) # 1.2816 -> 80% interval = forecast +/- 1.28 SE

# Orders chosen from the window-1 identification (see section 3 below).
# include_drift = TRUE adds a constant to the differenced series (= linear trend
# in levels), which deposits need and the mortgage rate does not.
SPECS <- list(
  mortgage30 = list(file = "data/MORTGAGE30US.csv", label = "30-year mortgage rate (%)",
                    order = c(2, 1, 0), include_drift = FALSE),
  deposits   = list(file = "data/Deposits.csv",     label = "Commercial bank deposits ($bn)",
                    order = c(6, 1, 0), include_drift = TRUE)
)

# FALSE (default): keep the same (p,d,q) in all 8 windows, re-estimate coefficients.
# TRUE           : re-select (p,q) by BIC at every origin (d and drift kept fixed).
RESELECT_ORDERS <- FALSE

dir.create("output", showWarnings = FALSE)

# ---- 1. Helpers -------------------------------------------------------------
read_fred <- function(file) {
  d <- read.csv(file, stringsAsFactors = FALSE)
  names(d) <- c("date", "value")
  d$date  <- as.Date(d$date)
  d$value <- as.numeric(d$value)
  d <- d[!is.na(d$value) & d$date >= HISTORY_START, ]
  d[order(d$date), ]
}

# Fit ARIMA on the original scale. Drift is a time-index regressor: with d = 1,
# arima() differences it too, so its coefficient is the mean weekly change.
fit_arima <- function(y, order, include_drift) {
  if (include_drift) {
    arima(y, order = order, xreg = seq_along(y), method = "ML")
  } else {
    arima(y, order = order, method = "ML")
  }
}

forecast_arima <- function(fit, n, h, include_drift) {
  p <- if (include_drift) predict(fit, n.ahead = h, newxreg = (n + 1):(n + h))
       else                predict(fit, n.ahead = h)
  data.frame(forecast = as.numeric(p$pred),
             lo80     = as.numeric(p$pred - Z80 * p$se),
             hi80     = as.numeric(p$pred + Z80 * p$se))
}

# BIC grid search over p, q with d and drift fixed (used only if RESELECT_ORDERS)
select_order <- function(y, d, include_drift, max_p = 6, max_q = 2) {
  best <- NULL; best_bic <- Inf
  for (p in 0:max_p) for (q in 0:max_q) {
    f <- tryCatch(suppressWarnings(fit_arima(y, c(p, d, q), include_drift)),
                  error = function(e) NULL)
    if (!is.null(f) && BIC(f) < best_bic) { best_bic <- BIC(f); best <- c(p, d, q) }
  }
  best
}

# Ljung-Box p-values at several lags (fitdf = number of ARMA coefficients)
ljung_box_table <- function(res, k, lags = c(10, 20, 30)) {
  data.frame(lag = lags,
             Q = sapply(lags, function(L) Box.test(res, L, "Ljung-Box", fitdf = k)$statistic),
             p_value = sapply(lags, function(L) Box.test(res, L, "Ljung-Box", fitdf = k)$p.value))
}

# ---- 2. Load data and windows ----------------------------------------------
windows <- read.csv("output/evaluation_windows.csv", stringsAsFactors = FALSE)
windows$origin         <- as.Date(windows$origin)
windows$first_forecast <- as.Date(windows$first_forecast)
windows$last_forecast  <- as.Date(windows$last_forecast)

data_list <- lapply(SPECS, function(s) read_fred(s$file))

# Sanity checks: every origin is in the data and the next 13 rows match the
# window's first and last forecast dates.
for (s in names(SPECS)) {
  d <- data_list[[s]]; w <- windows[windows$series == s, ]
  stopifnot(nrow(w) == 8)
  for (i in seq_len(nrow(w))) {
    k <- match(w$origin[i], d$date)
    if (is.na(k)) stop(s, ": origin ", w$origin[i], " not found in data")
    if (d$date[k + 1] != w$first_forecast[i] || d$date[k + H] != w$last_forecast[i])
      stop(s, " window ", w$window[i], ": forecast dates do not match evaluation_windows.csv")
  }
}

sink_file <- "output/arima_model_summary.txt"
cat("ARIMA model summary\nGenerated:", format(Sys.time()), "\n\n", file = sink_file)
log_txt <- function(...) cat(..., file = sink_file, append = TRUE)
log_out <- function(x, ...) cat(capture.output(print(x, ...)), sep = "\n", file = sink_file, append = TRUE)

# ---- 3. Identification on window-1 history ---------------------------------
for (s in names(SPECS)) {
  spec <- SPECS[[s]]; d <- data_list[[s]]
  o1   <- windows$origin[windows$series == s & windows$window == 1]
  y    <- d$value[d$date <= o1]
  dy   <- diff(y)

  png(sprintf("output/arima_identification_%s.png", s), width = 1100, height = 800, res = 110)
  par(mfrow = c(2, 2), mar = c(4, 4, 3, 1))
  plot(d$date[d$date <= o1], y, type = "l", xlab = "", ylab = spec$label,
       main = paste(spec$label, "- window 1 history"))
  plot(d$date[d$date <= o1][-1], dy, type = "l", xlab = "", ylab = "First difference",
       main = "First difference")
  abline(h = 0, col = "grey50")
  acf(dy,  lag.max = 52, main = "ACF of first difference")
  pacf(dy, lag.max = 52, main = "PACF of first difference")
  dev.off()

  log_txt("=====================================================================\n")
  log_txt("Series:", s, "| window-1 history:", format(min(d$date)), "to", format(o1),
          "|", length(y), "weeks\n")
  log_txt("Mean weekly change:", round(mean(dy), 4), " SD:", round(sd(dy), 4), "\n")
  log_txt("ACF of differences, lags 1-12:\n");  log_out(round(acf(dy, 12, plot = FALSE)$acf[2:13], 3))
  log_txt("PACF of differences, lags 1-12:\n"); log_out(round(pacf(dy, 12, plot = FALSE)$acf[1:12], 3))
  log_txt("Approx. 95% band: +/-", round(2 / sqrt(length(dy)), 3), "\n\n")

  # Candidate comparison (for the write-up): BIC of ARIMA(p,1,q), p<=6, q<=2
  cand <- NULL
  for (p in 0:6) for (q in 0:2) {
    f <- tryCatch(suppressWarnings(fit_arima(y, c(p, 1, q), spec$include_drift)),
                  error = function(e) NULL)
    if (!is.null(f)) cand <- rbind(cand, data.frame(p = p, d = 1, q = q,
                                                    AIC = round(AIC(f), 1), BIC = round(BIC(f), 1)))
  }
  log_txt("Candidate models on window-1 history (sorted by BIC, top 8):\n")
  log_out(head(cand[order(cand$BIC), ], 8))

  # Chosen model: coefficients and residual diagnostics
  fit <- fit_arima(y, spec$order, spec$include_drift)
  res <- residuals(fit)
  k   <- spec$order[1] + spec$order[3]
  log_txt(sprintf("\nChosen model: ARIMA(%d,%d,%d)%s\n", spec$order[1], spec$order[2],
                  spec$order[3], if (spec$include_drift) " with drift" else ""))
  log_out(fit)
  log_txt("\nLjung-Box test on residuals:\n"); log_out(ljung_box_table(res, k))
  log_txt("\n")

  png(sprintf("output/arima_residuals_%s.png", s), width = 1100, height = 800, res = 110)
  par(mfrow = c(2, 2), mar = c(4, 4, 3, 1))
  plot(d$date[d$date <= o1], res, type = "l", xlab = "", ylab = "Residual",
       main = sprintf("Residuals, ARIMA(%s)", paste(spec$order, collapse = ",")))
  abline(h = 0, col = "grey50")
  acf(res, lag.max = 52, main = "ACF of residuals")
  lb_p <- sapply(1:30, function(L) if (L > k) Box.test(res, L, "Ljung-Box", fitdf = k)$p.value else NA)
  plot(1:30, lb_p, ylim = c(0, 1), pch = 19, xlab = "Lag", ylab = "p-value",
       main = "Ljung-Box p-values")
  abline(h = 0.05, lty = 2, col = "blue")
  qqnorm(res, main = "Normal Q-Q of residuals"); qqline(res)
  dev.off()
}

# ---- 4. Rolling-origin forecasts -------------------------------------------
fc_arima <- list(); fc_naive <- list()

for (s in names(SPECS)) {
  spec <- SPECS[[s]]; d <- data_list[[s]]
  w    <- windows[windows$series == s, ]
  w    <- w[order(w$window), ]

  for (i in seq_len(nrow(w))) {
    k      <- match(w$origin[i], d$date)
    y      <- d$value[1:k]                    # all data from 2000 up to the origin
    future <- d[(k + 1):(k + H), ]

    ord <- if (RESELECT_ORDERS) select_order(y, spec$order[2], spec$include_drift) else spec$order
    fit <- fit_arima(y, ord, spec$include_drift)
    fc  <- forecast_arima(fit, length(y), H, spec$include_drift)

    fc_arima[[length(fc_arima) + 1]] <- data.frame(
      series = s, model = "arima", window = w$window[i], origin = w$origin[i],
      timestamp = future$date, h = 1:H, actual = future$value,
      forecast = fc$forecast, lo80 = fc$lo80, hi80 = fc$hi80)

    fc_naive[[length(fc_naive) + 1]] <- data.frame(
      series = s, model = "naive", window = w$window[i], origin = w$origin[i],
      timestamp = future$date, h = 1:H, actual = future$value,
      forecast = y[length(y)], lo80 = NA, hi80 = NA)

    log_txt(sprintf("%s window %d (origin %s, n = %d): ARIMA(%s)  coef: %s\n",
                    s, w$window[i], format(w$origin[i]), length(y), paste(ord, collapse = ","),
                    paste(sprintf("%s=%.4f", names(coef(fit)), coef(fit)), collapse = " ")))
  }
  log_txt("\n")
}

fc_arima <- do.call(rbind, fc_arima)
fc_naive <- do.call(rbind, fc_naive)
write.csv(fc_arima, "output/forecasts_arima.csv", row.names = FALSE)
write.csv(fc_naive, "output/forecasts_naive.csv", row.names = FALSE)

# ---- 5. Metrics -------------------------------------------------------------
metrics <- function(df, naive_df) {
  out <- NULL
  for (s in unique(df$series)) {
    a <- df[df$series == s, ]; n <- naive_df[naive_df$series == s, ]
    e  <- a$actual - a$forecast
    en <- n$actual - n$forecast
    out <- rbind(out, data.frame(
      series   = s, model = a$model[1], n_errors = length(e),
      MAE      = mean(abs(e)),
      RMSE     = sqrt(mean(e^2)),
      rel_MAE  = mean(abs(e)) / mean(abs(en)),
      coverage80 = if (all(is.na(a$lo80))) NA else mean(a$actual >= a$lo80 & a$actual <= a$hi80)))
  }
  out
}
met <- rbind(metrics(fc_arima, fc_naive), metrics(fc_naive, fc_naive))
met <- met[order(met$series, met$model), ]
write.csv(met, "output/metrics_arima_naive.csv", row.names = FALSE)

log_txt("Accuracy over the 104 test weeks:\n"); log_out(met, row.names = FALSE)
print(met, row.names = FALSE)

# ---- 6. Forecast plots ------------------------------------------------------
for (s in names(SPECS)) {
  spec <- SPECS[[s]]; d <- data_list[[s]]
  a    <- fc_arima[fc_arima$series == s, ]
  show <- d[d$date >= min(a$origin) - 7 * 52, ]   # one year before the test period

  png(sprintf("output/arima_forecasts_%s.png", s), width = 1200, height = 650, res = 110)
  par(mar = c(4, 4, 3, 1))
  plot(show$date, show$value, type = "l", lwd = 1.5,
       ylim = range(c(show$value, a$lo80, a$hi80)), xlab = "", ylab = spec$label,
       main = sprintf("%s: ARIMA(%s) forecasts with 80%% intervals", spec$label,
                      paste(spec$order, collapse = ",")))
  for (wi in unique(a$window)) {
    b <- a[a$window == wi, ]
    polygon(c(b$timestamp, rev(b$timestamp)), c(b$lo80, rev(b$hi80)),
            col = adjustcolor("steelblue", 0.25), border = NA)
    lines(b$timestamp, b$forecast, col = "steelblue", lwd = 2)
  }
  abline(v = unique(a$origin), lty = 3, col = "grey60")
  legend("topleft", c("Actual", "ARIMA forecast", "80% interval"), bty = "n",
         col = c("black", "steelblue", adjustcolor("steelblue", 0.4)),
         lwd = c(1.5, 2, 8))
  dev.off()
}

cat("\nDone. Files written to output/.\n")
