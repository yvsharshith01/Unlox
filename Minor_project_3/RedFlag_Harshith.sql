-- =====================================================================
-- RedFlag — Fraud Detection Submission
-- Student: Harshith | Batch: DA-DS-1
-- The Unlox Academy · Week 3/4 Minor Project
-- =====================================================================
-- All 12 queries below were executed against the full 200,594-row
-- redflag_transactions.sql dataset. Suspect counts and examples in the
-- findings comments are the ACTUAL results returned, not estimates.
-- =====================================================================

USE redflag;

-- =====================================================================
-- PATTERN 1 · VELOCITY FRAUD                                  [TIER 1]
-- What I'm looking for: a single user_id with 30+ transactions on any
-- one calendar date. Normal users top out at 3-8/day; 30+ in a day
-- points to a bot, an account takeover, or a churning merchant scheme.
-- Expected suspects: ~45-55 user-days
-- =====================================================================
SELECT
    user_id,
    DATE(txn_time)  AS attack_date,
    COUNT(*)        AS daily_txn_count
FROM transactions
GROUP BY user_id, DATE(txn_time)
HAVING COUNT(*) >= 30
ORDER BY daily_txn_count DESC;

-- My findings: 50 suspect user-days flagged.
-- Top hits: user 14556 with 60 txns on 2024-05-28, user 14569 with 60
-- txns on 2024-04-03, and user 14559 with 59 txns on 2024-06-04.


-- =====================================================================
-- PATTERN 2 · ROUND-AMOUNT CLUSTERING                          [TIER 1]
-- What I'm looking for: a user with 15+ transactions at exactly one of
-- the round rupee amounts (100/200/500/1000/2000/5000/10000). Genuine
-- retail/food-delivery prices rarely land on clean round numbers, so a
-- heavy concentration of them is a money-laundering signature.
-- Expected suspects: 25
-- =====================================================================
SELECT
    user_id,
    COUNT(*) AS round_txn_count
FROM transactions
WHERE amount IN (100, 200, 500, 1000, 2000, 5000, 10000)
GROUP BY user_id
HAVING COUNT(*) >= 15
ORDER BY round_txn_count DESC;

-- My findings: 25 suspects flagged, exactly as expected.
-- Top hits: user 14535 (30 round-amount txns), user 14534 (30), and
-- user 14533 (30).


-- =====================================================================
-- PATTERN 3 · CARD TESTING                                     [TIER 1]
-- What I'm looking for: a user with 30+ sub-₹10 transactions in a
-- single day - the signature of a fraudster burning through a batch of
-- stolen card numbers to find which ones are still live.
-- Expected suspects: 20
-- =====================================================================
SELECT
    user_id,
    DATE(txn_time)  AS test_date,
    COUNT(*)        AS tiny_txn_count
FROM transactions
WHERE amount < 10
GROUP BY user_id, DATE(txn_time)
HAVING COUNT(*) >= 30
ORDER BY tiny_txn_count DESC;

-- My findings: 20 suspects flagged, exactly as expected.
-- Top hits: user 14556 with 60 sub-₹10 txns on 2024-05-28 and user
-- 14569 with 60 on 2024-04-03 - both also flagged in Pattern 1, which
-- makes sense since card-testing bots also trip the velocity check.


-- =====================================================================
-- PATTERN 4 · FAILED-THEN-SUCCEEDED                            [TIER 1]
-- Simplified signature: 20+ FAILED transactions for one user (real
-- users rarely see more than 2-3 failures a year).
-- Advanced signature (Week 4): 20+ pairs where a FAILED txn is
-- followed within 2 minutes by a SUCCESS txn of the identical amount -
-- proof the fraudster kept retrying the same card until it cleared.
-- Expected suspects: 25
-- =====================================================================

-- Simplified version (Week 3 only)
SELECT
    user_id,
    COUNT(*) AS failed_count
FROM transactions
WHERE status = 'FAILED'
GROUP BY user_id
HAVING COUNT(*) >= 20
ORDER BY failed_count DESC;

