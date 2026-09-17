/* =============================================================
   NYC Green Taxi Trips - Load Verification
   MySQL 8.0.40

   Run after 04_load_trips.sql, before anything else.

   HOW THIS FILE WORKS
   -------------------
   Every check states its expected result before the query that
   produces it. The expected values were measured against the raw
   CSVs before loading, not read off the database afterwards.

   That ordering is the whole point. A number you decide is
   acceptable after seeing it is not a check, it is a glance. The
   load of the zone geometry made this concrete: an axis-order
   fault returns 21,286 metres where the truth is 17,724, and
   both are perfectly believable for an airport to a city centre.
   Only a committed expectation separates them.

   NOTHING HERE FAILS THE LOAD
   ---------------------------
   Most of these checks confirm that defects survived loading
   intact. 73,759 negative fares and 438,914 zero-distance trips
   are in the source, and a load that silently removed them would
   be the broken one. The analysis decides what to exclude,
   question by question, and says so.
   ============================================================= */

USE nyc_taxi;

/* -------------------------------------------------------------
   1. ROW COUNT
   -------------------------------------------------------------
   Expected: 28,326,071

   Note this is not the 28,327,624 quoted by the data provider.
   The difference of 1,553 is unexplained. This number is the one
   that can be reproduced by counting the files.
   ------------------------------------------------------------- */

SELECT COUNT(*) AS total_rows FROM trips;


/* -------------------------------------------------------------
   2. PICKUP YEAR DISTRIBUTION
   -------------------------------------------------------------
   Expected: 14 rows, exactly

     2008        102        2019   6,043,879
     2009        283        2020   1,734,040
     2010        344        2021           1
     2012          3        2030           2
     2017 11,740,514        2035           1
     2018  8,806,899        2041           1
                            2062           1
                            2081           1

   The four yearly files are not cleanly partitioned by year. The
   2017 file holds 127 trips dated 2018, the 2018 file holds 44
   dated 2017, and 59 trips dated 2020 arrive from the 2018 and
   2019 files. Every question that groups by year must use the
   timestamp, never the file a row came from.
   ------------------------------------------------------------- */

SELECT YEAR(pickup_datetime) AS pickup_year,
       COUNT(*)              AS trips
FROM trips
GROUP BY YEAR(pickup_datetime)
ORDER BY pickup_year;


/* -------------------------------------------------------------
   3. DATES OUTSIDE THE NOMINAL PERIOD
   -------------------------------------------------------------
   Expected: 739 rows, of which 732 are before 2017 and 7 after
   2020.

   The early ones cluster in 2008 to 2010 rather than scattering,
   which points at meters reporting a reset factory date rather
   than random clock drift. The late ones run to 2081.

   They are kept. Every trend query filters to the study period
   explicitly, so an unfiltered query returning a slightly odd
   total is a signal that the filter was forgotten.
   ------------------------------------------------------------- */

SELECT SUM(pickup_datetime <  '2017-01-01') AS before_2017,
       SUM(pickup_datetime >= '2021-01-01') AS after_2020,
       SUM(pickup_datetime <  '2017-01-01'
        OR pickup_datetime >= '2021-01-01') AS outside_period
FROM trips;


/* -------------------------------------------------------------
   4. IMPOSSIBLE DURATIONS
   -------------------------------------------------------------
   Expected: 414 trips where the meter stopped before it started.
   ------------------------------------------------------------- */

SELECT COUNT(*) AS dropoff_before_pickup
FROM trips
WHERE dropoff_datetime < pickup_datetime;


/* -------------------------------------------------------------
   5. COVERAGE AGAINST THE SUPPLIED CALENDAR
   -------------------------------------------------------------
   Expected: 1,232,058 trips with a pickup before 2017-02-05,
   which is the first date in fiscal_calendar.

   That is 4.4% of the dataset. An INNER JOIN to the calendar
   discards every one of them without raising anything, which is
   why the calendar is used only for genuinely fiscal questions
   and always with a LEFT JOIN.
   ------------------------------------------------------------- */

