# SQL analytics portfolio

Three end-to-end analytics projects built in MySQL 8, each working from raw CSVs
through schema design, loading, and business analysis.

Every project starts from unmodelled source files. The `CREATE TABLE` statements,
data types, keys and indexes are designed here rather than inherited from a
prepared database dump.

---

## Projects

| # | Project | Domain | Scale | Status |
|---|---------|--------|-------|--------|
| 01 | [Maven Fuzzy Factory](./01-maven-fuzzy-factory) | E-commerce and marketing | 1.7M rows across 6 tables | **Complete** |
| 02 | [Airbnb listings and reviews](./02-airbnb-listings) | Travel and pricing | 5.8M rows across 3 tables | **Complete** |
| 03 | [NYC taxi trips](./03-nyc-taxi-trips) | Transport | 28M rows | Not started |

### Maven Fuzzy Factory

Ten business questions on an online retailer's first three years of trading, from
traffic and channel attribution through to refunds. Some of what it found:

- The checkout leaks hardest: 37.9% of visitors reaching the billing page never complete, worth roughly $1.18M
- Mobile converts at a third of desktop's rate, worth about $477,000 in missing orders
- One product's refund rate tripled for exactly two months in 2014 while no other product moved, which points at a defective batch
- No product launch changed basket size. A cross-sell feature added in September 2013 did

Full write-up, method and assumptions in the
[project README](./01-maven-fuzzy-factory).

### Airbnb listings and reviews

Ten questions on 279,712 listings across ten cities in nine currencies, joined to
5.37 million reviews. Normalised from two flat CSVs into three tables. Some of
what it found:

- Price steps with bedrooms, not guests. A third guest costs 3.8% more; a fourth costs 25%, because half of them come with another room
- Review scores carry almost no information about price. The strongest of six dimensions explains half a percent of variation
- The superhost badge commands a premium in one city out of ten, and comes with a discount in five
- Hong Kong looks like a cheap city and is the fourth most expensive for a family apartment

Ten separate questions converged on the same conclusion about two markets, none
of which was designed to show it.

Full write-up in the [project README](./02-airbnb-listings).

---

## Techniques used

Listed as they appear in the repository, not as a wishlist. Project 3 will add
query tuning at scale.

**Schema design.** Data type selection sized to the data, primary and foreign
keys, and an index strategy applied after loading with the reasoning recorded in
the script.

**Joins.** Inner and left joins across a six-table model, including the fan-out
problem and when a left join is required to keep a denominator intact.

**CTEs.** Single and chained common table expressions, used to pivot results and
to aggregate an already-aggregated result.

**Window functions.** `ROW_NUMBER` and `COUNT` partitioned to build medians and
percentiles, since MySQL has no `MEDIAN`. `RANK` where ties should share a
position rather than be ordered arbitrarily. `LAG` for the marginal cost of one
more guest. Running totals with `SUM() OVER (ORDER BY ...)` for supply
concentration, including the tie-breaking that stops the default `RANGE` framing
collapsing a curve into steps.

**Normalisation.** A flat CSV split into three tables through a staging table,
with the host attributes that repeat across 279,712 rows moved to their own
182,024-row table.

**Statistics without a stats package.** Pearson correlation built from raw sums,
with the six dimensions unpivoted so the formula is written once rather than
repeated per column.

**Aggregation.** Conditional aggregation with `CASE` and `SUM`, `GROUP BY` with
`HAVING`, and scalar subqueries for share-of-total columns.

**Date handling.** Period-over-period comparison, and like-for-like windows to
avoid comparing a partial year against a full one. That correction changed the
conclusion three separate times.

**Data quality.** Null strategies with `NULLIF`, a verification script whose
expected results are stated before it runs, and documented handling of the three
ways a CSV load can fail without raising an error.

**Query performance.** `EXPLAIN` plans read before and after indexing, with
deliberate decisions about which columns not to index.

---

## Repository structure

Each project folder follows the same layout:

```
NN-project-name/
├── README.md          Business questions, findings, and method
├── schema/            CREATE TABLE statements, load scripts, verification, indexes
├── analysis/          Numbered analysis queries, one file per question
├── results/           Query output saved as CSV
└── data/              Raw source files, gitignored, see project README
```

---

## Reproducing these projects

Full instructions, including the two places local file loading has to be enabled
and the failure modes that produce no error message, are in
[`SETUP.md`](./SETUP.md).

The short version: clone, put the CSVs in `data/`, run the four `schema/` scripts
in order, check the verification results, then run `analysis/` in numerical order.

Raw data files are not committed. They are large and freely available from the
original sources, and every project README documents where to get them.

---

## Tech stack

MySQL 8.0 · MySQL Workbench · Git

---

## About

Built by Sruthi. Feedback and questions are welcome via the issues tab.
