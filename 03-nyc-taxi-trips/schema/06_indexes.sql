/* =============================================================
   NYC Green Taxi Trips - Indexes
   MySQL 8.0.40

   Run after 05_verify_load.sql.

   HOW THIS FILE IS BUILT
   ----------------------
   One index at a time, each one measured.

   The tempting approach is to index every column a question
   might filter on and move on. That produces a table with six
   indexes, a load that takes three times as long, and no
   evidence that any of them helped.

   So each index here follows the same four steps:

     1. EXPLAIN the query, and time it, before the index exists
     2. Predict what the plan should become and why
     3. Build it, recording how long the build took and its size
     4. EXPLAIN and time again, and compare against the prediction

   A prediction that turns out wrong is the useful case. It means
   something about the optimiser was misunderstood, and that is
   worth more than an index that happened to work.

   THE COST SIDE
   -------------
   Every index is a second copy of its columns plus the primary
   key, kept sorted. On 28.3 million rows that is hundreds of
   megabytes each and minutes to build. The baseline from
   05_verify_load.sql: 2,066 MB of data, 0 MB of index.
   ============================================================= */

USE nyc_taxi;

SET SESSION information_schema_stats_expiry = 0;


/* =============================================================
   INDEX 1: pickup_datetime
   =============================================================

   NEEDED BY
   ---------
   Questions 1, 2 and 9, and the time filter on almost everything
   else. Every trend query in this project filters or groups on
   this column.

   BASELINE, MEASURED BEFORE BUILDING
   ----------------------------------
   Query: monthly trip counts across 2017 to 2020, 48 rows out.

     Duration : 51.734 s
     type     : ALL
     key      : NULL
     rows     : 26,491,637
     Extra    : Using where; Using temporary; Using filesort

   PREDICTION
   ----------
   The plan should become type: range with key: ix_pickup, and
   Extra should gain "Using index".

   That last part is the interesting one. COUNT(*) needs no
   column values, and both the filter and the grouping come from
   pickup_datetime, so every value the query wants is already in
   the index. MySQL can answer from the index alone and never
   read the table. An index that satisfies a query by itself is
   called covering, and it is the difference between reading a
   few hundred megabytes and reading 2,066.

   "Using temporary" and "Using filesort" should survive. YEAR()
   and MONTH() are monotonic in the underlying datetime, so the
   index order would in principle produce the groups in order
   already, but the optimiser does not reason about monotonicity
   through a function call. It sees an expression it cannot match
   to the index and falls back to a temp table.

   Expected: 400 to 600 MB, a few minutes to build, and the query
   somewhere between 8 and 15 seconds.

   RESULT
   ------
   Build time : 455.0 s
   Duration   : 17.750 s, down from 51.734 s, a 2.9x gain
   Plan       : type: range, key: ix_pickup, key_len: 5,
                Extra: Using where; Using index; Using temporary;
                       Using filesort

   Four of the five predictions held. The duration did not: 17.75
   seconds against a predicted 8 to 15.

   TWO THINGS THE PLAN REVEALS
   ---------------------------
   key_len is 5, the width of a DATETIME. The index holds that
   column and the primary key and nothing else, which is why it
   is cheap enough to scan.

   rows says 13,245,818, exactly half the 26,491,637 reported for
   the full scan. That is not an estimate. It is the optimiser's
   fallback assumption that a range matches half a table when it
   has no better information. The filter actually matches
   28,325,332 rows, being everything except the 739 with dates
   outside the study period.

   WHICH MEANS THIS INDEX IS NOT SELECTIVE
   ---------------------------------------
   It excludes 739 rows out of 28.3 million. Every bit of the 2.9x
   came from width, not from filtering: the same number of entries
   gets read either way, but each is about 9 bytes in the index
   against roughly 77 in the table.

   That is worth separating from the usual reason to index. A
   covering index pays off through what it lets the server avoid
   reading, and it can be worth building on a column with almost
   no selectivity at all.

   WHAT IS LEFT
   ------------
   The residual 17.75 seconds is not I/O against the table, which
   is no longer touched. It is 28.3 million calls to YEAR() and
   MONTH() plus the temp table that collects the 48 groups.

   Removing that needs the grouping key stored rather than
   computed, which means a generated column and a second index.
   That is the next experiment, and it costs an ALTER TABLE on
   28.3 million rows to find out.
   ------------------------------------------------------------- */

CREATE INDEX ix_pickup ON trips (pickup_datetime);

/* Re-run both, and record above. */

EXPLAIN
SELECT YEAR(pickup_datetime)  AS yr,
       MONTH(pickup_datetime) AS mth,
       COUNT(*)               AS trips
FROM trips
WHERE pickup_datetime >= '2017-01-01'
  AND pickup_datetime <  '2021-01-01'
GROUP BY yr, mth
ORDER BY yr, mth;

SELECT table_name,
       ROUND(data_length  / 1024 / 1024) AS data_mb,
       ROUND(index_length / 1024 / 1024) AS index_mb
