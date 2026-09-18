/* =============================================================
   Question 5: where did green taxis retreat to?

   Question 3 found the shape of the loss without knowing where
   it happened: between 2017 and 2018, trips under a mile fell
   31.5% while trips over ten miles grew 47.5%. Short hops went
   first.

   Short hops happen where density is highest, which is near the
   Manhattan core. So the prediction is that trips should shift
   outward, and the geometry can test it.

   THE REGULATORY BACKGROUND MATTERS HERE
   --------------------------------------
   Green taxis were licensed in 2013 to street-hail only in the
   Boro Zones and the 14 Manhattan zones above 96th Street.
   Picking up inside the 55-zone Yellow Zone was never permitted
   for them.

   So this is not a question about a trade that once served
   Manhattan and withdrew. It is about a trade confined to the
   outer city from birth, and whether it was pushed further out
   still.

   Dropoffs carry no such restriction, which is why they are
   measured separately at the bottom. The difference between
   where a green taxi may collect a passenger and where it may
   leave one is itself informative.
   ============================================================= */

USE nyc_taxi;

/* -------------------------------------------------------------
   1. Pickups by distance from the core
   -------------------------------------------------------------
   LEFT JOIN, not INNER. Five zones have no geometry, and 159,807
   trips touch one. An inner join would silently drop them; the
   "no geometry" row keeps them visible and countable.
   ------------------------------------------------------------- */

SELECT YEAR(t.pickup_datetime) AS yr,
       CASE
           WHEN m.location_id IS NULL             THEN '6. no geometry'
           WHEN m.service_zone = 'Yellow Zone'    THEN '0. Yellow Zone'
           WHEN m.km_to_yellow_zone <  4          THEN '1. 0 to 4 km'
           WHEN m.km_to_yellow_zone <  8          THEN '2. 4 to 8 km'
           WHEN m.km_to_yellow_zone < 12          THEN '3. 8 to 12 km'
           WHEN m.km_to_yellow_zone < 18          THEN '4. 12 to 18 km'
           ELSE                                        '5. 18 km plus'
       END                     AS band,
       COUNT(*)                AS trips,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY YEAR(t.pickup_datetime)), 2) AS pct_of_year
FROM trips t
LEFT JOIN zone_metrics m ON m.location_id = t.pu_location_id
WHERE t.pickup_datetime >= '2017-01-01'
  AND t.pickup_datetime <  '2021-01-01'
GROUP BY yr, band
ORDER BY yr, band;

/* SUM(COUNT(*)) OVER (PARTITION BY ...) gives each band's share
   of its own year without a second pass or a self-join. The
   window runs over the already-grouped rows, so it aggregates an
   aggregate. */


/* -------------------------------------------------------------
   2. Which bands lost most
   -------------------------------------------------------------
   2017 against 2019, which is the clean comparison: both years
   complete, neither touched by the pandemic.

   If the retreat story is right, the inner bands should fall
   hardest and the outer ones least. If every band falls by
   roughly the same proportion, green taxis lost customers evenly
   and the geography explains nothing.
   ------------------------------------------------------------- */

WITH by_band AS (
    SELECT YEAR(t.pickup_datetime) AS yr,
           CASE
               WHEN m.location_id IS NULL          THEN '6. no geometry'
               WHEN m.service_zone = 'Yellow Zone' THEN '0. Yellow Zone'
               WHEN m.km_to_yellow_zone <  4       THEN '1. 0 to 4 km'
               WHEN m.km_to_yellow_zone <  8       THEN '2. 4 to 8 km'
               WHEN m.km_to_yellow_zone < 12       THEN '3. 8 to 12 km'
               WHEN m.km_to_yellow_zone < 18       THEN '4. 12 to 18 km'
               ELSE                                     '5. 18 km plus'
           END                     AS band,
           COUNT(*)                AS trips
    FROM trips t
    LEFT JOIN zone_metrics m ON m.location_id = t.pu_location_id
    WHERE t.pickup_datetime >= '2017-01-01'
      AND t.pickup_datetime <  '2020-01-01'
    GROUP BY yr, band
)
SELECT band,
       MAX(CASE WHEN yr = 2017 THEN trips END) AS trips_2017,
       MAX(CASE WHEN yr = 2019 THEN trips END) AS trips_2019,
       ROUND(100 * (MAX(CASE WHEN yr = 2019 THEN trips END)
                  - MAX(CASE WHEN yr = 2017 THEN trips END))
                 / MAX(CASE WHEN yr = 2017 THEN trips END), 1) AS pct_change
