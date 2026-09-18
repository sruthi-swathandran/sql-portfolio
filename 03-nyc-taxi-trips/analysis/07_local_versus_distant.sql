/* =============================================================
   Question 7: what share of trips stay local, and did that
   change as volume collapsed?

   Question 3 measured trip length in miles and found the short
   trips leaving first. Miles are a blunt instrument for this,
   because a mile in dense Brooklyn and a mile in outer Queens
   are different kinds of journey.

   Adjacency is the structural version of the same question. A
   trip that ends in the zone it started in, or in one that
   borders it, is local by construction, regardless of how many
   miles the meter recorded. A trip that crosses zones which do
   not touch has left the neighbourhood.

   That definition comes from the geometry rather than from a
   threshold anybody chose, which is the same reason question 6
   was worth building.
   ============================================================= */

USE nyc_taxi;

/* -------------------------------------------------------------
   1. Trips by structural class
   -------------------------------------------------------------
   Four categories, and the fourth is the honest one:

     same zone       started and ended in one zone
     adjacent        ended in a zone sharing a border
     distant         ended somewhere not touching the origin
     unclassifiable  either end has no geometry

   The 159,807 trips with no geometry cannot be placed and are
   not quietly assigned to "distant", which is what an inner join
   would have done.
   ------------------------------------------------------------- */

SELECT YEAR(t.pickup_datetime) AS yr,
       CASE
           WHEN gp.location_id IS NULL
             OR gd.location_id IS NULL        THEN '4. unclassifiable'
           WHEN t.pu_location_id = t.do_location_id THEN '1. same zone'
           WHEN a.from_id IS NOT NULL         THEN '2. adjacent zone'
           ELSE                                    '3. distant zone'
       END AS trip_class,
       COUNT(*) AS trips,
       ROUND(100 * COUNT(*)
             / SUM(COUNT(*)) OVER (PARTITION BY YEAR(t.pickup_datetime)), 2) AS pct_of_year
FROM trips t
LEFT JOIN zone_geometry  gp ON gp.location_id = t.pu_location_id
LEFT JOIN zone_geometry  gd ON gd.location_id = t.do_location_id
LEFT JOIN zone_adjacency a  ON a.from_id = t.pu_location_id
                           AND a.to_id   = t.do_location_id
WHERE t.pickup_datetime >= '2017-01-01'
  AND t.pickup_datetime <  '2021-01-01'
GROUP BY yr, trip_class
ORDER BY yr, trip_class;


/* -------------------------------------------------------------
   2. Which class lost most
   -------------------------------------------------------------
   2017 against 2019 again, both complete and neither pandemic.

   The prediction from question 3: same-zone and adjacent trips
   should fall hardest, because those are the short hops, and
   distant trips should hold up.

   If all three fall together, adjacency adds nothing that miles
   did not already say and this question is decoration.
   ------------------------------------------------------------- */

WITH classed AS (
    SELECT YEAR(t.pickup_datetime) AS yr,
           CASE
               WHEN gp.location_id IS NULL
                 OR gd.location_id IS NULL             THEN '4. unclassifiable'
               WHEN t.pu_location_id = t.do_location_id THEN '1. same zone'
               WHEN a.from_id IS NOT NULL              THEN '2. adjacent zone'
               ELSE                                         '3. distant zone'
           END AS trip_class,
           COUNT(*) AS trips
    FROM trips t
    LEFT JOIN zone_geometry  gp ON gp.location_id = t.pu_location_id
    LEFT JOIN zone_geometry  gd ON gd.location_id = t.do_location_id
    LEFT JOIN zone_adjacency a  ON a.from_id = t.pu_location_id
                               AND a.to_id   = t.do_location_id
    WHERE t.pickup_datetime >= '2017-01-01'
      AND t.pickup_datetime <  '2020-01-01'
    GROUP BY yr, trip_class
)
SELECT trip_class,
       MAX(CASE WHEN yr = 2017 THEN trips END) AS trips_2017,
       MAX(CASE WHEN yr = 2019 THEN trips END) AS trips_2019,
       ROUND(100 * (MAX(CASE WHEN yr = 2019 THEN trips END)
                  - MAX(CASE WHEN yr = 2017 THEN trips END))
                 / MAX(CASE WHEN yr = 2017 THEN trips END), 1) AS pct_change
FROM classed
GROUP BY trip_class
ORDER BY trip_class;


