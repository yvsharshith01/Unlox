-- BingePlay Streaming Analytics Project
-- Answers / SQL queries for Q1-Q12
-- MySQL 8+
-- IMPORTANT: This file contains the correct queries.
-- Numeric answers are produced when run against bingeplay_setup.sql data.

USE bingeplay;

-- =========================================================
-- Q1 - Active revenue as of 30 June 2024
-- =========================================================
SELECT
    COUNT(*) AS active_subscriptions,
    SUM(monthly_price_inr) AS total_monthly_revenue_inr
FROM subscriptions
WHERE status = 'active'
  AND (end_date IS NULL OR end_date > '2024-06-30');


-- =========================================================
-- Q2 - Signup momentum
-- =========================================================
SELECT
    MONTH(signup_date) AS month,
    COUNT(*) AS signup_count
FROM users
WHERE signup_date >= '2024-01-01'
  AND signup_date < '2024-07-01'
GROUP BY MONTH(signup_date)
ORDER BY month;

-- Month with highest signups
SELECT
    MONTH(signup_date) AS month,
    MONTHNAME(signup_date) AS month_name,
    COUNT(*) AS signup_count
FROM users
WHERE signup_date >= '2024-01-01'
  AND signup_date < '2024-07-01'
GROUP BY MONTH(signup_date), MONTHNAME(signup_date)
ORDER BY signup_count DESC, month
LIMIT 1;


-- =========================================================
-- Q3 - Device analytics
-- Excludes sessions having NULL user_id.
-- =========================================================
SELECT
    device_type,
    COUNT(*) AS total_sessions,
    SUM(watch_minutes) AS total_watch_minutes,
    ROUND(AVG(watch_minutes), 2) AS avg_watch_minutes_per_session,
    ROUND(100.0 * AVG(completed), 2) AS completion_rate_pct
FROM watch_sessions
WHERE user_id IS NOT NULL
GROUP BY device_type
ORDER BY device_type;


-- =========================================================
-- Q4 - Rating distribution
-- =========================================================
SELECT
    stars,
    COUNT(*) AS rating_count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM ratings), 2) AS rating_percentage
FROM ratings
GROUP BY stars
ORDER BY stars;

