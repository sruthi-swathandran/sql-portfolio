/* =============================================================
   Question 3: did the payment mix shift, and what does excluding
   the metadata-free rows do to that answer?

   The question has two halves and the second one is the point.

   Cash versus card is easy to compute and the answer will look
   convincing. But payment_type is one of the seven columns
   missing from 942,199 rows, and those rows are not spread
   evenly: none in 2017, none in 2018, 414,107 in 2019 and
   528,092 in 2020.

   So the obvious query compares a complete 2017 against a 2020
   that is missing 30% of its rows, and the missing 30% is
   missing precisely the column being measured. Whether that
   matters cannot be established from the data, because the
   evidence needed to check it is the evidence that is absent.

   What can be done is to bound it.
   ============================================================= */

USE nyc_taxi;

/* -------------------------------------------------------------
   1. The mix as usually reported
   -------------------------------------------------------------
   Card share of card-plus-cash, which is the comparison that
   matters. Codes 3 to 6 are no-charge, dispute, unknown and
   voided, together under 1% of trips, and they are not a
   payment method in the sense the question means.

   pct_unknown is printed beside the answer deliberately. A
   reader who sees a card share of 56% next to a 30% unknown rate
   knows immediately how much weight to put on it.
   ------------------------------------------------------------- */

SELECT YEAR(pickup_datetime)                         AS yr,
       COUNT(*)                                      AS trips,
       SUM(payment_type IS NULL)                     AS unknown_rows,
       ROUND(100 * SUM(payment_type IS NULL)
                 / COUNT(*), 1)                      AS pct_unknown,
       SUM(payment_type = 1)                         AS card,
       SUM(payment_type = 2)                         AS cash,
       SUM(payment_type IN (3,4,5,6))                AS other,
       ROUND(100 * SUM(payment_type = 1)
                 / NULLIF(SUM(payment_type IN (1,2)), 0), 1) AS card_share_pct
FROM trips
WHERE pickup_datetime >= '2017-01-01'
  AND pickup_datetime <  '2021-01-01'
GROUP BY yr
ORDER BY yr;


/* -------------------------------------------------------------
   2. Bounding the years where rows are missing
   -------------------------------------------------------------
   The missing rows took one of two values. Rather than assume
   they resemble the rows that survived, compute the answer under
   both extremes and report the interval.

   lower_bound : every missing row was cash
   upper_bound : every missing row was card

   The truth is somewhere between. If the interval is narrow the
   uncertainty does not matter and the point estimate can be
   used. If it is wide, no honest trend can be drawn through it
   and the query has just proved the question unanswerable for
   that year, which is a result rather than a failure.

   This is the same move as any mechanically bounded metric: when
   a value cannot be known, establish what it cannot be.
   ------------------------------------------------------------- */

SELECT YEAR(pickup_datetime) AS yr,
       ROUND(100 * SUM(payment_type = 1)
                 / NULLIF(SUM(payment_type IN (1,2)), 0), 1)        AS point_estimate,
       ROUND(100 * SUM(payment_type = 1)
                 / NULLIF(SUM(payment_type IN (1,2))
                        + SUM(payment_type IS NULL), 0), 1)         AS lower_bound,
       ROUND(100 * (SUM(payment_type = 1) + SUM(payment_type IS NULL))
                 / NULLIF(SUM(payment_type IN (1,2))
                        + SUM(payment_type IS NULL), 0), 1)         AS upper_bound
FROM trips
WHERE pickup_datetime >= '2017-01-01'
  AND pickup_datetime <  '2021-01-01'
GROUP BY yr
ORDER BY yr;


/* -------------------------------------------------------------
   3. Is the card share moving, or is the trip mix moving?
   -------------------------------------------------------------
   Question 2 established that the typical trip grew from 1.79 to
   2.03 miles between 2017 and 2019. Longer trips cost more, and
   people pay for larger fares by card more often than they do
   for small ones.

   So a rising card share might be nobody changing their habits
   at all, just the same habits applied to a different mix of
   trips. Holding distance roughly constant separates the two.

   If card share rises within every band, behaviour changed. If
   it only rises overall, the composition changed and the
   headline number is a mix effect.
   ------------------------------------------------------------- */

