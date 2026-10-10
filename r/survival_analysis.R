# survival_analysis.R
# --------------------
# Kaplan-Meier estimates (population-level survival curves, overall and
# stratified) plus a Cox Proportional Hazards model (individual-level risk
# scoring with covariates) on the BankChurners dataset.
#
# FRAMING CAVEAT, stated plainly: this is a cross-sectional snapshot dataset,
# not a longitudinal panel with exact tracked event times. months_on_book is
# used as the survival "duration" and churned (Attrited Customer) as the
# event indicator; existing customers are treated as right-censored at their
# current tenure. This is a standard, defensible practical technique for
# exactly this kind of snapshot data (sometimes called a "synthetic cohort"
# framing) -- but it is an assumption, not a fact: it assumes a customer's
# current tenure is uninformative about *when within the panel* they were
# observed, which would be violated if e.g. all data were pulled from a
# single calendar date across customers who joined at very different times
# with very different macro conditions. Real production use would ideally
# have genuine enrollment and event dates.

library(survival)
library(ggplot2)
library(DBI)
library(RSQLite)

con <- dbConnect(RSQLite::SQLite(), "bank_churn.db")
df <- dbGetQuery(con, "SELECT * FROM customers_clean")
dbDisconnect(con)

dir.create("outputs", showWarnings = FALSE)

# ---------------------------------------------------------------------------
# 1. Kaplan-Meier: overall survival curve
# ---------------------------------------------------------------------------
surv_obj <- Surv(time = df$months_on_book, event = df$churned)
km_overall <- survfit(surv_obj ~ 1, data = df)

png("outputs/km_overall.png", width = 800, height = 550)
plot(km_overall, xlab = "Tenure (months)", ylab = "Survival Probability (retained)",
     main = "Kaplan-Meier: Overall Customer Survival", col = "steelblue", lwd = 2,
     conf.int = TRUE, mark.time = FALSE)
grid()
dev.off()

cat("Median survival time (months):", summary(km_overall)$table["median"], "\n")

# ---------------------------------------------------------------------------
# 2. Kaplan-Meier stratified by contact_band (customer-service contact
#    frequency) -- identifying WHICH segment's survival curve drops earliest
#    and fastest is exactly "the window when churn is most likely", per
#    segment, not just a single population-wide number.
# ---------------------------------------------------------------------------
km_by_contact <- survfit(surv_obj ~ contact_band, data = df)

png("outputs/km_by_contact_band.png", width = 900, height = 600)
plot(km_by_contact, xlab = "Tenure (months)", ylab = "Survival Probability",
     main = "Kaplan-Meier by Service Contact Frequency (last 12mo)",
     col = 1:5, lwd = 2, mark.time = FALSE)
legend("bottomleft", legend = names(km_by_contact$strata), col = 1:5, lwd = 2, cex = 0.8)
grid()
dev.off()

# Log-rank test: are the stratified curves genuinely statistically different,
# or could the visual separation be noise? Reported, not assumed.
logrank <- survdiff(surv_obj ~ contact_band, data = df)
cat("\nLog-rank test (contact_band strata): chi-sq =", round(logrank$chisq, 2),
    ", p-value =", format.pval(1 - pchisq(logrank$chisq, length(logrank$n) - 1)), "\n")

# ---------------------------------------------------------------------------
# 3. Cox Proportional Hazards: individual-level risk scoring with covariates
#    -- this is the actual "predict WHO and roughly WHEN" model; Kaplan-Meier
#    alone only describes group-level curves, it doesn't score individuals.
# ---------------------------------------------------------------------------
df$income_category <- factor(df$income_category)
df$card_category <- factor(df$card_category)

cox_model <- coxph(surv_obj ~ total_relationship_count + months_inactive_12_mon +
                      contacts_count_12_mon + total_revolving_bal + total_trans_ct +
                      total_ct_chng_q4_q1 + avg_utilization_ratio + credit_limit +
                      income_category + card_category, data = df)

sink("outputs/cox_model_summary.txt")
print(summary(cox_model))
cat("\nProportional-hazards assumption check (Schoenfeld residuals):\n")
print(cox.zph(cox_model))
sink()

cat("\nCox model fit. Top hazard ratios (see outputs/cox_model_summary.txt for full output):\n")
hr <- exp(coef(cox_model))
print(round(sort(hr, decreasing = TRUE), 3))

# ---------------------------------------------------------------------------
# 4. Individual risk scores: predicted relative hazard per customer, written
#    back out for the CLV calculation step (04_clv_calculation.R) and for
#    the Power BI / dashboard export.
# ---------------------------------------------------------------------------
df$risk_score <- predict(cox_model, type = "risk")  # relative hazard vs. baseline
df$predicted_survival_12mo <- NA
base_surv <- survfit(cox_model)
# Individual survival probability at 12 months ahead, from each customer's
# current tenure, using their personal risk score applied to the baseline
# cumulative hazard (the standard Cox-model individual survival formula).
base_surv_fn <- stepfun(base_surv$time, c(1, base_surv$surv))
for (i in seq_len(nrow(df))) {
  t0 <- df$months_on_book[i]
  t1 <- t0 + 12
  s0 <- base_surv_fn(t0)
  s1 <- base_surv_fn(t1)
  cond_base_surv <- ifelse(s0 > 0, s1 / s0, NA)
  df$predicted_survival_12mo[i] <- cond_base_surv ^ df$risk_score[i]
}

write.csv(df[, c("clientnum", "months_on_book", "churned", "risk_score", "predicted_survival_12mo")],
          "outputs/risk_scores.csv", row.names = FALSE)

cat("\nWrote outputs/risk_scores.csv (", nrow(df), "customers ) and 2 KM plots + Cox summary.\n")
