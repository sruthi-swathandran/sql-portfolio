/* =============================================================
   Question 10: which zones lost the most, which held up, and is
   the pattern geographic?

   Question 5 answered a version of this in bands: the closer to
   the Manhattan core, the harder the fall. Bands are an average
   over dozens of zones, and averages hide the zones that broke
   the pattern.

   This is the zone-level version, and it is the one that becomes
   a map. 260 rows is too many to read as a table and exactly
   right to read as a picture.

   THRESHOLD
   ---------
   Zones with fewer than 5,000 trips in 2017 are excluded. A zone
   with 40 trips that grows to 120 is a 200% rise and means
   nothing, and on a map it would be a bright patch drawing the
   eye to noise.

   The count of excluded zones is reported so the exclusion is
   visible rather than assumed.
   ============================================================= */

USE nyc_taxi;

/* -------------------------------------------------------------
   1. What the threshold costs
   -------------------------------------------------------------
   Expected: most zones survive it, and the ones dropped hold a
   negligible share of trips. If the excluded zones turn out to
   hold 10% of the data, the threshold is wrong.
   ------------------------------------------------------------- */

WITH z2017 AS (
    SELECT pu_location_id AS location_id, COUNT(*) AS trips
    FROM trips
    WHERE pickup_datetime >= '2017-01-01' AND pickup_datetime < '2018-01-01'
    GROUP BY pu_location_id
)
SELECT SUM(trips >= 5000)                                  AS zones_kept,
       SUM(trips <  5000)                                  AS zones_dropped,
       ROUND(100 * SUM(CASE WHEN trips < 5000 THEN trips END)
                 / SUM(trips), 3)                          AS pct_of_trips_dropped
FROM z2017;


/* -------------------------------------------------------------
   2. Zone level change, 2017 to 2019
   -------------------------------------------------------------
   The table behind the map.
   ------------------------------------------------------------- */

WITH yearly AS (
    SELECT pu_location_id AS location_id,
           SUM(pickup_datetime <  '2018-01-01') AS trips_2017,
           SUM(pickup_datetime >= '2019-01-01') AS trips_2019
    FROM trips
    WHERE pickup_datetime >= '2017-01-01'
      AND pickup_datetime <  '2020-01-01'
    GROUP BY pu_location_id
)
SELECT y.location_id,
       z.zone_name,
       z.borough,
       m.km_to_yellow_zone,
       y.trips_2017,
       y.trips_2019,
       ROUND(100 * (y.trips_2019 - y.trips_2017) / y.trips_2017, 1) AS pct_change
FROM yearly y
JOIN taxi_zones  z ON z.location_id = y.location_id
LEFT JOIN zone_metrics m ON m.location_id = y.location_id
WHERE y.trips_2017 >= 5000
ORDER BY pct_change DESC;

/* SUM(pickup_datetime < '2018-01-01') counts 2017 and
   SUM(pickup_datetime >= '2019-01-01') counts 2019, with 2018
   excluded by both. One pass over the data instead of two
   grouped queries joined together. */


/* -------------------------------------------------------------
   3. Does distance from the core explain it?
   -------------------------------------------------------------
   Question 5 said yes in bands. This tests it zone by zone by
   correlating each zone's distance from the core against its
   change.

   MySQL has no CORR function, so Pearson is built from the raw
   sums, the same way the Airbnb project computed review score
   correlations.

   A strong positive r means distance explains survival. A weak
   one means the band result was an average concealing a lot of
   variation, and the interesting zones are the ones off the
   line.
   ------------------------------------------------------------- */

WITH yearly AS (
    SELECT pu_location_id AS location_id,
           SUM(pickup_datetime <  '2018-01-01') AS trips_2017,
           SUM(pickup_datetime >= '2019-01-01') AS trips_2019
    FROM trips
    WHERE pickup_datetime >= '2017-01-01'
      AND pickup_datetime <  '2020-01-01'
    GROUP BY pu_location_id
),
paired AS (
    SELECT m.km_to_yellow_zone                                   AS x,
           100.0 * (y.trips_2019 - y.trips_2017) / y.trips_2017  AS y
    FROM yearly y
    JOIN zone_metrics m ON m.location_id = y.location_id
    WHERE y.trips_2017 >= 5000
)
SELECT COUNT(*) AS zones,
       ROUND((COUNT(*) * SUM(x * y) - SUM(x) * SUM(y))
             / SQRT( (COUNT(*) * SUM(x * x) - SUM(x) * SUM(x))
                   * (COUNT(*) * SUM(y * y) - SUM(y) * SUM(y)) ), 3) AS pearson_r
FROM paired;


/* -------------------------------------------------------------
   4. The zones that broke the pattern
   -------------------------------------------------------------
   Whatever the correlation, the residuals are where the story
   is. A zone close to the core that held up, or a distant one
   that collapsed, is doing something its neighbours are not.
   ------------------------------------------------------------- */

WITH yearly AS (
    SELECT pu_location_id AS location_id,
           SUM(pickup_datetime <  '2018-01-01') AS trips_2017,
           SUM(pickup_datetime >= '2019-01-01') AS trips_2019
    FROM trips
    WHERE pickup_datetime >= '2017-01-01'
      AND pickup_datetime <  '2020-01-01'
    GROUP BY pu_location_id
),
changed AS (
    SELECT y.location_id, z.zone_name, z.borough,
           m.km_to_yellow_zone AS km,
           y.trips_2017, y.trips_2019,
           100.0 * (y.trips_2019 - y.trips_2017) / y.trips_2017 AS pct_change
    FROM yearly y
    JOIN taxi_zones   z ON z.location_id = y.location_id
    JOIN zone_metrics m ON m.location_id = y.location_id
    WHERE y.trips_2017 >= 5000
)
(SELECT 'held up best' AS group_label, zone_name, borough,
        ROUND(km, 1) AS km, trips_2017, trips_2019, ROUND(pct_change, 1) AS pct_change
 FROM changed ORDER BY pct_change DESC LIMIT 10)
