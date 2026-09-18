/* =============================================================
   Question 4: did tipping change, and is any change explained by
   the payment mix rather than by behaviour?

   Neither. The measure is not comparable across years, and this
   file is the demonstration.

   The question started from one line in the data dictionary:

     tip_amount: Tip amount (automatically populated for credit
     card tips - cash tips are not included)

   Cash tips are absent, not zero. Question 3 found card share
   rising 6.5 points in 2018, so recorded tips per trip had to
   rise in 2018 whether or not anybody changed what they gave.
   That was the expected trap.

   The real problem turned out to be larger and in the opposite
   direction, and it took two further queries to find.
   ============================================================= */

USE nyc_taxi;

/* -------------------------------------------------------------
   1. The naive version
   -------------------------------------------------------------
   Average recorded tip across all trips, which is what most
   people would produce for this question.

     2017   1.155   41.7% of trips show a tip
     2018   1.021   37.2%
     2019   0.990   35.7%
     2020   1.270   45.6%

   Recorded tips fell in 2018, against a prediction that the
   rising card share would push them up. So something bigger was
   moving underneath.
   ------------------------------------------------------------- */

SELECT YEAR(pickup_datetime)            AS yr,
       COUNT(*)                         AS trips,
       ROUND(AVG(tip_amount), 3)        AS avg_recorded_tip,
       ROUND(100 * SUM(tip_amount > 0)
                 / COUNT(*), 1)         AS pct_with_a_recorded_tip
FROM trips
WHERE pickup_datetime >= '2017-01-01'
  AND pickup_datetime <  '2021-01-01'
  AND total_amount    >  0
GROUP BY yr
ORDER BY yr;


/* -------------------------------------------------------------
   2. Card trips only
   -------------------------------------------------------------
   Restricting to payment_type = 1 removes the cash problem
   entirely. Within card trips a tip of zero means somebody chose
   not to tip, rather than a tip being invisible.

     yr    card trips   % tipped   tip % of fare   avg fare
     2017   5,910,794      82.4         17.49       13.04
     2018   5,004,057      65.1         11.44       15.63
     2019   3,206,200      66.8         12.17       15.23
     2020     662,634      80.7         15.39       14.46

   A 17.3 point fall in one year, then a recovery. Too large and
   too abrupt for a change of habit, and it lands in 2018, the
   same year the card share stepped. Two unrelated behaviours
   making sharp one-year moves in the same year is not what
   behaviour does.

   tip_pct_of_fare is a ratio of sums, not an average of ratios.
   An average of per-trip percentages weights a $4 fare tipped $2
   the same as a $60 fare tipped $6, which answers what the
   typical passenger does rather than what share of revenue
   arrives as tips. The second survives a changing trip mix.
   ------------------------------------------------------------- */

SELECT YEAR(pickup_datetime)                   AS yr,
       COUNT(*)                                AS card_trips,
       ROUND(100 * SUM(tip_amount > 0)
                 / COUNT(*), 1)                AS pct_tipped,
       ROUND(AVG(tip_amount), 3)               AS avg_tip,
       ROUND(AVG(fare_amount), 2)              AS avg_fare,
       ROUND(100 * SUM(tip_amount)
                 / SUM(fare_amount), 2)        AS tip_pct_of_fare
FROM trips
WHERE pickup_datetime >= '2017-01-01'
  AND pickup_datetime <  '2021-01-01'
  AND payment_type     =  1
  AND fare_amount      >  0
GROUP BY yr
ORDER BY yr;


/* -------------------------------------------------------------
   3. Step or slope?
   -------------------------------------------------------------
   A drop between two adjacent months points at a software or
   terminal change. A gradual slide points at something else.

     2018-01   74.5      2018-10   59.4
     2018-02   73.0      2018-11   58.9
     2018-03   69.4      2018-12   58.8
     2018-04   67.4      2019-01   55.8
     2018-05   64.6      2019-02   54.6
     2018-06   64.0      2019-03   56.4
     2018-07   64.6      2019-04   68.2
     2018-08   62.6      2019-05   69.5
     2018-09   62.8      2019-06   70.3

   Both, as it turns out. A slow slide of sixteen points across
   2018, then a jump of 11.8 points between March and April 2019.
   ------------------------------------------------------------- */