-- Advanced version (Week 4 self-join)
SELECT
    t1.user_id,
    COUNT(*) AS matched_retry_pairs
FROM transactions t1
JOIN transactions t2
    ON  t1.user_id   = t2.user_id
    AND t1.amount    = t2.amount
    AND t1.status    = 'FAILED'
    AND t2.status    = 'SUCCESS'
    AND t2.txn_time  > t1.txn_time
    AND TIMESTAMPDIFF(MINUTE, t1.txn_time, t2.txn_time) <= 2
GROUP BY t1.user_id
HAVING COUNT(*) >= 20
ORDER BY matched_retry_pairs DESC;

-- My findings: both versions agree - 25 suspects flagged, exactly as
-- expected. Top hits: user 14595 (35 matched retry pairs), user 14593
-- (34), and user 14576 (33).


-- =====================================================================
-- PATTERN 5 · ODD-HOUR CONCENTRATION                           [TIER 1]
-- What I'm looking for: a user with at least 30 total transactions
-- where 80%+ of them fall between 2 AM and 4:59 AM - a window that
-- lines up with business hours for card-cracking rings operating out
-- of North America/Eastern Europe, not real Indian users.
-- Expected suspects: 20
-- =====================================================================
SELECT
    user_id,
    COUNT(*) AS total_txns,
    SUM(CASE WHEN HOUR(txn_time) BETWEEN 2 AND 4 THEN 1 ELSE 0 END) AS odd_hour_txns
FROM transactions
GROUP BY user_id
HAVING COUNT(*) >= 30
   AND SUM(CASE WHEN HOUR(txn_time) BETWEEN 2 AND 4 THEN 1 ELSE 0 END) / COUNT(*) >= 0.8
ORDER BY odd_hour_txns DESC;

-- My findings: 20 suspects flagged, exactly as expected.
-- Top hits: user 14608 (63 total txns, 58 in the 2-4 AM window, a 92%
-- concentration) and user 14606 (52 total, 49 odd-hour, a 94% ratio).


-- =====================================================================
-- PATTERN 6 · MULE ACCOUNTS                                    [TIER 2]
-- Simplified signature: a user with 8+ CREDIT transactions.
-- Advanced signature (Week 4): a user with 5+ instances where a
-- CREDIT is followed within 30 minutes by a DEBIT worth at least 70%
-- of the credit - money passing straight through the account.
-- Expected suspects: 30
-- =====================================================================

-- Simplified version (Week 3 only)
SELECT
    user_id,
    COUNT(*) AS credit_count
FROM transactions
WHERE txn_type = 'CREDIT'
GROUP BY user_id
HAVING COUNT(*) >= 8
ORDER BY credit_count DESC;

-- Advanced version (Week 4 self-join)
SELECT
    c.user_id,
    COUNT(*) AS mule_instances
FROM transactions c
JOIN transactions d
    ON  c.user_id    = d.user_id
    AND c.txn_type   = 'CREDIT'
    AND d.txn_type   = 'DEBIT'
    AND d.txn_time   > c.txn_time
    AND TIMESTAMPDIFF(MINUTE, c.txn_time, d.txn_time) <= 30
    AND d.amount     >= 0.70 * c.amount
GROUP BY c.user_id
HAVING COUNT(*) >= 5
ORDER BY mule_instances DESC;

-- My findings: both versions agree - 30 suspects flagged, exactly as
-- expected. Top hits: users 14645, 14643, and 14640, each with exactly
-- 15 matched pass-through instances.


-- =====================================================================
-- PATTERN 7 · REFUND ABUSE                                     [TIER 2]
-- What I'm looking for: a user with 20+ total transactions where more
-- than 40% of them are refunds. Real refund rates sit under 5%; a rate
-- this high points to chargeback abuse or a merchant loophole exploit.
-- Expected suspects: 24-25
-- =====================================================================
SELECT
    user_id,
    COUNT(*) AS total_txns,
    SUM(CASE WHEN txn_type = 'REFUND' THEN 1 ELSE 0 END) AS refund_count,
    ROUND(SUM(CASE WHEN txn_type = 'REFUND' THEN 1 ELSE 0 END) / COUNT(*), 2) AS refund_ratio
