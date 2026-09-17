/* =============================================================
   NYC Green Taxi Trips - Schema
   MySQL 8.0.40

   Four tables: one fact table of 28.3 million trips, a zone
   lookup, the zone geometry, and the supplied fiscal calendar.

   Run order:
     01_create_tables.sql      this file
     02_load_zones.py          shapefile to zone_geometry
     03_load_trips.sql         the four yearly CSVs
     04_verify_load.sql        expected results stated first
     05_indexes.sql            built after loading, not before

   WHY INDEXES ARE NOT DEFINED HERE
   --------------------------------
   Only the primary key exists at load time. Every secondary
   index would otherwise be maintained row by row across 28.3
   million inserts, with InnoDB splitting B-tree pages as it
   goes. Built afterwards, the same index is produced by sorting
   the finished table once.

   The primary key is the exception because InnoDB has no choice:
   the table IS its clustered index. Without a declared key
   InnoDB invents a hidden 6-byte row id, so an explicit 4-byte
   key is both smaller and useful.
   ============================================================= */

CREATE DATABASE IF NOT EXISTS nyc_taxi
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE nyc_taxi;

/* =============================================================
   TRIPS
   =============================================================

   GRAIN
   -----
   One row per completed trip. 28,326,071 rows across four files.

   ONE TABLE, NOT FOUR
   -------------------
   The source arrives as one CSV per year. Keeping them apart
   would put a UNION ALL in every question spanning years and
   force four copies of every index. They are the same entity
   recorded in four files, so they are one table.

   The cost is congestion_surcharge, which does not exist in the
   2017 and 2018 files. It is NULL for those 20.5 million rows,
   which is accurate: the charge was introduced in 2019.

   COLUMN NAMES
   ------------
   Renamed from the source to snake_case. lpep_pickup_datetime
   becomes pickup_datetime: "lpep" is the Livery Passenger
   Enhancement Program and tells a reader nothing. The mapping to
   the original headers is in 03_load_trips.sql, where the column
   list has to name them anyway.

   TYPE SIZING
   -----------
   Sized to the values actually present, measured before writing
   this file rather than guessed:

     vendor_id              1, 2, empty
     ratecode_id            1-6, 99, empty
     location ids           1-265
     passenger_count        0-9
     trip_distance          0.00 to 205654.00
     money columns          -890.30 to 10528.80, always 2 dp

   That gives roughly 64 bytes per row including overhead, near
   1.8 GB for the table. Storing the same data as INT, DOUBLE and
   VARCHAR would roughly double it, and every full scan timed
   later would pay for it again.

   DECIMAL, NOT DOUBLE
   -------------------
   Binary floating point cannot represent 0.30 exactly. The
   improvement surcharge is 0.30 on nearly every row, so a DOUBLE
   sum over 28 million rows drifts away from the true total.
   DECIMAL stores the digits.

   NULLABILITY
   -----------
   Almost everything is nullable, and deliberately so. In the
   2019 and 2020 files, 414,107 and 528,092 rows respectively
   carry no vendor_id, ratecode_id, payment_type, trip_type or
   store_and_fwd_flag. Those columns are fully populated in 2017
   and 2018, so this is a change in what was collected rather
   than scattered missing values.

   This matters more than it looks. LOAD DATA writes an empty
   numeric field as 0, not NULL. Left alone, 528,092 trips would
   claim payment_type 0, a code that does not exist, and every
   payment mix calculation would carry an invented category.
   03_load_trips.sql converts empty to NULL explicitly.

   WHAT IS NOT ENFORCED HERE
   -------------------------
   No foreign key from the location ids to taxi_zones. Two
   reasons: constraint checking on 28.3 million inserts is slow,
   and the relationship is not clean anyway, since five zones
   have no geometry. The integrity is checked in 04_verify_load
   and reported rather than enforced.

   No CHECK constraints on the amounts either. 73,759 trips have
   a negative total and 438,914 record zero distance. Rejecting
   them at load would hide the data quality story instead of
   documenting it.
   ============================================================= */

DROP TABLE IF EXISTS trips;

CREATE TABLE trips (
    trip_id               INT UNSIGNED  NOT NULL AUTO_INCREMENT,

    vendor_id             TINYINT UNSIGNED  NULL,
    pickup_datetime       DATETIME          NOT NULL,
    dropoff_datetime      DATETIME          NOT NULL,
    store_and_fwd_flag    CHAR(1) CHARACTER SET ascii NULL,
    ratecode_id           TINYINT UNSIGNED  NULL,
    pu_location_id        SMALLINT UNSIGNED NULL,
    do_location_id        SMALLINT UNSIGNED NULL,
    passenger_count       TINYINT UNSIGNED  NULL,
    trip_distance         DECIMAL(8,2)      NULL,

    fare_amount           DECIMAL(8,2)      NULL,
    extra                 DECIMAL(6,2)      NULL,
    mta_tax               DECIMAL(6,2)      NULL,
    tip_amount            DECIMAL(8,2)      NULL,
    tolls_amount          DECIMAL(8,2)      NULL,
    improvement_surcharge DECIMAL(6,2)      NULL,
    total_amount          DECIMAL(8,2)      NULL,

    payment_type          TINYINT UNSIGNED  NULL,
    trip_type             TINYINT UNSIGNED  NULL,
    congestion_surcharge  DECIMAL(6,2)      NULL,

    PRIMARY KEY (trip_id)
) ENGINE = InnoDB;

