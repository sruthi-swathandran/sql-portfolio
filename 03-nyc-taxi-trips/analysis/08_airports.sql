/* =============================================================
   Question 8: did the airport share change?

   Airport work is the most defensible business a taxi has. The
   trips are long, the fares are large, the demand is not
   spontaneous, and a passenger with luggage and a flight to
   catch behaves differently from one deciding whether to walk.

   Questions 5 and 7 found the trade retreating outward and
   abandoning local travel while keeping the journey into the
   city. If that is a trade falling back on what it can defend,
   airport share should rise.

   THREE AIRPORTS, THREE DIFFERENT RELATIONSHIPS
   ---------------------------------------------
     132  JFK        Queens, 18.2 km from the core
     138  LaGuardia  Queens, 4.7 km
       1  Newark     New Jersey, 12.7 km, and outside the city

   Newark matters because a green taxi taking a fare there leaves
   the state and cannot legally pick up on the return. That makes
   it the least attractive of the three and a useful control: if
   airport share rises everywhere including Newark, it is demand.
   If it rises at JFK and LaGuardia but not Newark, it is drivers
   choosing work they can build a day around.
   ============================================================= */

USE nyc_taxi;

/* -------------------------------------------------------------
   1. Airport trips by year and direction
   -------------------------------------------------------------
   Pickups and dropoffs counted separately, because green taxis
   face different rules in each direction and the two answer
   different questions. A dropoff is a passenger catching a
   flight. A pickup is a driver competing at a rank.
   ------------------------------------------------------------- */

SELECT YEAR(t.pickup_datetime) AS yr,
       SUM(t.pu_location_id = 132) AS pickup_jfk,
       SUM(t.do_location_id = 132) AS dropoff_jfk,
       SUM(t.pu_location_id = 138) AS pickup_lga,
       SUM(t.do_location_id = 138) AS dropoff_lga,
       SUM(t.pu_location_id =   1) AS pickup_ewr,
       SUM(t.do_location_id =   1) AS dropoff_ewr,
       COUNT(*)                    AS all_trips
FROM trips t
WHERE t.pickup_datetime >= '2017-01-01'
  AND t.pickup_datetime <  '2021-01-01'
GROUP BY yr
ORDER BY yr;


/* -------------------------------------------------------------
   2. The same thing as a share, which is the question
   -------------------------------------------------------------
   Absolute airport trips will fall, because everything fell.
   Whether they fell by less than the rest is what matters.
   ------------------------------------------------------------- */

SELECT YEAR(t.pickup_datetime) AS yr,
       ROUND(100 * SUM(t.pu_location_id IN (1,132,138)
                    OR t.do_location_id IN (1,132,138)) / COUNT(*), 3) AS pct_touching_an_airport,
       ROUND(100 * SUM(t.do_location_id = 132) / COUNT(*), 3)          AS pct_to_jfk,
       ROUND(100 * SUM(t.do_location_id = 138) / COUNT(*), 3)          AS pct_to_lga,
       ROUND(100 * SUM(t.do_location_id =   1) / COUNT(*), 3)          AS pct_to_ewr
FROM trips t
WHERE t.pickup_datetime >= '2017-01-01'
  AND t.pickup_datetime <  '2021-01-01'
GROUP BY yr
ORDER BY yr;


/* -------------------------------------------------------------
   3. Change against the baseline
   -------------------------------------------------------------
   Total volume fell 48.5% from 2017 to 2019. Any airport flow
   that fell by less than that gained share; anything that fell
   by more lost it.
   ------------------------------------------------------------- */