SELECT YEAR(pickup_datetime) AS yr,
       CASE
           WHEN trip_distance <  1 THEN '1. under 1 mile'
           WHEN trip_distance <  2 THEN '2. 1 to 2'
           WHEN trip_distance <  5 THEN '3. 2 to 5'
           WHEN trip_distance < 10 THEN '4. 5 to 10'
           ELSE                        '5. 10 plus'
       END AS distance_band,
       COUNT(*) AS trips,
       ROUND(100 * SUM(payment_type = 1)
                 / NULLIF(SUM(payment_type IN (1,2)), 0), 1) AS card_share_pct
FROM trips
WHERE pickup_datetime >= '2017-01-01'
  AND pickup_datetime <  '2021-01-01'
  AND trip_distance   >  0
  AND trip_distance   <  100
  AND payment_type IS NOT NULL
GROUP BY yr, distance_band
ORDER BY yr, distance_band;


/* =============================================================
   FINDINGS
   =============================================================

   1. THE MIX SHIFTED ONCE, IN 2018

        2017   50.7%   card share of card-plus-cash
        2018   57.2%
        2019   57.4%
        2020   55.5%

   A 6.5 point step in a single year, then nothing: 2018 to 2019
   moves by 0.2 points. Gradual adoption does not look like a
   step.

   2017 and 2018 are the only years with no missing rows, so the
   one comparison carrying the finding is also the only one free
   of uncertainty.

   2. AFTER 2018 THE DATA CANNOT SAY

        2019   53.5% to 60.4%
        2020   38.5% to 69.1%

   Bounds computed by assuming the missing rows were all cash,
   then all card. 2019's interval is 6.9 points wide against a
   0.2 point change to measure. 2020's is 30.6 points wide, which
   is a way of saying the year has no answer.

   Reporting 55.5% for 2020 would not be wrong exactly. It would
   be a number with no information in it.

   3. THE STEP IS BEHAVIOUR, NOT COMPOSITION

   Card share rose in every distance band between 2017 and 2018,
   so it is not an artefact of trips getting longer.

        under 1 mile   42.1 -> 44.7   +2.6
        1 to 2         47.2 -> 50.7   +3.5
        2 to 5         54.9 -> 61.1   +6.2
        5 to 10        63.2 -> 72.2   +9.0
        10 plus        66.6 -> 85.2  +18.6

   Applying 2018's within-band rates to 2017's mix gives 55.9%
   against the 57.2% observed. So of the 6.5 points, about 5.2
   are behaviour and 1.3 are mix. Roughly four fifths real.

   4. THE BIGGEST RESULT WAS NOT THE ONE BEING MEASURED

   The trip counts in the banded query answer a different
   question. Between 2017 and 2018:

        under 1 mile   2,726,960 -> 1,867,728   -31.5%
        1 to 2         3,654,370 -> 2,572,882   -29.6%
        2 to 5         3,623,478 -> 2,689,765   -25.8%
        5 to 10        1,277,560 -> 1,098,799   -14.0%
        10 plus          322,369 ->   475,410   +47.5%

   A clean monotonic gradient. The shorter the trip, the harder
   it fell, and the longest band grew by nearly half in a year
   when total volume dropped a quarter.

   That reframes question 2. The median trip length rose from
   1.79 to 1.95 miles not because journeys stretched, but because
   the bottom of the distribution was removed. Short hops are
   exactly the trips a competitor hailed from a phone takes
   first.

   The gradient does not hold. In 2019 every band falls 35 to 42
   per cent, with the long ones falling slightly faster. Whatever
   protected long journeys in 2018 had stopped by 2019.

   5. CAVEAT ON THE BANDED COUNTS

   The banded query excludes trips with no payment type, which is
   6.9% of 2019 and 30.5% of 2020. Counts for those years are
   understated and cross-year comparisons involving them are
   unsafe. 2017 against 2018 has no missing rows at all, which is
   why every claim above rests on that pair.

   TIMINGS
   -------
   Query 1   81 s
   Query 2   90 s
   Query 3  177 s

   All three are full table scans. A covering index on
   (pickup_month, payment_type, trip_distance) would serve all
   three and is the obvious next index experiment.
   ============================================================= */
