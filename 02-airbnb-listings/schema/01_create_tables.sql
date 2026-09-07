/* =============================================================
   Airbnb Listings and Reviews - Schema Definition
   MySQL 8.0

   Source is two flat CSVs. This script models them as three
   tables rather than two, because the ten host columns in
   Listings.csv describe a host, not a listing: 279,712 listings
   come from 182,024 distinct hosts, and one host owns 627 of
   them. Splitting removes that repetition.

   Host attributes are consistent within a host_id for all but
   about 30 hosts out of 182,024, where the ten cities appear to
   have been captured on different dates.

   NOTES
   -----
   reviews uses a composite primary key. review_id alone is not
   unique: 160 values appear twice, always split across two
   listings that look like the same property listed twice.
   listing_id leads the key so the same index serves the primary
   key, the foreign key and every join.

   maximum_nights reaches 2,147,483,647 on three rows, which is
   the largest signed 32-bit integer and a sentinel for "no
   limit" rather than a real value. It is stored as supplied and
   filtered in analysis, so the raw value stays recoverable.

   Nullability is declared from the data: twelve columns in
   listings have no nulls across 279,712 rows and are marked
   NOT NULL. The rest are genuinely absent rather than unknown,
   notably district, which is populated only for New York.
   ============================================================= */

DROP DATABASE IF EXISTS airbnb_listings;
CREATE DATABASE airbnb_listings;
USE airbnb_listings;

/* --- hosts: one row per host ------------------------------- */

CREATE TABLE hosts (
    host_id                   INT UNSIGNED   NOT NULL,
    host_since                DATE,
    host_location             VARCHAR(500),
    host_response_time        VARCHAR(20),
    host_response_rate        DECIMAL(4,3),
    host_acceptance_rate      DECIMAL(4,3),
    host_is_superhost         TINYINT UNSIGNED,
    host_total_listings_count SMALLINT UNSIGNED,
    host_has_profile_pic      TINYINT UNSIGNED,
    host_identity_verified    TINYINT UNSIGNED,
    PRIMARY KEY (host_id)
) ENGINE = InnoDB;

/* --- listings: one row per property ------------------------ */

CREATE TABLE listings (
    listing_id                  INT UNSIGNED     NOT NULL,
    host_id                     INT UNSIGNED     NOT NULL,
    name                        VARCHAR(500),
    neighbourhood               VARCHAR(30)      NOT NULL,
    district                    VARCHAR(100),
    city                        VARCHAR(100)     NOT NULL,
    latitude                    DECIMAL(9,6)     NOT NULL,
    longitude                   DECIMAL(9,6)     NOT NULL,
    property_type               VARCHAR(50)      NOT NULL,
    room_type                   VARCHAR(100)     NOT NULL,
    accommodates                TINYINT UNSIGNED NOT NULL,
    bedrooms                    TINYINT UNSIGNED,
    amenities                   TEXT             NOT NULL,
    price                       DECIMAL(10,2)    NOT NULL,
    minimum_nights              SMALLINT UNSIGNED NOT NULL,
    maximum_nights              INT UNSIGNED     NOT NULL,
    review_scores_rating        TINYINT UNSIGNED,
    review_scores_accuracy      TINYINT UNSIGNED,
    review_scores_cleanliness   TINYINT UNSIGNED,
    review_scores_checkin       TINYINT UNSIGNED,
    review_scores_communication TINYINT UNSIGNED,
    review_scores_location      TINYINT UNSIGNED,
    review_scores_value         TINYINT UNSIGNED,
    instant_bookable            TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (listing_id),
    FOREIGN KEY (host_id) REFERENCES hosts(host_id)
) ENGINE = InnoDB;

/* --- reviews: one row per review --------------------------- */

CREATE TABLE reviews (
    listing_id  INT UNSIGNED NOT NULL,
    review_id   INT UNSIGNED NOT NULL,
    review_date DATE         NOT NULL,
    reviewer_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (listing_id, review_id),
    FOREIGN KEY (listing_id) REFERENCES listings(listing_id)
) ENGINE = InnoDB;
