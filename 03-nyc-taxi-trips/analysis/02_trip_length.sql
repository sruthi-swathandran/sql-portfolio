/* =============================================================
   Question 2: did the trips that survived get longer or shorter?

   Volume halved between 2017 and 2019. If the remaining trips
   look like a random half of the old ones, green taxis lost
   customers evenly. If they look different, something specific
   was taken and something specific was left behind.

   Measured two ways, because distance and duration can move in
   opposite directions. Longer trips at the same speed means the
   trade shifted outward. The same trips taking longer means
   traffic, not geography.
   ============================================================= */

USE nyc_taxi;

/* -------------------------------------------------------------
   What gets excluded, and what it costs
   -------------------------------------------------------------
   Run this first. Nothing should be dropped without a count
   attached to it, because an exclusion that removes 40% of the
   data is a finding, and one that removes 0.4% is housekeeping.
   ------------------------------------------------------------- */

SELECT COUNT(*)                                                       AS all_trips,
       SUM(trip_distance = 0)                                         AS zero_distance,
       SUM(trip_distance >= 100)                                      AS absurd_distance,
       SUM(dropoff_datetime <= pickup_datetime)                       AS bad_time_order,
       SUM(TIMESTAMPDIFF(SECOND, pickup_datetime, dropoff_datetime) <    60) AS under_a_minute,
       SUM(TIMESTAMPDIFF(SECOND, pickup_datetime, dropoff_datetime) > 10800) AS over_three_hours
FROM trips
WHERE pickup_datetime >= '2017-01-01'
  AND pickup_datetime <  '2021-01-01';

/*
   The reasoning behind each.

   Zero distance is a mixture of cancellations, meter faults and
   trips returning to the same point. None of them is "a journey
   of length zero", so including them would drag the median down
   with non-journeys.

   Distances of 100 miles or more are not credible for a green
   taxi, which is licensed for street hails outside the Manhattan
   core. The maximum in the data is 205,654 miles.

   Trips under a minute are meter errors. Trips over three hours
   are usually a meter left running; a genuine three-hour green
   taxi fare exists but is rare enough not to shift a median.

   The three-hour line is a judgement, not a fact. The count
   above shows exactly what it costs, so a reader can disagree
   with it and know the size of the disagreement.
*/


/* -------------------------------------------------------------
   Median distance and duration by year
   -------------------------------------------------------------
   Median, not mean. One trip recorded at 205,654 miles moves the
   mean of six million trips by about three hundredths of a mile,
   which sounds harmless until you notice there are 452 of them.
   The median cannot be moved by an outlier's size, only by its
   existence.

   MySQL has no MEDIAN function, so it is built from ROW_NUMBER
   and COUNT: number the rows in order within each year, count
   them, and take the middle one, or the average of the middle
   two when the count is even. FLOOR and CEIL of (n+1)/2 give the
   same row for odd counts and the two middle rows for even.

   BE PATIENT WITH THIS ONE
   ------------------------
   It sorts roughly 27 million rows twice, once per measure, and
   there is no index on trip_distance or on the computed
   duration. Expect minutes, and note the time.

   That cost is not incidental. It is the subject of the
   alternative at the bottom of this file.
   ------------------------------------------------------------- */

WITH valid AS (
    SELECT YEAR(pickup_datetime) AS yr,
           trip_distance,
           TIMESTAMPDIFF(SECOND, pickup_datetime, dropoff_datetime) / 60.0 AS duration_min
    FROM trips
    WHERE pickup_datetime >= '2017-01-01'
      AND pickup_datetime <  '2021-01-01'
      AND trip_distance   >  0
      AND trip_distance   <  100
      AND TIMESTAMPDIFF(SECOND, pickup_datetime, dropoff_datetime) BETWEEN 60 AND 10800
),
ranked AS (
    SELECT yr,
           trip_distance,
           duration_min,
           ROW_NUMBER() OVER (PARTITION BY yr ORDER BY trip_distance) AS rn_dist,
           ROW_NUMBER() OVER (PARTITION BY yr ORDER BY duration_min)  AS rn_dur,
           COUNT(*)     OVER (PARTITION BY yr)                        AS n
    FROM valid
)
SELECT yr,
       MAX(n) AS trips,
       ROUND(AVG(CASE WHEN rn_dist IN (FLOOR((n + 1) / 2), CEIL((n + 1) / 2))
                      THEN trip_distance END), 2) AS median_miles,
       ROUND(AVG(CASE WHEN rn_dur  IN (FLOOR((n + 1) / 2), CEIL((n + 1) / 2))
                      THEN duration_min  END), 1) AS median_minutes
FROM ranked
GROUP BY yr
ORDER BY yr;


/* -------------------------------------------------------------
   The same answer, computed by bucketing instead of sorting
   -------------------------------------------------------------
   Do not run this until the query above has been timed. The
   comparison is the point.

   Sorting 27 million rows to find the middle one is wasteful.
   The median only needs to know how many trips fall below each
   distance, and trip_distance is recorded to two decimal places,
   so rounding to one gives at most a few thousand distinct
   values per year.

   Counting into buckets is a GROUP BY, not a sort. The running
   total then runs over a few thousand rows rather than millions,
   and the median is the first bucket whose cumulative count
   passes half.

   The trade is precision: this returns the median to the nearest
   tenth of a mile rather than the nearest hundredth. For a
   question about whether typical journeys got longer, a tenth of
   a mile is far below the resolution of the answer.

   The general shape is worth remembering. Reduce the data to the
   distinct values you actually need, then compute on those.
   ------------------------------------------------------------- */

WITH buckets AS (
    SELECT YEAR(pickup_datetime)      AS yr,
           ROUND(trip_distance, 1)    AS miles,
           COUNT(*)                   AS n
    FROM trips
    WHERE pickup_datetime >= '2017-01-01'
      AND pickup_datetime <  '2021-01-01'
      AND trip_distance   >  0
      AND trip_distance   <  100
      AND TIMESTAMPDIFF(SECOND, pickup_datetime, dropoff_datetime) BETWEEN 60 AND 10800
    GROUP BY yr, miles
),
running AS (
    SELECT yr, miles, n,
           SUM(n) OVER (PARTITION BY yr ORDER BY miles
                        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cum,
           SUM(n) OVER (PARTITION BY yr)                                  AS total
    FROM buckets
)
SELECT yr,
       MAX(total)                                        AS trips,
       MIN(CASE WHEN cum >= total / 2 THEN miles END)    AS median_miles
FROM running
GROUP BY yr
ORDER BY yr;
