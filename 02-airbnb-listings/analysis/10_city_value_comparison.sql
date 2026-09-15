/* Question 10: which city offers the best value?

   "Value" cannot mean price per unit of quality here, because
   finding 6 showed review scores carry almost no information
   about price. What is answerable is a like-for-like price
   comparison: hold the product fixed and see what each market
   charges for it.

   The basket is a whole home sleeping four with a review score
   of 90 or above. Fixing room type removes the composition
   effect from finding 3, fixing capacity removes the bedroom
   step from finding 4, and requiring a rating removes listings
   that have never been booked, which finding 8 showed are a
   fifth to a half of supply depending on the city.
*/
USE airbnb_listings;
WITH basket AS (
    SELECT l.city,
           l.price / c.units_per_usd AS price_usd
    FROM listings l
    JOIN currency_rates c ON l.city = c.city
    WHERE l.price > 0
      AND l.room_type = 'Entire place'
      AND l.accommodates = 4
      AND l.review_scores_rating >= 90
),
ranked AS (
    SELECT city, price_usd,
           ROW_NUMBER() OVER (PARTITION BY city ORDER BY price_usd) AS rn,
           COUNT(*)     OVER (PARTITION BY city)                    AS n
    FROM basket
)
SELECT city,
       MAX(n) AS listings_in_basket,
       ROUND(AVG(CASE WHEN rn = CEIL(n * 0.25) THEN price_usd END), 2) AS p25,
       ROUND(AVG(CASE WHEN rn IN (FLOOR((n + 1) / 2), CEIL((n + 1) / 2))
                      THEN price_usd END), 2)                          AS median,
       ROUND(AVG(CASE WHEN rn = CEIL(n * 0.75) THEN price_usd END), 2) AS p75
FROM ranked
GROUP BY city
ORDER BY median;