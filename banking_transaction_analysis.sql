-- ============================================================
-- Banking Transaction Data Quality Analysis
-- Author: Diksha Mulik
-- Tools: Oracle SQL / MySQL
-- Dataset: Public Bank Transaction Dataset (Kaggle)
-- Description: SQL-based data quality analysis inspired by
-- real production challenges in banking transaction pipelines
-- ============================================================


-- ============================================================
-- SECTION 1: BASIC DATA EXPLORATION
-- ============================================================

-- 1.1 Total transaction count
SELECT COUNT(*) AS total_transactions
FROM transactions;

-- 1.2 Transaction summary by type
SELECT 
    transaction_type,
    COUNT(*) AS total_count,
    SUM(amount) AS total_amount,
    ROUND(AVG(amount), 2) AS avg_amount,
    MIN(amount) AS min_amount,
    MAX(amount) AS max_amount
FROM transactions
GROUP BY transaction_type
ORDER BY total_count DESC;

-- 1.3 Daily transaction volume trend
SELECT 
    transaction_date,
    COUNT(*) AS daily_count,
    SUM(amount) AS daily_amount
FROM transactions
GROUP BY transaction_date
ORDER BY transaction_date;


-- ============================================================
-- SECTION 2: DATA QUALITY CHECKS
-- ============================================================

-- 2.1 Check for NULL values in critical fields
SELECT 
    COUNT(*) AS total_rows,
    SUM(CASE WHEN transaction_id IS NULL THEN 1 ELSE 0 END) AS null_transaction_id,
    SUM(CASE WHEN account_id IS NULL THEN 1 ELSE 0 END) AS null_account_id,
    SUM(CASE WHEN amount IS NULL THEN 1 ELSE 0 END) AS null_amount,
    SUM(CASE WHEN transaction_date IS NULL THEN 1 ELSE 0 END) AS null_date,
    SUM(CASE WHEN transaction_type IS NULL THEN 1 ELSE 0 END) AS null_type,
    SUM(CASE WHEN reference_number IS NULL THEN 1 ELSE 0 END) AS null_reference
FROM transactions;

-- 2.2 Find transactions with missing or malformed reference numbers
-- (Inspired by real production issue: ~8% transactions had missing reference fields)
SELECT 
    transaction_id,
    account_id,
    amount,
    transaction_date,
    reference_number,
    CASE 
        WHEN reference_number IS NULL THEN 'Missing Reference'
        WHEN LENGTH(TRIM(reference_number)) = 0 THEN 'Empty Reference'
        WHEN reference_number NOT REGEXP '^[A-Za-z0-9-]+$' THEN 'Malformed Reference'
        ELSE 'Valid'
    END AS reference_status
FROM transactions
WHERE reference_number IS NULL 
   OR LENGTH(TRIM(reference_number)) = 0
   OR reference_number NOT REGEXP '^[A-Za-z0-9-]+$';

-- 2.3 Percentage of transactions with data quality issues
SELECT 
    ROUND(
        COUNT(CASE WHEN reference_number IS NULL OR LENGTH(TRIM(reference_number)) = 0 THEN 1 END) * 100.0 
        / COUNT(*), 2
    ) AS pct_missing_reference,
    ROUND(
        COUNT(CASE WHEN amount <= 0 THEN 1 END) * 100.0 
        / COUNT(*), 2
    ) AS pct_invalid_amount,
    ROUND(
        COUNT(CASE WHEN transaction_date IS NULL THEN 1 END) * 100.0 
        / COUNT(*), 2
    ) AS pct_missing_date
FROM transactions;


-- ============================================================
-- SECTION 3: DUPLICATE DETECTION
-- ============================================================

-- 3.1 Find exact duplicate transactions
SELECT 
    account_id,
    amount,
    transaction_date,
    transaction_type,
    reference_number,
    COUNT(*) AS duplicate_count