WITH yearly AS (
    SELECT YEAR(t.pickup_datetime) AS yr,
           SUM(t.do_location_id = 132) AS to_jfk,
           SUM(t.do_location_id = 138) AS to_lga,
           SUM(t.do_location_id =   1) AS to_ewr,
           SUM(t.pu_location_id = 132) AS from_jfk,
           SUM(t.pu_location_id = 138) AS from_lga,
           COUNT(*)                    AS all_trips
    FROM trips t
    WHERE t.pickup_datetime >= '2017-01-01'
      AND t.pickup_datetime <  '2020-01-01'
    GROUP BY yr
)
SELECT 'to JFK'      AS flow,
       MAX(CASE WHEN yr=2017 THEN to_jfk END) AS y2017,
       MAX(CASE WHEN yr=2019 THEN to_jfk END) AS y2019,
       ROUND(100*(MAX(CASE WHEN yr=2019 THEN to_jfk END)-MAX(CASE WHEN yr=2017 THEN to_jfk END))
              /MAX(CASE WHEN yr=2017 THEN to_jfk END),1) AS pct_change FROM yearly
UNION ALL
SELECT 'to LaGuardia',
       MAX(CASE WHEN yr=2017 THEN to_lga END), MAX(CASE WHEN yr=2019 THEN to_lga END),
       ROUND(100*(MAX(CASE WHEN yr=2019 THEN to_lga END)-MAX(CASE WHEN yr=2017 THEN to_lga END))
              /MAX(CASE WHEN yr=2017 THEN to_lga END),1) FROM yearly
UNION ALL
SELECT 'to Newark',
       MAX(CASE WHEN yr=2017 THEN to_ewr END), MAX(CASE WHEN yr=2019 THEN to_ewr END),
       ROUND(100*(MAX(CASE WHEN yr=2019 THEN to_ewr END)-MAX(CASE WHEN yr=2017 THEN to_ewr END))
              /MAX(CASE WHEN yr=2017 THEN to_ewr END),1) FROM yearly
UNION ALL
SELECT 'from JFK',
       MAX(CASE WHEN yr=2017 THEN from_jfk END), MAX(CASE WHEN yr=2019 THEN from_jfk END),
       ROUND(100*(MAX(CASE WHEN yr=2019 THEN from_jfk END)-MAX(CASE WHEN yr=2017 THEN from_jfk END))
              /MAX(CASE WHEN yr=2017 THEN from_jfk END),1) FROM yearly
UNION ALL
SELECT 'from LaGuardia',
       MAX(CASE WHEN yr=2017 THEN from_lga END), MAX(CASE WHEN yr=2019 THEN from_lga END),
       ROUND(100*(MAX(CASE WHEN yr=2019 THEN from_lga END)-MAX(CASE WHEN yr=2017 THEN from_lga END))
              /MAX(CASE WHEN yr=2017 THEN from_lga END),1) FROM yearly
UNION ALL
SELECT 'all trips',
       MAX(CASE WHEN yr=2017 THEN all_trips END), MAX(CASE WHEN yr=2019 THEN all_trips END),
       ROUND(100*(MAX(CASE WHEN yr=2019 THEN all_trips END)-MAX(CASE WHEN yr=2017 THEN all_trips END))
              /MAX(CASE WHEN yr=2017 THEN all_trips END),1) FROM yearly;


/* -------------------------------------------------------------
   4. Do the zone codes and the rate codes agree?
   -------------------------------------------------------------
   Rate code 2 is the JFK flat fare and rate code 3 is Newark.
   Those are recorded by the meter. The location ids come from
   GPS. Two independent sources describing the same trips.

   Where they disagree, one of them is wrong, and knowing which
   flows carry that disagreement matters for every airport number
   above.

   A perfect match is not expected. The JFK flat fare applies
   only between JFK and Manhattan, so a JFK trip to Brooklyn is
   correctly rate code 1.
   ------------------------------------------------------------- */

SELECT t.ratecode_id,
       SUM(t.pu_location_id = 132 OR t.do_location_id = 132) AS touches_jfk_zone,
       SUM(t.pu_location_id =   1 OR t.do_location_id =   1) AS touches_ewr_zone,
       COUNT(*)                                              AS trips
