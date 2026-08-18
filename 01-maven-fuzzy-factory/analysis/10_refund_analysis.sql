/* =============================================================
   Question 10: Which product has the highest refund rate, and
   does any product show a quality problem in a specific period?

   Refund rate is measured per product against that product's own
   units sold.

   Monthly analysis keys on the ORDER date, not the refund date.
   A refund issued in October may relate to an item ordered in
   September, so grouping by refund date smears a batch problem
   across the following weeks and measures the support queue
   rather than the product.

   Refunds are recorded per order item, so an order containing two
   items can be refunded in part.
   ============================================================= */

USE mavenfuzzyfactory;

-- Query 1: refund rate by product across the full period. The
-- denominator is items sold of that product, so each product is
-- measured against its own volume rather than against total sales.

SELECT p.product_name,
       COUNT(oi.order_item_id)                       AS items_sold,
       COUNT(DISTINCT oir.order_item_id)             AS items_refunded,
       ROUND(COUNT(DISTINCT oir.order_item_id) / COUNT(oi.order_item_id) * 100.0, 2)                    AS refund_rate_pct,
       ROUND(SUM(oi.price_usd), 2)                   AS revenue,
       ROUND(SUM(oir.refund_amount_usd), 2)          AS refunded_value
FROM order_items oi
LEFT JOIN order_item_refunds oir ON oi.order_item_id = oir.order_item_id
LEFT JOIN products p             ON oi.product_id    = p.product_id
GROUP BY p.product_name
ORDER BY refund_rate_pct DESC;

-- Query 2: monthly refund rate by product, keyed on ORDER date so
-- a bad batch lands in the month it shipped rather than the month
-- customers happened to complain. Low-volume months are excluded
-- because a handful of refunds produces a meaningless rate.

SELECT p.product_name,
       DATE_FORMAT(o.created_at, '%Y-%m')            AS order_month,
       COUNT(oi.order_item_id)                       AS items_sold,
       COUNT(DISTINCT oir.order_item_id)             AS items_refunded,
       ROUND(COUNT(DISTINCT oir.order_item_id) * 100.0
             / COUNT(oi.order_item_id), 2)           AS refund_rate_pct
FROM order_items oi
JOIN orders o                    ON oi.order_id      = o.order_id
LEFT JOIN order_item_refunds oir ON oi.order_item_id = oir.order_item_id
LEFT JOIN products p             ON oi.product_id    = p.product_id
GROUP BY p.product_name, DATE_FORMAT(o.created_at, '%Y-%m')
HAVING items_sold >= 100
ORDER BY p.product_name, order_month;

-- Query 3: the same refunds grouped by refund date rather than
-- order date, for Mr Fuzzy only. Compared against query 2 this
-- shows how much a batch problem gets smeared when keyed on when
-- the customer complained instead of when the item shipped.
-- avg_days_to_refund quantifies the lag directly.

SELECT DATE_FORMAT(oir.created_at, '%Y-%m')                    AS refund_month,
       COUNT(*)                                                AS refunds_issued,
       ROUND(AVG(DATEDIFF(oir.created_at, o.created_at)), 1)   AS avg_days_to_refund
FROM order_item_refunds oir
JOIN order_items oi ON oir.order_item_id = oi.order_item_id
JOIN orders o       ON oi.order_id       = o.order_id
JOIN products p     ON oi.product_id     = p.product_id
WHERE p.product_name = 'The Original Mr. Fuzzy'
GROUP BY DATE_FORMAT(oir.created_at, '%Y-%m')
ORDER BY refund_month;

-- Query 4: refund rate by product AND role in the order. Comparing
-- products alone confounds quality with role, since Hudson is
-- overwhelmingly an add-on and Mr Fuzzy is almost never one.
-- Splitting within each product removes that confound.

SELECT p.product_name,
       oi.is_primary_item,
       COUNT(oi.order_item_id)                       AS items_sold,
       COUNT(DISTINCT oir.order_item_id)             AS items_refunded,
       ROUND(COUNT(DISTINCT oir.order_item_id) * 100.0
             / COUNT(oi.order_item_id), 2)           AS refund_rate_pct
FROM order_items oi
LEFT JOIN order_item_refunds oir ON oi.order_item_id = oir.order_item_id
LEFT JOIN products p             ON oi.product_id    = p.product_id
GROUP BY p.product_name, oi.is_primary_item
ORDER BY p.product_name, oi.is_primary_item;

-- Query 5: query 4 restricted to the period when cross-selling
-- existed. Mr Fuzzy add-ons only became possible in September 2013,
-- so the unrestricted comparison measures two eras as well as two
-- roles.
SELECT p.product_name,
       oi.is_primary_item,
       COUNT(oi.order_item_id)                       AS items_sold,
       COUNT(DISTINCT oir.order_item_id)             AS items_refunded,
       ROUND(COUNT(DISTINCT oir.order_item_id) * 100.0
             / COUNT(oi.order_item_id), 2)           AS refund_rate_pct
FROM order_items oi
JOIN orders o                    ON oi.order_id      = o.order_id
LEFT JOIN order_item_refunds oir ON oi.order_item_id = oir.order_item_id
LEFT JOIN products p             ON oi.product_id    = p.product_id
WHERE o.created_at >= '2013-09-01'
GROUP BY p.product_name, oi.is_primary_item
ORDER BY p.product_name, oi.is_primary_item;