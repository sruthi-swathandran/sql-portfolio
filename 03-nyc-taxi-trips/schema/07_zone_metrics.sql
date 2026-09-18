/* =============================================================
   NYC Green Taxi Trips - Zone Metrics
   MySQL 8.0.40

   Run after 06_indexes.sql.

   WHAT THIS IS FOR
   ----------------
   Questions 5, 7, 8 and 10 all need geometry-derived properties
   of a zone: how far it sits from the Manhattan core, whether it
   is an airport, which zones it touches.

   Computing those inside a query against 28 million trips means
   28 million spatial calculations. Computing them once against
   260 zones means 260. The trip table then joins to a small
   indexed lookup.

   This is the same move that took the median from 1,146 seconds
   to 106 in question 2: reduce the data to the distinct values
   the question needs, compute on those, then join back.

   WHY DISTANCE TO THE YELLOW ZONE
   -------------------------------
   The TLC divides the city into a Yellow Zone of 55 Manhattan
   zones, 205 Boro Zones, 2 airports and Newark.

   Green taxis exist because of that division. They were licensed
   in 2013 to street-hail only in the Boro Zones and in the 14
   Manhattan zones above 96th Street. Picking up in the Yellow
   Zone was never permitted.

   So the core is not a landmark somebody chose. It is the
   regulatory boundary the whole trade is defined against, and
   distance from it is the natural axis for asking where the
   business went.

   Measuring from a point instead would be worse. Manhattan is
   thirteen miles long and two wide, so distance from Times
   Square would call a zone at the northern tip of the Bronx
   remote when it sits a mile from Inwood.

   WHY CENTROIDS AND NOT BOUNDARIES
   --------------------------------
   The honest measure is the shortest distance between two
   polygons. MySQL 8.0.40 supports ST_Distance on geographic
   SRIDs for point pairs; support for polygon pairs is less
   certain and would need testing before relying on it.

   Centroid to centroid is a well-defined approximation that
   overstates by roughly half the width of each zone. Zones here
   are small, so the error is small, and it is constant across
   years, which is what matters for a question about change.
   ============================================================= */

USE nyc_taxi;

DROP TABLE IF EXISTS zone_metrics;

CREATE TABLE zone_metrics (
    location_id       SMALLINT UNSIGNED NOT NULL,
    borough           VARCHAR(20)       NOT NULL,
    service_zone      VARCHAR(12)       NOT NULL,
    is_airport        TINYINT           NOT NULL,
    km_to_yellow_zone DECIMAL(6,2)      NULL,

    PRIMARY KEY (location_id),
    KEY ix_band (km_to_yellow_zone)
) ENGINE = InnoDB;

/* Populated for the 260 zones that have geometry. The five
   without one (57, 104, 105, 264, 265) are absent, so every
   join from trips to this table is a LEFT JOIN and the
   unmatched trips are counted rather than dropped. */

INSERT INTO zone_metrics (location_id, borough, service_zone, is_airport, km_to_yellow_zone)
SELECT z.location_id,
       z.borough,
       z.service_zone,
       (z.service_zone IN ('Airports', 'EWR')) AS is_airport,
       ROUND(MIN(ST_Distance(g.centroid, y.centroid)) / 1000, 2) AS km_to_yellow_zone
FROM taxi_zones   z
JOIN zone_geometry g ON g.location_id = z.location_id
CROSS JOIN (
    SELECT zg.centroid
    FROM zone_geometry zg
    JOIN taxi_zones    tz ON tz.location_id = zg.location_id
    WHERE tz.borough      = 'Manhattan'
      AND tz.service_zone = 'Yellow Zone'
) AS y
GROUP BY z.location_id, z.borough, z.service_zone;

/* 260 zones against 55 Yellow Zone centroids is 14,300 distance
   calculations, which is why this is done here once rather than
   inside a query over 28 million trips. */


/* --- Check: did it populate, and is the scale credible? -----
   Expected: 260 rows.

   Yellow Zone zones should show 0.00, since each one's nearest
   Yellow Zone centroid is its own.

   Staten Island should be the most remote borough. Newark
   Airport should be further from the Manhattan core than either
   JFK or LaGuardia.
   ------------------------------------------------------------- */

