/* =============================================================
   Airbnb Listings and Reviews - Data Load
   MySQL 8.0

   Run 01_create_tables.sql first.

   PREREQUISITES
   -------------
   1. Place Listings.csv and Reviews.csv in this project's data/
      folder.

   2. Enable local file loading, which is required in TWO places:

      Server:  SET GLOBAL local_infile = 1;

      Client:  Workbench home screen > right-click the connection
               > Edit Connection > Advanced tab > "Others:" box,
               add OPT_LOCAL_INFILE=1, then reopen the connection.

      Missing either gives "Loading local data is disabled".

   3. Update the file paths below if the repository is not at
      D:/Projects. Use forward slashes even on Windows.

   4. Raise Workbench's read timeout. Edit > Preferences > SQL
      Editor > DBMS connection read timeout, from 600 to 6000.
      The Reviews load runs for several minutes and Workbench
      otherwise reports a lost connection partway through. The
      load itself completes either way; check the row counts in
      03_verify_load.sql rather than trusting the message.

   WHY THE LOAD CLAUSES LOOK LIKE THIS
   -----------------------------------
   Listings.csv fails in four ways that produce no error:

   a) CHARACTER SET binary
      The file is UTF-8 but contains a small number of invalid
      bytes. Declaring utf8mb4 makes MySQL reject the whole load
      with "Invalid utf8mb4 character string". Declaring latin1
      instead loads successfully and silently mangles every
      accented character. binary copies the bytes without
      validating or converting them, which is correct here
      because the columns are already utf8mb4.

   b) ESCAPED BY ''
      MySQL defaults to backslash escaping, which CSV does not
      use. A backslash inside a listing name swallows the comma
      after it and shifts every remaining field on that row left
      by one. This affected four rows, detectable only because
      't' turned up in a numeric column.

   c) The repair expression on name
      The source is double-encoded: text that was UTF-8, read as
      Latin-1, and re-saved as UTF-8, so "pièces" is stored as
      "piÃ¨ces". 38,328 of 279,712 listing names are affected.
      CONVERT(CAST(CONVERT(col USING latin1) AS BINARY) USING
      utf8mb4) reverses exactly one layer. Only name is affected;
      every other text column is pure ASCII.

   d) NULLIF(col, '')
      Missing values arrive as empty strings, not as the literal
      text NULL. Loaded directly into a DATE or DECIMAL column
      they become zero values rather than nulls.

   STAGING
   -------
   Listings.csv is loaded into a staging table whose columns are
   all text, with no keys and no constraints, so nothing can be
   rejected or silently converted on the way in. Every conversion
   then happens in an INSERT ... SELECT where it is visible and
   can be checked. Reviews.csv needs no transformation and loads
   directly.
   ============================================================= */

USE airbnb_listings;

/* --- staging: mirrors Listings.csv exactly ------------------ */

DROP TABLE IF EXISTS staging_listings;

CREATE TABLE staging_listings (
    listing_id                  VARCHAR(50),
    name                        VARCHAR(500),
    host_id                     VARCHAR(50),
    host_since                  VARCHAR(50),
    host_location               VARCHAR(500),
    host_response_time          VARCHAR(50),
    host_response_rate          VARCHAR(50),
    host_acceptance_rate        VARCHAR(50),
    host_is_superhost           VARCHAR(50),
    host_total_listings_count   VARCHAR(50),
    host_has_profile_pic        VARCHAR(50),
    host_identity_verified      VARCHAR(50),
    neighbourhood               VARCHAR(50),
    district                    VARCHAR(50),
    city                        VARCHAR(50),
    latitude                    VARCHAR(50),
    longitude                   VARCHAR(50),
    property_type               VARCHAR(50),
    room_type                   VARCHAR(50),
    accommodates                VARCHAR(50),
    bedrooms                    VARCHAR(50),
    amenities                   TEXT,
    price                       VARCHAR(50),
    minimum_nights              VARCHAR(50),
    maximum_nights              VARCHAR(50),
    review_scores_rating        VARCHAR(50),
    review_scores_accuracy      VARCHAR(50),
    review_scores_cleanliness   VARCHAR(50),
    review_scores_checkin       VARCHAR(50),
    review_scores_communication VARCHAR(50),
    review_scores_location      VARCHAR(50),
    review_scores_value         VARCHAR(50),
    instant_bookable            VARCHAR(50)
) ENGINE = InnoDB;