FROM transactions
GROUP BY account_id, amount, transaction_date, transaction_type, reference_number
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- 3.2 Find duplicate transaction IDs (should never happen)
SELECT 
    transaction_id,
    COUNT(*) AS occurrence_count
FROM transactions
GROUP BY transaction_id
HAVING COUNT(*) > 1;

-- 3.3 Identify potential duplicate transactions within same day
-- (Same account, same amount, same day - suspicious)
WITH potential_dupes AS (
    SELECT 
        account_id,
        amount,
        transaction_date,
        COUNT(*) AS same_day_count,
        GROUP_CONCAT(transaction_id) AS transaction_ids
    FROM transactions
    GROUP BY account_id, amount, transaction_date
    HAVING COUNT(*) > 1
)
SELECT 
    pd.*,
    t.transaction_type,
    t.reference_number
FROM potential_dupes pd
JOIN transactions t ON t.account_id = pd.account_id 
    AND t.amount = pd.amount 
    AND t.transaction_date = pd.transaction_date
ORDER BY pd.same_day_count DESC;


-- ============================================================
-- SECTION 4: EOD BATCH FAILURE PATTERN ANALYSIS
-- ============================================================

-- 4.1 Classify transactions by processing status
-- (Mirrors EOD batch monitoring done in production)
SELECT 
    transaction_date,
    transaction_type,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) AS successful,
    SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) AS failed,
    SUM(CASE WHEN status = 'PENDING' THEN 1 ELSE 0 END) AS pending,
    ROUND(
        SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2
    ) AS failure_rate_pct
FROM transactions
GROUP BY transaction_date, transaction_type
ORDER BY failure_rate_pct DESC;

-- 4.2 Identify recurring failure patterns using CASE classification
SELECT 
    CASE 
        WHEN status = 'FAILED' AND error_code = 'INSUFF_FUNDS' THEN 'Insufficient Funds'
        WHEN status = 'FAILED' AND error_code = 'INVALID_ACCT' THEN 'Invalid Account'
        WHEN status = 'FAILED' AND error_code = 'DUPLICATE' THEN 'Duplicate Transaction'
        WHEN status = 'FAILED' AND error_code = 'DATA_ERROR' THEN 'Data Quality Issue'
        WHEN status = 'FAILED' AND error_code IS NULL THEN 'Unknown Failure'
        WHEN status = 'PENDING' THEN 'Stuck in Processing'
        ELSE 'Processed Successfully'
    END AS failure_category,
    COUNT(*) AS transaction_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM transactions
GROUP BY failure_category
ORDER BY transaction_count DESC;

-- 4.3 Month-start and month-end high volume analysis
-- (Critical period when most job failures occur)
SELECT 
    EXTRACT(DAY FROM transaction_date) AS day_of_month,
    COUNT(*) AS transaction_volume,
    SUM(amount) AS total_amount,
    SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) AS failed_count,
    CASE 
        WHEN EXTRACT(DAY FROM transaction_date) <= 3 THEN 'Month Start'
        WHEN EXTRACT(DAY FROM transaction_date) >= 28 THEN 'Month End'
        ELSE 'Mid Month'
    END AS period_type
FROM transactions
GROUP BY EXTRACT(DAY FROM transaction_date)
ORDER BY day_of_month;


-- ============================================================
-- SECTION 5: ACCOUNT ANALYSIS
-- ============================================================

-- 5.1 Top 10 accounts by transaction volume
SELECT 
    account_id,
    COUNT(*) AS transaction_count,
    SUM(amount) AS total_amount,
    ROUND(AVG(amount), 2) AS avg_transaction,
    MIN(transaction_date) AS first_transaction,
    MAX(transaction_date) AS last_transaction
FROM transactions
GROUP BY account_id
ORDER BY transaction_count DESC
LIMIT 10;

