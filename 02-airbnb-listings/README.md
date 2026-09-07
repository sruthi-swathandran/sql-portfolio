# Airbnb listings and reviews: cross-city market analysis

Analysis of 279,712 Airbnb listings across ten cities, joined to 5.37 million
historical reviews.

The cities span nine currencies, so the central problem is that no cross-city
price comparison is valid until the prices are converted. Getting that wrong is
the most common mistake made with this dataset, and getting it right is most of
what this project is about.

---

## Business questions

**Market comparison**

1. How do the ten city markets compare on price, once converted to a common currency?
2. Within each city, which neighbourhoods command the highest prices?
3. Which room and property types dominate each market, and what do they cost?

**What drives price**

4. What does each additional bedroom or guest add to the price, and does that hold across cities?
5. Do superhosts charge a premium, and do they earn better review scores?
6. Which review score dimension is most associated with price?

**Supply and demand**

7. How concentrated is supply among hosts with multiple listings?
8. What share of listings never receive a review, and what distinguishes them?
9. How did each city's market grow over time, using `host_since`?

**Value**

10. Which city offers the best value, measured as price per person accommodated?

---

## Data

**Source:** [Maven Analytics Data Playground](https://mavenanalytics.io/data-playground),
"Airbnb Listings and Reviews"
**Rows:** 279,712 listings · 5,373,143 reviews
**Files:** `Listings.csv` (152 MB), `Reviews.csv` (244 MB)

Place both CSVs in `data/`. They are not committed to this repository.

---

## Prices are in local currency

The `price` column is denominated in each city's own currency, so a raw
cross-city comparison means nothing. A listing at 1,100 in Bangkok is not eleven
times one at 99 in New York.

| City | Listings | Median price (local) | Currency |
|---|---:|---:|---|
| Paris | 64,690 | 80 | EUR |
| New York | 37,012 | 99 | USD |
| Sydney | 33,630 | 120 | AUD |
| Rome | 27,647 | 65 | EUR |
| Rio de Janeiro | 26,615 | 280 | BRL |
| Istanbul | 24,519 | 252 | TRY |
| Mexico City | 20,065 | 661 | MXN |
| Bangkok | 19,361 | 1,100 | THB |
| Cape Town | 19,086 | 1,069 | ZAR |
| Hong Kong | 7,087 | 386 | HKD |

All cross-city analysis converts to a single currency using a rate table in
[`schema/04_currency_reference.sql`](./schema/04_currency_reference.sql), with
the rates and the date they were taken recorded there. The data was captured in
early 2021, so the rates are matched to that period rather than to today.

---

## Model

Three tables, normalised from two flat files.

```
hosts      182,024 rows   host_id PK
listings   279,712 rows   listing_id PK, host_id FK
reviews  5,373,143 rows   (listing_id, review_id) PK, listing_id FK
```

`Listings.csv` mixes two entities. Ten of its 33 columns describe a host rather
than a property, and 279,712 listings come from 182,024 distinct hosts, one of
whom owns 627 of them. Splitting removes that repetition. Host attributes are
consistent within a host for all but about 30 hosts out of 182,024, where the
ten cities appear to have been captured on different dates.

`reviews` uses a composite primary key because `review_id` is not unique. 160
values appear twice, always split across two listings that look like the same
property listed twice. `listing_id` leads the key so that one index serves the
primary key, the foreign key and every join.

---

## Method

### Loading

`Listings.csv` is loaded into a staging table whose columns are all text, with no
keys and no constraints, so nothing can be rejected or silently converted on the
way in. Every type conversion then happens in an `INSERT ... SELECT` where it is
visible and can be argued with. `Reviews.csv` needs no transformation and loads
directly.

### Four ways this file fails silently

Each of these produced a successful load with wrong data, and none raised an
error. They are documented in the load script header alongside the clause that
fixes each one.

**Encoding.** The file is UTF-8 but contains a handful of invalid bytes.
Declaring `utf8mb4` makes MySQL reject the entire load. Declaring `latin1`
instead succeeds and mangles every accented character. `CHARACTER SET binary`
copies the bytes without validating them, which is correct because the target
columns are already utf8mb4.

**Double encoding in the source.** Text that was UTF-8, read as Latin-1, and
re-saved as UTF-8, so `pièces` is stored as `piÃ¨ces`. This affects 38,328 of
279,712 listing names. Reversing one layer with
`CONVERT(CAST(CONVERT(col USING latin1) AS BINARY) USING utf8mb4)` restores them.
Only `name` and `host_location` are affected; every other text column is ASCII.

**Backslash escaping.** MySQL defaults to `ESCAPED BY '\\'`, which CSV does not
use. A backslash inside a listing name swallows the comma after it and shifts
every remaining field on that row left by one. Four rows were affected, found
only because `'t'` turned up in a numeric column.

**Empty strings, not nulls.** Missing values arrive as `''`. Loaded straight into
a `DATE` or `DECIMAL` column they become zero values rather than nulls, so every
nullable column passes through `NULLIF(col, '')`.

### Verification

`03_verify_load.sql` states an expected result above every check: row counts,
field alignment, encoding, null conversion, boolean conversion, referential
integrity, and a set of known data characteristics recorded so that a future
reload changing them gets noticed.

---

## Findings

<!-- Fill in as each question is answered. -->

---

## Notes and assumptions

<!-- Record how outlier prices were handled, which listings were excluded and
     why, and the exchange rates used with the date they were taken. -->