-- Percentage of all ratings that are 4 or 5 stars
SELECT
    ROUND(
        100.0 * SUM(CASE WHEN stars IN (4, 5) THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS pct_ratings_4_or_5
FROM ratings;


-- =========================================================
-- Q5 - Originals vs acquired
-- =========================================================
SELECT
    CASE
        WHEN is_original = 1 THEN 'Original'
        ELSE 'Acquired'
    END AS content_type,
    COUNT(*) AS number_of_shows,
    ROUND(AVG(imdb_rating), 2) AS avg_imdb_rating,
    ROUND(AVG(release_year), 2) AS avg_release_year
FROM shows
GROUP BY is_original
ORDER BY is_original DESC;

-- Rating difference between Originals and Acquired
SELECT
    ROUND(
        AVG(CASE WHEN is_original = 1 THEN imdb_rating END) -
        AVG(CASE WHEN is_original = 0 THEN imdb_rating END),
        2
    ) AS original_minus_acquired_rating
FROM shows;


-- =========================================================
-- Q6 - Binge day detection
-- Binge day = same user + same show + same date with >=5 sessions
-- Q2 2024 only.
-- =========================================================
WITH binge_days AS (
    SELECT
        user_id,
        show_id,
        session_date
    FROM watch_sessions
    WHERE user_id IS NOT NULL
      AND session_date >= '2024-04-01'
      AND session_date < '2024-07-01'
    GROUP BY user_id, show_id, session_date
    HAVING COUNT(*) >= 5
)
SELECT COUNT(*) AS total_binge_days
FROM binge_days;

-- User with most binge days
WITH binge_days AS (
    SELECT
        user_id,
        show_id,
        session_date
    FROM watch_sessions
    WHERE user_id IS NOT NULL
      AND session_date >= '2024-04-01'
      AND session_date < '2024-07-01'
    GROUP BY user_id, show_id, session_date
    HAVING COUNT(*) >= 5
)
SELECT
    user_id,
    COUNT(*) AS binge_days
FROM binge_days
GROUP BY user_id
ORDER BY binge_days DESC, user_id
LIMIT 1;


-- =========================================================
-- Q7 - Q1 signups who never watched
-- Uses NOT EXISTS to safely handle NULLs in watch_sessions.user_id.
-- =========================================================
SELECT COUNT(*) AS total_q1_signups
FROM users
WHERE signup_date >= '2024-01-01'
  AND signup_date < '2024-04-01';

SELECT COUNT(*) AS q1_signups_never_watched
FROM users u
WHERE u.signup_date >= '2024-01-01'
  AND u.signup_date < '2024-04-01'
  AND NOT EXISTS (
      SELECT 1
      FROM watch_sessions ws
      WHERE ws.user_id = u.user_id
  );


-- =========================================================
-- Q8 - Over-paying Premium/Family users
-- Current plan = most recent subscription that is active/open
-- as of 30-Jun-2024. User must have watched at least one show,
-- and must NEVER have watched a Premium/Family-tier show.
-- =========================================================
WITH active_subs AS (
    SELECT
        s.*,
        ROW_NUMBER() OVER (
            PARTITION BY s.user_id
            ORDER BY s.start_date DESC, s.subscription_id DESC
        ) AS rn
    FROM subscriptions s
    WHERE s.status = 'active'
      AND s.start_date <= '2024-06-30'
      AND (s.end_date IS NULL OR s.end_date > '2024-06-30')
),
current_paid_users AS (
    SELECT user_id, plan
    FROM active_subs
    WHERE rn = 1
      AND plan IN ('Premium', 'Family')
)
SELECT COUNT(*) AS overpaying_users
FROM current_paid_users c
WHERE EXISTS (
    SELECT 1
    FROM watch_sessions ws
    WHERE ws.user_id = c.user_id
)
AND NOT EXISTS (
    SELECT 1
    FROM watch_sessions ws
    JOIN shows sh
      ON sh.show_id = ws.show_id
    WHERE ws.user_id = c.user_id
      AND sh.min_plan IN ('Premium', 'Family')
);


-- =========================================================
-- Q9 - Upgrade success cohort
-- January signup; earliest subscription Basic; later Premium/Family;
-- still active as of 30-Jun-2024.
-- =========================================================
WITH ordered_subs AS (
    SELECT
        s.*,
        ROW_NUMBER() OVER (
            PARTITION BY s.user_id
            ORDER BY s.start_date, s.subscription_id
        ) AS rn
    FROM subscriptions s
),
basic_starters AS (
    SELECT user_id, start_date AS first_sub_date
    FROM ordered_subs
    WHERE rn = 1
      AND plan = 'Basic'
),
first_upgrades AS (
    SELECT
        s.user_id,
        MIN(s.start_date) AS first_upgrade_date
    FROM subscriptions s
    JOIN basic_starters b
      ON b.user_id = s.user_id
    WHERE s.plan IN ('Premium', 'Family')
      AND s.start_date > b.first_sub_date
    GROUP BY s.user_id
),
active_as_of_june30 AS (
    SELECT DISTINCT user_id
    FROM subscriptions
    WHERE status = 'active'
      AND start_date <= '2024-06-30'
      AND (end_date IS NULL OR end_date > '2024-06-30')
),
cohort AS (
    SELECT
        u.user_id,
        u.signup_date,
        f.first_upgrade_date
    FROM users u
    JOIN basic_starters b
      ON b.user_id = u.user_id
    JOIN first_upgrades f
      ON f.user_id = u.user_id
    JOIN active_as_of_june30 a
      ON a.user_id = u.user_id
    WHERE u.signup_date >= '2024-01-01'
      AND u.signup_date < '2024-02-01'
)
SELECT
    COUNT(*) AS upgrade_success_users,
    ROUND(AVG(DATEDIFF(first_upgrade_date, signup_date)), 2)
        AS avg_days_signup_to_first_upgrade
FROM cohort;


-- =========================================================
-- Q10 - Cliffhanger comebacks
-- Each unique (user, show, incomplete_date) counts once.
-- =========================================================
WITH comeback_events AS (
    SELECT DISTINCT
        w1.user_id,
        w1.show_id,
        w1.session_date AS incomplete_date
    FROM watch_sessions w1
    JOIN watch_sessions w2
      ON w2.user_id = w1.user_id
     AND w2.show_id = w1.show_id
     AND w2.session_date BETWEEN
         DATE_ADD(w1.session_date, INTERVAL 1 DAY)
         AND DATE_ADD(w1.session_date, INTERVAL 7 DAY)
    WHERE w1.user_id IS NOT NULL
      AND w1.completed = 0
)
SELECT COUNT(*) AS total_cliffhanger_comeback_events
FROM comeback_events;

-- Show generating the most cliffhanger comeback events
WITH comeback_events AS (
    SELECT DISTINCT
        w1.user_id,
        w1.show_id,
        w1.session_date AS incomplete_date
    FROM watch_sessions w1
    JOIN watch_sessions w2
      ON w2.user_id = w1.user_id
     AND w2.show_id = w1.show_id
     AND w2.session_date BETWEEN
         DATE_ADD(w1.session_date, INTERVAL 1 DAY)
         AND DATE_ADD(w1.session_date, INTERVAL 7 DAY)
    WHERE w1.user_id IS NOT NULL
      AND w1.completed = 0
)
SELECT
    ce.show_id,
    sh.title,
    COUNT(*) AS comeback_events
FROM comeback_events ce
JOIN shows sh
  ON sh.show_id = ce.show_id
GROUP BY ce.show_id, sh.title
ORDER BY comeback_events DESC, ce.show_id
LIMIT 1;


-- =========================================================
-- Q11 - Consecutive-week engagement
-- ISO week numbering + gaps-and-islands.
-- TO_DAYS(MONDAY_OF_WEEK) gives a continuous week ordinal and
-- avoids errors across year boundaries.
-- =========================================================
WITH distinct_weeks AS (
    SELECT DISTINCT
        user_id,
        DATE_SUB(
            session_date,
            INTERVAL WEEKDAY(session_date) DAY
        ) AS week_start
    FROM watch_sessions
    WHERE user_id IS NOT NULL
),
numbered AS (
    SELECT
        user_id,
        week_start,
        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY week_start
        ) AS rn
    FROM distinct_weeks
),
islands AS (
    SELECT
        user_id,
        week_start,
        FLOOR(TO_DAYS(week_start) / 7) - rn AS grp
    FROM numbered
),
streaks AS (
    SELECT
        user_id,
        grp,
        COUNT(*) AS streak_weeks
    FROM islands
    GROUP BY user_id, grp
)
SELECT
    COUNT(DISTINCT user_id) AS users_with_4plus_week_streak
FROM streaks
WHERE streak_weeks >= 4;

-- Longest streak and one user having it
WITH distinct_weeks AS (
    SELECT DISTINCT
        user_id,
        DATE_SUB(
            session_date,
            INTERVAL WEEKDAY(session_date) DAY
        ) AS week_start
    FROM watch_sessions
    WHERE user_id IS NOT NULL
),
numbered AS (
    SELECT
        user_id,
        week_start,
        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY week_start
        ) AS rn
    FROM distinct_weeks
),
islands AS (
    SELECT
        user_id,
        week_start,
        FLOOR(TO_DAYS(week_start) / 7) - rn AS grp
    FROM numbered
),
streaks AS (
    SELECT
        user_id,
        grp,
        COUNT(*) AS streak_weeks
    FROM islands
    GROUP BY user_id, grp
)
SELECT
    user_id,
    streak_weeks AS longest_streak_weeks
