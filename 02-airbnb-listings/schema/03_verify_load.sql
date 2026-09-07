/* =============================================================
   Airbnb Listings and Reviews - Load Verification
   MySQL 8.0

   Run after 02_load_data.sql. Every check states its expected
   result above the query. All must match before the data is
   used for analysis.

   This file exists because every one of the four problems in
   Listings.csv produced a successful load with wrong data. None
   of them raised an error, and none would have been noticed by
   looking at row counts alone.
   ============================================================= */

USE airbnb_listings;

/* --- Check 1: row counts -----------------------------------
   Expected: 182024, 279712, 5373143
   ---------------------------------------------------------- */

SELECT 'hosts'    AS table_name, COUNT(*) AS rows_loaded FROM hosts
UNION ALL SELECT 'listings',     COUNT(*) FROM listings
UNION ALL SELECT 'reviews',      COUNT(*) FROM reviews;

/* --- Check 2: no fields shifted by escape characters -------
   MySQL's default backslash escaping swallows the delimiter
   after any backslash in the file, shifting the rest of the row
   left by one field. Detected by looking for values that cannot
   belong in a given column.

   Expected: exactly three rows, 'f' 229294, 't' 50253, '' 165.
   Any numeric value here means ESCAPED BY '' is missing from
   the load statement.
   ---------------------------------------------------------- */

SELECT host_is_superhost, COUNT(*) AS rows_found
FROM staging_listings
GROUP BY host_is_superhost
ORDER BY rows_found DESC;

/* --- Check 3: text is not double-encoded -------------------
   The source stores "pièces" as "piÃ¨ces". The load reverses
   one layer of that on name and host_location.

   Expected: readable French and other accented text, with
   bytes exceeding chars by a small margin. Values like
   "piÃ¨ces" mean the repair did not run; "piÃƒÂ¨ces" means the
   load added a third layer by declaring latin1.
   ---------------------------------------------------------- */

SELECT name, LENGTH(name) AS bytes, CHAR_LENGTH(name) AS chars
FROM listings
WHERE LENGTH(name) <> CHAR_LENGTH(name)
LIMIT 10;

/* --- Check 4: empty strings became real nulls --------------
   Missing values arrive as '' rather than as the text NULL.
   Loaded straight into typed columns they become 0000-00-00 or
   0 rather than NULL.

   Expected: 128782, 113087, 29435, 242700, 91405
   ---------------------------------------------------------- */

SELECT
    (SELECT COUNT(*) FROM hosts    WHERE host_response_time    IS NULL) AS null_response_time,
    (SELECT COUNT(*) FROM hosts    WHERE host_acceptance_rate  IS NULL) AS null_acceptance_rate,
    (SELECT COUNT(*) FROM listings WHERE bedrooms              IS NULL) AS null_bedrooms,
    (SELECT COUNT(*) FROM listings WHERE district              IS NULL) AS null_district,
    (SELECT COUNT(*) FROM listings WHERE review_scores_rating  IS NULL) AS null_rating;

/* --- Check 5: booleans converted from 't'/'f' --------------
   Expected: superhosts 50253, listings with instant_bookable
   about 71000, and no value other than 0, 1 or NULL.
   ---------------------------------------------------------- */

SELECT
    (SELECT COUNT(*) FROM hosts WHERE host_is_superhost = 1) AS superhosts,
    (SELECT COUNT(*) FROM hosts WHERE host_is_superhost NOT IN (0,1)) AS bad_superhost_values,
    (SELECT COUNT(*) FROM listings WHERE instant_bookable = 1) AS instant_bookable,
    (SELECT COUNT(*) FROM listings WHERE instant_bookable NOT IN (0,1)) AS bad_bookable_values;

/* --- Check 6: referential integrity ------------------------
   The foreign keys enforce this at insert time, so a non-zero
   result here would mean the constraints are missing rather
   than that the data is wrong.

   Expected: 0, 0
   ---------------------------------------------------------- */

SELECT
    (SELECT COUNT(*) FROM listings l
      LEFT JOIN hosts h ON l.host_id = h.host_id
      WHERE h.host_id IS NULL) AS listings_without_host,
    (SELECT COUNT(*) FROM reviews r
      LEFT JOIN listings l ON r.listing_id = l.listing_id
      WHERE l.listing_id IS NULL) AS reviews_without_listing;

/* --- Check 7: known data characteristics -------------------
   Not errors, but facts the analysis depends on. Recording them
   here means a future reload that changes them is noticed.

   Expected: 10 cities, 9 currencies represented, 86156 listings
   with no reviews, 113 listings priced at zero, 3 listings with
   maximum_nights at the 32-bit sentinel.
   ---------------------------------------------------------- */

SELECT
    (SELECT COUNT(DISTINCT city) FROM listings)                      AS cities,
    (SELECT COUNT(*) FROM listings l
      LEFT JOIN reviews r ON l.listing_id = r.listing_id
      WHERE r.listing_id IS NULL)                                    AS listings_never_reviewed,
    (SELECT COUNT(*) FROM listings WHERE price = 0)                  AS zero_price,
    (SELECT COUNT(*) FROM listings WHERE maximum_nights = 2147483647) AS sentinel_max_nights;
