/* =============================================================
   NYC Green Taxi Trips - Reference Data
   MySQL 8.0.40

   Loads the three small tables: zone lookup, zone geometry, and
   the fiscal calendar. The 28 million trip rows come next, in
   04_load_trips.sql.

   Run 02_build_zone_geometry.py first. It produces
   data/zone_geometry.tsv, which this script reads.

   PREREQUISITE
   ------------
   LOAD DATA LOCAL INFILE needs enabling in two places, the
   server and the client. See SETUP.md in the repository root.

   PATHS
   -----
   Written for a clone at D:/Projects/sql-portfolio. Adjust if
   yours differs. Forward slashes, even on Windows: a backslash
   inside a MySQL string literal is an escape character, so
   D:\Projects would try to interpret \P.

   LINE ENDINGS
   ------------
   The three supplied files are CRLF. zone_geometry.tsv is LF,
   because the Python script writes it that way. Each LOAD DATA
   below declares what its own file uses.

   This is worth being careful about. Declare '\n' against a CRLF
   file and MySQL treats the carriage return as data, so the last
   column of every row gains an invisible trailing character.
   A VARCHAR silently stores it and comparisons against it fail
   for no visible reason. A numeric column produces a truncation
   warning that is easy to scroll past.
   ============================================================= */

USE nyc_taxi;

/* -------------------------------------------------------------
   1. TAXI ZONES
   -------------------------------------------------------------
   265 rows. Quoted fields, CRLF, one header line.

   Expected after load: 265 rows, 7 distinct boroughs.
   ------------------------------------------------------------- */

TRUNCATE TABLE taxi_zones;

LOAD DATA LOCAL INFILE 'D:/Projects/sql-portfolio/03-nyc-taxi-trips/data/taxi_zones.csv'
INTO TABLE taxi_zones
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(location_id, borough, zone_name, service_zone);

SELECT COUNT(*)                  AS zones,
       COUNT(DISTINCT borough)   AS boroughs,
       MIN(location_id)          AS min_id,
       MAX(location_id)          AS max_id
FROM taxi_zones;


/* -------------------------------------------------------------
   2. ZONE GEOMETRY
   -------------------------------------------------------------
   260 rows from zone_geometry.tsv. Tab separated because the WKT
   is full of commas and spaces. No header, no quoting, LF.

   AXIS ORDER
   ----------
   'axis-order=long-lat' is not optional. EPSG:4326 defines
   latitude first and MySQL follows that when parsing WKT. The
   shapefile writes longitude first.

   Omit it and every zone lands near latitude -74, in the
   Southern Ocean. Nothing raises an error, and ST_Touches,
   ST_Within and ST_Intersects all keep returning correct answers,
   because swapping both operands consistently preserves how
   shapes relate to one another. The check below is therefore an
   absolute measurement, which is the only kind that can detect
   the fault.
   ------------------------------------------------------------- */

TRUNCATE TABLE zone_geometry;

LOAD DATA LOCAL INFILE 'D:/Projects/sql-portfolio/03-nyc-taxi-trips/data/zone_geometry.tsv'
INTO TABLE zone_geometry
CHARACTER SET utf8mb4
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
(@location_id, @geom_wkt, @centroid_wkt)
SET location_id = @location_id,
    geom        = ST_GeomFromText(@geom_wkt,     4326, 'axis-order=long-lat'),
    centroid    = ST_GeomFromText(@centroid_wkt, 4326, 'axis-order=long-lat');

/* --- Check: did the geometry land in New York? ---------------
   Zone 230 is Times Square / Theatre District.

   Expected: longitude -73.9842, latitude 40.7598

   ST_Longitude and ST_Latitude, not ST_X and ST_Y.

   On a geographic SRID, ST_X and ST_Y return the first and
   second coordinate as the spatial reference system defines
   them, and EPSG:4326 defines latitude first. So ST_X on one of
   these points returns latitude. Labelling that column
   "longitude" produces output that looks like a failed load when
   nothing is wrong.

   ST_Longitude and ST_Latitude name what they return and are
   immune to the axis-order question entirely.
   ------------------------------------------------------------- */

