# Banking Transaction Data Quality Analysis — Oracle SQL

## Overview
This project contains SQL-based data quality analysis for banking transaction data, built from real production experience monitoring 10,000+ daily transactions across enterprise banking applications.

Working in banking transaction operations, I dealt with data quality issues daily — missing reference fields, duplicate transactions, EOD batch failures, and month-end high-volume anomalies. This project formalizes those real-world validation patterns into a reusable SQL framework.

## Problem Statement
In production banking environments, transaction data quality issues can cause:
- Payment processing failures
- EOD batch job failures
- Reconciliation mismatches between source and processed records
- Regulatory reporting inaccuracies

This project identifies and classifies these issues using structured SQL analysis.

## Dataset
- **Source:** Public Bank Transaction Dataset (Kaggle)
- **Size:** 50,000+ transaction records
- **Fields:** transaction_id, account_id, amount, transaction_date, transaction_type, status, reference_number, error_code

## Tools Used
- Oracle SQL / MySQL
- SQL concepts: CTEs, Window Functions, Joins, Subqueries, CASE statements, GROUP BY, HAVING

## Key Findings
- ~8% of transactions had missing or malformed reference number fields
- Duplicate transactions detected in same-day same-amount same-account combinations
- Month-start (days 1-3) and month-end (days 28-31) showed highest failure rates
- Data quality failures classified into 5 categories: Insufficient Funds, Invalid Account, Duplicate, Data Error, Unknown

## Project Structure
```
project1_sql/
│
├── banking_transaction_analysis.sql    # All SQL queries with comments
└── README.md                           # Project documentation
```

## SQL Concepts Covered
| Concept | Where Used |
|---|---|
| CTEs (WITH clause) | Duplicate detection, anomaly detection |
| Window Functions | Running totals, ranking, LAG/LEAD, moving averages |
| CASE statements | Failure classification, status labeling |
| Correlated Subqueries | Account-level statistics |
| GROUP BY + HAVING | Aggregation and filtering |
| JOINS | Reconciliation between source and processed tables |
| NULLIF / COALESCE | Safe division, null handling |

## How to Run
1. Download the Kaggle Bank Transaction dataset
2. Load into MySQL or Oracle SQL database
3. Run queries section by section in any SQL client (MySQL Workbench, DBeaver, SQL Developer)

## Author
Diksha Mulik | Data Analyst | [LinkedIn](your-linkedin-url)