FROM by_band
GROUP BY band
ORDER BY band;


/* -------------------------------------------------------------
   3. Pickups against dropoffs
   -------------------------------------------------------------
   Green taxis may not collect a passenger in the Yellow Zone.
   They may deliver one there.

   So the share of dropoffs landing in the Yellow Zone measures
   how much of the trade was carrying people into Manhattan. If
   that share falls while total volume falls, green taxis lost
   the commute into the core. If it holds or rises, what they
   lost was local travel within the outer boroughs.

   Those are different businesses disappearing, and the remedy a
   regulator would reach for differs accordingly.
   ------------------------------------------------------------- */

SELECT YEAR(t.pickup_datetime) AS yr,
       ROUND(100 * SUM(pu.service_zone = 'Yellow Zone') / COUNT(*), 2) AS pct_pickups_yellow,
       ROUND(100 * SUM(dr.service_zone = 'Yellow Zone') / COUNT(*), 2) AS pct_dropoffs_yellow,
       ROUND(AVG(pu.km_to_yellow_zone), 2)                             AS mean_km_pickup,
       ROUND(AVG(dr.km_to_yellow_zone), 2)                             AS mean_km_dropoff
FROM trips t
LEFT JOIN zone_metrics pu ON pu.location_id = t.pu_location_id
LEFT JOIN zone_metrics dr ON dr.location_id = t.do_location_id
WHERE t.pickup_datetime >= '2017-01-01'
  AND t.pickup_datetime <  '2021-01-01'
GROUP BY yr
ORDER BY yr;


