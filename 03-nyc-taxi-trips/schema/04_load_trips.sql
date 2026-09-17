/* =============================================================
   NYC Green Taxi Trips - Trip Data
   MySQL 8.0.40

   Loads 28,326,071 rows from four CSVs into one table.

   Run after 03_load_reference.sql.
   Then run 05_verify_load.sql before trusting any of it.

   EXPECT THIS TO TAKE A WHILE
   ---------------------------
   Minutes, not seconds. Do not cancel a statement partway
   through: LOAD DATA is a single transaction, so an interrupted
   load rolls back, and the rollback of twelve million rows takes
   longer than the insert did.

   LOAD ORDER
   ----------
   2020 first, although it is the last year, because at 1.7
   million rows it is the smallest. If something is wrong with
   the column mapping, the line endings or the empty-to-NULL
   handling, it is better to discover that after ninety seconds
   than after twenty minutes. The remaining three follow once the
   pilot verifies.

   TWO COLUMN LAYOUTS
   ------------------
   2017 and 2018 have 18 columns. 2019 and 2020 have 19, adding
   congestion_surcharge, which was introduced in 2019. Each group
   gets its own column list. The 18-column loads simply never
   mention congestion_surcharge, so it stays NULL, which is what
   it should be for a charge that did not exist.

   WHY EVERY FIELD GOES THROUGH A VARIABLE
   ---------------------------------------
   This is the part that matters most.

   LOAD DATA writes an empty field into a numeric column as 0,
   not NULL, and raises only a warning. In the 2019 and 2020
   files, 414,107 and 528,092 rows carry no vendor_id,
   ratecode_id, payment_type, trip_type or store_and_fwd_flag.
   Loaded naively, 528,092 trips would claim payment_type 0.

   There is no payment type 0. The dictionary defines 1 to 6.
   Nothing would error. Every payment mix calculation would carry
   an invented sixth category holding 30% of 2020, and the only
   symptom would be a chart that looked slightly odd.

   So each field is read into a user variable and passed through
   NULLIF(@var, ''). It costs something per row. Correctness on
   28 million rows is worth more than the seconds it saves.

   The two datetimes are the exception and map directly. Every
   one of the 56.6 million timestamps is exactly 23 characters
   ending in .000, verified across all four files, so there is no
   empty value to guard against.

   NO SESSION TUNING HERE
   ----------------------
   Deliberately none. No disabled unique checks, no altered
   buffer pool. The only load optimisation in this project is
   structural: the table carries nothing but its primary key
   while the data goes in, and 06_indexes.sql builds the rest
   afterwards. That decision gets measured in the performance
   write-up, and measuring it means not confounding it with
   half a dozen session variables.
   ============================================================= */

USE nyc_taxi;

TRUNCATE TABLE trips;


/* =============================================================
   PILOT: 2020, 19 columns, 1,734,051 rows
   ============================================================= */

LOAD DATA LOCAL INFILE 'D:/Projects/sql-portfolio/03-nyc-taxi-trips/data/taxi_trips/2020_taxi_trips.csv'
INTO TABLE trips
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(@vendor_id, pickup_datetime, dropoff_datetime, @flag, @ratecode,
 @pu, @do, @passengers, @distance,
 @fare, @extra, @mta, @tip, @tolls, @improvement, @total,
 @payment, @trip_type, @congestion)
SET vendor_id             = NULLIF(@vendor_id,   ''),
    store_and_fwd_flag    = NULLIF(@flag,        ''),
    ratecode_id           = NULLIF(@ratecode,    ''),
    pu_location_id        = NULLIF(@pu,          ''),
    do_location_id        = NULLIF(@do,          ''),
    passenger_count       = NULLIF(@passengers,  ''),
    trip_distance         = NULLIF(@distance,    ''),
    fare_amount           = NULLIF(@fare,        ''),
    extra                 = NULLIF(@extra,       ''),
    mta_tax               = NULLIF(@mta,         ''),
    tip_amount            = NULLIF(@tip,         ''),
    tolls_amount          = NULLIF(@tolls,       ''),
    improvement_surcharge = NULLIF(@improvement, ''),
    total_amount          = NULLIF(@total,       ''),
    payment_type          = NULLIF(@payment,     ''),
    trip_type             = NULLIF(@trip_type,   ''),
    congestion_surcharge  = NULLIF(@congestion,  '');

