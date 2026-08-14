/* =============================================================
   Maven Fuzzy Factory - Device Performance
   MySQL 8.0

   Business question 7: do mobile and desktop visitors convert
   differently, and has the gap changed over time?

   device_type holds only 'desktop' or 'mobile' - no tablet or other
   category exists in this dataset, so the two segments are exhaustive
   and their session counts must sum to 472,871.

   MEASURING "THE GAP"
   -------------------
   The phrase is ambiguous and the two readings can disagree. If
   desktop goes 5% -> 10% and mobile goes 2% -> 4%, the gap has
   doubled in percentage points but is unchanged as a ratio.

   Percentage points measure lost orders per thousand visits - what the
   business actually feels. The ratio measures relative efficiency -
   whether mobile is catching up. Both are reported below; where they
   disagree, the disagreement is the finding.

   NOTE ON device_type AND INDEXES
   -------------------------------
   device_type has only two distinct values, so it is deliberately not
   indexed (see 04_add_indexes.sql). An index matching half the table
   costs more to read than a full scan. These queries scan; that is the
   correct behaviour at this cardinality.
   ============================================================= */

USE mavenfuzzyfactory;

/* Query 1 - overall performance by device.

   Watch the two average-order-value figures. If they are close, mobile
   users spend the same amount WHEN they buy, and the entire problem is
   that they do not buy - a checkout and usability issue. If mobile AOV
   were materially lower, the problem would be different: mobile users
   choosing cheaper products, pointing at merchandising rather than UX.
   The two diagnoses lead to different fixes.

   CHECK: desktop + mobile sessions = 472,871.

   Exported to results/07_device_overall.csv
*/
SELECT ws.device_type,
COUNT(ws.website_session_id)                        AS sessions,
ROUND(COUNT(ws.website_session_id) * 100.0 
/ (SELECT COUNT(*) FROM website_sessions),1)        AS pct_of_traffic,
COUNT(o.order_id)                                   AS orders,
ROUND(COUNT(o.order_id) * 100.0
/ COUNT(ws.website_session_id),2)                   AS conversion_rate_pct,
ROUND(SUM(o.price_usd) / COUNT(o.order_id),2)       AS avg_order_value,
ROUND(SUM(o.price_usd) / COUNT(ws.website_session_id), 2) AS revenue_per_session
FROM website_sessions ws
LEFT JOIN orders  o ON ws.website_session_id = o.website_session_id
GROUP BY ws.device_type
ORDER BY sessions DESC;

/* Query 2 - conversion and revenue per session by year and device.

   Reports the gap both ways. If the percentage-point gap widens while
   the ratio holds steady or narrows, both statements are true and the
   write-up must say which it means.

   Exported to results/07_device_by_year.csv
*/
WITH by_year_device AS (
    SELECT
        YEAR(ws.created_at)          AS year_,
        ws.device_type,
        COUNT(ws.website_session_id) AS sessions,
        COUNT(o.order_id)            AS orders,
        SUM(o.price_usd)             AS revenue
    FROM website_sessions ws
    LEFT JOIN orders o ON ws.website_session_id = o.website_session_id
    GROUP BY YEAR(ws.created_at), ws.device_type
),
pivoted AS (
    SELECT
        year_,
        MAX(CASE WHEN device_type = 'desktop' THEN 100.0 * orders / sessions END) AS desktop_conv,
        MAX(CASE WHEN device_type = 'mobile'  THEN 100.0 * orders / sessions END) AS mobile_conv
    FROM by_year_device
    GROUP BY year_
)
SELECT
    year_,
    ROUND(desktop_conv, 2)                 AS desktop_conv_pct,
    ROUND(mobile_conv, 2)                  AS mobile_conv_pct,
    ROUND(desktop_conv - mobile_conv, 2)   AS gap_points,
    ROUND(desktop_conv / mobile_conv, 2)   AS gap_ratio
FROM pivoted
ORDER BY year_;

/* Query 3 - mobile share of sessions by year.

   Matters because a weaker channel taking a growing share of traffic
   is a compounding problem, not a static one. If mobile share is
   rising while mobile conversion lags, the blended conversion rate is
   being dragged down by mix alone, independent of either segment
   getting better or worse.

   Exported to results/07_device_mix.csv
*/
SELECT
    YEAR(created_at)                                        AS year_,
    COUNT(*)                                                AS total_sessions,
    SUM(device_type = 'desktop')                            AS desktop_sessions,
    SUM(device_type = 'mobile')                             AS mobile_sessions,
    ROUND(100.0 * SUM(device_type = 'mobile') / COUNT(*), 1) AS mobile_pct_of_traffic
FROM website_sessions
GROUP BY YEAR(created_at)
ORDER BY year_;

/* Query 4 - mobile share of traffic on a like-for-like basis.

   Query 3 shows mobile share dipping from 33.4% (2014) to 30.3% (2015),
   but 2015 covers only 1 Jan - 19 Mar. If mobile browsing is itself
   seasonal, that dip may be an artefact of the window rather than a
   real reversal. Restricting every year to the same calendar window
   removes the possibility.

   Same technique as the like-for-like comparison in
   04_revenue_metrics.sql. DATE_FORMAT on created_at prevents use of
   idx_sessions_created_at; acceptable at 473k rows.

   Exported to results/07_device_mix_like_for_like.csv
*/
SELECT
    YEAR(created_at)                                        AS year_,
    COUNT(*)                                                AS total_sessions,
    SUM(device_type = 'mobile')                             AS mobile_sessions,
    ROUND(100.0 * SUM(device_type = 'mobile') / COUNT(*), 1) AS mobile_pct_of_traffic
FROM website_sessions
WHERE DATE_FORMAT(created_at, '%m-%d') <= '03-19'
GROUP BY YEAR(created_at)
ORDER BY year_;
