DROP TABLE IF EXISTS customers_clean;
CREATE TABLE customers_clean AS
SELECT
    clientnum,
    CASE WHEN attrition_flag = 'Attrited Customer' THEN 1 ELSE 0 END AS churned,
    customer_age, gender, dependent_count, education_level, marital_status,
    income_category, card_category, months_on_book, total_relationship_count,
    months_inactive_12_mon, contacts_count_12_mon, credit_limit, total_revolving_bal,
    avg_open_to_buy, total_amt_chng_q4_q1, total_trans_amt, total_trans_ct,
    total_ct_chng_q4_q1, avg_utilization_ratio,
    CASE WHEN months_on_book < 24 THEN '0-2 yrs' WHEN months_on_book < 48 THEN '2-4 yrs'
         WHEN months_on_book < 60 THEN '4-5 yrs' ELSE '5+ yrs' END AS tenure_band,
    CASE WHEN contacts_count_12_mon = 0 THEN '0 contacts' WHEN contacts_count_12_mon <= 2 THEN '1-2 contacts'
         WHEN contacts_count_12_mon = 3 THEN '3 contacts' WHEN contacts_count_12_mon = 4 THEN '4 contacts'
         ELSE '5+ contacts' END AS contact_band
FROM raw_bank_churners;
CREATE INDEX idx_customers_clean_tenure ON customers_clean(tenure_band);
CREATE INDEX idx_customers_clean_contact ON customers_clean(contact_band);
