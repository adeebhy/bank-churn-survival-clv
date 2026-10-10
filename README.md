# Retail Banking Customer Churn & Lifetime Value (CLV) Optimization

Survival analysis on 10,127 real credit-card customers (Kaggle "BankChurners") to predict **who** is
likely to churn, **roughly when**, and **how much revenue is at risk / worth spending to retain**.

**Stack:** SQL (SQLite) for wrangling · R (`survival`) for Kaplan-Meier + Cox PH · Power BI-ready export + HTML dashboard.

## Pipeline
```
python3 load_data.py            # CSV -> SQLite, drops 2 leaked Naive-Bayes columns, builds customers_clean
Rscript r/survival_analysis.R   # Kaplan-Meier, log-rank test, Cox PH, per-customer risk scores
Rscript r/clv_calculation.R     # CLV, at-risk revenue, retention-spend ceiling, risk tiers
python3 dashboard/build_dashboard.py   # Power BI star-schema CSVs + executive_dashboard.html
```
Requires R with `survival`, `ggplot2`, `DBI`, `RSQLite`; Python with `pandas`, `matplotlib`.

## Results (real data)
| Metric | Value |
|---|---|
| Customers / churned | 10,127 / 1,627 (16.1%) |
| Median survival | 56 months |
| Log-rank test, service-contact bands | chi-sq 344.7, p < 2.2e-16 |
| Strongest protective factor (Cox HR) | rising transaction count (Q4/Q1): **0.27** |
| More product relationships | HR 0.79 per extra product |
| More service contacts (12mo) | HR 1.31 per extra contact |
| 12-mo revenue at risk (8,500 active customers) | ~180K (revenue proxy units) |

**Answer to the core question:** Kaplan-Meier shows *when* each segment's survival curve drops; the Cox
model scores *each customer*. Customers with many service contacts and falling transaction counts have the
earliest/steepest curves. It identifies a risk **window and ranking**, not an exact churn date.

## Honest limitations
1. **Snapshot, not panel data.** `months_on_book` is used as duration, existing customers as right-censored.
   A standard practical framing, but an assumption - real use needs enrollment/event dates.
2. **Revenue is a proxy** (1.5% interchange on spend + 12% yield on revolving balance). The dataset has no
   P&L, so CLV and at-risk revenue are illustrative; replace with the bank's real margin data.
3. **Retention-spend ceiling** uses an assumed 30% campaign success rate and a conservative 0.5 haircut.
4. **Proportional-hazards assumption** was tested (`cox.zph` in `outputs/cox_model_summary.txt`) - check it
   before relying on hazard ratios; violations mean effects vary over tenure.
5. **No out-of-sample validation yet** (no train/test split or concordance on held-out data) - a clear next step.
6. **Power BI:** Power BI Desktop (.pbix) can't be produced in this Linux environment. `powerbi_export/` holds
   a ready star schema (`fact_customer_risk`, `dim_customer`, `agg_segment_at_risk`) to import and build the
   report in minutes; `dashboard/executive_dashboard.html` is a working substitute built from the same data.
7. Dataset quirk handled: two leaked "Naive_Bayes_Classifier..." columns are dropped.
