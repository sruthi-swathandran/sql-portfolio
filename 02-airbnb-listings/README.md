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

### 1. How do the ten city markets compare on price?

**Ranking by mean and ranking by median give different answers, and the gap
between them says more than either ranking does.**

| City | Median | Mean | Mean ÷ median | 25th to 75th percentile |
|---|---:|---:|---:|---|
| New York | $99.00 | $142.95 | 1.44 | $60 to $151 |
| Paris | $96.42 | $136.45 | 1.42 | $71 to $145 |
| Sydney | $92.89 | $171.86 | 1.85 | $57 to $170 |
| Rome | $78.34 | $126.71 | 1.62 | $54 to $119 |
| Cape Town | $70.99 | $159.72 | 2.25 | $43 to $146 |
| Rio de Janeiro | $50.19 | $133.14 | **2.65** | $28 to $99 |
| Hong Kong | $49.76 | $96.19 | 1.93 | $32 to $90 |
| Bangkok | $36.39 | $68.75 | 1.89 | $23 to $63 |
| Istanbul | $34.84 | $73.64 | 2.11 | $21 to $62 |
| Mexico City | $31.97 | $55.36 | 1.73 | $19 to $54 |

Rio is the clearest illustration. Its mean of $133 sits alongside Paris at $136,
so on averages Rio looks like a European capital. Its median is $50 against
Paris at $96, so the typical Rio listing costs half the typical Paris one.
Anyone comparing average prices would reach exactly the wrong conclusion.

Cape Town moves the same way: second most expensive city by mean, fifth by
median.

**The skew is uneven, and that unevenness is itself the result.** Paris at 1.42
and New York at 1.44 are the least skewed markets; Rio at 2.65, Cape Town at
2.25 and Istanbul at 2.11 the most. The interquartile spreads agree. Paris runs
$71 to $145, a factor of 2.0. Rio runs $28 to $99, a factor of 3.5.

That shape is what you would expect if a small high-end segment aimed at
international visitors sits above a much larger budget segment, with little in
between. Paris and New York appear to have deep mid-markets that fill the gap;
Rio and Cape Town appear not to. This is a reading of the distribution rather
than a demonstrated fact, since nothing in the data identifies who a listing
serves.

Sydney is the exception to the pattern. Its 75th percentile of $170 is the
highest in the dataset, above New York's $151, while its median is only third.
Its expensive half is the most expensive anywhere and its cheap half is cheaper
than New York's.

*Query: [`analysis/01_city_price_comparison.sql`](./analysis/01_city_price_comparison.sql) ·
Results: [`results/01_city_price_comparison.csv`](./results/01_city_price_comparison.csv)*

### 2. Which neighbourhoods command the highest prices, and is it location?

**Half of Sydney's apparent location premium is property size. New York's is
real.**

Ranking neighbourhoods by nightly price answers what a guest pays. It does not
answer whether a location is expensive, because some areas rent whole houses
sleeping six while others rent studios. Ranking a second time by price per
person separates the two.

| City | Spread, nightly | Spread, per person | Size effect |
|---|---:|---:|---:|
| New York | 6.15 | **3.58** | 1.72 |
| Cape Town | 3.70 | 3.21 | 1.15 |
| Sydney | 6.28 | 2.87 | **2.19** |
| Rio de Janeiro | 3.30 | 2.86 | 1.16 |
| Mexico City | 2.65 | 2.29 | 1.16 |
| Bangkok | 2.65 | 2.10 | 1.26 |
| Istanbul | 3.41 | 1.87 | 1.82 |
| Paris | 2.06 | 1.82 | 1.14 |
| Hong Kong | 3.12 | 1.74 | 1.79 |
| Rome | 1.98 | 1.53 | 1.29 |

Spread is the dearest neighbourhood's median divided by the cheapest. Size
effect is how much the nightly figure overstates the per-person one.

On nightly prices Sydney looks like the city where location matters most, at
6.28 against New York's 6.15. Controlling for size, Sydney falls to 2.87 while
New York holds 3.58. Istanbul and Hong Kong each drop three places for the same
reason, both with size effects near 1.8.

Cape Town moves the other way. Its size effect of 1.15 means almost all of its
3.70 nightly spread survives, taking it from third to second. Location matters
nearly as much there as in New York, which the nightly figures obscured.

**Sydney's Pittwater shows the mechanism.** Its median is $308.87 against
$92.89 for the rest of Sydney, a factor of 3.3. But 92% of Pittwater listings
are whole homes sleeping 5.6 people, against 59% and 3.2 for the city. Per
person the premium is $64.51 against $36.38, a factor of 1.8. Pittwater is
genuinely expensive; it is not 3.3 times expensive.

Its rank does not change, though, holding first place on both measures. The
correction changed the size of the premium, not the ordering.

**Rome shows the reverse.** Six neighbourhoods share a median of exactly $72.32
a night. Per person they run from $25.31 down to $20.09, spreading across ranks
2 to 13. The tie was not neighbourhoods being equally priced. It was hosts
converging on the same round number while renting very different properties.

That tie is also why the query uses `RANK` rather than `ROW_NUMBER`, which would
have ordered the six arbitrarily and concealed it.

**Limitation.** Neighbourhood granularity is not comparable across cities. New
York is divided into 59 qualifying areas and Rome into 15, one of which holds
14,869 listings, over half the city. A market carved into many small units will
show more spread than the same market carved into few large ones. Comparing per
person removes the property-size confound; it does not remove the geographic
one. Neighbourhoods with fewer than 100 listings are excluded, leaving 272 of
660.

*Query: [`analysis/02_neighbourhood_ranking.sql`](./analysis/02_neighbourhood_ranking.sql) ·
Results: [`results/02_neighbourhood_ranking.csv`](./results/02_neighbourhood_ranking.csv),
[`results/02_neighbourhood_spread.csv`](./results/02_neighbourhood_spread.csv)*

---

## Notes and assumptions

<!-- Record how outlier prices were handled, which listings were excluded and
     why, and the exchange rates used with the date they were taken. -->
