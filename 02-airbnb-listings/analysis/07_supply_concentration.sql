/* Question 7: how concentrated is supply among hosts?

   SUM(COUNT(*)) OVER () is an aggregate inside a window
   function. The inner COUNT collapses each band to one row, the
   outer SUM totals across all bands, giving a denominator for
   the percentage without a second query.
*/

WITH host_counts AS (
    SELECT host_id, COUNT(*) AS listings
    FROM listings
    GROUP BY host_id
),
banded AS (
    SELECT listings,
           CASE WHEN listings = 1              THEN '1'
                WHEN listings = 2              THEN '2'
                WHEN listings BETWEEN 3  AND 5  THEN '3 to 5'
                WHEN listings BETWEEN 6  AND 10 THEN '6 to 10'
                WHEN listings BETWEEN 11 AND 50 THEN '11 to 50'
                ELSE '51 or more' END AS band,
           CASE WHEN listings = 1              THEN 1
                WHEN listings = 2              THEN 2
                WHEN listings BETWEEN 3  AND 5  THEN 3
                WHEN listings BETWEEN 6  AND 10 THEN 4
                WHEN listings BETWEEN 11 AND 50 THEN 5
                ELSE 6 END AS band_sort
    FROM host_counts
)
SELECT band,
       COUNT(*)                                                AS hosts,
       ROUND(100.0 * COUNT(*)      / SUM(COUNT(*))      OVER (), 1) AS pct_of_hosts,
       SUM(listings)                                           AS listings,
       ROUND(100.0 * SUM(listings) / SUM(SUM(listings)) OVER (), 1) AS pct_of_supply
FROM banded
GROUP BY band, band_sort
ORDER BY band_sort;

/* What share of hosts controls what share of supply?

   SUM(listings) OVER (ORDER BY ...) is a running total: each
   row gets the sum of every row up to and including itself.

   host_id is added to the ORDER BY to break ties. Without it,
   the default RANGE framing lumps all hosts with the same
   listing count into one step, and the curve jumps rather than
   climbing. That is one of the easier window function mistakes
   to make and one of the harder ones to spot.
*/

WITH host_counts AS (
    SELECT host_id, COUNT(*) AS listings
    FROM listings
    GROUP BY host_id
),
ranked AS (
    SELECT host_id, listings,
           ROW_NUMBER()  OVER (ORDER BY listings DESC, host_id) AS host_rank,
           SUM(listings) OVER (ORDER BY listings DESC, host_id) AS cum_listings,
           COUNT(*)      OVER ()                                AS total_hosts,
           SUM(listings) OVER ()                                AS total_listings
    FROM host_counts
),
pct AS (
    SELECT 100.0 * host_rank    / total_hosts    AS pct_hosts,
           100.0 * cum_listings / total_listings AS pct_listings
    FROM ranked
)
SELECT ROUND(MIN(CASE WHEN pct_listings >= 10 THEN pct_hosts END), 2) AS top_hosts_pct_for_10,
       ROUND(MIN(CASE WHEN pct_listings >= 25 THEN pct_hosts END), 2) AS top_hosts_pct_for_25,
       ROUND(MIN(CASE WHEN pct_listings >= 50 THEN pct_hosts END), 2) AS top_hosts_pct_for_50,
       ROUND(MIN(CASE WHEN pct_listings >= 75 THEN pct_hosts END), 2) AS top_hosts_pct_for_75
FROM pct;

/* --- Concentration by city ---------------------------------
   The platform-wide figures average ten markets that turn out
   to be very different. This splits each city's supply by the
   size of the host behind it: the share coming from operators
   with eleven or more listings anywhere, against the share from
   hosts with exactly one.

   Host size is measured across all cities, not within one, so a
   host with six listings in Paris and six in Rome counts as
   large in both. The 150 hosts who appear in more than one city
   are therefore counted once per city, and the host counts sum
   slightly above the 182,024 total.
   ---------------------------------------------------------- */
WITH host_city AS (
    SELECT l.city, l.host_id, COUNT(*) AS listings_in_city
    FROM listings l
    GROUP BY l.city, l.host_id
),
host_total AS (
    SELECT host_id, COUNT(*) AS total_listings
    FROM listings
    GROUP BY host_id
)
SELECT hc.city,
       COUNT(DISTINCT hc.host_id)                                  AS hosts,
       SUM(hc.listings_in_city)                                    AS listings,
       ROUND(100.0 * SUM(CASE WHEN ht.total_listings >= 11
                              THEN hc.listings_in_city ELSE 0 END)
             / SUM(hc.listings_in_city), 1)                        AS pct_from_large_hosts,
       ROUND(100.0 * SUM(CASE WHEN ht.total_listings = 1
                              THEN hc.listings_in_city ELSE 0 END)
             / SUM(hc.listings_in_city), 1)                        AS pct_from_single_hosts
FROM host_city hc
JOIN host_total ht ON hc.host_id = ht.host_id
GROUP BY hc.city
ORDER BY pct_from_large_hosts DESC;