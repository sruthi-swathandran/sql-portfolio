# SQL Analytics Portfolio

Three end-to-end analytics projects built in MySQL 8, each working from raw CSVs
through schema design, loading, and business analysis.

Every project starts from unmodelled source files — the `CREATE TABLE` statements,
data types, keys, and indexes are all designed here rather than inherited from a
prepared database dump.

---

## Projects

| # | Project | Domain | Scale | Focus |
|---|---------|--------|-------|-------|
| 01 | [Maven Fuzzy Factory](./01-maven-fuzzy-factory) | E-commerce / marketing | 1.7M rows across 6 tables | Conversion funnels, channel attribution, product launch impact |
| 02 | [Airbnb Listings & Reviews](./02-airbnb-listings) | Travel / pricing | 5.7M rows across 2 tables | Cross-city price comparison, currency normalisation, review seasonality |
| 03 | [NYC Taxi Trips](./03-nyc-taxi-trips) | Transport | 28M rows | Query performance at scale, indexing strategy, geospatial joins |

*Status: in progress.*

---

## Techniques demonstrated

- **Schema design** — data type selection, primary and foreign keys, index strategy
- **Joins** — inner, left, and self-joins across multi-table models
- **CTEs** — including chained and recursive common table expressions
- **Window functions** — `ROW_NUMBER`, `RANK`, `LAG`/`LEAD`, running totals, moving averages
- **Aggregation** — conditional aggregation, `GROUP BY` with `HAVING`, pivoting with `CASE`
- **Date and time analysis** — cohorting, period-over-period comparison, time-of-day bucketing
- **Data quality handling** — null strategies, deduplication, outlier treatment
- **Performance** — `EXPLAIN` plans, index tuning, and partitioning on large tables

---

## Repository structure

Each project folder follows the same layout:

```
NN-project-name/
├── README.md          Business questions, findings, and method
├── schema/            CREATE TABLE statements and data load scripts
├── analysis/          Numbered analysis queries, one file per question
├── results/           Query output saved as CSV, plus any charts
└── data/              Raw source files (gitignored — see project README)
```

---

## Reproducing these projects

1. Install MySQL 8.0 or later.
2. Clone this repository.
3. Download the source data using the link in the relevant project README, and
   place the files in that project's `data/` folder.
4. Run `schema/01_create_tables.sql`, then `schema/02_load_data.sql`.
5. Run the files in `analysis/` in numerical order.

Raw data files are not committed — they are large and freely available from the
original sources. Every project README documents exactly where to get them.

---

## Tech stack

MySQL 8.0 · MySQL Workbench · Git

---

## About

Built by Sruthi. Feedback and questions are welcome via the issues tab.
