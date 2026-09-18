/* =============================================================
   Question 6: how does the meter's reported distance compare to
   the straight line between the two zones, and how many trips
   report a distance that is physically impossible?

   Every data quality check so far has needed a threshold
   somebody chose. Zero distance is wrong. A hundred miles is
   wrong. Three hours is probably wrong. Each of those is a
   judgement, defensible but arbitrary, and a reader can
   reasonably disagree with all of them.

   Geometry removes the judgement. A vehicle cannot travel a
   shorter path between two points than the straight line joining
   them. That is not a convention, it is a fact about space, and
   it gives an objective floor to test 28 million meter readings
   against.

   WHAT THE COMPARISON CAN AND CANNOT DO
   -------------------------------------
   The straight line available here runs centroid to centroid,
   not endpoint to endpoint. The true endpoints sit somewhere
   inside their zones, so the real straight line may be shorter
   or longer than the centroid distance by roughly the size of a
   zone.

   For a trip between adjacent zones that error swamps the
   measurement. Two points either side of a shared boundary are
   metres apart while their centroids may be a kilometre or more,
   so a perfectly honest meter can report less than the centroid
   distance.

   For a trip of fifteen kilometres, a zone-sized error is
   noise.

   So the impossibility test is applied only to pairs at least
   5 km apart, where zone size cannot explain the gap. Everything
   closer is reported separately and not called impossible.
   ============================================================= */

USE nyc_taxi;

/* -------------------------------------------------------------
   1. The circuity factor
   -------------------------------------------------------------
   How much further does a car actually travel than the crow
   flies? For a dense street grid the expected answer is somewhere
   around 1.2 to 1.4.

   This is worth computing before looking for faults, because it
   establishes what normal looks like. Without it, any ratio
   flagged as suspicious is being judged against an assumption.

   Median rather than mean, computed by the bucketing method from
   question 2. Ratios have a long right tail and one trip
   recorded at 205,654 miles would otherwise decide the answer.
   ------------------------------------------------------------- */

