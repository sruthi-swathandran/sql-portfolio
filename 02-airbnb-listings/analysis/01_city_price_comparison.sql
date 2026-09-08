/* Question 1: how do the ten city markets compare on price,
   once converted to a common currency?

   MySQL has no MEDIAN function, so percentiles are built from
   two window functions:

     ROW_NUMBER() ... PARTITION BY city ORDER BY price_usd
       numbers each city's listings from cheapest to dearest,
       restarting at 1 for every city.

     COUNT(*) ... PARTITION BY city
       puts that city's total on every one of its rows, so each
       row knows which position is the middle.

   PARTITION BY is GROUP BY for window functions, except the
   rows survive instead of collapsing.

   Listings priced at zero are excluded. A free listing is a
   missing value entered as 0, not a price. 113 rows.
*/

WITH converted AS (
    SELECT l.city,
           l.price / c.units_per_usd AS price_usd
    FROM listings l
    JOIN currency_rates c ON l.city = c.city
    WHERE l.price > 0
),
ranked AS (
    SELECT city,
           price_usd,
           ROW_NUMBER() OVER (PARTITION BY city ORDER BY price_usd) AS rn,
           COUNT(*)     OVER (PARTITION BY city)                    AS n
    FROM converted
)
SELECT city,
       MAX(n)                                                             AS listings,
       ROUND(AVG(price_usd), 2)                                           AS mean_usd,
       ROUND(AVG(CASE WHEN rn = CEIL(n * 0.25)
                      THEN price_usd END), 2)                             AS p25_usd,
       ROUND(AVG(CASE WHEN rn IN (FLOOR((n + 1) / 2), CEIL((n + 1) / 2))
                      THEN price_usd END), 2)                             AS median_usd,
       ROUND(AVG(CASE WHEN rn = CEIL(n * 0.75)
                      THEN price_usd END), 2)                             AS p75_usd,
       ROUND(AVG(price_usd)
             / AVG(CASE WHEN rn IN (FLOOR((n + 1) / 2), CEIL((n + 1) / 2))
                        THEN price_usd END), 2)                           AS mean_to_median
FROM ranked
GROUP BY city
ORDER BY median_usd DESC;
