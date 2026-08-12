# NYC Taxi Trips — Analysis at Scale

Analysis of 28 million green taxi trips in New York City between 2017 and 2020,
with a focus on querying a large table efficiently.

---

## Business questions

1. What is the average number of trips per week, and how did it change over the period?
2. What is the average distance travelled per trip?
3. Which days of the week and times of day are busiest?
4. What are the most popular pick-up and drop-off locations?

---

## Data

**Source:** [Maven Analytics Data Playground](https://mavenanalytics.io/data-playground) — "NYC Taxi Trips"
**Rows:** 28,327,624 across four yearly files
**Uncompressed size:** ~2.8 GB

Files: `2017_taxi_trips.csv`, `2018_taxi_trips.csv`, `2019_taxi_trips.csv`,
`2020_taxi_trips.csv`, plus `taxi_zones.csv` and `454_calendar.csv`.

Place them in `data/`. They are not committed to this repository.

> **Disk space:** allow ~4 GB for the extracted CSVs and a further ~3 GB for the
> MySQL tables and indexes.

---

## Performance notes

This project exists to demonstrate handling volume, not just writing correct SQL.
Documented here: load strategy, index choices, `EXPLAIN` plans before and after
tuning, and query timings.

<!-- Fill in as you build. -->

---

## Data quality

The 2020 file covers a period disrupted by COVID-19 restrictions, so trip volumes
drop sharply from March 2020. Any trend analysis spanning that boundary needs to
say so explicitly rather than presenting the fall as a normal seasonal pattern.

---

## Findings

<!-- Fill in as you build. -->
