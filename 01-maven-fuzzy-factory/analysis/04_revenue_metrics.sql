/* =============================================================
   Maven Fuzzy Factory - Revenue Metrics
   MySQL 8.0

   Business question 4: How have revenue per order and revenue per session evolved?
   ============================================================= */

USE mavenfuzzyfactory;

-- Monthly detail (37 rows) - exported to results/04_monthly_revenue_metrics.csv
SELECT YEAR(ws.created_at) AS year_,
MONTH(ws.created_at) AS month_,
COUNT(ws.website_session_id) AS sessions,
COUNT(o.order_id) AS orders,
ROUND(SUM(o.price_usd) / COUNT(o.order_id),2) AS revenue_per_order,
ROUND(SUM(o.price_usd) / COUNT(ws.website_session_id),2) AS revenue_per_session
FROM website_sessions ws
LEFT JOIN orders o on ws.website_session_id = o.website_session_id
GROUP BY YEAR(ws.created_at), MONTH(ws.created_at)
ORDER BY year_, month_;

-- Annual summary. Revenue per session: $2.07 (2012) -> $5.30 (2015), 2.56x.
-- Decomposes as conversion 2.04x and revenue per order 1.26x.
-- NOTE: 2012 starts 19 March and 2015 ends 19 March, so these are not
-- directly comparable. See the like-for-like query below.
SELECT YEAR(ws.created_at) AS year_,
COUNT(ws.website_session_id) AS sessions,
COUNT(o.order_id) AS orders,
ROUND(SUM(o.price_usd) / COUNT(o.order_id),2) AS revenue_per_order,
ROUND(SUM(o.price_usd) / COUNT(ws.website_session_id),2) AS revenue_per_session
FROM website_sessions ws
LEFT JOIN orders o on ws.website_session_id = o.website_session_id
GROUP BY YEAR(ws.created_at)
ORDER BY year_;

-- Like-for-like: 1 Jan - 19 Mar only, matching 2015's coverage.
-- Rev/session $4.04 (2014) -> $5.30 (2015), +31% - larger than the full-year
-- comparison suggests, because Q1 is seasonally weaker.
-- Revenue per order rose ($61.84 -> $62.80) where full-year showed a decline.
-- 2012 unusable here: the site launched 19 March, so its window is one day.
-- Note: DATE_FORMAT on created_at prevents use of idx_sessions_created_at.
-- Acceptable at 473k rows; would need a different approach at scale.
SELECT YEAR(ws.created_at) AS year_,
COUNT(ws.website_session_id) AS sessions,
COUNT(o.order_id) AS orders,
ROUND(SUM(o.price_usd) / COUNT(o.order_id),2) AS revenue_per_order,
ROUND(SUM(o.price_usd) / COUNT(ws.website_session_id),2) AS revenue_per_session
FROM website_sessions ws
LEFT JOIN orders o on ws.website_session_id = o.website_session_id
WHERE DATE_FORMAT(ws.created_at, '%m-%d') <= '03-19'
GROUP BY YEAR(ws.created_at)
ORDER BY year_;
