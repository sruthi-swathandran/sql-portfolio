/* Question 4: what does each additional guest add to the price?

   Three queries.

   1. Median price by capacity, with the marginal cost of each
      extra guest.
   2. Bedroom distribution by capacity, which is what explains
      the pattern the first query finds.
   3. The same comparison run per city, to check the pooled
      result is not an artefact of combining ten markets.

   Restricted to whole homes throughout. Mixing room types would
   confound the answer, since a private room sleeping four is a
   different product from an apartment sleeping four.

   Capped at 8 guests. Above that the counts thin out and the
   medians get noisy.

   LAG(median_usd) OVER (ORDER BY accommodates) returns the
   previous row's value, so subtracting gives the marginal cost
   of one more guest. LAG and LEAD are how you compare a row to
   its neighbours without a self-join.
*/

WITH converted AS (
    SELECT l.accommodates,
           l.bedrooms,
           l.price / c.units_per_usd                  AS price_usd,
           l.price / c.units_per_usd / l.accommodates AS price_per_person
    FROM listings l
    JOIN currency_rates c ON l.city = c.city
    WHERE l.price > 0
      AND l.room_type = 'Entire place'
      AND l.accommodates BETWEEN 1 AND 8
),
ranked AS (
    SELECT accommodates, bedrooms, price_usd, price_per_person,
           ROW_NUMBER() OVER (PARTITION BY accommodates ORDER BY price_usd)        AS rn,
           ROW_NUMBER() OVER (PARTITION BY accommodates ORDER BY price_per_person) AS rn_pp,
           COUNT(*)     OVER (PARTITION BY accommodates)                           AS n
    FROM converted
),
by_size AS (
    SELECT accommodates,
           MAX(n) AS listings,
           ROUND(AVG(bedrooms), 2) AS avg_bedrooms,
           ROUND(AVG(CASE WHEN rn IN (FLOOR((n + 1) / 2), CEIL((n + 1) / 2))
                          THEN price_usd END), 2)        AS median_usd,
           ROUND(AVG(CASE WHEN rn_pp IN (FLOOR((n + 1) / 2), CEIL((n + 1) / 2))
                          THEN price_per_person END), 2) AS median_per_person
    FROM ranked
    GROUP BY accommodates
)
SELECT accommodates,
       listings,
       avg_bedrooms,
       ROUND(avg_bedrooms - LAG(avg_bedrooms) OVER (ORDER BY accommodates), 2) AS extra_bedrooms,
       median_usd,
       ROUND(median_usd - LAG(median_usd) OVER (ORDER BY accommodates), 2)     AS extra_per_guest,
       ROUND(100.0 * (median_usd / LAG(median_usd) OVER (ORDER BY accommodates) - 1), 1) AS pct_increase,
       median_per_person
FROM by_size
ORDER BY accommodates;

/* --- Why the average was not enough -----------------------
   The query above shows price steps alternating between large
   and small, and AVG(bedrooms) rising smoothly, which appears
   to rule out bedrooms as the cause.

   It does not. Each capacity level is a blend of tiers, and a
   mean over a mixture slides even when the groups underneath it
   jump. Sleeping five is 16.9% one-bedroom, 60.0% two-bedroom
   and 21.3% three-bedroom, averaging 2.08 and looking like a
   smooth midpoint.

   The distribution shows the step the average concealed: 96.4%
   of two-guest listings are one-bedroom, and by four guests
   49.6% are two-bedroom.
   ---------------------------------------------------------- */

SELECT l.accommodates,
       COUNT(*)                              AS listings,
       ROUND(100.0 * AVG(l.bedrooms = 1), 1) AS pct_1_bed,
       ROUND(100.0 * AVG(l.bedrooms = 2), 1) AS pct_2_bed,
       ROUND(100.0 * AVG(l.bedrooms = 3), 1) AS pct_3_bed,
       ROUND(100.0 * AVG(l.bedrooms >= 4), 1) AS pct_4_plus
FROM listings l
WHERE l.price > 0
  AND l.room_type = 'Entire place'
  AND l.accommodates BETWEEN 1 AND 8
  AND l.bedrooms IS NOT NULL
GROUP BY l.accommodates
ORDER BY l.accommodates;

/* --- Does the pattern hold across cities? -----------------
   Pooling ten markets could manufacture a pattern that exists
   in none of them, if their price levels differ enough. This
   compares the small step (2 to 3 guests) against the large one
   (3 to 4) within each city separately.

   Eight of ten confirm. Istanbul is flat. Hong Kong reverses,
   which fits its position as the densest market in the dataset.
   ---------------------------------------------------------- */
WITH converted AS (
    SELECT l.city, l.accommodates,
           l.price / c.units_per_usd AS price_usd
    FROM listings l
    JOIN currency_rates c ON l.city = c.city
    WHERE l.price > 0
      AND l.room_type = 'Entire place'
      AND l.accommodates BETWEEN 2 AND 4
),
ranked AS (
    SELECT city, accommodates, price_usd,
           ROW_NUMBER() OVER (PARTITION BY city, accommodates ORDER BY price_usd) AS rn,
           COUNT(*)     OVER (PARTITION BY city, accommodates)                    AS n
    FROM converted
),
by_size AS (
    SELECT city, accommodates,
           MAX(n) AS listings,
           ROUND(AVG(CASE WHEN rn IN (FLOOR((n + 1) / 2), CEIL((n + 1) / 2))
                          THEN price_usd END), 2) AS median_usd
    FROM ranked
    GROUP BY city, accommodates
)
SELECT city,
       MAX(CASE WHEN accommodates = 2 THEN median_usd END) AS sleeps_2,
       MAX(CASE WHEN accommodates = 3 THEN median_usd END) AS sleeps_3,
       MAX(CASE WHEN accommodates = 4 THEN median_usd END) AS sleeps_4,
       ROUND(100.0 * (MAX(CASE WHEN accommodates = 3 THEN median_usd END)
                    / MAX(CASE WHEN accommodates = 2 THEN median_usd END) - 1), 1) AS step_2_to_3,
       ROUND(100.0 * (MAX(CASE WHEN accommodates = 4 THEN median_usd END)
                    / MAX(CASE WHEN accommodates = 3 THEN median_usd END) - 1), 1) AS step_3_to_4
FROM by_size
GROUP BY city
ORDER BY step_3_to_4 DESC;