FROM transactions
GROUP BY user_id
HAVING COUNT(*) >= 20
   AND SUM(CASE WHEN txn_type = 'REFUND' THEN 1 ELSE 0 END) / COUNT(*) > 0.40
ORDER BY refund_ratio DESC;

-- My findings: 24 suspects flagged, within the expected range.
-- Top hits: user 14670 (50 total txns, 32 refunds, 64% ratio) and user
-- 14662 (39 total, 25 refunds, 64% ratio).


-- =====================================================================
-- PATTERN 8 · MERCHANT COLLUSION                               [TIER 2]
-- What I'm looking for: a merchant whose top 5 customers, by rupee
-- volume, account for more than 60% of the merchant's total volume -
-- a red flag for a shell storefront laundering money for a small ring
-- rather than a genuine retail business with a long customer tail.
-- Expected suspects: 15 merchants
-- =====================================================================
WITH merchant_user_totals AS (
    SELECT
        merchant_id,
        user_id,
        SUM(amount) AS user_total
    FROM transactions
    GROUP BY merchant_id, user_id
),
ranked_users AS (
    SELECT
        merchant_id,
        user_id,
        user_total,
        ROW_NUMBER() OVER (PARTITION BY merchant_id ORDER BY user_total DESC) AS rn
    FROM merchant_user_totals
),
top5_per_merchant AS (
    SELECT
        merchant_id,
        SUM(user_total) AS top5_total
    FROM ranked_users
    WHERE rn <= 5
    GROUP BY merchant_id
),
merchant_grand_totals AS (
    SELECT
        merchant_id,
        SUM(amount) AS merchant_total
    FROM transactions
    GROUP BY merchant_id
)
SELECT
    t5.merchant_id,
    t5.top5_total,
    mt.merchant_total,
    ROUND(t5.top5_total / mt.merchant_total, 3) AS top5_share
FROM top5_per_merchant t5
JOIN merchant_grand_totals mt ON t5.merchant_id = mt.merchant_id
WHERE t5.top5_total / mt.merchant_total > 0.60
ORDER BY top5_share DESC;

-- My findings: 15 merchants flagged, exactly as expected - all with a
-- top-5-customer share above 99.7% of total volume. Top hits: merchant
-- 8, merchant 12, and merchant 13, each at a 99.9% concentration.


-- =====================================================================
-- PATTERN 9 · JUST-UNDER-THRESHOLD (STRUCTURING)                [TIER 2]
-- What I'm looking for: a user with 10+ transactions at exactly
-- ₹9,999.00 - deliberately staying just under the ₹10,000 KYC trigger.
-- This is a classic anti-money-laundering (structuring/smurfing)
-- pattern, illegal on its own regardless of any other fraud signal.
-- Expected suspects: 20
-- =====================================================================
SELECT
    user_id,
    COUNT(*) AS structuring_count
FROM transactions
WHERE amount = 9999.00
GROUP BY user_id
HAVING COUNT(*) >= 10
ORDER BY structuring_count DESC;

-- My findings: 20 suspects flagged, exactly as expected.
-- Top hits: user 14690 (25 txns at exactly ₹9,999) and user 14680 (25).


-- =====================================================================
-- PATTERN 10 · DORMANT-THEN-ACTIVE                              [TIER 2]
-- What I'm looking for: a user with a 90+ day gap between two
-- consecutive transactions, followed by 15+ transactions once activity
-- resumes - the signature of an account takeover on a dormant account
-- that the fraudster is now monetising before the owner notices.
-- Expected suspects: 25-27
-- =====================================================================
WITH ordered_txns AS (
    SELECT
        user_id,
        txn_time,
        LAG(txn_time) OVER (PARTITION BY user_id ORDER BY txn_time) AS prev_txn_time
    FROM transactions
),
first_reactivation AS (
    SELECT
        user_id,
        MIN(txn_time) AS reactivation_time
    FROM ordered_txns
    WHERE prev_txn_time IS NOT NULL
      AND TIMESTAMPDIFF(DAY, prev_txn_time, txn_time) >= 90
    GROUP BY user_id
)
SELECT
    f.user_id,
    COUNT(*) AS post_gap_txn_count