LOAD DATA LOCAL INFILE 'D:/Projects/sql-portfolio/02-airbnb-listings/data/Listings.csv'
INTO TABLE staging_listings
CHARACTER SET binary
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

/* --- hosts: one row per host -------------------------------
   GROUP BY rather than SELECT DISTINCT, because about 30 hosts
   have conflicting attribute values across their listings. MIN()
   picks one deterministically; DISTINCT would emit two rows and
   the primary key would reject the second.
   ---------------------------------------------------------- */

INSERT INTO hosts (host_id, host_since, host_location, host_response_time,
                   host_response_rate, host_acceptance_rate, host_is_superhost,
                   host_total_listings_count, host_has_profile_pic,
                   host_identity_verified)
SELECT
    host_id,
    MIN(NULLIF(host_since, ''))                                       AS host_since,
    MIN(CONVERT(CAST(CONVERT(NULLIF(host_location, '') USING latin1)
        AS BINARY) USING utf8mb4))                                    AS host_location,
    MIN(NULLIF(host_response_time, ''))                               AS host_response_time,
    MIN(NULLIF(host_response_rate, ''))                               AS host_response_rate,
    MIN(NULLIF(host_acceptance_rate, ''))                             AS host_acceptance_rate,
    MIN(NULLIF(host_is_superhost, '') = 't')                          AS host_is_superhost,
    MIN(CAST(NULLIF(host_total_listings_count, '') AS UNSIGNED))      AS host_total_listings_count,
    MIN(NULLIF(host_has_profile_pic, '') = 't')                       AS host_has_profile_pic,
    MIN(NULLIF(host_identity_verified, '') = 't')                     AS host_identity_verified
FROM staging_listings
GROUP BY host_id;

/* --- listings: one row per property ------------------------ */

INSERT INTO listings (listing_id, host_id, name, neighbourhood, district, city,
                      latitude, longitude, property_type, room_type,
                      accommodates, bedrooms, amenities, price,
                      minimum_nights, maximum_nights,
                      review_scores_rating, review_scores_accuracy,
                      review_scores_cleanliness, review_scores_checkin,
                      review_scores_communication, review_scores_location,
                      review_scores_value, instant_bookable)
SELECT
    listing_id,
    host_id,
    CONVERT(CAST(CONVERT(NULLIF(name, '') USING latin1) AS BINARY) USING utf8mb4),
    neighbourhood,
    NULLIF(district, ''),
    city,
    latitude,
    longitude,
    property_type,
    room_type,
    accommodates,
    NULLIF(bedrooms, ''),
    amenities,
    price,
    minimum_nights,
    maximum_nights,
    NULLIF(review_scores_rating, ''),
    NULLIF(review_scores_accuracy, ''),
    NULLIF(review_scores_cleanliness, ''),
    NULLIF(review_scores_checkin, ''),
    NULLIF(review_scores_communication, ''),
    NULLIF(review_scores_location, ''),
    NULLIF(review_scores_value, ''),
    NULLIF(instant_bookable, '') = 't'
FROM staging_listings;

/* --- reviews: loaded directly, no transformation needed ----- */

LOAD DATA LOCAL INFILE 'D:/Projects/sql-portfolio/02-airbnb-listings/data/Reviews.csv'
INTO TABLE reviews
CHARACTER SET binary
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(listing_id, review_id, review_date, reviewer_id);

/* --- staging has done its job ------------------------------
   Run 03_verify_load.sql before dropping this, since two of the
   checks in it read from staging.
   ---------------------------------------------------------- */

-- DROP TABLE staging_listings;
