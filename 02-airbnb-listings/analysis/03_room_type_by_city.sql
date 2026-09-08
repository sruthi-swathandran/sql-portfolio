/* Question 3: which room types dominate each market, what do
   they cost, and is the whole-home premium about privacy or
   just about space?

   A whole home sleeps more people than a private room, so a
   higher nightly price is expected. Comparing per person
   separates the two: what survives is what guests pay for
   exclusivity rather than for extra beds.
*/

WITH converted AS (
    SELECT l.city,
           l.room_type,
           l.accommodates,
           l.price / c.units_per_usd                  AS price_usd,
           l.price / c.units_per_usd / l.accommodates AS price_per_person
    FROM listings l
    JOIN currency_rates c ON l.city = c.city
    WHERE l.price > 0
      AND l.accommodates > 0
),
ranked AS (
    SELECT city, room_type, accommodates, price_usd, price_per_person,
           ROW_NUMBER() OVER (PARTITION BY city, room_type ORDER BY price_usd)        AS rn,
           ROW_NUMBER() OVER (PARTITION BY city, room_type ORDER BY price_per_person) AS rn_pp,
           COUNT(*)     OVER (PARTITION BY city, room_type)                           AS n,
           COUNT(*)     OVER (PARTITION BY city)                                      AS city_n
    FROM converted
),
rt_median AS (
    SELECT city, room_type,
           MAX(n)                                 AS listings,
           ROUND(100.0 * MAX(n) / MAX(city_n), 1) AS pct_of_city,
           ROUND(AVG(accommodates), 1)            AS avg_sleeps,
           ROUND(AVG(CASE WHEN rn IN (FLOOR((n + 1) / 2), CEIL((n + 1) / 2))
                          THEN price_usd END), 2)        AS median_usd,
           ROUND(AVG(CASE WHEN rn_pp IN (FLOOR((n + 1) / 2), CEIL((n + 1) / 2))
                          THEN price_per_person END), 2) AS median_per_person
    FROM ranked
    GROUP BY city, room_type
)
SELECT city,
       MAX(CASE WHEN room_type = 'Entire place' THEN pct_of_city       END) AS pct_entire,
       MAX(CASE WHEN room_type = 'Entire place' THEN avg_sleeps        END) AS entire_sleeps,
       MAX(CASE WHEN room_type = 'Entire place' THEN median_usd        END) AS entire_median,
       MAX(CASE WHEN room_type = 'Private room' THEN avg_sleeps        END) AS private_sleeps,
       MAX(CASE WHEN room_type = 'Private room' THEN median_usd        END) AS private_median,
       ROUND(MAX(CASE WHEN room_type = 'Entire place' THEN median_usd END)
             / MAX(CASE WHEN room_type = 'Private room' THEN median_usd END), 2) AS premium_nightly,
       ROUND(MAX(CASE WHEN room_type = 'Entire place' THEN median_per_person END)
             / MAX(CASE WHEN room_type = 'Private room' THEN median_per_person END), 2) AS premium_per_person
FROM rt_median
GROUP BY city
ORDER BY premium_per_person DESC;