/* =============================================================
   Maven Fuzzy Factory - Traffic Trends
   MySQL 8.0

   Business question: what is the session-to-order conversion rate?
   ============================================================= */
USE mavenfuzzyfactory;

-- Result: 472,871 sessions, 32,313 orders, 6.83% overall conversion.
SELECT COUNT(ws.website_session_id) AS sessions,
COUNT(o.order_id) as orders,
(COUNT(o.order_id)/COUNT(ws.website_session_id))*100.00 as conversion_rate_pct
FROM website_sessions ws
LEFT JOIN orders o on ws.website_session_id = o.website_session_id;


-- Result: conversion improved from ~3.2% (Mar 2012) to ~8.7% (Feb 2015).
SELECT YEAR(ws.created_at) AS year_,
MONTH(ws.created_at) AS month_,
COUNT(ws.website_session_id) AS sessions,
COUNT(o.order_id) AS orders,
(COUNT(o.order_id)/COUNT(ws.website_session_id))*100.0 AS conversion_rate_pct
FROM website_sessions ws
LEFT JOIN orders o on ws.website_session_id = o.website_session_id
GROUP BY YEAR(ws.created_at), MONTH(ws.created_at)
ORDER BY year_, month_ ;

