/* Question 9: how old is each city's host base?

   Framed as the age of the surviving host base rather than as
   market growth, because this is a snapshot of hosts active in
   early 2021. Hosts who joined and later left are absent
   entirely, so every early year is understated by an unknown
   amount of churn.

   host_since is when the host joined Airbnb, not when they
   first listed in this city, so a 2013 host who moved into a
   new market in 2020 counts as 2013 here.
*/
USE airbnb_listings;

WITH host_city AS (
    SELECT DISTINCT l.city, l.host_id, h.host_since
    FROM listings l
    JOIN hosts h ON l.host_id = h.host_id
    WHERE h.host_since IS NOT NULL
),
ranked AS (
    SELECT city, host_id, YEAR(host_since) AS join_year,
           ROW_NUMBER() OVER (PARTITION BY city ORDER BY host_since) AS rn,
           COUNT(*)     OVER (PARTITION BY city)                     AS n
    FROM host_city
)
SELECT city,
       MAX(n)                                                  AS hosts,
       MAX(CASE WHEN rn = CEIL(n / 2) THEN join_year END)      AS median_join_year,
       ROUND(100.0 * AVG(join_year <= 2014), 1)                AS pct_joined_by_2014,
       ROUND(100.0 * AVG(join_year >= 2019), 1)                AS pct_joined_2019_plus
FROM ranked
GROUP BY city
ORDER BY median_join_year;


/* --- The full intake curve --------------------------------
   One row per city per year: new hosts, the running total, and
   the cumulative share of that city's current host base.

   SUM(new_hosts) OVER (PARTITION BY city ORDER BY join_year)
   is the running total, restarting for each city. The same
   function without ORDER BY returns the city total, which is
   why both appear in the percentage.

   Read the early years as a floor rather than a count.
   Survivorship thins them: a host who joined in 2012 and left
   before 2021 is absent entirely, so the true intake in those
   years was larger than shown and the peak was earlier than it
   appears.

   2021 holds two months, not twelve. The data ends 1 March.
   ---------------------------------------------------------- */
WITH host_city AS (
    SELECT DISTINCT l.city, l.host_id, h.host_since
    FROM listings l
    JOIN hosts h ON l.host_id = h.host_id
    WHERE h.host_since IS NOT NULL
),
by_year AS (
    SELECT city, YEAR(host_since) AS join_year, COUNT(*) AS new_hosts
    FROM host_city
    GROUP BY city, YEAR(host_since)
)
SELECT city, join_year, new_hosts,
       SUM(new_hosts) OVER (PARTITION BY city ORDER BY join_year) AS cumulative_hosts,
       ROUND(100.0 * SUM(new_hosts) OVER (PARTITION BY city ORDER BY join_year)
                   / SUM(new_hosts) OVER (PARTITION BY city), 1)  AS pct_of_host_base
FROM by_year
ORDER BY city, join_year;