/* --- Stop here and check the pilot -------------------------

   1. Workbench reports rows affected. Expected: 1,734,051.

   2. Run SHOW WARNINGS. Expected: none.

      A truncation warning on the datetime columns would mean
      MySQL objects to the .000 suffix, in which case change the
      two direct mappings to a variable and LEFT(@pickup, 19).

      A warning like "Incorrect integer value" would mean a
      NULLIF was missed on a column that carries empties.

   3. Run the three queries below.
   ------------------------------------------------------------- */

SELECT COUNT(*)                                      AS rows_loaded,
       MIN(pickup_datetime)                          AS earliest,
       MAX(pickup_datetime)                          AS latest
FROM trips;
-- Expected: 1,734,051 rows, 2008-12-31 22:06:48, 2041-08-17 16:24:38
-- The out-of-range dates are real and stay. See 05_verify_load.sql.

SELECT SUM(payment_type IS NULL) AS payment_null,
       SUM(payment_type = 0)     AS payment_zero,
       SUM(vendor_id IS NULL)    AS vendor_null,
       SUM(vendor_id = 0)        AS vendor_zero
FROM trips;
-- Expected: 528,092 nulls and 0 zeroes, in both pairs.
-- Any non-zero in the "zero" columns means NULLIF did not apply
-- and the load has to be redone.

SELECT COUNT(*) AS congestion_populated
FROM trips
WHERE congestion_surcharge IS NOT NULL;
-- Expected: 1,205,959, being 1,734,051 less the 528,092 rows
-- that carry no descriptive metadata.
--
-- Those 528,092 rows are missing exactly seven columns:
-- vendor_id, store_and_fwd_flag, ratecode_id, passenger_count,
-- payment_type, trip_type and congestion_surcharge.
--
-- They do carry pickup and dropoff times, both location ids,
-- trip_distance, and all seven money columns.
--
-- So this is a coherent record type, not random corruption:
-- geography, timing and money present, descriptive codes absent.
-- The rows stay usable for distance, duration, fare and zone
-- questions and are unusable for anything grouped by payment
-- type, vendor or rate code. Dropping them wholesale would
-- discard 30% of 2020 for no reason, and every query grouped by
-- one of those seven columns has to say what it excluded.


/* =============================================================
   2019, 19 columns, 6,044,050 rows
   ============================================================= */

LOAD DATA LOCAL INFILE 'D:/Projects/sql-portfolio/03-nyc-taxi-trips/data/taxi_trips/2019_taxi_trips.csv'
INTO TABLE trips
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(@vendor_id, pickup_datetime, dropoff_datetime, @flag, @ratecode,
 @pu, @do, @passengers, @distance,
 @fare, @extra, @mta, @tip, @tolls, @improvement, @total,
 @payment, @trip_type, @congestion)
SET vendor_id             = NULLIF(@vendor_id,   ''),
    store_and_fwd_flag    = NULLIF(@flag,        ''),
    ratecode_id           = NULLIF(@ratecode,    ''),
    pu_location_id        = NULLIF(@pu,          ''),
    do_location_id        = NULLIF(@do,          ''),
    passenger_count       = NULLIF(@passengers,  ''),
    trip_distance         = NULLIF(@distance,    ''),
    fare_amount           = NULLIF(@fare,        ''),
    extra                 = NULLIF(@extra,       ''),
    mta_tax               = NULLIF(@mta,         ''),
    tip_amount            = NULLIF(@tip,         ''),
    tolls_amount          = NULLIF(@tolls,       ''),
    improvement_surcharge = NULLIF(@improvement, ''),
    total_amount          = NULLIF(@total,       ''),
    payment_type          = NULLIF(@payment,     ''),
    trip_type             = NULLIF(@trip_type,   ''),
    congestion_surcharge  = NULLIF(@congestion,  '');


/* =============================================================
   2018, 18 columns, 8,807,303 rows

   No congestion_surcharge in the file and none set here, so it
   stays NULL for every row.
   ============================================================= */

