/* =============================================================
   Question 8: Is the brand campaign worth the spend,
   compared with nonbrand?

   Brand campaigns bid on the company's own name. Nonbrand
   campaigns bid on generic product terms. Brand traffic is
   usually expected to convert far better, since those visitors
   already know the business. The question is whether that
   better performance reflects the campaign working, or simply
   reflects who the campaign reaches.

   Comparing conversion rates alone therefore answers the
   wrong question. What matters is whether brand spend buys
   incremental visits or pays for traffic already earned.

   This data has no advertising cost, so return on spend
   cannot be calculated. The analysis looks instead for
   evidence about incrementality in the traffic itself.
   ============================================================= */

USE mavenfuzzyfactory;

-- Query 1: what campaigns exist, and how much traffic does each carry?
SELECT utm_campaign,
COUNT(website_session_id) AS sessions
FROM website_sessions
GROUP BY utm_campaign
ORDER BY sessions DESC;

-- Query 2: performance by campaign. The NULL row is organic plus
-- direct traffic and acts as the "would they have come anyway"
-- comparator.
SELECT ws.utm_campaign,
COUNT(ws.website_session_id) AS sessions,
COUNT(o.order_id) AS orders,
ROUND((COUNT(o.order_id)/COUNT(ws.website_session_id))*100.0,2) AS conversion_rate_pct,
ROUND(SUM(o.price_usd),2) AS revenue,
ROUND((SUM(o.price_usd)/COUNT(ws.website_session_id)),2) AS revenue_per_session
FROM website_sessions ws
LEFT JOIN orders o on ws.website_session_id = o.website_session_id
GROUP BY utm_campaign
ORDER BY sessions DESC;

-- Query 3: repeat-visitor share by campaign. A first-time visitor
-- cannot search for a brand they have never heard of, so repeat
-- share is a structural signal of prior awareness.
SELECT  utm_campaign,
COUNT(*)                   AS total_sessions,
SUM(is_repeat_session)     AS repeated_sessions,
ROUND((SUM(is_repeat_session)/COUNT(*)*100.0),2) as repeat_session_pct
FROM website_sessions
GROUP BY utm_campaign
ORDER BY repeat_session_pct DESC;

-- Query 4: conversion by campaign AND repeat status. Brand's
-- advantage over nonbrand may be a mix effect rather than the
-- campaign working, since brand traffic is 64% returning
-- visitors and nonbrand is 0%. Comparing first-time sessions
-- only removes that confound.
SELECT ws.utm_campaign,
ws.is_repeat_session,
COUNT(ws.website_session_id)        AS sessions,
COUNT(o.order_id)                   AS orders,
ROUND((COUNT(o.order_id)/COUNT(ws.website_session_id))*100.0,2) AS conversion_rate_pct
FROM website_sessions ws
LEFT JOIN orders o ON ws.website_session_id = o.website_session_id
GROUP BY ws.utm_campaign, ws.is_repeat_session
ORDER BY ws.utm_campaign, ws.is_repeat_session;

-- Query 5: date range per campaign. Campaigns that ran only in a
-- narrow window are experiments; campaigns that ran throughout are
-- ongoing spend. The distinction changes how pilot's 1.08%
-- conversion should be read.
SELECT utm_campaign,
COUNT(*)             AS sessions,
MIN(created_at)      AS first_session,
MAX(created_at)      AS last_session,
DATEDIFF(MAX(created_at), MIN(created_at))     AS days_active
FROM website_sessions
GROUP BY utm_campaign
ORDER BY first_session;