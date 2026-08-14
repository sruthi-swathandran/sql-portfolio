/* =============================================================
   Maven Fuzzy Factory - Channel Performance
   MySQL 8.0

   Business question 3: which marketing channels drive the most
   traffic, and which drive the most *revenue*?
   ============================================================= */

USE mavenfuzzyfactory;

SELECT CASE WHEN ws.utm_source IS NOT NULL THEN 'Paid'
WHEN ws.http_referer IS NOT NULL THEN 'Organic Search'
ELSE 'Direct'
END AS channel,
COUNT(ws.website_session_id) AS sessions,
COUNT(o.order_id) AS orders,
ROUND((COUNT(o.order_id)/COUNT(ws.website_session_id))*100.0,2) AS conversion_rate_pct,
ROUND(SUM(o.price_usd),2) AS revenue,
ROUND((SUM(o.price_usd)/COUNT(ws.website_session_id)),2) AS revenue_per_session
FROM website_sessions ws
LEFT JOIN orders o on ws.website_session_id = o.website_session_id
GROUP BY channel
ORDER BY sessions DESC;
