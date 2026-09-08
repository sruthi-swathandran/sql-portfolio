/* Question 6: which review score dimension is most associated
   with price?

   MySQL has no CORR(), so Pearson is built from the raw sums:
     r = (n*Sxy - Sx*Sy) / sqrt(n*Sxx - Sx^2) / sqrt(n*Syy - Sy^2)

   The six dimensions are unpivoted with UNION ALL so the
   formula is written once and grouped, rather than repeated per
   column.

   Price per person is trimmed to $1 to $1000. Pearson is very
   sensitive to outliers and this dataset reaches $625,216.
*/

WITH base AS (
    SELECT l.price / c.units_per_usd / l.accommodates AS ppp,
           l.review_scores_accuracy,
           l.review_scores_cleanliness,
           l.review_scores_checkin,
           l.review_scores_communication,
           l.review_scores_location,
           l.review_scores_value
    FROM listings l
    JOIN currency_rates c ON l.city = c.city
    WHERE l.price > 0
      AND l.accommodates > 0
      AND l.price / c.units_per_usd / l.accommodates BETWEEN 1 AND 1000
),
unpivoted AS (
    SELECT ppp, 'accuracy'      AS dimension, review_scores_accuracy      AS score FROM base WHERE review_scores_accuracy      IS NOT NULL
    UNION ALL
    SELECT ppp, 'cleanliness',                review_scores_cleanliness         FROM base WHERE review_scores_cleanliness   IS NOT NULL
    UNION ALL
    SELECT ppp, 'checkin',                    review_scores_checkin             FROM base WHERE review_scores_checkin       IS NOT NULL
    UNION ALL
    SELECT ppp, 'communication',              review_scores_communication       FROM base WHERE review_scores_communication IS NOT NULL
    UNION ALL
    SELECT ppp, 'location',                   review_scores_location            FROM base WHERE review_scores_location      IS NOT NULL
    UNION ALL
    SELECT ppp, 'value',                      review_scores_value               FROM base WHERE review_scores_value         IS NOT NULL
)
SELECT dimension,
       COUNT(*) AS listings,
       ROUND(AVG(score), 2) AS avg_score,
       ROUND(
           (COUNT(*) * SUM(score * ppp) - SUM(score) * SUM(ppp))
           / (SQRT(COUNT(*) * SUM(score * score) - POW(SUM(score), 2))
            * SQRT(COUNT(*) * SUM(ppp * ppp)     - POW(SUM(ppp), 2)))
       , 3) AS correlation
FROM unpivoted
GROUP BY dimension
ORDER BY correlation DESC;

/* --- The same correlations computed within each city -------
   The pooled figures mix ten markets whose price levels differ
   threefold while their review scores barely move. That
   between-city variation is noise for this question and could
   be drowning a real within-city signal.

   Pivoted so each city is one row.
   ---------------------------------------------------------- */

WITH base AS (
    SELECT l.city,
           l.price / c.units_per_usd / l.accommodates AS ppp,
           l.review_scores_accuracy,
           l.review_scores_cleanliness,
           l.review_scores_checkin,
           l.review_scores_communication,
           l.review_scores_location,
           l.review_scores_value
    FROM listings l
    JOIN currency_rates c ON l.city = c.city
    WHERE l.price > 0
      AND l.accommodates > 0
      AND l.price / c.units_per_usd / l.accommodates BETWEEN 1 AND 1000
),
unpivoted AS (
    SELECT city, ppp, 'accuracy'      AS dimension, review_scores_accuracy      AS score FROM base WHERE review_scores_accuracy      IS NOT NULL
    UNION ALL
    SELECT city, ppp, 'cleanliness',                review_scores_cleanliness         FROM base WHERE review_scores_cleanliness   IS NOT NULL
    UNION ALL
    SELECT city, ppp, 'checkin',                    review_scores_checkin             FROM base WHERE review_scores_checkin       IS NOT NULL
    UNION ALL
    SELECT city, ppp, 'communication',              review_scores_communication       FROM base WHERE review_scores_communication IS NOT NULL
    UNION ALL
    SELECT city, ppp, 'location',                   review_scores_location            FROM base WHERE review_scores_location      IS NOT NULL
    UNION ALL
    SELECT city, ppp, 'value',                      review_scores_value               FROM base WHERE review_scores_value         IS NOT NULL
),
corr AS (
    SELECT city, dimension,
           ROUND(
               (COUNT(*) * SUM(score * ppp) - SUM(score) * SUM(ppp))
               / (SQRT(COUNT(*) * SUM(score * score) - POW(SUM(score), 2))
                * SQRT(COUNT(*) * SUM(ppp * ppp)     - POW(SUM(ppp), 2)))
           , 3) AS r
    FROM unpivoted
    GROUP BY city, dimension
)
SELECT city,
       MAX(CASE WHEN dimension = 'location'      THEN r END) AS location,
       MAX(CASE WHEN dimension = 'cleanliness'   THEN r END) AS cleanliness,
       MAX(CASE WHEN dimension = 'accuracy'      THEN r END) AS accuracy,
       MAX(CASE WHEN dimension = 'communication' THEN r END) AS communication,
       MAX(CASE WHEN dimension = 'checkin'       THEN r END) AS checkin,
       MAX(CASE WHEN dimension = 'value'         THEN r END) AS value_score
FROM corr
GROUP BY city
ORDER BY location DESC;