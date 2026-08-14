/* =============================================================
   Maven Fuzzy Factory - Traffic Trends
   MySQL 8.0

   Business question: how have website sessions trended over time?
   ============================================================= */

USE mavenfuzzyfactory;


-- Establish the data range before reading any trend.
-- Result: 2012-03-19 08:04:16 to 2015-03-19 07:59:08
-- March 2015 is therefore PARTIAL (19 of 31 days). Any month-on-month
-- comparison ending there shows a decline that is not real.
SELECT MIN(created_at) AS first_session,
       MAX(created_at) AS last_session
FROM website_sessions;


-- Monthly session volume, Mar 2012 - Mar 2015 (37 months)
SELECT
    YEAR(created_at)  AS year_,
    MONTH(created_at) AS month_,
    COUNT(*)          AS sessions
FROM website_sessions
GROUP BY YEAR(created_at), MONTH(created_at)
ORDER BY year_, month_;

SELECT 
MONTH(created_at) AS month_,
SUM(CASE WHEN YEAR(created_at) = 2012 THEN 1 END) as sessions_2012,
SUM(CASE WHEN YEAR(created_at) = 2013 THEN 1 ELSE 0 END) as sessions_2013,
SUM(CASE WHEN YEAR(created_at) = 2014 THEN 1 ELSE 0 END) as sessions_2014
FROM website_sessions
GROUP BY MONTH(created_at)
ORDER BY month_;