LOAD DATA LOCAL INFILE 'D:/Projects/sql-portfolio/03-nyc-taxi-trips/data/taxi_trips/2018_taxi_trips.csv'
INTO TABLE trips
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(@vendor_id, pickup_datetime, dropoff_datetime, @flag, @ratecode,
 @pu, @do, @passengers, @distance,
 @fare, @extra, @mta, @tip, @tolls, @improvement, @total,
 @payment, @trip_type)
SET vendor_id             = NULLIF(@vendor_id,   ''),
    store_and_fwd_flag    = NULLIF(@flag,        ''),
    ratecode_id           = NULLIF(@ratecode,    ''),
    pu_location_id        = NULLIF(@pu,          ''),
    do_location_id        = NULLIF(@do,          ''),
    passenger_count       = NULLIF(@passengers,  ''),
    trip_distance         = NULLIF(@distance,    ''),
    fare_amount           = NULLIF(@fare,        ''),
    extra                 = NULLIF(@extra,       ''),
    mta_tax               = NULLIF(@mta,         ''),
    tip_amount            = NULLIF(@tip,         ''),
    tolls_amount          = NULLIF(@tolls,       ''),
    improvement_surcharge = NULLIF(@improvement, ''),
    total_amount          = NULLIF(@total,       ''),
    payment_type          = NULLIF(@payment,     ''),
    trip_type             = NULLIF(@trip_type,   '');


/* =============================================================
   2017, 18 columns, 11,740,667 rows

   The largest file, loaded last.
   ============================================================= */

LOAD DATA LOCAL INFILE 'D:/Projects/sql-portfolio/03-nyc-taxi-trips/data/taxi_trips/2017_taxi_trips.csv'
INTO TABLE trips
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(@vendor_id, pickup_datetime, dropoff_datetime, @flag, @ratecode,
 @pu, @do, @passengers, @distance,
 @fare, @extra, @mta, @tip, @tolls, @improvement, @total,
 @payment, @trip_type)
SET vendor_id             = NULLIF(@vendor_id,   ''),
    store_and_fwd_flag    = NULLIF(@flag,        ''),
    ratecode_id           = NULLIF(@ratecode,    ''),
    pu_location_id        = NULLIF(@pu,          ''),
    do_location_id        = NULLIF(@do,          ''),
    passenger_count       = NULLIF(@passengers,  ''),
    trip_distance         = NULLIF(@distance,    ''),
    fare_amount           = NULLIF(@fare,        ''),
    extra                 = NULLIF(@extra,       ''),
    mta_tax               = NULLIF(@mta,         ''),
    tip_amount            = NULLIF(@tip,         ''),
    tolls_amount          = NULLIF(@tolls,       ''),
    improvement_surcharge = NULLIF(@improvement, ''),
    total_amount          = NULLIF(@total,       ''),
    payment_type          = NULLIF(@payment,     ''),
    trip_type             = NULLIF(@trip_type,   '');


/* =============================================================
   RECONCILIATION
   =============================================================
   Counts by calendar year of the pickup timestamp, which is not
   the same as counts by source file. A row in the 2018 file with
   a pickup in 2081 lands in neither 2018 nor any sane year, so
   these numbers will not match the file counts exactly. That is
   the point of running it.

   File counts, for comparison:
     2017  11,740,667
     2018   8,807,303
     2019   6,044,050
     2020   1,734,051
     total 28,326,071
   ============================================================= */

SELECT YEAR(pickup_datetime) AS pickup_year,
       COUNT(*)              AS trips
FROM trips
GROUP BY YEAR(pickup_datetime)
ORDER BY pickup_year;

SELECT COUNT(*) AS total_rows FROM trips;
-- Expected: 28,326,071

-- information_schema caches table statistics for a day by
-- default, so immediately after a load these columns report what
-- was true beforehand. Zero for a table holding 28 million rows
-- means stale statistics, not an empty table.
SET SESSION information_schema_stats_expiry = 0;

SELECT ROUND(data_length  / 1024 / 1024) AS data_mb,
       ROUND(index_length / 1024 / 1024) AS index_mb
FROM information_schema.tables
WHERE table_schema = 'nyc_taxi' AND table_name = 'trips';
-- index_mb should be small: the primary key is the only index,
-- and in InnoDB the primary key IS the table, so it is counted
-- in data_mb. This number is the baseline that 06_indexes.sql
-- will be compared against.
