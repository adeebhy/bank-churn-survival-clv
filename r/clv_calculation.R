# clv_calculation.R -- combines Cox survival predictions with a revenue proxy.
# REVENUE PROXY (disclosed assumption, dataset has no P&L): annual revenue =
# 1.5% interchange on card spend + 12% net yield on revolving balance.
library(DBI); library(RSQLite)
con <- dbConnect(RSQLite::SQLite(), "bank_churn.db")
cust <- dbGetQuery(con, "SELECT * FROM customers_clean"); dbDisconnect(con)
risk <- read.csv("outputs/risk_scores.csv")
df <- merge(cust, risk[, c("clientnum", "risk_score", "predicted_survival_12mo")], by = "clientnum")

DISCOUNT <- 0.10; HORIZON <- 5; CAMPAIGN_SUCCESS <- 0.30
df$annual_revenue <- 0.015 * df$total_trans_amt + 0.12 * df$total_revolving_bal
p <- pmin(pmax(df$predicted_survival_12mo, 0.001), 0.999)
df$clv <- df$annual_revenue * sapply(p, function(pp) sum((pp / (1 + DISCOUNT))^(1:HORIZON)))
df$at_risk_revenue_12mo <- df$annual_revenue * (1 - p)
df$max_justified_retention_spend <- (df$clv / p) * (1 - p) * CAMPAIGN_SUCCESS * 0.5  # conservative cap
df$risk_tier <- cut(1 - p, breaks = c(-Inf, 0.15, 0.30, Inf), labels = c("Low", "Medium", "High"))

write.csv(df, "outputs/customer_clv.csv", row.names = FALSE)
active <- df[df$churned == 0, ]
cat("Active customers:", nrow(active), "\n")
cat("Total 12mo at-risk revenue (active):", round(sum(active$at_risk_revenue_12mo)), "\n")
print(aggregate(cbind(n = 1, at_risk = at_risk_revenue_12mo, clv = clv) ~ risk_tier, data = active, FUN = sum))
