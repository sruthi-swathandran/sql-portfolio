/* =============================================================
   Maven Fuzzy Factory - Product Launch Impact
   MySQL 8.0

   Business question 6: what was the measurable impact of each new
   product launch?

   LAUNCH DATES (from products.created_at)
   ---------------------------------------
   The Original Mr. Fuzzy       $49.99   19 Mar 2012  (site launch)
   The Forever Love Bear        $59.99   06 Jan 2013
   The Birthday Sugar Panda     $45.99   12 Dec 2013
   The Hudson River Mini bear   $29.99   05 Feb 2014

   WHY A NAIVE BEFORE/AFTER FAILS HERE
   -----------------------------------
   Conversion rose from 4.1% to 8.4% across the whole period. Compare
   any 90 days against the following 90 days and "after" looks better,
   including around dates when nothing happened. A before/after
   comparison is only valid if nothing else changed, and here plenty
   did:

     - a strong upward trend in every metric
     - Q4 seasonality (the Sugar Panda launched 12 December)
     - two launches only 55 days apart, so the Panda's "after" window
       contains the Hudson River launch

   THE METRIC THAT SURVIVES
   ------------------------
   Items per order. With a single product on sale it is mechanically
   impossible to exceed 1.000 - you cannot buy two distinct items from
   a catalogue of one. Trend, seasonality and ad spend cannot lift a
   number past a structural ceiling. So any rise is directly
   attributable to the catalogue expanding.

   Note the ceiling is 2.000, not unbounded: orders contain one or two
   items, never more, and never the same product twice. Items per order
   therefore measures the ADD-ON ATTACH RATE, where 1.000 = no add-ons
   and 2.000 = every order has one.

   This is a narrow metric by design. It establishes that something
   changed; the broader metrics below say whether it mattered.
   ============================================================= */

USE mavenfuzzyfactory;

/* Monthly items per order and average order value.

   Items per order is exact 1.000 from Mar 2012 to Aug 2013 - eighteen
   months, including eight months AFTER the second product launched in
   January 2013. Adding a product did not by itself make anyone buy two.

   First movement: September 2013 (1.010). No product launched that
   month, so the cause must be a site change enabling add-ons.
   Step change: February 2014 (1.131 -> 1.320), coinciding with the
   Hudson River Mini bear at $29.99.

   Exported to results/06_monthly_items_per_order.csv
*/
SELECT YEAR(created_at) AS year_,
MONTH(created_at)       AS month_,
ROUND(SUM(items_purchased) / COUNT(*),3) AS items_per_order,
ROUND(SUM(price_usd) / COUNT(*),2)              AS average_order_value
FROM orders
GROUP BY YEAR(created_at), MONTH(created_at)
ORDER BY year_,  month_;

/* Primary versus add-on sales by product.

   MAX(price_usd) is safe here only because each product has exactly one
   distinct price - verified separately. It is not a general pattern.

   The Hudson River Mini bear sells 8x more often as an add-on (4,437)
   than as a main purchase (581) - 88.4% of its volume. Mr Fuzzy is the
   opposite at 1.5%: it is the destination product, 60% of all primary
   items.

   Prices are identical whether an item is primary or an add-on, so no
   discount was introduced alongside the cross-sell feature.

   CHECK: sold_as_primary + sold_as_addon across all rows = 40,025,
   the row count of order_items.

   Exported to results/06_product_mix.csv
*/
SELECT p.product_name,
MAX(oi.price_usd)             AS price,
SUM(oi.is_primary_item = 1)   AS sold_as_primary,
SUM(oi.is_primary_item = 0)   AS sold_as_addon,
ROUND(SUM(oi.is_primary_item = 0) / COUNT(oi.product_id)*100.0,2)   AS pct_sold_as_addon
FROM order_items oi
JOIN products p on oi.product_id = p.product_id
GROUP BY p.product_name
ORDER BY sold_as_addon DESC;

/* Before/after comparison, 90 days either side of each launch.

   TREAT WITH CAUTION. Included for completeness, but confounded three
   ways: every metric was trending upward regardless; the Sugar Panda
   launched on 12 December, inside the Q4 peak; and the Panda and Hudson
   River launches are only 55 days apart, so the Panda's "after" window
   contains the Hudson launch.

   The monthly series above is the sounder read. This query is here to
   show the comparison was considered and why it was not relied on.

*/
-- Exported to results/06_launch_windows.csv. Included not as evidence
-- of launch impact but as a demonstration of why before/after fails
-- here: the Forever Love Bear shows fewer orders after launch purely
-- because its "before" window covers Christmas.

SELECT 'Forever Love Bear'         AS launch,
'before'                           AS window_,
COUNT(o.order_id)                  AS orders,
ROUND(SUM(o.items_purchased) / COUNT(o.order_id), 3)  AS items_per_order,
ROUND(SUM(o.price_usd) / COUNT(o.order_id), 2)        AS avg_order_value
FROM orders o
WHERE o.created_at >= DATE_SUB('2013-01-06', INTERVAL 90 DAY)
AND o.created_at < '2013-01-06'

UNION ALL

SELECT 'Forever Love Bear', 'after',
COUNT(o.order_id),
ROUND(SUM(o.items_purchased) / COUNT(o.order_id), 3),
ROUND(SUM(o.price_usd) / COUNT(o.order_id), 2)
FROM orders o
WHERE o.created_at >= '2013-01-06'
AND o.created_at < DATE_ADD('2013-01-06', INTERVAL 90 DAY)
UNION ALL
SELECT 'Birthday Sugar Panda',
'before',
COUNT(o.order_id),
ROUND(SUM(o.items_purchased) / COUNT(o.order_id), 3),
ROUND(SUM(o.price_usd) / COUNT(o.order_id), 2)
FROM orders o
WHERE o.created_at >= DATE_SUB('2013-12-12', INTERVAL 90 DAY)
AND o.created_at < '2013-12-12'
UNION ALL
SELECT 'Birthday Sugar Panda', 'after',
COUNT(o.order_id),
ROUND(SUM(o.items_purchased) / COUNT(o.order_id), 3),
ROUND(SUM(o.price_usd) / COUNT(o.order_id), 2)
FROM orders o
WHERE o.created_at >= '2013-12-12'
AND o.created_at < DATE_ADD('2013-12-12', INTERVAL 90 DAY)
UNION ALL
SELECT 'Hudson River Mini bear',
'before',
COUNT(o.order_id),
ROUND(SUM(o.items_purchased) / COUNT(o.order_id), 3),
ROUND(SUM(o.price_usd) / COUNT(o.order_id), 2)
FROM orders o
WHERE o.created_at >= DATE_SUB('2014-02-05', INTERVAL 90 DAY)
AND o.created_at < '2014-02-05'
UNION ALL
SELECT 'Hudson River Mini bear', 'after',
COUNT(o.order_id),
ROUND(SUM(o.items_purchased) / COUNT(o.order_id), 3),
ROUND(SUM(o.price_usd) / COUNT(o.order_id), 2)
FROM orders o
WHERE o.created_at >= '2014-02-05'
AND o.created_at < DATE_ADD('2014-02-05', INTERVAL 90 DAY);
