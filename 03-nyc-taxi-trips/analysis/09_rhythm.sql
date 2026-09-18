/* =============================================================
   Question 9: did the daily and weekly rhythm change as volume
   collapsed, or did the shape hold and only the height drop?

   Every question so far has been about what was lost. This one
   is about whether what remained behaves like a smaller version
   of what was there, or like something different.

   THE TRAP, WHICH IS THE WHOLE DIFFICULTY
   ---------------------------------------
   Counting trips by hour across four years mixes a 48% decline
   with a repeating cycle. The decline is larger than any
   variation between hours, so the raw numbers would show 2017
   above 2019 at every hour of the day and say nothing at all.

   Every figure here is therefore a share of its own year. The
   question is the shape, not the height.

   This is the same correction as the like-for-like windows in
   the Airbnb project, where comparing a partial period against a
   full one changed the conclusion three separate times.
   ============================================================= */

USE nyc_taxi;

/* -------------------------------------------------------------
   1. Hour of day
   -------------------------------------------------------------
   Share of each year's trips starting in each hour.

   If green taxis lost spontaneous travel and kept planned
   travel, the peaks should change shape: commuting holds, late
   night and midday casual work goes.
   ------------------------------------------------------------- */

SELECT HOUR(pickup_datetime) AS hr,
       ROUND(100 * SUM(YEAR(pickup_datetime) = 2017)
                 / SUM(SUM(YEAR(pickup_datetime) = 2017)) OVER (), 2) AS pct_2017,
       ROUND(100 * SUM(YEAR(pickup_datetime) = 2018)
                 / SUM(SUM(YEAR(pickup_datetime) = 2018)) OVER (), 2) AS pct_2018,
       ROUND(100 * SUM(YEAR(pickup_datetime) = 2019)
                 / SUM(SUM(YEAR(pickup_datetime) = 2019)) OVER (), 2) AS pct_2019,
       ROUND(100 * SUM(YEAR(pickup_datetime) = 2020)
                 / SUM(SUM(YEAR(pickup_datetime) = 2020)) OVER (), 2) AS pct_2020
FROM trips
WHERE pickup_datetime >= '2017-01-01'
  AND pickup_datetime <  '2021-01-01'
GROUP BY hr
ORDER BY hr;

/* SUM(SUM(...)) OVER () is an aggregate of an aggregate: the
   inner SUM produces the count per hour, the window sums those
   across all hours to give the year total. It avoids a second
   pass over 28 million rows to compute a denominator. */


/* -------------------------------------------------------------
   2. Day of week
   -------------------------------------------------------------
   WEEKDAY returns 0 for Monday through 6 for Sunday, which sorts
   the way a person reads a week. DAYOFWEEK starts on Sunday and
   would put the weekend at both ends.
   ------------------------------------------------------------- */

SELECT WEEKDAY(pickup_datetime) AS dow,
       DAYNAME(MIN(pickup_datetime)) AS day_name,
       ROUND(100 * SUM(YEAR(pickup_datetime) = 2017)
                 / SUM(SUM(YEAR(pickup_datetime) = 2017)) OVER (), 2) AS pct_2017,
       ROUND(100 * SUM(YEAR(pickup_datetime) = 2019)
                 / SUM(SUM(YEAR(pickup_datetime) = 2019)) OVER (), 2) AS pct_2019,
       ROUND(100 * SUM(YEAR(pickup_datetime) = 2020)
                 / SUM(SUM(YEAR(pickup_datetime) = 2020)) OVER (), 2) AS pct_2020
FROM trips
WHERE pickup_datetime >= '2017-01-01'
  AND pickup_datetime <  '2021-01-01'
GROUP BY dow
ORDER BY dow;


/* -------------------------------------------------------------
   3. Which parts of the day lost most
   -------------------------------------------------------------
   Shares say what the shape is. This says what changed, by
   comparing each period's decline against the 48.5% baseline.

   Four periods rather than twenty-four hours, because the
   question is about kinds of travel rather than about clock
   time:

     night     22:00 to 05:59   bars, shift work, no transit
     morning   06:00 to 09:59   commuting
     midday    10:00 to 15:59   errands, appointments
     evening   16:00 to 21:59   commuting home, going out
   ------------------------------------------------------------- */

WITH periods AS (
    SELECT YEAR(pickup_datetime) AS yr,
           CASE
               WHEN HOUR(pickup_datetime) BETWEEN  6 AND  9 THEN '2. morning 06-09'
               WHEN HOUR(pickup_datetime) BETWEEN 10 AND 15 THEN '3. midday 10-15'
               WHEN HOUR(pickup_datetime) BETWEEN 16 AND 21 THEN '4. evening 16-21'
               ELSE                                              '1. night 22-05'
           END AS period,
           COUNT(*) AS trips
    FROM trips
    WHERE pickup_datetime >= '2017-01-01'
      AND pickup_datetime <  '2020-01-01'
    GROUP BY yr, period
)
SELECT period,
       MAX(CASE WHEN yr = 2017 THEN trips END) AS trips_2017,
       MAX(CASE WHEN yr = 2019 THEN trips END) AS trips_2019,
       ROUND(100 * (MAX(CASE WHEN yr = 2019 THEN trips END)
                  - MAX(CASE WHEN yr = 2017 THEN trips END))
                 / MAX(CASE WHEN yr = 2017 THEN trips END), 1) AS pct_change
