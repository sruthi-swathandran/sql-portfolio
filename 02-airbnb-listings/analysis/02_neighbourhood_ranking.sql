/* Question 2: which neighbourhoods command the highest prices,
   and how much of that is location rather than property size?

   Ranked twice. Nightly price is what a guest pays. Price per
   person controls for the fact that some areas rent whole
   houses sleeping six while others rent studios.

   rank_shift = rank_nightly - rank_per_person
     negative: the nightly rank was inflated by larger properties
     positive: genuinely expensive per person, smaller properties
     zero:     the two measures agree
*/

/* --- Choosing the volume threshold -------------------------
   A median built on eight listings is noise. This shows how
   many of the 660 neighbourhoods survive various cutoffs.
   100 keeps 272, roughly 27 per city, which is enough for a
   top-three-per-city ranking while dropping the ones too small
   to mean anything.
   ---------------------------------------------------------- */

WITH nb AS (
    SELECT city, neighbourhood, COUNT(*) AS listings
    FROM listings
    GROUP BY city, neighbourhood
)
SELECT COUNT(*)             AS neighbourhoods,
       SUM(listings >= 30)  AS at_least_30,
       SUM(listings >= 50)  AS at_least_50,
       SUM(listings >= 100) AS at_least_100,
       SUM(listings >= 200) AS at_least_200
FROM nb;

/* --- Neighbourhood ranking, both measures ------------------ */

WITH converted AS (
    SELECT l.city,
           l.neighbourhood,
           l.price / c.units_per_usd                  AS price_usd,
           l.price / c.units_per_usd / l.accommodates AS price_per_person
    FROM listings l
    JOIN currency_rates c ON l.city = c.city
    WHERE l.price > 0
      AND l.accommodates > 0
),
nb_ranked AS (
    SELECT city, neighbourhood, price_usd, price_per_person,
           ROW_NUMBER() OVER (PARTITION BY city, neighbourhood ORDER BY price_usd)        AS rn_price,
           ROW_NUMBER() OVER (PARTITION BY city, neighbourhood ORDER BY price_per_person) AS rn_pp,
           COUNT(*)     OVER (PARTITION BY city, neighbourhood)                           AS n
    FROM converted
),
nb_median AS (
    SELECT city, neighbourhood,
           MAX(n) AS listings,
           ROUND(AVG(CASE WHEN rn_price IN (FLOOR((n + 1) / 2), CEIL((n + 1) / 2))
                          THEN price_usd END), 2)        AS median_usd,
           ROUND(AVG(CASE WHEN rn_pp IN (FLOOR((n + 1) / 2), CEIL((n + 1) / 2))
                          THEN price_per_person END), 2) AS median_per_person
    FROM nb_ranked
    GROUP BY city, neighbourhood
    HAVING listings >= 100
),
ranked AS (
    SELECT city, neighbourhood, listings, median_usd, median_per_person,
           RANK() OVER (PARTITION BY city ORDER BY median_usd DESC)        AS rank_nightly,
           RANK() OVER (PARTITION BY city ORDER BY median_per_person DESC) AS rank_per_person
    FROM nb_median
)
SELECT city, neighbourhood, listings,
       median_usd, rank_nightly,
       median_per_person, rank_per_person,
       CAST(rank_nightly AS SIGNED) - CAST(rank_per_person AS SIGNED) AS rank_shift
FROM ranked
WHERE rank_nightly <= 3 OR rank_per_person <= 3
ORDER BY city, rank_nightly;

/* --- City-level spread -------------------------------------
   Dearest neighbourhood median over cheapest, computed both
   ways. size_effect above 1 means the nightly spread overstates
   how much location varies, because the expensive areas also
   rent larger properties.

   The CTEs repeat because a WITH clause lives only for the
   statement it is attached to. A view would avoid the
   duplication at the cost of another object to maintain.
   ---------------------------------------------------------- */

WITH converted AS (
    SELECT l.city,
           l.neighbourhood,
           l.price / c.units_per_usd                  AS price_usd,
           l.price / c.units_per_usd / l.accommodates AS price_per_person
    FROM listings l
    JOIN currency_rates c ON l.city = c.city
    WHERE l.price > 0
      AND l.accommodates > 0
),
nb_ranked AS (
    SELECT city, neighbourhood, price_usd, price_per_person,
           ROW_NUMBER() OVER (PARTITION BY city, neighbourhood ORDER BY price_usd)        AS rn_price,
           ROW_NUMBER() OVER (PARTITION BY city, neighbourhood ORDER BY price_per_person) AS rn_pp,
           COUNT(*)     OVER (PARTITION BY city, neighbourhood)                           AS n
    FROM converted
),
nb_median AS (
    SELECT city, neighbourhood,
           MAX(n) AS listings,
           ROUND(AVG(CASE WHEN rn_price IN (FLOOR((n + 1) / 2), CEIL((n + 1) / 2))
                          THEN price_usd END), 2)        AS median_usd,
           ROUND(AVG(CASE WHEN rn_pp IN (FLOOR((n + 1) / 2), CEIL((n + 1) / 2))
                          THEN price_per_person END), 2) AS median_per_person
    FROM nb_ranked
    GROUP BY city, neighbourhood
    HAVING listings >= 100
)
SELECT city,
       COUNT(*)                                                  AS neighbourhoods,
       ROUND(MAX(median_usd) / MIN(median_usd), 2)               AS spread_nightly,
       ROUND(MAX(median_per_person) / MIN(median_per_person), 2) AS spread_per_person,
       ROUND((MAX(median_usd) / MIN(median_usd))
             / (MAX(median_per_person) / MIN(median_per_person)), 2) AS size_effect
FROM nb_median
GROUP BY city
ORDER BY spread_per_person DESC;
