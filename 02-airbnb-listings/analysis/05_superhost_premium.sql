/* Question 5: do superhosts charge a premium, and do they earn
   better review scores?

   Three queries.

   1. Superhost against regular host per city, on price per
      person and average rating.
   2. Room type mix by superhost status, to check whether any
      price difference is composition.
   3. The same comparison restricted to whole homes.

   Compared per person rather than per night, since a superhost
   renting a four-bed house against a regular host renting a
   studio would show a premium that is really about size.

   Split by city, because superhosts are unlikely to be evenly
   distributed and the cities differ in price by a factor of
   three. A pooled comparison would partly measure which cities
   superhosts are concentrated in.

   Note that the rating comparison is close to circular. Airbnb
   awards superhost status partly for maintaining a high rating,
   so a gap is the eligibility rule showing up rather than a
   finding about host behaviour. It is reported as a check that
   the flag means what it claims.
*/

WITH converted AS (
    SELECT l.city,
           h.host_is_superhost,
           l.review_scores_rating,
           l.price / c.units_per_usd / l.accommodates AS price_per_person
    FROM listings l
    JOIN hosts h          ON l.host_id = h.host_id
    JOIN currency_rates c ON l.city    = c.city
    WHERE l.price > 0
      AND l.accommodates > 0
      AND h.host_is_superhost IS NOT NULL
),
ranked AS (
    SELECT city, host_is_superhost, review_scores_rating, price_per_person,
           ROW_NUMBER() OVER (PARTITION BY city, host_is_superhost
                              ORDER BY price_per_person)          AS rn,
           COUNT(*)     OVER (PARTITION BY city, host_is_superhost) AS n,
           COUNT(*)     OVER (PARTITION BY city)                    AS city_n
    FROM converted
),
agg AS (
    SELECT city, host_is_superhost,
           MAX(n)                                 AS listings,
           ROUND(100.0 * MAX(n) / MAX(city_n), 1) AS pct_of_city,
           ROUND(AVG(review_scores_rating), 1)    AS avg_rating,
           ROUND(AVG(CASE WHEN rn IN (FLOOR((n + 1) / 2), CEIL((n + 1) / 2))
                          THEN price_per_person END), 2) AS median_per_person
    FROM ranked
    GROUP BY city, host_is_superhost
)
SELECT city,
       MAX(CASE WHEN host_is_superhost = 1 THEN pct_of_city       END) AS pct_superhost,
       MAX(CASE WHEN host_is_superhost = 1 THEN median_per_person END) AS superhost_ppp,
       MAX(CASE WHEN host_is_superhost = 0 THEN median_per_person END) AS regular_ppp,
       ROUND(MAX(CASE WHEN host_is_superhost = 1 THEN median_per_person END)
             / MAX(CASE WHEN host_is_superhost = 0 THEN median_per_person END), 2) AS price_ratio,
       MAX(CASE WHEN host_is_superhost = 1 THEN avg_rating END) AS superhost_rating,
       MAX(CASE WHEN host_is_superhost = 0 THEN avg_rating END) AS regular_rating
FROM agg
GROUP BY city
ORDER BY price_ratio DESC;

/* --- Room type mix by superhost status ---------------------
   Price per person controls for property size but not for room
   type. If superhosts rented disproportionately more private
   rooms, which cost less per person, the discount in query 1
   would be composition rather than pricing.

   It runs the other way: superhosts hold 70.9% whole homes
   against 63.8% for regular hosts, so the mix works against the
   discount rather than explaining it.
   ---------------------------------------------------------- */
SELECT h.host_is_superhost,
       COUNT(*)                                        AS listings,
       ROUND(100.0 * AVG(l.room_type = 'Entire place'), 1) AS pct_entire,
       ROUND(100.0 * AVG(l.room_type = 'Private room'), 1) AS pct_private,
       ROUND(100.0 * AVG(l.room_type = 'Hotel room'),   1) AS pct_hotel,
       ROUND(100.0 * AVG(l.room_type = 'Shared room'),  1) AS pct_shared
FROM listings l
JOIN hosts h ON l.host_id = h.host_id
WHERE h.host_is_superhost IS NOT NULL
GROUP BY h.host_is_superhost;


/* --- The same comparison, whole homes only -----------------
   Removes the room type confound entirely. Hong Kong's apparent
   0.83 discount becomes exactly 1.00, so it was mix. New York's
   grows from 0.93 to 0.84, so its pooled figure was hiding a
   real one. Rio holds at 0.73 and Paris at 1.17.
   ---------------------------------------------------------- */
WITH converted AS (
    SELECT l.city,
           h.host_is_superhost,
           l.price / c.units_per_usd / l.accommodates AS price_per_person
    FROM listings l
    JOIN hosts h          ON l.host_id = h.host_id
    JOIN currency_rates c ON l.city    = c.city
    WHERE l.price > 0
      AND l.accommodates > 0
      AND l.room_type = 'Entire place'
      AND h.host_is_superhost IS NOT NULL
),
ranked AS (
    SELECT city, host_is_superhost, price_per_person,
           ROW_NUMBER() OVER (PARTITION BY city, host_is_superhost
                              ORDER BY price_per_person)            AS rn,
           COUNT(*)     OVER (PARTITION BY city, host_is_superhost) AS n
    FROM converted
),
agg AS (
    SELECT city, host_is_superhost,
           MAX(n) AS listings,
           ROUND(AVG(CASE WHEN rn IN (FLOOR((n + 1) / 2), CEIL((n + 1) / 2))
                          THEN price_per_person END), 2) AS median_per_person
    FROM ranked
    GROUP BY city, host_is_superhost
)
SELECT city,
       MAX(CASE WHEN host_is_superhost = 1 THEN median_per_person END) AS superhost_ppp,
       MAX(CASE WHEN host_is_superhost = 0 THEN median_per_person END) AS regular_ppp,
       ROUND(MAX(CASE WHEN host_is_superhost = 1 THEN median_per_person END)
             / MAX(CASE WHEN host_is_superhost = 0 THEN median_per_person END), 2) AS price_ratio_entire_only
FROM agg
GROUP BY city
ORDER BY price_ratio_entire_only DESC;