-- 5.2 Accounts with unusually high transaction amounts
-- (Anomaly detection using standard deviation)
WITH account_stats AS (
    SELECT 
        account_id,
        AVG(amount) AS avg_amount,
        STDDEV(amount) AS std_amount
    FROM transactions
    GROUP BY account_id
)
SELECT 
    t.transaction_id,
    t.account_id,
    t.amount,
    t.transaction_date,
    ROUND(as_.avg_amount, 2) AS account_avg,
    ROUND(as_.std_amount, 2) AS account_std,
    ROUND((t.amount - as_.avg_amount) / NULLIF(as_.std_amount, 0), 2) AS z_score
FROM transactions t
JOIN account_stats as_ ON t.account_id = as_.account_id
WHERE ABS((t.amount - as_.avg_amount) / NULLIF(as_.std_amount, 0)) > 3
ORDER BY ABS((t.amount - as_.avg_amount) / NULLIF(as_.std_amount, 0)) DESC;


-- ============================================================
-- SECTION 6: ADVANCED WINDOW FUNCTION ANALYSIS
-- ============================================================

-- 6.1 Running total of transactions per account
SELECT 
    transaction_id,
    account_id,
    transaction_date,
    amount,
    SUM(amount) OVER (
        PARTITION BY account_id 
        ORDER BY transaction_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_balance
FROM transactions
ORDER BY account_id, transaction_date;

-- 6.2 Rank transactions by amount within each transaction type
SELECT 
    transaction_id,
    account_id,
    transaction_type,
    amount,
    RANK() OVER (PARTITION BY transaction_type ORDER BY amount DESC) AS amount_rank,
    DENSE_RANK() OVER (PARTITION BY transaction_type ORDER BY amount DESC) AS dense_rank,
    NTILE(4) OVER (PARTITION BY transaction_type ORDER BY amount) AS amount_quartile
FROM transactions;

-- 6.3 Compare each transaction to previous transaction for same account
-- (Useful for detecting sudden spikes)
SELECT 
    transaction_id,
    account_id,
    transaction_date,
    amount,
    LAG(amount) OVER (PARTITION BY account_id ORDER BY transaction_date) AS previous_amount,
    amount - LAG(amount) OVER (PARTITION BY account_id ORDER BY transaction_date) AS amount_change,
    ROUND(
        (amount - LAG(amount) OVER (PARTITION BY account_id ORDER BY transaction_date)) * 100.0 
        / NULLIF(LAG(amount) OVER (PARTITION BY account_id ORDER BY transaction_date), 0), 2
    ) AS pct_change
FROM transactions
ORDER BY account_id, transaction_date;

-- 6.4 7-day moving average of daily transaction volume
SELECT 
    transaction_date,
    COUNT(*) AS daily_count,
    ROUND(AVG(COUNT(*)) OVER (
        ORDER BY transaction_date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS seven_day_moving_avg
FROM transactions
GROUP BY transaction_date
ORDER BY transaction_date;


-- ============================================================
-- SECTION 7: DATA RECONCILIATION
-- ============================================================

-- 7.1 Reconcile transaction counts between source and processed tables
-- (Core task done daily in production)
SELECT 
    s.transaction_date,
    s.source_count,
    p.processed_count,
    s.source_count - COALESCE(p.processed_count, 0) AS unprocessed_count,
    CASE 
        WHEN s.source_count = COALESCE(p.processed_count, 0) THEN 'BALANCED'
        WHEN s.source_count > COALESCE(p.processed_count, 0) THEN 'SHORTFALL'
        ELSE 'OVERAGE'
    END AS reconciliation_status
FROM (
    SELECT transaction_date, COUNT(*) AS source_count
    FROM transactions
    GROUP BY transaction_date
) s
LEFT JOIN (
    SELECT transaction_date, COUNT(*) AS processed_count
    FROM processed_transactions
    GROUP BY transaction_date
) p ON s.transaction_date = p.transaction_date
ORDER BY s.transaction_date;