/* Why DATETIME and not DATETIME(3): every one of the 56.6
   million timestamps in the four files ends in .000. Checked,
   not assumed. DATETIME(3) would cost one extra byte per column
   per row to store three zeroes.

   Why the clustered key is a surrogate and not the pickup time:
   clustering on pickup_datetime would physically order the table
   by date and make every date-range scan faster, which is
   tempting given how many questions filter by date. That is a
   change worth measuring rather than assuming, so it is one of
   the experiments in the performance write-up. Measure the
   simple version first. */


/* =============================================================
   TAXI ZONES
   =============================================================

   265 zones, from taxi_zones.csv. This is the complete list and
   includes the five with no geometry, so a trip referencing zone
   264 still resolves to a name.

   zone_name rather than zone, because "zone" reads ambiguously
   beside service_zone in a query.
   ============================================================= */

DROP TABLE IF EXISTS taxi_zones;

CREATE TABLE taxi_zones (
    location_id   SMALLINT UNSIGNED NOT NULL,
    borough       VARCHAR(20)       NOT NULL,
    zone_name     VARCHAR(60)       NOT NULL,
    service_zone  VARCHAR(12)       NOT NULL,

    PRIMARY KEY (location_id)
) ENGINE = InnoDB;


/* =============================================================
   ZONE GEOMETRY
   =============================================================

   Separate from taxi_zones because a SPATIAL INDEX requires its
   column to be NOT NULL, and five zones have no polygon:

     57   Corona, Queens
     104  Governor's Island/Ellis Island/Liberty Island
     105  Governor's Island/Ellis Island/Liberty Island
     264  Unknown, NV
     265  Unknown, NA

   264 and 265 are the source's placeholders for an unrecorded
   location and were never real places. The other three are a
   shapefile defect: it holds 263 records but only 260 distinct
   location ids, with 56 and 103 each appearing twice. In the CSV
   56 and 57 are both named Corona, and 103, 104 and 105 are all
   Governor's Island/Ellis Island/Liberty Island, so the
   shapefile appears to label same-named adjacent zones
   inconsistently. Which record belongs to which id cannot be
   resolved from the files, so nothing is guessed. The duplicates
   are merged per location id and the three ids are left absent.

   That leaves 260 rows here against 265 in taxi_zones, so any
   spatial question must use a LEFT JOIN or state that it covers
   260 zones.

   CENTROID
   --------
   Stored rather than computed, because MySQL 8.0.40 rejects
   ST_Centroid on a geographic SRID:

     Error 3618: st_centroid(POLYGON) has not been implemented
     for geographic spatial reference systems

   02_load_zones.py computes it and loads it as a POINT.

   AXIS ORDER
   ----------
   Every geometry here is SRID 4326 and every ST_GeomFromText
   call that builds one must pass 'axis-order=long-lat'.

   EPSG:4326 formally defines latitude first, and MySQL honours
   that when parsing WKT. The shapefile stores longitude first.
   Omit the option and every polygon lands at latitude -74, off
   the coast of Antarctica.

   Nothing looks broken when this happens. ST_Touches, ST_Within
   and ST_Intersects all still return correct answers, because a
   consistent axis swap preserves how shapes relate to each
   other. Only an absolute measurement exposes it. A test box
   spanning 0.1 degree each way at latitude 40.7 returns
   34,456,370 square metres with the axes swapped and 93,783,462
   with them correct.
   ============================================================= */

DROP TABLE IF EXISTS zone_geometry;

CREATE TABLE zone_geometry (
    location_id  SMALLINT UNSIGNED NOT NULL,
    geom         MULTIPOLYGON      NOT NULL SRID 4326,
    centroid     POINT             NOT NULL SRID 4326,

    PRIMARY KEY (location_id),
    SPATIAL INDEX sx_zone_geom     (geom),
    SPATIAL INDEX sx_zone_centroid (centroid)
) ENGINE = InnoDB;

/* Spatial indexes are declared here rather than deferred, unlike
   the trip indexes. 260 rows is not a load to optimise. */


/* =============================================================
   FISCAL CALENDAR
   =============================================================

   1,456 rows from 454_calendar.csv, a 4-5-4 retail calendar:
   fiscal quarters of thirteen weeks split into months of four,
   five and four weeks, so that comparable periods hold the same
   number of weekends.

   IT DOES NOT COVER THE DATA
   --------------------------
   The calendar runs 2017-02-05 to 2021-01-30, contiguous, no
   gaps within that span. The trips start on 2017-01-01.

   1,231,326 real trips fall before the calendar begins, which is
   4.3% of the dataset and 10.5% of 2017. An inner join to this
   table drops every one of them without raising anything.

   So this table answers questions about fiscal periods and
   nothing else. Day of week, month and year come from the trip's
   own timestamp. Where the calendar is used, the join is a LEFT
   JOIN and the uncovered rows are counted and reported.

   The file also carries a UTF-8 byte order mark on its first
   line, which IGNORE 1 LINES discards along with the header.
   ============================================================= */

DROP TABLE IF EXISTS fiscal_calendar;

CREATE TABLE fiscal_calendar (
    calendar_date          DATE         NOT NULL,
    fiscal_year            SMALLINT     NOT NULL,
    fiscal_quarter         TINYINT      NOT NULL,
    fiscal_month_number    TINYINT      NOT NULL,
    fiscal_month_of_qtr    TINYINT      NOT NULL,
    fiscal_week_of_year    TINYINT      NOT NULL,
    day_of_week            TINYINT      NOT NULL,
    fiscal_month_name      VARCHAR(10)  NOT NULL,
    fiscal_month_year      VARCHAR(10)  NOT NULL,
    fiscal_quarter_year    VARCHAR(10)  NOT NULL,
    day_of_month_number    TINYINT      NOT NULL,
    day_name               VARCHAR(9)   NOT NULL,

    PRIMARY KEY (calendar_date)
) ENGINE = InnoDB;