SELECT COUNT(*)                       AS zones,
       MIN(km_to_yellow_zone)         AS nearest,
       MAX(km_to_yellow_zone)         AS furthest,
       SUM(km_to_yellow_zone IS NULL) AS unmeasured
FROM zone_metrics;

SELECT borough,
       service_zone,
       COUNT(*)                            AS zones,
       ROUND(MIN(km_to_yellow_zone), 1)    AS nearest,
       ROUND(AVG(km_to_yellow_zone), 1)    AS mean,
       ROUND(MAX(km_to_yellow_zone), 1)    AS furthest
FROM zone_metrics
GROUP BY borough, service_zone
ORDER BY mean;

/* --- Check: named zones, so the numbers can be sanity-tested
   against somewhere real -------------------------------------- */

SELECT m.location_id, z.zone_name, m.borough, m.service_zone,
       m.km_to_yellow_zone
FROM zone_metrics m
JOIN taxi_zones   z ON z.location_id = m.location_id
WHERE m.location_id IN (
    132,  -- JFK Airport
    138,  -- LaGuardia Airport
      1,  -- Newark Airport
    230,  -- Times Sq / Theatre District, inside the Yellow Zone
     43,  -- Central Park
    244,  -- Washington Heights, upper Manhattan
      3,  -- Allerton / Pelham Gardens, Bronx
      6   -- Arrochar / Fort Wadsworth, Staten Island
)
ORDER BY m.km_to_yellow_zone;

/* --- The distribution, which decides the bands ---------------
   Bands are chosen after seeing where zones actually fall, not
   before. Round numbers that split the data badly are worse than
   awkward ones that split it well.
   ------------------------------------------------------------- */

SELECT FLOOR(km_to_yellow_zone / 2) * 2 AS km_band_start,
       COUNT(*)                         AS zones
FROM zone_metrics
GROUP BY km_band_start
ORDER BY km_band_start;


/* =============================================================
   ZONE PAIR DISTANCES
   =============================================================

   Question 6 tests every reported trip distance against the
   straight line between its two zones. Doing that inside a query
   over 28 million trips means 28 million geodesic calculations.

   There are only 260 zones, so there are only 67,600 possible
   pairs. Computing those once and joining is the same move as
   the bucketed median in question 2 and the zone metrics above.

   Ordered pairs rather than unordered, both directions stored.
   The distance is symmetric so half the rows are redundant, but
   67,600 rows costs nothing and a join on (pu_location_id,
   do_location_id) needs no CASE expression to normalise the
   order. Clarity at the call site is worth 33,800 duplicate
   rows.

   Same-zone pairs are included and have a distance of zero,
   which is correct and is exactly why question 6 has to exclude
   them: a trip within one zone has no measurable straight line.
   ============================================================= */

DROP TABLE IF EXISTS zone_pair_distance;

CREATE TABLE zone_pair_distance (
    from_id  SMALLINT UNSIGNED NOT NULL,
    to_id    SMALLINT UNSIGNED NOT NULL,
    km       DECIMAL(7,3)      NOT NULL,

    PRIMARY KEY (from_id, to_id)
) ENGINE = InnoDB;

INSERT INTO zone_pair_distance (from_id, to_id, km)
SELECT a.location_id,
       b.location_id,
       ROUND(ST_Distance(a.centroid, b.centroid) / 1000, 3)
FROM zone_geometry a
CROSS JOIN zone_geometry b;

/* --- Checks -------------------------------------------------
   Expected: 67,600 rows, being 260 squared.
   260 of them at exactly zero, the same-zone pairs.
   The maximum should be around 50 km, roughly Staten Island to
   the far edge of Queens.
   ------------------------------------------------------------- */

SELECT COUNT(*)          AS pairs,
       SUM(km = 0)       AS same_zone_pairs,
       ROUND(MAX(km), 1) AS furthest_km,
       ROUND(AVG(km), 1) AS mean_km
FROM zone_pair_distance;

/* --- Check: symmetry ---------------------------------------
   ST_Distance(a,b) must equal ST_Distance(b,a). If any pair
   disagrees, something is wrong with the geometry rather than
   with the arithmetic.

   Expected: 0 rows
   ------------------------------------------------------------- */

SELECT COUNT(*) AS asymmetric_pairs
FROM zone_pair_distance p
JOIN zone_pair_distance q ON q.from_id = p.to_id
                         AND q.to_id   = p.from_id
