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
| 02 | [Airbnb listings and reviews](./02-airbnb-listings) | Travel and pricing | 5.7M rows across 2 tables | Not started |
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

---

## Techniques used

Listed as they appear in the repository, not as a wishlist. Projects 2 and 3 will
add window functions and query tuning at scale.

**Schema design.** Data type selection sized to the data, primary and foreign
keys, and an index strategy applied after loading with the reasoning recorded in
the script.

**Joins.** Inner and left joins across a six-table model, including the fan-out
problem and when a left join is required to keep a denominator intact.

**CTEs.** Single and chained common table expressions, used to pivot results and
to aggregate an already-aggregated result.

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