UNION ALL
(SELECT 'fell hardest', zone_name, borough,
        ROUND(km, 1), trips_2017, trips_2019, ROUND(pct_change, 1)
 FROM changed ORDER BY pct_change ASC LIMIT 10);


/* -------------------------------------------------------------
   5. By borough
   -------------------------------------------------------------
   Ten out of ten of the worst-hit zones being in Brooklyn is
   either a pattern or a coincidence, and one query separates
   them.
   ------------------------------------------------------------- */

WITH yearly AS (
    SELECT pu_location_id AS location_id,
           SUM(pickup_datetime <  '2018-01-01') AS trips_2017,
           SUM(pickup_datetime >= '2019-01-01') AS trips_2019
    FROM trips
    WHERE pickup_datetime >= '2017-01-01'
      AND pickup_datetime <  '2020-01-01'
    GROUP BY pu_location_id
)
SELECT z.borough,
       COUNT(*)                                     AS zones,
       SUM(y.trips_2017)                            AS trips_2017,
       SUM(y.trips_2019)                            AS trips_2019,
       ROUND(100 * (SUM(y.trips_2019) - SUM(y.trips_2017))
                 / SUM(y.trips_2017), 1)            AS pct_change
FROM yearly y
JOIN taxi_zones z ON z.location_id = y.location_id
GROUP BY z.borough
ORDER BY pct_change;


/* =============================================================
   FINDINGS

   THE THRESHOLD WAS CHEAP

   146 zones excluded for holding fewer than 5,000 trips in 2017,
   and they carry 1.28% of all trips between them. 115 kept.

   DISTANCE EXPLAINS LESS THAN THE BANDS SUGGESTED

   Pearson r of 0.531 between a zone's distance from the core and
   its change from 2017 to 2019, across 114 zones.

   That is a real relationship and it leaves 72% of the variance
   unexplained. Question 5's clean band gradient was an average
   laid over something much lumpier.

   THE RESIDUALS ARE THE FINDING

   All ten worst-hit zones are in Brooklyn, between 1.7 and 5.6
   km from the core:

     Williamsburg (South Side)   178,631 ->  29,644   -83.4%
     Williamsburg (North Side)   450,227 ->  79,055   -82.4%
     Greenpoint                  174,300 ->  32,127   -81.6%
     Brooklyn Navy Yard            8,010 ->   2,059   -74.3%
     Prospect Heights             54,644 ->  14,573   -73.3%
     Gowanus                      42,127 ->  11,434   -72.9%
     Carroll Gardens              95,797 ->  26,554   -72.3%
     Clinton Hill                180,194 ->  50,190   -72.1%
     Park Slope                  395,912 -> 114,255   -71.1%
     Bushwick North               49,013 ->  14,362   -70.7%

   The ten that held up are outer Brooklyn, the Bronx and Queens,
   6 to 13 km out, several of them growing:

     Canarsie                      7,088 ->  21,625  +205.1%
     Williamsbridge/Olinville      5,090 ->  13,723  +169.6%
     East Flatbush/Remsen Village  6,921 ->  17,245  +149.2%
     Flatlands                     7,786 ->  17,718  +127.6%
     Soundview/Castle Hill         8,694 ->  18,326  +110.8%
     East New York                16,799 ->  34,367  +104.6%

   CONCENTRATION

   Williamsburg North lost 371,172 trips on its own, which is
   6.5% of the entire city-wide decline from one zone out of 260.

   The ten worst zones together account for 22% of a loss spread
   across the whole city.

   This was not a uniform withdrawal. It was a collapse in one
   contiguous stretch of inner Brooklyn.

   -------------------------------------------------------------
   THE BOROUGH EFFECT, WHICH BREAKS THE DISTANCE STORY

     borough         2017        2019     change   share of decline
     Brooklyn     4,082,669   1,730,200   -57.6%        41.3%
     Queens       3,434,543   1,778,576   -48.2%        29.1%
     Manhattan    3,728,397   2,090,208   -43.9%        28.8%
     Bronx          473,500     426,626    -9.9%         0.8%
     Staten Island    2,400       2,867   +19.5%    negligible

   The Bronx fell 9.9% while the city fell 48.5%.

   And that cannot be distance. The Bronx sits closer to the core
   than Queens does, mean 8.1 km against 11.4 from zone_metrics.
   The nearer borough held and the further one collapsed, which is
   the reverse of what a distance model predicts.

   So a borough effect operates on top of the distance gradient,
   and it is larger than the gradient. Brooklyn produced 23% of
   2017's trips and 41% of the decline.

   WHAT THIS DATA CANNOT SAY

   Why the Bronx held is the obvious next question and nothing
   here can answer it. The dataset has no demographics, no
   income, no subway coverage, no competitor volumes.

   Anyone familiar with New York will recognise the list of
   collapsed zones and reach for an explanation about who lives
   there and what they carry in their pocket. That explanation
   may well be right. It is not in this data, and writing it up
   as a finding would be fiction with a citation attached.

   The pattern is the result. The cause is outside the files.
   ============================================================= */
