/* =============================================================
   Question 9: Do returning visitors convert better than
   first-time visitors, and what share of revenue do they drive?

   A repeat session means someone returned to the site. A repeat
   customer means someone bought twice. These are different
   populations and only the second represents retained value.

   is_repeat_session answers the first. Finding the second
   requires counting orders per user_id.

   Retention is conventionally held to be cheaper than
   acquisition, and returning visitors are expected to convert
   substantially better. This file tests whether that holds
   here, and how much of the business actually depends on it.
   ============================================================= */

USE mavenfuzzyfactory;

-- Query 1: conversion and revenue by repeat status. The share
-- columns matter as much as the rates: a group can convert better
-- and still be too small to build a strategy on.

SELECT ws.is_repeat_session,
       COUNT(ws.website_session_id)                        AS sessions,
       ROUND(COUNT(ws.website_session_id) * 100.0
             / (SELECT COUNT(*) FROM website_sessions), 1) AS pct_of_sessions,
       COUNT(o.order_id)                                   AS orders,
       ROUND((COUNT(o.order_id)/COUNT(ws.website_session_id))*100.0,2) AS conversion_rate_pct,
       ROUND(SUM(o.price_usd), 2)                          AS revenue,
       ROUND(SUM(o.price_usd) * 100.0
             / (SELECT SUM(price_usd) FROM orders), 1)     AS pct_of_revenue,
       ROUND((SUM(o.price_usd)/COUNT(ws.website_session_id)),2) AS revenue_per_session
FROM website_sessions ws
LEFT JOIN orders o ON ws.website_session_id = o.website_session_id
GROUP BY ws.is_repeat_session
ORDER BY ws.is_repeat_session;

-- Query 2: how many sessions does each user have? Session-level
-- metrics treat a nine-visit user as nine observations. This
-- counts people.

WITH user_sessions AS (
    SELECT user_id,
           COUNT(*) AS sessions_per_user
    FROM website_sessions
    GROUP BY user_id
)
SELECT sessions_per_user,
       COUNT(*) AS users,
       ROUND(COUNT(*) * 100.0
             / (SELECT COUNT(DISTINCT user_id) FROM website_sessions), 2) AS pct_of_users
FROM user_sessions
GROUP BY sessions_per_user
ORDER BY sessions_per_user;

-- Query 3: orders per customer. Query 2 counted visits; this
-- counts purchases. A user who visited four times and bought once
-- is not a retained customer, and only this query can tell the
-- difference.

WITH user_orders AS (
    SELECT user_id,
           COUNT(*)                                       AS orders_per_user,
           SUM(price_usd)                                 AS revenue_per_user
    FROM orders
    GROUP BY user_id
)
SELECT orders_per_user,
       COUNT(*)                                           AS customers,
       ROUND(COUNT(*) * 100.0
             / (SELECT COUNT(DISTINCT user_id) FROM orders), 2) AS pct_of_customers,
       ROUND(SUM(revenue_per_user), 2)                    AS revenue,
       ROUND(SUM(revenue_per_user) * 100.0
             / (SELECT SUM(price_usd) FROM orders), 1)    AS pct_of_revenue
FROM user_orders
GROUP BY orders_per_user
ORDER BY orders_per_user;