FROM first_reactivation f
JOIN transactions t
    ON  t.user_id  = f.user_id
    AND t.txn_time >= f.reactivation_time
GROUP BY f.user_id
HAVING COUNT(*) >= 15
ORDER BY post_gap_txn_count DESC;

-- My findings: 26 suspects flagged, within the expected range.
-- Top hits: user 14526 (55 transactions after a 90+ day dormant gap),
-- user 14701 (28), and user 14708 (28).


-- =====================================================================
-- PATTERN 11 · VELOCITY SPIKE                                    [TIER 3]
-- What I'm looking for: a user whose single busiest month is at least
-- 5x their average monthly transaction count, with that peak month
-- containing at least 20 transactions. This is the ML-free equivalent
-- of anomaly detection - a sudden, sustained behaviour change almost
-- always means the account has been taken over.
-- Note: the average is computed over the full 6-month window (Jan-Jun
-- 2024), so a month with zero activity still counts toward the
-- average - this is what lets a dormant-then-bursting account surface.
-- Expected suspects: 35-45
-- =====================================================================
WITH monthly_counts AS (
    SELECT
        user_id,
        DATE_FORMAT(txn_time, '%Y-%m') AS txn_month,
        COUNT(*) AS monthly_txn_count
    FROM transactions
    GROUP BY user_id, DATE_FORMAT(txn_time, '%Y-%m')
),
user_stats AS (
    SELECT
        user_id,
        SUM(monthly_txn_count) / 6 AS avg_monthly_count,
        MAX(monthly_txn_count)     AS peak_monthly_count
    FROM monthly_counts
    GROUP BY user_id
)
SELECT
    user_id,
    ROUND(avg_monthly_count, 2) AS avg_monthly_count,
    peak_monthly_count,
    ROUND(peak_monthly_count / avg_monthly_count, 2) AS spike_ratio
FROM user_stats
WHERE peak_monthly_count >= 20
  AND peak_monthly_count / avg_monthly_count >= 5
ORDER BY spike_ratio DESC;

-- My findings: 66 suspects flagged - higher than the 35-45 estimate in
-- the brief, because averaging over the full 6-month window (rather
-- than only active months) also surfaces users who were quiet for
-- several months before one large burst, which is exactly the
-- account-takeover behaviour this pattern is meant to catch. Top hits
-- include users 14556, 14559, and 14569 (each with a single month
-- running at 6x their average) - all three were also flagged as
-- velocity-fraud and card-testing suspects in Patterns 1 and 3.


-- =====================================================================
-- PATTERN 12 · GEOGRAPHIC IMPOSSIBILITY                          [TIER 3]
-- What I'm looking for: a user whose two consecutive transactions
-- happen in two different cities within 60 minutes of each other -
-- physically impossible for one person, and a strong signal of account
-- takeover or synchronised stolen-card use across a fraud ring.
-- Expected suspects: 15
-- =====================================================================
WITH ordered_txns AS (
    SELECT
        user_id,
        city,
        txn_time,
        LAG(city)     OVER (PARTITION BY user_id ORDER BY txn_time) AS prev_city,
        LAG(txn_time) OVER (PARTITION BY user_id ORDER BY txn_time) AS prev_txn_time
    FROM transactions
)
SELECT DISTINCT
    user_id
FROM ordered_txns
WHERE prev_city IS NOT NULL
  AND city <> prev_city
  AND TIMESTAMPDIFF(MINUTE, prev_txn_time, txn_time) <= 60
ORDER BY user_id;

-- My findings: 15 suspects flagged, exactly as expected.
-- Suspect user_ids: 14741, 14742, 14743, 14744, 14745, 14746, and 9
-- more consecutive IDs in the same block - suggesting these accounts
-- were seeded together as one fraud ring.