SELECT location_id,
       ROUND(ST_Longitude(centroid), 4) AS longitude,
       ROUND(ST_Latitude(centroid), 4)  AS latitude
FROM zone_geometry
WHERE location_id = 230;

/* --- Check: is the scale right? -----------------------------
   Newark Airport (1) to Times Square (230).

   Expected: 17,724 metres

   The same pair with the axes swapped returns 21,286 metres.
   That is what makes this check work, and it only works because
   the expected value is written down in advance.

   Someone eyeballing the result would accept either number, since
   both are plausible for an airport to a city centre. Against a
   stated 17,724, a return of 21,286 is unambiguous.

   The difference between a check and a glance is whether you
   committed to the answer before you saw it.
   ------------------------------------------------------------- */

SELECT ROUND(ST_Distance(a.centroid, b.centroid)) AS metres_ewr_to_times_sq
FROM zone_geometry a
JOIN zone_geometry b ON b.location_id = 230
WHERE a.location_id = 1;

/* --- Check: which zones have no geometry? -------------------
   Expected: exactly 5 rows, ids 57, 104, 105, 264, 265.

   264 and 265 are the source's placeholders for an unrecorded
   location. 57, 104 and 105 are casualties of the shapefile
   labelling two same-named zone groups inconsistently, which
   02_build_zone_geometry.py documents.

   Every spatial query therefore covers 260 zones, not 265, and
   joins from taxi_zones to zone_geometry are LEFT JOINs.
   ------------------------------------------------------------- */

SELECT z.location_id, z.borough, z.zone_name
FROM taxi_zones z
LEFT JOIN zone_geometry g ON g.location_id = z.location_id
WHERE g.location_id IS NULL
ORDER BY z.location_id;


/* -------------------------------------------------------------
   3. FISCAL CALENDAR
   -------------------------------------------------------------
   1,456 rows. CRLF, one header line, and a UTF-8 byte order mark
   at the very start of the file which IGNORE 1 LINES discards
   along with the header.

   Loaded because it came with the data, not because the analysis
   depends on it. It covers 2017-02-05 to 2021-01-30, and the
   trips begin on 2017-01-01, so 1,231,326 real trips sit outside
   it. Day, month and year come from the trip's own timestamp
   throughout. This table is used only where a question is
   genuinely about fiscal periods, and then with a LEFT JOIN.
   ------------------------------------------------------------- */

TRUNCATE TABLE fiscal_calendar;

LOAD DATA LOCAL INFILE 'D:/Projects/sql-portfolio/03-nyc-taxi-trips/data/454_calendar.csv'
INTO TABLE fiscal_calendar
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(calendar_date, fiscal_year, fiscal_quarter, fiscal_month_number,
 fiscal_month_of_qtr, fiscal_week_of_year, day_of_week,
 fiscal_month_name, fiscal_month_year, fiscal_quarter_year,
 day_of_month_number, day_name);

/* --- Check: contiguous, and where does it start? -------------
   Expected: 1,456 rows, 2017-02-05 to 2021-01-30, and the row
   count equal to the number of days between those dates
   inclusive, which proves there are no gaps inside the range.
   ------------------------------------------------------------- */

SELECT COUNT(*)                                            AS rows_loaded,
       MIN(calendar_date)                                  AS first_date,
       MAX(calendar_date)                                  AS last_date,
       DATEDIFF(MAX(calendar_date), MIN(calendar_date)) + 1 AS days_in_range,
       COUNT(*) - (DATEDIFF(MAX(calendar_date), MIN(calendar_date)) + 1) AS gap
FROM fiscal_calendar;

/* --- Check: trailing carriage returns -----------------------
   If LINES TERMINATED BY were wrong, the last column of every
   row would end in \r. day_name is the last column.

   Expected: 0 rows
   ------------------------------------------------------------- */

SELECT COUNT(*) AS day_names_with_trailing_cr
FROM fiscal_calendar
WHERE day_name <> TRIM(day_name)
   OR day_name LIKE '%\r';
