"""
load_data.py
------------
Loads BankChurners.csv into SQLite, applying the schema in
sql/01_schema_and_load.sql. Drops the two leaked Naive Bayes columns before
insertion; the data model and wrangling live in .sql files.
"""
import sqlite3
import csv
import os

DB_PATH = "bank_churn.db"
CSV_PATH = "data/BankChurners.csv"

COLUMNS = [
    "clientnum", "attrition_flag", "customer_age", "gender", "dependent_count",
    "education_level", "marital_status", "income_category", "card_category",
    "months_on_book", "total_relationship_count", "months_inactive_12_mon",
    "contacts_count_12_mon", "credit_limit", "total_revolving_bal", "avg_open_to_buy",
    "total_amt_chng_q4_q1", "total_trans_amt", "total_trans_ct", "total_ct_chng_q4_q1",
    "avg_utilization_ratio",
]


def main():
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    cur.execute("DROP TABLE IF EXISTS raw_bank_churners")
    cur.execute("""CREATE TABLE raw_bank_churners (
        clientnum INTEGER PRIMARY KEY, attrition_flag TEXT, customer_age INTEGER,
        gender TEXT, dependent_count INTEGER, education_level TEXT, marital_status TEXT,
        income_category TEXT, card_category TEXT, months_on_book INTEGER,
        total_relationship_count INTEGER, months_inactive_12_mon INTEGER,
        contacts_count_12_mon INTEGER, credit_limit REAL, total_revolving_bal REAL,
        avg_open_to_buy REAL, total_amt_chng_q4_q1 REAL, total_trans_amt REAL,
        total_trans_ct INTEGER, total_ct_chng_q4_q1 REAL, avg_utilization_ratio REAL)""")
    conn.commit()

    with open(CSV_PATH, newline="", encoding="utf-8-sig") as f:
        reader = csv.reader(f)
        next(reader)
        rows = [row[:21] for row in reader]

    placeholders = ",".join(["?"] * len(COLUMNS))
    cur.executemany(f"INSERT INTO raw_bank_churners VALUES ({placeholders})", rows)
    conn.commit()
    print(f"Loaded {len(rows)} rows into raw_bank_churners.")

    with open("sql/02_build_clean_table.sql") as f:
        cur.executescript(f.read())
    conn.commit()

    n_clean = cur.execute("SELECT COUNT(*) FROM customers_clean").fetchone()[0]
    n_churned = cur.execute("SELECT SUM(churned) FROM customers_clean").fetchone()[0]
    print(f"customers_clean: {n_clean} rows, {n_churned} churned ({n_churned/n_clean*100:.1f}%).")
    conn.close()


if __name__ == "__main__":
    main()
