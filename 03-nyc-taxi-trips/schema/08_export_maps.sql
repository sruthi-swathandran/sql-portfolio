/* =============================================================
   NYC Green Taxi Trips - Map Export
   MySQL 8.0.40

   Writes GeoJSON from the database, with the shading already
   computed. GitHub renders a .geojson file as an interactive map
   in its file viewer, so the output of this script is directly
   viewable in the repository without any tooling.

   WHY THE COLOUR IS COMPUTED IN SQL
   ---------------------------------
   GeoJSON has no styling of its own, but GitHub's renderer reads
   the simplestyle convention: properties named fill, stroke,
   fill-opacity and stroke-width on a feature control how it is
   drawn.

   So a CASE expression over the percentage change becomes the
   map's shading. No separate styling step, no JavaScript, and
   the thresholds that define the colour scale sit in the same
   file as the query that produces the numbers. Anyone reviewing
   the map can see exactly what -60% had to mean to be red.

   FULL RESOLUTION
   ---------------
   The output is about 4 MB, under GitHub's rendering limit.
   Simplifying the polygons to a 10 metre tolerance would cut it
   to 0.6 MB and change zone areas by 0.0025%, which was measured
   when the shapefile was loaded.

   It is not done, because MySQL has no ST_Simplify and because
   the file loads acceptably as it is. Worth knowing as an option
   if the map ever feels slow.

   Either way the analysis runs on the full geometry. A display
   decision never touches the numbers.
   ============================================================= */

USE nyc_taxi;

/* JSON_ARRAYAGG builds the whole document in one value, so the
   result has to fit inside max_allowed_packet. At roughly 4 MB
   against a 64 MB default this is comfortable, but a larger
   export would need the limit raised. */

SET SESSION group_concat_max_len = 50000000;


/* =============================================================
   MAP 1: zone change 2017 to 2019
   =============================================================

   The headline map. Zones shaded by how their pickup volume
   changed across the two clean pre-pandemic years.

   COLOUR SCALE
   ------------
   Diverging, centred on no change, because the quantity is a
   change and has a meaningful zero. A sequential scale would
   imply that a 5% fall and a 5% rise differ only in degree.

     growth over 50%      dark green
     growth 10 to 50%     green
     within 10% either way pale
     fall 10 to 40%       orange
     fall 40 to 60%       dark orange
     fall over 60%        red

   Zones under 5,000 trips in 2017 are grey rather than coloured.
   A zone going from 40 trips to 120 is a 200% rise and would
   otherwise be the brightest thing on the map. Grey says "not
   enough data" instead of shouting a meaningless number.
   ============================================================= */

WITH yearly AS (
    SELECT pu_location_id AS location_id,
           SUM(pickup_datetime <  '2018-01-01') AS trips_2017,
           SUM(pickup_datetime >= '2019-01-01') AS trips_2019
    FROM trips
    WHERE pickup_datetime >= '2017-01-01'
      AND pickup_datetime <  '2020-01-01'
    GROUP BY pu_location_id
),
features AS (
    SELECT JSON_OBJECT(
             'type', 'Feature',
             'properties', JSON_OBJECT(
                 'location_id', z.location_id,
                 'zone',        z.zone_name,
                 'borough',     z.borough,
                 'km_to_core',  m.km_to_yellow_zone,
                 'trips_2017',  COALESCE(y.trips_2017, 0),
                 'trips_2019',  COALESCE(y.trips_2019, 0),
                 'pct_change',
                     CASE WHEN COALESCE(y.trips_2017, 0) >= 5000
                          THEN ROUND(100.0 * (y.trips_2019 - y.trips_2017) / y.trips_2017, 1)
                     END,
                 'fill',
                     CASE
                         WHEN COALESCE(y.trips_2017, 0) < 5000                          THEN '#cccccc'
                         WHEN 100.0*(y.trips_2019-y.trips_2017)/y.trips_2017 >  50       THEN '#1a9850'
                         WHEN 100.0*(y.trips_2019-y.trips_2017)/y.trips_2017 >  10       THEN '#a6d96a'
                         WHEN 100.0*(y.trips_2019-y.trips_2017)/y.trips_2017 > -10       THEN '#ffffbf'
                         WHEN 100.0*(y.trips_2019-y.trips_2017)/y.trips_2017 > -40       THEN '#fdae61'
                         WHEN 100.0*(y.trips_2019-y.trips_2017)/y.trips_2017 > -60       THEN '#f46d43'
                         ELSE                                                                 '#d73027'
                     END,
                 'fill-opacity', 0.75,
                 'stroke',       '#666666',
                 'stroke-width', 0.5
             ),
             'geometry', CAST(ST_AsGeoJSON(g.geom) AS JSON)
           ) AS feature
    FROM zone_geometry g
    JOIN taxi_zones    z ON z.location_id = g.location_id
    LEFT JOIN zone_metrics m ON m.location_id = g.location_id
    LEFT JOIN yearly       y ON y.location_id = g.location_id
)
SELECT JSON_OBJECT('type', 'FeatureCollection',
                   'features', JSON_ARRAYAGG(feature)) AS geojson
