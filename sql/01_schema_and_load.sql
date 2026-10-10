-- 01_schema_and_load.sql
-- ------------------------
-- Loads the raw BankChurners CSV (10,127 credit card customers, real Kaggle
-- dataset, originally published by LEAPS Analyttica) into a raw staging
-- table, exactly as-is, then builds a cleaned analysis table.
--
-- KNOWN DATA QUIRK, handled explicitly: the raw CSV ships with two trailing
-- columns ("Naive_Bayes_Classifier_Attrition_Flag_...") that are leaked
-- output from an unrelated third party's Naive Bayes model, not genuine
-- customer attributes. This is a well-documented quirk of this specific
-- public dataset. They are dropped here rather than silently included as if
-- they were real features -- keeping them would let a churn model "cheat"
-- by reading another model's already-computed churn prediction.

DROP TABLE IF EXISTS raw_bank_churners;
CREATE TABLE raw_bank_churners (
    clientnum INTEGER PRIMARY KEY,
    attrition_flag TEXT,
    customer_age INTEGER,
    gender TEXT,
    dependent_count INTEGER,
    education_level TEXT,
    marital_status TEXT,
    income_category TEXT,
    card_category TEXT,
    months_on_book INTEGER,
    total_relationship_count INTEGER,
    months_inactive_12_mon INTEGER,
    contacts_count_12_mon INTEGER,
    credit_limit REAL,
    total_revolving_bal REAL,
    avg_open_to_buy REAL,
    total_amt_chng_q4_q1 REAL,
    total_trans_amt REAL,
    total_trans_ct INTEGER,
    total_ct_chng_q4_q1 REAL,
    avg_utilization_ratio REAL
    -- the two leaked Naive Bayes columns are deliberately NOT declared here
    -- an explicit schema is itself a data-quality control, not just documentation
);

-- Cleaned analysis table: standardizes categorical text, adds the
-- survival-analysis fields (duration + event indicator) up front so every
-- downstream query/script reads from one already-correct source rather than
-- re-deriving the churn/censoring logic in multiple places.
DROP TABLE IF EXISTS customers_clean;
CREATE TABLE customers_clean AS
SELECT
    clientnum,
    CASE WHEN attrition_flag = 'Attrited Customer' THEN 1 ELSE 0 END AS churned,
    customer_age,
    gender,
    dependent_count,
    education_level,
    marital_status,
    income_category,
    card_category,
    months_on_book,                         -- used as the survival "duration" (see r/ scripts for the framing caveat)
    total_relationship_count,
    months_inactive_12_mon,
    contacts_count_12_mon,
    credit_limit,
    total_revolving_bal,
    avg_open_to_buy,
    total_amt_chng_q4_q1,
    total_trans_amt,
    total_trans_ct,
    total_ct_chng_q4_q1,
    avg_utilization_ratio,
    -- Segmentation buckets used throughout the SQL wrangling and dashboard layers
    CASE
        WHEN months_on_book < 24 THEN '0-2 yrs'
        WHEN months_on_book < 48 THEN '2-4 yrs'
        WHEN months_on_book < 60 THEN '4-5 yrs'
        ELSE '5+ yrs'
    END AS tenure_band,
    CASE
        WHEN contacts_count_12_mon = 0 THEN '0 contacts'
        WHEN contacts_count_12_mon <= 2 THEN '1-2 contacts'
        WHEN contacts_count_12_mon = 3 THEN '3 contacts'
        WHEN contacts_count_12_mon = 4 THEN '4 contacts'
        ELSE '5+ contacts'
    END AS contact_band
FROM raw_bank_churners;

CREATE INDEX idx_customers_clean_tenure ON customers_clean(tenure_band);
CREATE INDEX idx_customers_clean_contact ON customers_clean(contact_band);
