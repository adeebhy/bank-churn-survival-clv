"""Builds Power BI-ready star-schema CSVs + a self-contained HTML executive dashboard."""
import pandas as pd, matplotlib, base64, io
matplotlib.use("Agg"); import matplotlib.pyplot as plt
df = pd.read_csv("outputs/customer_clv.csv")
active = df[df.churned == 0].copy()

# --- Power BI star schema ---
fact = df[["clientnum","churned","months_on_book","risk_score","predicted_survival_12mo","annual_revenue",
           "clv","at_risk_revenue_12mo","max_justified_retention_spend","risk_tier"]]
dim = df[["clientnum","customer_age","gender","income_category","card_category","education_level",
          "marital_status","tenure_band","contact_band"]]
seg = (active.groupby(["card_category","risk_tier"], observed=True)
       .agg(customers=("clientnum","count"), at_risk_revenue=("at_risk_revenue_12mo","sum"), clv=("clv","sum"))
       .reset_index())
fact.to_csv("powerbi_export/fact_customer_risk.csv", index=False)
dim.to_csv("powerbi_export/dim_customer.csv", index=False)
seg.to_csv("powerbi_export/agg_segment_at_risk.csv", index=False)

def b64(fig):
    buf = io.BytesIO(); fig.savefig(buf, format="png", dpi=110, bbox_inches="tight"); plt.close(fig)
    return base64.b64encode(buf.getvalue()).decode()

order = ["Low","Medium","High"]
t = active.groupby("risk_tier")["at_risk_revenue_12mo"].sum().reindex(order)
f1, a = plt.subplots(figsize=(5,3.4)); a.bar(order, t.values, color=["#2ca02c","#ff7f0e","#d62728"])
a.set_ylabel("12-mo at-risk revenue"); a.set_title("At-Risk Revenue by Risk Tier")
c = active.groupby("card_category")["at_risk_revenue_12mo"].sum().sort_values()
f2, a = plt.subplots(figsize=(5,3.4)); a.barh(c.index, c.values, color="#1f77b4"); a.set_title("At-Risk Revenue by Card")
top = active.nlargest(15, "at_risk_revenue_12mo")
f3, a = plt.subplots(figsize=(5,3.4)); a.scatter(active.clv, active.at_risk_revenue_12mo, s=4, alpha=.3)
a.set_xlabel("CLV"); a.set_ylabel("12-mo at-risk revenue"); a.set_title("CLV vs At-Risk Revenue")
imgs = [b64(f) for f in (f1, f2, f3)]
kpi = lambda l, v: f"<div class=k><div class=v>{v}</div><div>{l}</div></div>"
html = f"""<html><head><title>Churn & CLV Executive Dashboard</title><style>
body{{font-family:Segoe UI,Arial;margin:24px;background:#f4f6f8}}h1{{margin:0 0 4px}}
.row{{display:flex;gap:14px;flex-wrap:wrap}}.k{{background:#fff;padding:14px 22px;border-radius:8px;box-shadow:0 1px 3px #0002}}
.v{{font-size:26px;font-weight:700;color:#0b5394}}img{{background:#fff;border-radius:8px;padding:6px}}</style></head><body>
<h1>Retail Banking Churn & CLV - Executive Dashboard</h1>
<p>Substitute for a Power BI report (built from the same tables in powerbi_export/). Revenue = proxy, see README.</p>
<div class=row>{kpi("Active customers", f"{len(active):,}")}{kpi("Observed churn rate", f"{df.churned.mean()*100:.1f}%")}
{kpi("12-mo revenue at risk", f"{active.at_risk_revenue_12mo.sum():,.0f}")}
{kpi("High-risk customers", f"{(active.risk_tier=='High').sum():,}")}
{kpi("Max justified retention spend (High tier)", f"{active[active.risk_tier=='High'].max_justified_retention_spend.sum():,.0f}")}</div><br>
<div class=row>{''.join(f'<img src="data:image/png;base64,{i}">' for i in imgs)}</div>
<h3>Top 15 customers by at-risk revenue</h3>{top[["clientnum","card_category","income_category","annual_revenue","predicted_survival_12mo","at_risk_revenue_12mo"]].round(3).to_html(index=False)}
</body></html>"""
open("dashboard/executive_dashboard.html","w").write(html)
print("built:", len(fact), "fact rows,", len(seg), "segment rows")
