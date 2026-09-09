/* Question 8: what share of listings never receive a review,
   and what distinguishes them?

   Two queries.

   1. Never-reviewed share by city, with the two groups compared
      on room type, superhost status and minimum nights.
   2. The same share by host join year, testing whether the
      pattern is really about listing age.

   review_counts collapses 5.37M review rows to one per listing
   in a single pass using the primary key. Joining listings to
   that is far cheaper than a correlated EXISTS per listing.

   AVG(CASE WHEN reviewed = 0 THEN x END) averages x over the
   unreviewed only: the CASE returns NULL for the others and AVG
   skips nulls, so both groups appear side by side in one pass.
*/

WITH review_counts AS (
    SELECT listing_id,
           COUNT(*)         AS n_reviews,
           MIN(review_date) AS first_review,
           MAX(review_date) AS last_review
    FROM reviews
    GROUP BY listing_id
),
flagged AS (
    SELECT l.city,
           l.room_type,
           l.minimum_nights,
           h.host_is_superhost,
           CASE WHEN rc.listing_id IS NULL THEN 0 ELSE 1 END AS reviewed
    FROM listings l
    JOIN hosts h              ON l.host_id    = h.host_id
    LEFT JOIN review_counts rc ON l.listing_id = rc.listing_id
)
SELECT city,
       COUNT(*)                                                              AS listings,
       ROUND(100.0 * AVG(reviewed = 0), 1)                                   AS pct_never_reviewed,
       ROUND(100.0 * AVG(CASE WHEN reviewed = 0 THEN room_type = 'Entire place' END), 1) AS unrev_pct_entire,
       ROUND(100.0 * AVG(CASE WHEN reviewed = 1 THEN room_type = 'Entire place' END), 1) AS rev_pct_entire,
       ROUND(100.0 * AVG(CASE WHEN reviewed = 0 THEN host_is_superhost END), 1)          AS unrev_pct_superhost,
       ROUND(100.0 * AVG(CASE WHEN reviewed = 1 THEN host_is_superhost END), 1)          AS rev_pct_superhost,
       ROUND(AVG(CASE WHEN reviewed = 0 THEN minimum_nights END), 1)         AS unrev_min_nights,
       ROUND(AVG(CASE WHEN reviewed = 1 THEN minimum_nights END), 1)         AS rev_min_nights
FROM flagged
GROUP BY city
ORDER BY pct_never_reviewed DESC;


/* --- Is it just that the listings are new? ----------------
   A listing posted last month cannot have been reviewed, so
   the differences above could be measuring age rather than
   anything about the listings.

   There is no listing creation date in this data. host_since is
   the closest proxy, and an imperfect one: a host who joined in
   2013 can have added a listing in 2021, so every cohort
   contains some genuinely new listings. That flattens the
   relationship, meaning the real age effect is steeper than
   whatever this shows.

   The 2020 and 2021 cohorts carry a second confound. Global
   travel had stopped, and the data ends 1 March 2021, so those
   hosts had little opportunity to be booked for reasons that
   have nothing to do with their listings.
   ---------------------------------------------------------- */
WITH review_counts AS (
    SELECT listing_id, COUNT(*) AS n_reviews
    FROM reviews
    GROUP BY listing_id
),
flagged AS (
    SELECT h.host_since,
           CASE WHEN rc.listing_id IS NULL THEN 0 ELSE 1 END AS reviewed
    FROM listings l
    JOIN hosts h               ON l.host_id    = h.host_id
    LEFT JOIN review_counts rc ON l.listing_id = rc.listing_id
    WHERE h.host_since IS NOT NULL
)
SELECT YEAR(host_since) AS host_joined,
       COUNT(*)                            AS listings,
       ROUND(100.0 * AVG(reviewed = 0), 1) AS pct_never_reviewed
FROM flagged
GROUP BY YEAR(host_since)
ORDER BY host_joined;