FROM information_schema.tables
WHERE table_schema = 'nyc_taxi' AND table_name = 'trips';


/* =============================================================
   INDEX 2: an indexed virtual column for the month
   =============================================================

   THE PROBLEM LEFT OVER
   ---------------------
   ix_pickup made the query covering, so the table is never read,
   and it is still 17.75 seconds. The remaining work is 28.3
   million calls to YEAR() and MONTH() and a temp table holding
   the 48 groups.

   The optimiser cannot avoid either. YEAR() and MONTH() are
   monotonic in a datetime, so scanning ix_pickup in order would
   produce the months already grouped and already sorted, but
   MySQL does not reason about monotonicity through a function.
   It sees an expression, gives up on the index order, and builds
   a temp table.

   The fix is to stop computing the grouping key and store it, so
   that it can be indexed and the index order is the group order.

   VIRTUAL, NOT STORED
   -------------------
   A STORED generated column writes a value into all 28.3 million
   rows, which rebuilds the table. Minutes of work and about 85 MB
   of extra width, permanently.

   A VIRTUAL one is a definition and nothing else. Adding it is a
   metadata change that returns immediately, because the value is
   computed whenever a query reads it.

   On its own that solves nothing: computing on read is what the
   query already does. The point is that MySQL 8 allows an index
   on a virtual column, and building that index materialises the
   value inside the index. The table stays 2,066 MB, the
   expression is evaluated once per row at build time rather than
   once per row per query, and the index arrives sorted by month.

   PREDICTION
   ----------
   ALTER TABLE returns in under a second.

   The index costs roughly what ix_pickup did, somewhere near 400
   to 500 MB and several minutes, since it holds a 3-byte DATE
   plus the primary key.

   The plan should read type: range, key: ix_pickup_month, with
   Extra showing "Using where; Using index" and nothing more.
   Both "Using temporary" and "Using filesort" should disappear,
   because a GROUP BY on the leading column of an index it is
   already scanning in order can be streamed.

   Duration somewhere between 3 and 8 seconds.

   RESULT
   ------
   Alter time : 0.750 s, as predicted, nothing was written
   Build time : 501.2 s
   Index size : 453 MB for both indexes together, so roughly 226
                MB each
   Duration   : 13.766 s, down from 17.750 s
   Plan       : type: range, key: ix_pickup_month, key_len: 4,
                Extra: Using where; Using index

   The plan prediction was exactly right. Using temporary and
   Using filesort are both gone: the index is scanned in month
   order, so the groups arrive in order and are aggregated as
   they stream.

   The duration prediction was wrong. I said 3 to 8 seconds and
   it is 13.8.

   WHY, WHICH IS THE POINT OF THE EXERCISE
   ---------------------------------------
   Convert each measurement to rows per second:

     no index, full scan        51.7 s      548,000 rows/s
     ix_pickup, covering        17.8 s    1,600,000 rows/s
     ix_pickup_month, streamed  13.8 s    2,060,000 rows/s

   The question requires counting every trip in four years, which
   is 28,325,332 rows. On this machine MySQL walks index entries
   at about two million a second, so 28.3 million of them take
   fourteen seconds no matter how good the plan is.

   The first index removed reads of a 77-byte row in favour of a
   9-byte index entry, and that was the real win. The second
   removed 28 million function calls and a temp table, worth
   about four seconds. What remains is the iteration itself.

   No index removes row visits that the question genuinely
   requires. Getting below fourteen seconds means answering from
   fewer rows, which means storing monthly counts rather than
   deriving them. That is pre-aggregation, a different technique
   with a different cost: a summary table is fast, and it is
   wrong the moment the underlying data changes.

   VERDICT ON THIS INDEX
   ---------------------
   22% faster, for eight minutes of build time and 226 MB. Kept,
   because several later questions group by month and all of them
   benefit, but it is a marginal index and the write-up says so.

   A note on key_len. It reads 4, and a DATE is three bytes. The
   fourth is the null flag, because a generated column is
   nullable unless declared otherwise. NOT NULL would have saved
   one byte per entry, about 28 MB.
   ------------------------------------------------------------- */

ALTER TABLE trips
    ADD COLUMN pickup_month DATE
    GENERATED ALWAYS AS (CAST(DATE_FORMAT(pickup_datetime, '%Y-%m-01') AS DATE))
    VIRTUAL;

CREATE INDEX ix_pickup_month ON trips (pickup_month);

EXPLAIN
SELECT pickup_month,
       COUNT(*) AS trips
FROM trips
WHERE pickup_month >= '2017-01-01'
  AND pickup_month <  '2021-01-01'
GROUP BY pickup_month
ORDER BY pickup_month;

SELECT table_name,
       ROUND(data_length  / 1024 / 1024) AS data_mb,
       ROUND(index_length / 1024 / 1024) AS index_mb
FROM information_schema.tables
WHERE table_schema = 'nyc_taxi' AND table_name = 'trips';
