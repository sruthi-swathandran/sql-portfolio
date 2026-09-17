/* =============================================================
   Question 1: how did trip volume change between 2017 and 2020,
   and how much of the fall predates COVID?

   The headline is easy and misleading. Green taxi trips fall from
   11.7 million to 1.7 million, an 85% collapse across a period
   that ends in a pandemic, and the obvious reading is that COVID
   destroyed the trade.

   Roughly half of it happened before anyone had heard of COVID.
   ============================================================= */

USE nyc_taxi;

/* --- Check first: is 2020 a real year or a truncated file? ---
   1.7 million trips against 6.0 million the year before is
   either a collapse or a file that stops in March. Those are
   completely different findings and the query that produces the
   number cannot tell them apart.

   This is the same trap as comparing a partial year against a
   full one, which changed the conclusion three separate times in
   the Airbnb project.

   Expected if the year is complete: twelve months, and a
   December that is not conspicuously short.
   ---------------------------------------------------------- */

SELECT MIN(pickup_datetime) AS first_trip,
       MAX(pickup_datetime) AS last_trip,
       COUNT(DISTINCT MONTH(pickup_datetime)) AS months_present
FROM trips
WHERE pickup_datetime >= '2020-01-01'
  AND pickup_datetime <  '2021-01-01';

/* 2020-01-01 to 2020-12-31, twelve months. The year is complete,
   so the collapse is real. */


/* --- Yearly volume ---------------------------------------- */

SELECT YEAR(pickup_datetime) AS yr,
       COUNT(*)              AS trips
FROM trips
WHERE pickup_datetime >= '2017-01-01'
  AND pickup_datetime <  '2021-01-01'
GROUP BY yr
ORDER BY yr;

/*
   2017  11,740,514
   2018   8,806,899   -25.0%
   2019   6,043,879   -31.4%
   2020   1,734,040   -71.3%

   2017 to 2019 alone is -48.5%, with no pandemic involved.
*/


/* --- Monthly volume ---------------------------------------
   Uses pickup_month, the indexed virtual column added in
   06_indexes.sql. Grouping on YEAR() and MONTH() returns the
   same 48 rows and takes 17.8 seconds against 13.8, because the
   optimiser cannot use an index through a function call.
   ---------------------------------------------------------- */

SELECT pickup_month,
       COUNT(*) AS trips
FROM trips
WHERE pickup_month >= '2017-01-01'
  AND pickup_month <  '2021-01-01'
GROUP BY pickup_month
ORDER BY pickup_month;

/*
   Two things this shows that the yearly figures hide.

   The decline is smooth, not stepped. Every month of 2018 sits
   below the same month of 2017, and every month of 2019 below
   2018, without exception. A shock produces a cliff. Steady
   proportional decline across 36 consecutive months is what
   substitution looks like: customers leaving a little at a time
   for something else.

   Seasonality cannot be read off this series, and it is worth
   saying why rather than guessing at it.

   March is the busiest month of 2017 and of 2018, which looks
   like a pattern until 2019, where January is higher. The
   trough moves too: August in 2017, November in 2018.

   A 29% annual decline is about 2.8% a month, which is the same
   size as the seasonal swings being looked for. Any month is
   competing against a month two or three percent larger simply
   for being earlier. Separating season from trend needs the
   trend removed first, and nothing here does that, so no
   seasonal claim is made.
*/


/* --- Separating the trend from the pandemic ----------------
   January and February 2020 are the last clean months. If those
   fell at the rate already established, the pandemic explains
   only what happened after them.
   ---------------------------------------------------------- */

SELECT YEAR(pickup_datetime) AS yr,
       COUNT(*)              AS jan_feb_trips
FROM trips
WHERE MONTH(pickup_datetime) IN (1, 2)
  AND pickup_datetime >= '2017-01-01'
  AND pickup_datetime <  '2021-01-01'
GROUP BY yr
ORDER BY yr;

/*
   Jan+Feb 2019  1,206,567
   Jan+Feb 2020    846,404   -29.9%

   The compound annual decline from 2017 to 2019 is 28.3%. The
   first two months of 2020 came in at -29.9%, which is the same
   trend still running, untouched.

   So the trend rate is about -29% a year, and everything beyond
   that rate in 2020 is attributable to the pandemic.

   Extended forward, 2020 "should" have produced about 4.34
   million trips. It produced 1.73 million. On that reading the
   long decline cost roughly 1.71 million trips and the pandemic
   roughly 2.60 million.

   That is a straight-line counterfactual and nothing more. It
   assumes the decline would have continued at exactly its
   previous rate, which is an assumption, not a finding. It is
   quoted here as an order of magnitude: the two causes are
   comparable in size, and neither dominates.
*/


/* --- The pandemic months ----------------------------------- */

SELECT pickup_month,
       COUNT(*) AS trips
FROM trips
WHERE pickup_month >= '2020-01-01'
  AND pickup_month <  '2021-01-01'
GROUP BY pickup_month
ORDER BY pickup_month;

/*
   2020-03  223,403   -44% on February
   2020-04   35,610   the floor, -93.1% against April 2019
   2020-10   95,115   the peak of the recovery
   2020-12   83,128   still -81.6% against December 2019

   The recovery stalls in October and turns back down. By the end
   of the year green taxis are running at under a fifth of their
   volume twelve months earlier, and at under 8% of January 2017.
*/