WHERE p.km <> q.km;

/* --- Check: a known pair -----------------------------------
   JFK (132) to Times Square (230).

   Expected: 20 to 21 km.

   The spatial support test in 03_load_reference.sql measured JFK
   to the Empire State Building at 21.2 km against an independent
   calculation. Times Square sits a short distance from there, so
   a similar figure here means the pair table agrees with a
   number already verified by other means.
   ------------------------------------------------------------- */

SELECT km AS jfk_to_times_sq_km
FROM zone_pair_distance
WHERE from_id = 132 AND to_id = 230;


/* =============================================================
   ZONE ADJACENCY
   =============================================================

   Which zones physically border one another. Question 7 uses it
   to separate short local hops from journeys that cross the city.

   WHY MBRIntersects COMES FIRST
   -----------------------------
   Two polygons can only share a boundary if their bounding boxes
   overlap. MBRIntersects tests boxes rather than outlines, costs
   almost nothing, and can use the spatial index.

   Measured: 67,600 possible pairs reduce to 840 candidates, so
   the expensive predicate runs 840 times. Some of these zones
   carry thousands of vertices, so that ratio is the difference
   between seconds and something much worse.

   WHY ST_Intersects AND NOT ST_Touches
   ------------------------------------
   ST_Touches is the textbook answer. It requires boundaries to
   meet while interiors stay disjoint, which is exactly what
   adjacency means.

   On this shapefile it returns 272 pairs. ST_Intersects returns
   646.

   A planar subdivision of 260 regions should have roughly 650 to
   780 adjacent pairs. 646 is in range. 272 is less than half of
   it.

   The gap is digitising error. Where two boundaries overlap by a
   few centimetres, the interiors technically intersect and
   ST_Touches returns false, even though the zones plainly abut.
   374 pairs fail on that technicality.

   Since the zones are meant to partition the city, no genuine
   overlap should exist, so any intersection is either a shared
   boundary or an artefact of one. ST_Intersects captures both
   and ST_Touches captures neither reliably.

   The strict function gives the wrong answer on real data. Worth
   knowing before trusting a spatial predicate that looks correct
   in the documentation.

   BOTH DIRECTIONS STORED
   ----------------------
   Same reasoning as zone_pair_distance: 1,292 rows costs nothing
   and removes the need to normalise pair order at every join.
   ============================================================= */

DROP TABLE IF EXISTS zone_adjacency;

CREATE TABLE zone_adjacency (
    from_id SMALLINT UNSIGNED NOT NULL,
    to_id   SMALLINT UNSIGNED NOT NULL,

    PRIMARY KEY (from_id, to_id)
) ENGINE = InnoDB;

INSERT INTO zone_adjacency (from_id, to_id)
SELECT a.location_id, b.location_id
FROM zone_geometry a
JOIN zone_geometry b
  ON a.location_id <> b.location_id
 AND MBRIntersects(a.geom, b.geom)
WHERE ST_Intersects(a.geom, b.geom);

/* --- Checks -------------------------------------------------
   Expected: 1,292 rows, being 646 pairs stored twice.

   Every zone should have at least one neighbour except islands.
   Zones with none are worth looking at by name: a genuine island
   is correct, anything else is a geometry problem.
   ------------------------------------------------------------- */

SELECT COUNT(*)                   AS directed_edges,
       COUNT(DISTINCT from_id)    AS zones_with_a_neighbour
FROM zone_adjacency;

SELECT z.location_id, z.zone_name, z.borough
FROM taxi_zones   z
JOIN zone_geometry g ON g.location_id = z.location_id
LEFT JOIN zone_adjacency a ON a.from_id = z.location_id
WHERE a.from_id IS NULL
ORDER BY z.location_id;

/* --- Neighbour counts --------------------------------------
   A zone in a dense grid should border four to eight others.
   Anything bordering twenty is probably a large park, a body of
   water, or a digitising problem.
   ------------------------------------------------------------- */

SELECT neighbours, COUNT(*) AS zones
FROM (
    SELECT from_id, COUNT(*) AS neighbours
    FROM zone_adjacency
    GROUP BY from_id
) n
GROUP BY neighbours
ORDER BY neighbours;