SELECT COUNT(*) AS trips_before_calendar_starts
FROM trips
WHERE pickup_datetime < '2017-02-05';

/* Same check expressed as the join that would go wrong.
   Expected: 1,232,058 again, and 0 after 2021-01-30. */

SELECT SUM(c.calendar_date IS NULL) AS trips_with_no_calendar_row
FROM trips t
LEFT JOIN fiscal_calendar c ON c.calendar_date = DATE(t.pickup_datetime);


/* -------------------------------------------------------------
   6. THE EMPTY-TO-NULL CONVERSION
   -------------------------------------------------------------
   The check the load depends on.

   Expected: 942,199 NULLs in each of the seven affected columns,
   and 0 zeroes in the numeric ones.

   942,199 is 414,107 rows from the 2019 file plus 528,092 from
   2020. Neither 2017 nor 2018 contributes any.

   A count of 942,199 in a "zero" column instead of its "null"
   column means NULLIF did not apply, and the load must be
   repeated. Those rows would otherwise claim vendor 0, rate code
   0 and payment type 0, none of which exist.
   ------------------------------------------------------------- */

SELECT SUM(vendor_id            IS NULL) AS vendor_null,
       SUM(vendor_id            =  0)    AS vendor_zero,
       SUM(ratecode_id          IS NULL) AS ratecode_null,
       SUM(ratecode_id          =  0)    AS ratecode_zero,
       SUM(passenger_count      IS NULL) AS passengers_null,
       SUM(payment_type         IS NULL) AS payment_null,
       SUM(payment_type         =  0)    AS payment_zero,
       SUM(trip_type            IS NULL) AS trip_type_null,
       SUM(store_and_fwd_flag   IS NULL) AS flag_null
FROM trips;

/* --- What those rows do contain -----------------------------
   Expected: 0 for all four.

   The 942,199 rows are missing seven columns and complete in the
   rest. They carry both timestamps, both location ids, the
   distance and all seven money columns. So they stay usable for
   distance, duration, fare and zone questions, and are excluded
   only from questions grouped by one of the seven.
   ------------------------------------------------------------- */

SELECT SUM(pu_location_id IS NULL) AS loc_null,
       SUM(trip_distance  IS NULL) AS distance_null,
       SUM(total_amount   IS NULL) AS total_null,
       SUM(fare_amount    IS NULL) AS fare_null
FROM trips
WHERE vendor_id IS NULL;


/* -------------------------------------------------------------
   7. CONGESTION SURCHARGE
   -------------------------------------------------------------
   Expected: 6,835,902 populated, 21,490,169 NULL.

   The populated rows are the 2019 and 2020 files less their
   942,199 metadata-free rows. The NULLs are 2017 and 2018, where
   the column does not exist in the source because the charge was
   introduced in 2019.

   A zero here would be a lie. NULL says the charge did not
   apply; 0.00 would say it applied and came to nothing.
   ------------------------------------------------------------- */

SELECT SUM(congestion_surcharge IS NOT NULL) AS populated,
       SUM(congestion_surcharge IS NULL)     AS not_applicable
FROM trips;


/* -------------------------------------------------------------
   8. CODE VALUES AGAINST THE DATA DICTIONARY
   -------------------------------------------------------------
   Expected for ratecode_id: 1 to 6 as documented, plus 154 rows
   at 99, plus 942,199 NULL.

   99 is not in the dictionary, which defines 1 through 6. It is
   too rare to matter and too undocumented to interpret, so it is
   reported and left alone.

   Expected for payment_type: 1 to 5, plus NULL. Code 6, voided
   trip, never appears.
   ------------------------------------------------------------- */

SELECT ratecode_id, COUNT(*) AS trips
FROM trips
GROUP BY ratecode_id
ORDER BY ratecode_id;

SELECT payment_type, COUNT(*) AS trips
FROM trips
GROUP BY payment_type
ORDER BY payment_type;