WITH ratios AS (
    SELECT ROUND(t.trip_distance / (p.km * 0.621371), 2) AS ratio,
           COUNT(*)                                      AS n
    FROM trips t
    JOIN zone_pair_distance p ON p.from_id = t.pu_location_id
                             AND p.to_id   = t.do_location_id
    WHERE t.pickup_datetime >= '2017-01-01'
      AND t.pickup_datetime <  '2021-01-01'
      AND t.trip_distance    > 0
      AND t.trip_distance    < 100
      AND p.km               > 5
    GROUP BY ratio
),
running AS (
    SELECT ratio, n,
           SUM(n) OVER (ORDER BY ratio
                        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cum,
           SUM(n) OVER ()                                                 AS total
    FROM ratios
)
SELECT MAX(total)                                     AS trips,
       MIN(CASE WHEN cum >= total * 0.10 THEN ratio END) AS p10,
       MIN(CASE WHEN cum >= total * 0.25 THEN ratio END) AS p25,
       MIN(CASE WHEN cum >= total * 0.50 THEN ratio END) AS median,
       MIN(CASE WHEN cum >= total * 0.75 THEN ratio END) AS p75,
       MIN(CASE WHEN cum >= total * 0.90 THEN ratio END) AS p90
FROM running;

/* 0.621371 converts kilometres to miles. trip_distance is in
   miles and ST_Distance returned metres, so one of them has to
   move and the constant belongs where it is visible rather than
   buried in the zone table. */


/* -------------------------------------------------------------
   2. Impossible readings
   -------------------------------------------------------------
   A ratio below 1 means the meter recorded a shorter journey
   than the straight line between the two zone centres. On pairs
   more than 5 km apart, zone size cannot account for it.

   Reported by year, because a fault that appears in one year and
   not others is a different problem from one spread evenly.
   ------------------------------------------------------------- */

SELECT YEAR(t.pickup_datetime) AS yr,
       COUNT(*)                                                    AS trips_over_5km,
       SUM(t.trip_distance < p.km * 0.621371)                      AS impossible,
       ROUND(100 * SUM(t.trip_distance < p.km * 0.621371)
                 / COUNT(*), 3)                                    AS pct_impossible,
       SUM(t.trip_distance < p.km * 0.621371 * 0.5)                AS under_half_the_straight_line
FROM trips t
JOIN zone_pair_distance p ON p.from_id = t.pu_location_id
                         AND p.to_id   = t.do_location_id
WHERE t.pickup_datetime >= '2017-01-01'
  AND t.pickup_datetime <  '2021-01-01'
  AND t.trip_distance    > 0
  AND t.trip_distance    < 100
  AND p.km               > 5
GROUP BY yr
ORDER BY yr;


/* -------------------------------------------------------------
   3. Is it the meter or the zone codes?
   -------------------------------------------------------------
   An impossible reading has two possible causes. The meter
   under-recorded the distance, or the pickup and dropoff zones
   are wrong, in which case the straight line being compared
   against is the wrong straight line.

   The two look different in aggregate. A broken meter should
   appear across all sorts of zone pairs. Bad zone coding should
   concentrate in particular pairs, and especially in pairs
   involving zones already known to be awkward.

   If the top offending pairs are scattered, it is meters. If a
   handful of pairs dominate, it is coding.
   ------------------------------------------------------------- */

SELECT zp.zone_name          AS pickup_zone,
       zd.zone_name          AS dropoff_zone,
       ROUND(p.km, 1)        AS straight_line_km,
       COUNT(*)              AS impossible_trips,
       ROUND(AVG(t.trip_distance), 2) AS mean_reported_miles
FROM trips t
JOIN zone_pair_distance p ON p.from_id = t.pu_location_id
                         AND p.to_id   = t.do_location_id
JOIN taxi_zones zp ON zp.location_id = t.pu_location_id
JOIN taxi_zones zd ON zd.location_id = t.do_location_id
WHERE t.pickup_datetime >= '2017-01-01'
  AND t.pickup_datetime <  '2021-01-01'
  AND t.trip_distance    > 0
  AND t.trip_distance    < 100
  AND p.km               > 5
  AND t.trip_distance    < p.km * 0.621371
GROUP BY pickup_zone, dropoff_zone, straight_line_km
ORDER BY impossible_trips DESC
LIMIT 20;


/* -------------------------------------------------------------
   4. What the arbitrary thresholds missed
   -------------------------------------------------------------
   Question 2 excluded trips at zero distance, over 100 miles,
   and outside a duration window. All three were judgement calls.

   This asks how many trips passed every one of those filters and
   are still impossible. Those are readings that no threshold
   would have caught, because nothing about them looks wrong
   until you know where they went.

   That is the argument for the geometry, stated as a number.
   ------------------------------------------------------------- */

SELECT COUNT(*) AS passed_every_filter_but_impossible
FROM trips t
JOIN zone_pair_distance p ON p.from_id = t.pu_location_id
                         AND p.to_id   = t.do_location_id
WHERE t.pickup_datetime >= '2017-01-01'
  AND t.pickup_datetime <  '2021-01-01'
  AND t.trip_distance    > 0
  AND t.trip_distance    < 100
  AND TIMESTAMPDIFF(SECOND, t.pickup_datetime, t.dropoff_datetime) BETWEEN 60 AND 10800
  AND p.km               > 5
  AND t.trip_distance    < p.km * 0.621371;


/* =============================================================
   FINDINGS

   This question took three wrong answers to get right. All three
   are kept, because the corrections are the method.

   -------------------------------------------------------------
   THE CIRCUITY FACTOR, WHICH VALIDATES EVERYTHING ELSE

   Across 5.8 million trips between zones more than 5 km apart:

     p10   1.05
     p25   1.18
     median 1.34
     p75   1.54
     p90   1.78

   A car in New York covers about a third more ground than the
   straight line. That is what a dense grid with rivers through
   it should produce, and it is an independent check on the whole
   spatial pipeline. Had the axis order been wrong, the centroids
   misplaced or the kilometre-to-mile conversion inverted, this
   number would be nonsense rather than plausible.

   -------------------------------------------------------------
   WRONG ANSWER 1: THE THRESHOLD

   Applying the impossibility test to pairs over 5 km gave 6.55%
   of trips reporting less than the straight line, roughly
   380,000 of them. A striking headline.

   Splitting by how far apart the zones are:

     5 to 10 km    8.661%
     10 to 20 km   1.097%
     20 to 30 km   0.254%
     30 km plus    0.139%

   An eightfold collapse between the first two bands. A meter
   fault does not care how far apart the zones are. A centroid
   approximation cares enormously, because one kilometre of
   uncertainty is 20% of a 5 km journey and 3% of a 30 km one.

   The header of this file opens by saying centroid error would
   swamp short pairs and be negligible at fifteen kilometres. The
   reasoning was right and the threshold was set at 5 km anyway,
   wrong by a factor of four. Stating a limitation is not the
   same as measuring it.

   THE NUMBER THAT SURVIVES

   Above 20 km, where the approximation is tight, 491 trips out
   of 197,590 report an impossible distance. About 1 in 400.

   Smaller than the headline and far better founded.

   -------------------------------------------------------------
   WRONG ANSWER 2: THE JFK THEORY

   Ranking the surviving 491 by zone pair put upper Manhattan to
   JFK in seven of the top eight places, 90 trips in all,
   reporting half to two thirds of the straight line.

   JFK has its own rate code and a flat fare. A meter that is not
   charging by distance seemed a good candidate for a meter that
   does not measure it accurately.

   Impossible rate by rate code, against the population of trips
   over 20 km:

     1  standard      176 / 95,267   0.185%
     .  null          159 / 42,960   0.370%
     2  JFK flat       88 / 33,788   0.260%
     5  negotiated     65 / 21,199   0.307%
     3  Newark          3 /  3,697   0.081%
     4  Nassau          0 /    679   0.000%

   JFK fails at 0.260% against an overall 0.249%. Barely
   elevated.

   It dominated the ranking because upper Manhattan to JFK is a
   high-volume route, not because those trips are faulty. The
   list was ordered by count and read as though it were ordered
   by rate. A base rate error, and avoidable: the fix was one
   query asking how many JFK trips there are altogether.

   -------------------------------------------------------------
   WHAT IS ACTUALLY TRUE

   Roughly 1 in 400 trips over 20 km reports a distance that
   cannot be correct. There is no single cause. The rate is
   slightly worse for negotiated fares and for the 942,199
   metadata-free rows, which is consistent with those rows coming
   from whatever system also drops seven columns.

   WHY THE GEOMETRY WAS WORTH IT

   Every other data quality filter in this project rests on a
   number somebody chose: zero miles is wrong, a hundred is
   wrong, three hours is probably wrong. Defensible, arbitrary,
   and open to reasonable disagreement.

   This one rests on the fact that a vehicle cannot travel a
   shorter path than the straight line between its endpoints.
   The threshold it needs is not a judgement about taxis. It is a
   judgement about how precisely the endpoints are known, which
   is measurable, and was measured.
   ============================================================= */