FROM features;

/* Save the single value this returns as
   maps/zone_change_2017_2019.geojson

   Two ways, depending on what @@secure_file_priv allows.

   If it is a path, append to the query above:

       INTO OUTFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/zone_change_2017_2019.geojson'
       FIELDS TERMINATED BY '' ENCLOSED BY '' ESCAPED BY ''
       LINES TERMINATED BY ''

   The three FIELDS clauses matter. Without them MySQL escapes
   quotes and backslashes for its own reload format and produces
   invalid JSON.

   If it is NULL, right-click the result cell in Workbench,
   choose Open Value in Viewer, and save from there. */


/* =============================================================
   MAP 2: distance bands from the Manhattan core
   =============================================================

   The geography question 5 is built on, drawn rather than
   described. Reading "the 8 to 12 km band" in a table requires
   trusting that the band means something; seeing it on a map
   shows immediately that it is a ring rather than a scatter.

   Sequential scale here, not diverging, because distance has no
   meaningful centre.
   ============================================================= */

WITH features AS (
    SELECT JSON_OBJECT(
             'type', 'Feature',
             'properties', JSON_OBJECT(
                 'location_id',  z.location_id,
                 'zone',         z.zone_name,
                 'borough',      z.borough,
                 'service_zone', z.service_zone,
                 'km_to_core',   m.km_to_yellow_zone,
                 'band',
                     CASE
                         WHEN z.service_zone = 'Yellow Zone' THEN 'Yellow Zone'
                         WHEN m.km_to_yellow_zone <  4       THEN '0 to 4 km'
                         WHEN m.km_to_yellow_zone <  8       THEN '4 to 8 km'
                         WHEN m.km_to_yellow_zone < 12       THEN '8 to 12 km'
                         WHEN m.km_to_yellow_zone < 18       THEN '12 to 18 km'
                         ELSE                                     '18 km plus'
                     END,
                 'fill',
                     CASE
                         WHEN z.service_zone = 'Yellow Zone' THEN '#54278f'
                         WHEN m.km_to_yellow_zone <  4       THEN '#756bb1'
                         WHEN m.km_to_yellow_zone <  8       THEN '#9e9ac8'
                         WHEN m.km_to_yellow_zone < 12       THEN '#bcbddc'
                         WHEN m.km_to_yellow_zone < 18       THEN '#dadaeb'
                         ELSE                                     '#f2f0f7'
                     END,
                 'fill-opacity', 0.8,
                 'stroke',       '#666666',
                 'stroke-width', 0.5
             ),
             'geometry', CAST(ST_AsGeoJSON(g.geom) AS JSON)
           ) AS feature
    FROM zone_geometry g
    JOIN taxi_zones    z ON z.location_id = g.location_id
    JOIN zone_metrics  m ON m.location_id = g.location_id
)
SELECT JSON_OBJECT('type', 'FeatureCollection',
                   'features', JSON_ARRAYAGG(feature)) AS geojson
FROM features;

/* Save as maps/zone_distance_bands.geojson */