FROM periods
GROUP BY period
ORDER BY period;


/* -------------------------------------------------------------
   4. Weekday against weekend, by period
   -------------------------------------------------------------
   A Friday night trip and a Tuesday morning one are different
   businesses. If one held and the other did not, the aggregate
   hourly profile would hide it, since both land in the same
   hours of the same chart.
   ------------------------------------------------------------- */

WITH split AS (
    SELECT YEAR(pickup_datetime) AS yr,
           CASE WHEN WEEKDAY(pickup_datetime) < 5 THEN 'weekday' ELSE 'weekend' END AS week_part,
           CASE
               WHEN HOUR(pickup_datetime) BETWEEN  6 AND  9 THEN '2. morning 06-09'
               WHEN HOUR(pickup_datetime) BETWEEN 10 AND 15 THEN '3. midday 10-15'
               WHEN HOUR(pickup_datetime) BETWEEN 16 AND 21 THEN '4. evening 16-21'
               ELSE                                              '1. night 22-05'
           END AS period,
           COUNT(*) AS trips
    FROM trips
    WHERE pickup_datetime >= '2017-01-01'
      AND pickup_datetime <  '2020-01-01'
    GROUP BY yr, week_part, period
)
SELECT week_part,
       period,
       MAX(CASE WHEN yr = 2017 THEN trips END) AS trips_2017,
       MAX(CASE WHEN yr = 2019 THEN trips END) AS trips_2019,
       ROUND(100 * (MAX(CASE WHEN yr = 2019 THEN trips END)
                  - MAX(CASE WHEN yr = 2017 THEN trips END))
                 / MAX(CASE WHEN yr = 2017 THEN trips END), 1) AS pct_change
FROM split
GROUP BY week_part, period
ORDER BY week_part, period;


/* =============================================================
   FINDINGS

   THE SHAPE CHANGED, NOT JUST THE HEIGHT

   Change from 2017 to 2019, against a baseline of -48.5%:

     night 22-05      -64.8%
     morning 06-09    -37.6%
     midday 10-15     -36.8%
     evening 16-21    -50.5%

   Split by week part the spread reaches 35 points:

     weekend night    -68.7%
     weekday night    -61.5%
     weekend evening  -55.3%
     weekday evening  -48.6%
     weekend midday   -44.9%
     weekend morning  -42.6%
     weekday morning  -36.5%
     weekday midday   -33.3%

   The hourly shares say the same without the banding. Night
   hours fell from 23.0% of all trips to 15.7%, while midday rose
   from 26.8% to 32.9%. Midnight went from 3.90% of trips to
   2.51%, 1am from 3.00% to 1.77%.

   Green taxis became a daytime service.

   AND A WEEKDAY ONE

   Share of each year's trips, by day:

     day         2017     2019     2020
     Monday     12.11%   13.12%   13.80%
     Tuesday    12.56%   14.18%   14.59%
     Wednesday  13.38%   14.61%   15.74%
     Thursday   14.08%   15.11%   16.01%
     Friday     16.03%   15.88%   16.31%
     Saturday   17.18%   14.83%   12.97%
     Sunday     14.66%   12.27%   10.58%

   In absolute terms against the -48.5% baseline: Sunday -56.9%,
   Saturday -55.6%, Tuesday -41.9%. A fifteen point spread.

   The inversion is the finding. Saturday was the busiest day of
   the week in 2017, and Sunday was busier than Monday, Tuesday
   or Wednesday. By 2020 Saturday and Sunday are the two quietest
   days of the seven.

   Nothing about grouping by day of week knows anything about
   time of day, so the two results are independent measurements
   of the same shift.

   THE MECHANISM FOLLOWS FROM WHAT A HAIL REQUIRES

   At two in the morning there is no traffic to hail from, so a
   phone is the only practical way to get a car. At two in the
   afternoon a green taxi passing on a busy street is a real
   alternative.

   Ride-hailing's advantage is largest exactly when hailing is
   hardest, and weekend nights are where that is most true.

   Plausible and not proved. What the data shows is the pattern,
   not the reason.

   -------------------------------------------------------------
   THIS RESOLVES A TENSION IN THE PROJECT

   Question 7 found local travel collapsing. Question 8 found a
   short local hop to LaGuardia surviving better than anything
   else measured, at -22.8%.

   Both are true, and the dividing line is not local against
   distant. It is spontaneous against planned.

   The trip that died was spontaneous, late-night, short and
   local. The trip that survived was planned and daytime, heading
   either into Manhattan or to an airport near enough to be worth
   a cab.

   Every question here has approached that distinction from a
   different direction:

     Q3  short trips went first, long trips grew for a year
     Q5  the trade retreated outward and turned toward Manhattan
     Q7  outer boroughs abandoned local travel, inner did not
     Q8  the airport run survived where the airport was local
     Q9  night collapsed, weekday midday held

   None of these was designed to test that idea. They converge on
   it, which is worth more than a single query built to confirm
   it would have been.

   -------------------------------------------------------------
   METHOD NOTE

   Every figure in queries 1 and 2 is a share of its own year.

   Raw hourly counts would have shown 2017 above 2019 at all
   twenty-four hours and concluded nothing, because a 48%
   decline is larger than any variation between hours. The
   question was the shape, so the height had to be removed first.
   ============================================================= */