FROM streaks
ORDER BY streak_weeks DESC, user_id
LIMIT 1;


-- =========================================================
-- Q12 - Churn signal detection
-- June watch minutes dropped >=50% from May.
-- May activity must be > 0. June with no activity is treated as 0.
-- =========================================================
WITH monthly_watch AS (
    SELECT
        user_id,
        SUM(CASE
            WHEN session_date >= '2024-05-01'
             AND session_date < '2024-06-01'
            THEN watch_minutes ELSE 0
        END) AS may_minutes,
        SUM(CASE
            WHEN session_date >= '2024-06-01'
             AND session_date < '2024-07-01'
            THEN watch_minutes ELSE 0
        END) AS june_minutes
    FROM watch_sessions
    WHERE user_id IS NOT NULL
      AND session_date >= '2024-05-01'
      AND session_date < '2024-07-01'
    GROUP BY user_id
),
churn_signals AS (
    SELECT
        user_id,
        may_minutes,
        june_minutes,
        ROUND(
            100.0 * (may_minutes - june_minutes) / may_minutes,
            2
        ) AS drop_percentage
    FROM monthly_watch
    WHERE may_minutes > 0
      AND june_minutes <= 0.5 * may_minutes
)
SELECT
    c.user_id,
    u.name,
    c.may_minutes,
    c.june_minutes,
    c.drop_percentage
FROM churn_signals c
JOIN users u
  ON u.user_id = c.user_id
ORDER BY c.drop_percentage DESC, c.user_id;

-- Total churn signal users
WITH monthly_watch AS (
    SELECT
        user_id,
        SUM(CASE
            WHEN session_date >= '2024-05-01'
             AND session_date < '2024-06-01'
            THEN watch_minutes ELSE 0
        END) AS may_minutes,
        SUM(CASE
            WHEN session_date >= '2024-06-01'
             AND session_date < '2024-07-01'
            THEN watch_minutes ELSE 0
        END) AS june_minutes
    FROM watch_sessions
    WHERE user_id IS NOT NULL
      AND session_date >= '2024-05-01'
      AND session_date < '2024-07-01'
    GROUP BY user_id
)
SELECT COUNT(*) AS total_churn_signal_users
FROM monthly_watch
WHERE may_minutes > 0
  AND june_minutes <= 0.5 * may_minutes;