/* -------------------------------------------------------------
   9. AMOUNTS
   -------------------------------------------------------------
   Expected:
     total_amount < 0    73,759
     total_amount = 0    56,972
     minimum total      -890.30
     maximum total    10,528.80

   Negative totals are refunds and reversals. They are real
   records and stay, but any average fare that includes them is
   answering a different question from the one it appears to.
   ------------------------------------------------------------- */

SELECT SUM(total_amount < 0) AS negative_total,
       SUM(total_amount = 0) AS zero_total,
       MIN(total_amount)     AS min_total,
       MAX(total_amount)     AS max_total
FROM trips;


/* -------------------------------------------------------------
   10. DISTANCES
   -------------------------------------------------------------
   Expected:
     trip_distance = 0       438,914
     trip_distance > 100         452
     maximum               205,654.12

   No taxi drove 205,654 miles. The zero-distance trips are a
   mixture of cancellations, meter faults and trips that began
   and ended in the same place.

   This column is why the geometry matters. Question 6 compares
   each reported distance against the straight line between its
   two zone centroids. A trip cannot be shorter than that, so the
   comparison finds impossible readings without needing an
   arbitrary threshold.
   ------------------------------------------------------------- */

SELECT SUM(trip_distance = 0)   AS zero_distance,
       SUM(trip_distance > 100) AS over_100_miles,
       MAX(trip_distance)       AS max_distance
FROM trips;


/* -------------------------------------------------------------
   11. REFERENTIAL INTEGRITY
   -------------------------------------------------------------
   No foreign keys were declared, so this checks by hand.

   Expected: 0 trips referencing a location id absent from
   taxi_zones. Every id in the source falls within 1 to 265.
   ------------------------------------------------------------- */

SELECT SUM(pu.location_id IS NULL) AS pickup_zone_missing,
       SUM(dr.location_id IS NULL) AS dropoff_zone_missing
FROM trips t
LEFT JOIN taxi_zones pu ON pu.location_id = t.pu_location_id
LEFT JOIN taxi_zones dr ON dr.location_id = t.do_location_id;


/* -------------------------------------------------------------
   12. SPATIAL COVERAGE
   -------------------------------------------------------------
   Expected: 159,807 trips, 0.56%, where either end has no
   geometry. Of those, 140,722 involve zone 264 or 265.

   Worth separating. 264 and 265 are the source's placeholders
   for an unrecorded location, so those trips were never
   locatable. The remaining 19,085, under 0.07%, are the cost of
   the shapefile labelling defect that leaves zones 57, 104 and
   105 without a polygon.

   That defect looked like the serious problem when it was
   discovered. It removes seven trips in every ten thousand.
   ------------------------------------------------------------- */

SELECT COUNT(*)                                                       AS no_geometry_either_end,
       ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM trips), 2)        AS pct,
       SUM(t.pu_location_id IN (264,265) OR t.do_location_id IN (264,265)) AS involving_unknown_zone
FROM trips t
LEFT JOIN zone_geometry gp ON gp.location_id = t.pu_location_id
LEFT JOIN zone_geometry gd ON gd.location_id = t.do_location_id
WHERE gp.location_id IS NULL OR gd.location_id IS NULL;


/* -------------------------------------------------------------
   13. STORAGE BASELINE
   -------------------------------------------------------------
   No expectation stated. This is the number the index work is
   measured against.

   In InnoDB the primary key is the table, so it is counted in
   data_mb rather than index_mb. index_mb should therefore be
   near zero at this point: nothing else has been built yet.

   information_schema caches table statistics for a day by
   default, so straight after a load these columns report
   whatever was true before it. Reading zero for a table holding
   millions of rows means stale statistics, not an empty table.

   information_schema_stats_expiry = 0 makes the server read them
   live for this session.
   ------------------------------------------------------------- */

SET SESSION information_schema_stats_expiry = 0;

SELECT table_name,
       ROUND(data_length  / 1024 / 1024) AS data_mb,
       ROUND(index_length / 1024 / 1024) AS index_mb,
       ROUND((data_length + index_length) / 1024 / 1024) AS total_mb
FROM information_schema.tables
WHERE table_schema = 'nyc_taxi'
ORDER BY data_length DESC;