SELECT pickup_month,
       COUNT(*)                                           AS card_trips,
       ROUND(100 * SUM(tip_amount > 0) / COUNT(*), 1)     AS pct_tipped,
       ROUND(100 * SUM(tip_amount) / SUM(fare_amount), 2) AS tip_pct_of_fare
FROM trips
WHERE pickup_month  >= '2017-01-01'
  AND pickup_month  <  '2019-07-01'
  AND payment_type   = 1
  AND fare_amount    > 0
GROUP BY pickup_month
ORDER BY pickup_month;


/* -------------------------------------------------------------
   4. By vendor, which settles it
   -------------------------------------------------------------
   VendorID identifies the technology provider supplying the
   meter and payment terminal: 1 is Creative Mobile Technologies,
   2 is Verifone.

                  % tipped              tip % of fare
     yr        vendor 1   vendor 2    vendor 1   vendor 2
     2017          88.8       80.9       18.85      17.20
     2018          90.2       60.9       18.15      10.44
     2019          58.5       68.4        9.95      12.62
     2020          61.6       84.8       11.15      16.34

   In 2018 vendor 1 does not move and vendor 2 loses twenty
   points. In 2019 they swap. In 2020 vendor 2 is back near where
   it started and vendor 1 is not.
   ------------------------------------------------------------- */

SELECT YEAR(pickup_datetime) AS yr,
       vendor_id,
       COUNT(*)                                           AS card_trips,
       ROUND(100 * SUM(tip_amount > 0) / COUNT(*), 1)     AS pct_tipped,
       ROUND(100 * SUM(tip_amount) / SUM(fare_amount), 2) AS tip_pct_of_fare
FROM trips
WHERE pickup_datetime >= '2017-01-01'
  AND pickup_datetime <  '2021-01-01'
  AND payment_type     = 1
  AND fare_amount      > 0
GROUP BY yr, vendor_id
ORDER BY yr, vendor_id;


/* =============================================================
   FINDINGS

   THE QUESTION CANNOT BE ANSWERED FROM THIS DATA

   A passenger hailing a green cab on the street cannot see which
   vendor supplies its payment terminal, cannot choose it, and
   has no reason to tip differently because of it. So a tipping
   pattern that alternates between the two vendors year by year
   is not passengers changing their behaviour. It is two systems
   recording the same act differently.

   IT IS NOT A MIX EFFECT EITHER

   Vendor 1 runs 18.5%, 14.5%, 15.9% and 17.6% of card trips
   across the four years. Applying 2018's vendor rates to 2017's
   vendor mix gives 66.3% against the 65.1% observed, so of the
   17.3 point fall roughly 16 points are within-vendor and about
   1 is composition.

   WHAT THE MECHANISM MIGHT BE

   The 2018 slide is gradual and the 2019 move is a step. A
   rolling replacement of terminals across a fleet would produce
   the first and a software update pushed at once would produce
   the second. That is a plausible story and these files cannot
   confirm it. It is offered as a hypothesis, not a conclusion.

   CONSEQUENCE FOR THE REST OF THE PROJECT

   tip_amount is not comparable across years and no question here
   uses it as a time series. A tipping chart built on this data
   would be a chart of vendor reporting practice wearing the
   label of passenger generosity.

   Within a single year and a single vendor the field is probably
   sound, so cross-sectional questions about tipping remain open.
   None of the ten asks one.

   WHAT WAS NOT RUN, AND WHY

   The plan included tip percentage broken down by distance band,
   to separate behaviour from trip mix. It was dropped once the
   measure was shown to be unreliable across years. Breaking an
   untrustworthy number into five smaller untrustworthy numbers
   does not rescue it, and the scan time is better spent
   elsewhere.
   ============================================================= */