FROM trips t
WHERE t.pickup_datetime >= '2017-01-01'
  AND t.pickup_datetime <  '2021-01-01'
  AND t.ratecode_id IN (2, 3)
GROUP BY t.ratecode_id
ORDER BY t.ratecode_id;


/* =============================================================
   FINDINGS

   THE HYPOTHESIS FAILED

   Questions 5 and 7 both suggested a trade falling back on the
   work it could defend. Airport work is the most defensible a
   taxi has: long trips, large fares, planned demand, passengers
   with luggage and a deadline.

   Share of trips touching an airport:

     2017   1.793%
     2018   1.694%
     2019   1.727%
     2020   1.015%

   It did not rise. Airport work fell at roughly the rate
   everything else did.

     flow              2017      2019    change
     to JFK          71,628    30,238    -57.8%
     to LaGuardia   133,254    71,309    -46.5%
     to Newark        4,425     1,906    -56.9%
     from JFK         2,076     1,029    -50.4%
     from LaGuardia   1,845     1,011    -45.2%
     all trips   11,740,514 6,043,879    -48.5%

   AIRPORTS ARE ONE-WAY, MORE SO THAN MANHATTAN

   71,628 dropoffs at JFK in 2017 against 2,076 pickups, a ratio
   of 34 to 1. Airport ranks belong to yellow cabs and permitted
   for-hire vehicles. Green taxis carried people to flights and
   returned empty.

   Question 5 found an 11 to 1 asymmetry into the Yellow Zone.
   This is three times starker.

   JFK AND LAGUARDIA DIVERGE, AND THE REASON IS NOT WHERE THEY
   ARE

   JFK lost eleven points more than LaGuardia, which sits oddly
   beside question 5 where the outer zones held up best. JFK is
   18.2 km from the core and LaGuardia 4.7, so JFK should have
   done better. It did much worse.

   The first hypothesis was origin mix: perhaps LaGuardia draws
   from the outer bands that survived. It does not. Both airports
   draw mostly from the inner bands, and LaGuardia more so, 58.2%
   of its traffic starting within 4 km against JFK's 54.5%.

   It is within-band rates, and one cell carries almost all of
   it:

     pickup band     to JFK    to LaGuardia
     0 to 4 km       -64.6%       -61.0%
     4 to 8 km       -62.3%       -22.8%
     8 to 12 km      -41.4%       -39.1%
     12 km plus      -41.4%       -38.3%

   Every band behaves alike for the two airports except 4 to 8
   km. Applying JFK's within-band rates to LaGuardia's own mix
   gives -61.9% against the -46.4% observed, so the entire gap
   lives in that one cell.

   THE BEST-PERFORMING FLOW IN THE PROJECT

   -22.8% against a baseline of -48.5%. Nothing else measured
   here held up so well.

   The 4 to 8 km ring in Queens is Astoria, Long Island City,
   Jackson Heights and Woodside. LaGuardia sits at 4.7 km, in the
   middle of it. So this is a short local hop to a nearby
   airport, and it survived while question 7 was recording local
   travel collapsing everywhere else.

   The airport run is the local trip that survived, but only
   where the airport is local. JFK from those same zones is a
   long expensive journey and it went the way of the rest.

   WHAT THE DATA SUPPORTS

   Proximity to the airport, not the existence of an airport,
   protected the flow. Why that should be is not established
   here. The obvious candidates, a short cheap fare being
   competitive where a long one is not, are plausible and
   untested.

   NEWARK AS A CONTROL

   Newark was included because a green taxi taking a fare there
   leaves the state and cannot legally pick up on the return,
   making it the least attractive of the three. It fell 56.9%,
   close to JFK and worse than the baseline, which is consistent
   with distance mattering more than airport status.

   It is also tiny, 4,425 trips in 2017 against LaGuardia's
   133,254, so it carries little weight on its own.
   ============================================================= */