/* =============================================================
   FINDINGS

   THE RETREAT IS REAL AND THE GRADIENT IS MONOTONIC

   Share of each year's pickups:

     band             2017     2018     2019     2020
     Yellow Zone      1.57%    1.72%    2.09%    2.99%
     0 to 4 km       62.96%   57.74%   54.80%   50.99%
     4 to 8 km       24.87%   24.77%   24.34%   23.55%
     8 to 12 km       7.03%   10.21%   11.65%   13.66%
     12 to 18 km      3.34%    5.09%    6.28%    7.50%
     18 km plus       0.06%    0.31%    0.58%    1.02%

   The absolute change from 2017 to 2019 is the finding:

     0 to 4 km     7,391,678 -> 3,311,823   -55.2%
     4 to 8 km     2,919,584 -> 1,471,371   -49.6%
     8 to 12 km      824,977 ->   703,984   -14.7%
     12 to 18 km     392,519 ->   379,268    -3.4%
     18 km plus        7,304 ->    35,034  +379.6%

   The closer a zone sits to the Manhattan core, the harder its
   green taxi business fell. Inside four kilometres it more than
   halved. Beyond twelve it barely moved. Beyond eighteen it grew
   almost fivefold.

   This is question 3's distance gradient placed on a map. Short
   trips near the core went first, which is exactly where a
   phone-hailed car is cheapest to supply and most worth
   supplying.

   CAUTION ON THE OUTER BAND

   7,304 trips across eighteen zones in 2017 is roughly four
   hundred per zone per year. A 380% rise on that base is a small
   number moving, not a market opening. It is reported because it
   fits the gradient, not because it carries weight on its own.

   2020 IS NOT PART OF THE TREND

   The 2020 shares continue in the same direction, and the year
   contains a pandemic. It is shown for completeness and excluded
   from every claim above, all of which rest on 2017 against
   2019.

   -------------------------------------------------------------
   THE YELLOW ZONE PICKUPS, AND WHY THEY ARE NOT A PROBLEM

   Green taxis were never permitted to street-hail in the Yellow
   Zone, yet 1.6% to 3.0% of pickups are recorded there, and over
   99% of those carry trip_type 1, a street hail rather than a
   dispatch.

   Four zones account for 97.3% of them in 2017:

     Central Park            106,138
     Bloomingdale             36,185
     Upper East Side North     27,957
     Yorkville West             7,598

   The remaining 49 Yellow Zone zones contribute 4,891 trips
   between them, about a hundred each, which against 11.7 million
   is 0.04% and indistinguishable from GPS error.

   Sorting Yellow Zone centroids by latitude puts five of the six
   busiest among the eight northernmost, against the edge of the
   territory where green taxis could hail.

   So this is a boundary drawn at street resolution being
   recorded at zone resolution. Central Park is the clearest
   case: one zone spanning roughly fifty blocks, with the hail
   boundary running through the middle of it. A pickup at the top
   of the park is permitted and a pickup at the bottom is not,
   and both carry the same zone code.

   The fit to latitude is imperfect. Manhattan Valley and Upper
   West Side North are also among the northernmost and contribute
   almost nothing. That is expected: the boundary follows
   different streets east and west of the park, which zone
   centroids cannot resolve and this data cannot settle.

   CONSEQUENCE

   The 1.6% is concentrated at the northern edge rather than
   scattered through Midtown, so it is a boundary artefact and
   not a sign that zone codes are unreliable. Zone-level analysis
   in questions 7, 8 and 10 stands.

   "Yellow Zone pickup" in this project means boundary-adjacent.
   It does not mean Midtown, and it does not mean a violation.

   -------------------------------------------------------------
   PICKUPS AGAINST DROPOFFS: THE TRADE CHANGED PURPOSE

   Green taxis may not collect a passenger in the Yellow Zone.
   They may deliver one there, and overwhelmingly they did.

     yr    % pickups yellow   % dropoffs yellow
     2017        1.57               17.50
     2018        1.72               17.85
     2019        2.09               17.84
     2020        2.99               18.49

   An eleven-to-one asymmetry: this was a one-way service into
   Manhattan.

   The Manhattan-bound share barely moves while volume falls
   48.5%. In absolute terms trips ending in the Yellow Zone fell
   47.5% against 48.5% overall. Read on its own, that says
   nothing changed about where green taxis go.

   It is exactly wrong, and the breakdown shows why.

   Share of trips bound for the Yellow Zone, by pickup band:

     band            2017    2019
     0 to 4 km       22.4%   24.0%
     4 to 8 km        7.6%    8.8%
     8 to 12 km       4.3%    7.1%
     12 to 18 km      1.5%    5.4%
     18 km plus       3.8%    9.1%

   The rate falls with distance, which is intuitive: the closer
   you start, the likelier you are going there. But it rose in
   every band between 2017 and 2019, and rose most in the outer
   ones. The 12 to 18 kilometre band more than tripled.

   TWO OPPOSING EFFECTS, NEARLY CANCELLING

   The trip mix moved outward, toward bands with low
   Manhattan-bound rates, which pulls the aggregate down about
   1.4 points. Within every band the rate rose, which pushes it
   up about 1.7 points. Net movement, 0.3 points.

   The most inert number in the analysis was under the most
   pressure.

   What it means: as green taxis lost local short-hop work, what
   survived in the outer boroughs was disproportionately the
   journey into Manhattan. The trade did not only shrink outward,
   it changed purpose. Far-out green taxis in 2019 were three to
   four times likelier to be carrying someone into the core than
   the same zones' taxis in 2017.

   DIRECTION OF TRAVEL FLIPPED IN 2018

   Mean distance from the core, pickup against dropoff:

     2017   3.79   3.94    dropoffs further out
     2018   4.30   4.30    even
     2019   4.59   4.52    pickups further out
     2020   4.95   4.84

   On balance green taxis carried people outward in 2017 and
   inward by 2019.
   ============================================================= */