/* -------------------------------------------------------------
   3. Does the retreat change what kind of trip survives?
   -------------------------------------------------------------
   Question 5 found the trade moving outward. Question 5's follow
   up found the surviving outer trips increasingly bound for
   Manhattan.

   This asks the structural version: in the outer bands, is what
   remains local travel or long-haul travel? A neighbourhood
   losing its short hops and keeping its airport runs is a
   different story from one keeping both.
   ------------------------------------------------------------- */

SELECT YEAR(t.pickup_datetime) AS yr,
       CASE
           WHEN m.km_to_yellow_zone <  4 THEN '1. 0 to 4 km'
           WHEN m.km_to_yellow_zone <  8 THEN '2. 4 to 8 km'
           WHEN m.km_to_yellow_zone < 12 THEN '3. 8 to 12 km'
           ELSE                               '4. 12 km plus'
       END AS pickup_band,
       COUNT(*) AS trips,
       ROUND(100 * SUM(t.pu_location_id = t.do_location_id
                    OR a.from_id IS NOT NULL) / COUNT(*), 1) AS pct_local
FROM trips t
JOIN zone_metrics m ON m.location_id = t.pu_location_id
JOIN zone_geometry gd ON gd.location_id = t.do_location_id
LEFT JOIN zone_adjacency a ON a.from_id = t.pu_location_id
                          AND a.to_id   = t.do_location_id
WHERE t.pickup_datetime >= '2017-01-01'
  AND t.pickup_datetime <  '2020-01-01'
  AND m.service_zone <> 'Yellow Zone'
GROUP BY yr, pickup_band
ORDER BY yr, pickup_band;


/* =============================================================
   FINDINGS

   THE AGGREGATE LOOKS WEAK

     class        2017        2019      change
     same zone   1,719,679   821,525    -52.2%
     adjacent    3,891,090 1,812,305    -53.4%
     distant     6,072,564 3,362,118    -44.6%

   Local trips fell about nine points harder than distant ones,
   which points the same way as question 3 but with far less
   force. Question 3 had trips under a mile falling 31.5% while
   trips over ten miles grew 47.5%.

   Same-zone and adjacent also fell at almost identical rates, so
   splitting "local" into two categories earned nothing.

   On this evidence the question looked like decoration.

   THE AGGREGATE WAS HIDING THE ANSWER

   Local share by how far the pickup zone sits from the core:

     band          2017    2019    change
     0 to 4 km     46.5%   46.3%    -0.2
     4 to 8 km     52.1%   44.6%    -7.5
     8 to 12 km    45.1%   36.1%    -9.0
     12 km plus    52.5%   36.7%   -15.8

   The inner band did not change its mix at all. It halved in
   size and went on doing the same proportion of local work.
   Everything outside it moved sharply away from local travel,
   and the further out, the sharper.

   Since the inner band is 56 to 63 per cent of all trips, its
   stillness dominated the aggregate and diluted the rest. The
   fourth time in this project that a flat total has concealed
   large movement beneath it.

   THE 12 KM PLUS BAND, IN DETAIL

   Total trips there rose 3.4% between 2017 and 2019. Underneath:
   local trips fell about 28% while distant trips grew about 38%.

   A shrinking trade with a growing segment inside it.

   WHAT IT MEANS, WITH QUESTION 5

   Question 5 found outer-borough trips becoming three to four
   times likelier to end in Manhattan. This finds the same zones
   abandoning local work at the same time.

   Two independent measures, built on different geometry, giving
   the same conclusion: the outer boroughs stopped using green
   taxis to move around their own neighbourhoods and kept them
   for the journey into the city.

   -------------------------------------------------------------
   A NOTE ON THE METHOD

   Adjacency sounded more principled than a mileage threshold,
   because it comes from the geometry rather than from a number
   somebody chose. In practice it is noisier, and the reason is
   visible in the 2017 row above.

   The zone grid is not uniform. Manhattan is carved into 69
   small zones and Staten Island into 20 large ones. A two-mile
   trip in Manhattan crosses several non-adjacent zones and
   counts as distant; a three-mile trip in Staten Island may
   never leave its neighbour and counts as local.

   That is why the outer bands showed the highest local share in
   2017: bigger zones, not more local travel. The artefact was
   real. It was then overwhelmed by a genuine shift, which is the
   only reason the 2019 figures can be read at all.

   A measure derived from geometry is not automatically more
   objective than one derived from a threshold. It inherits
   whatever arbitrariness is baked into the geometry.
   ============================================================= */
