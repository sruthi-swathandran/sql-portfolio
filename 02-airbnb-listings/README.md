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

### 3. Which room types dominate each market, and what do they cost?

**A whole home costs roughly twice a private room, and almost all of that is
beds rather than privacy.**

| City | Whole homes | Sleeps, whole / private | Premium nightly | Premium per person |
|---|---:|---|---:|---:|
| Sydney | 60.5% | 4.2 / 1.9 | 2.59× | **1.33×** |
| Hong Kong | 36.5% | 3.6 / 2.3 | 2.30× | 1.29× |
| New York | 52.4% | 3.6 / 1.9 | 2.33× | 1.21× |
| Cape Town | 74.1% | 4.4 / 2.4 | 2.07× | 1.19× |
| Mexico City | 52.6% | 3.9 / 2.0 | 2.37× | 1.12× |
| Istanbul | 50.7% | 4.1 / 2.2 | 2.15× | 1.10× |
| Rio de Janeiro | 72.5% | 4.8 / 2.4 | 2.19× | 1.04× |
| Paris | 85.7% | 3.2 / 2.0 | 1.55× | **1.00×** |
| Bangkok | 54.9% | 3.4 / 2.8 | 1.19× | **0.93×** |
| Rome | 62.4% | 4.5 / 2.4 | 1.57× | **0.87×** |

Nightly premiums of two to two and a half times shrink to between 0.87 and 1.33
once occupancy is accounted for. Sydney's whole homes sleep 2.2 times as many
people and cost 2.6 times as much, so the difference per head is 1.33.

Paris lands on exactly 1.00: a whole apartment and a private room cost the same
per person, and the entire nightly gap is beds.

**Rome and Bangkok invert.** In Rome a whole home costs 13% less per person than
a private room, so four friends taking an apartment each pay less than they
would taking rooms. Rome's 4.6% hotel-room share and 32.3% private-room share
point at guesthouse and bed-and-breakfast stock priced per room for two, against
whole apartments sleeping 4.5. That is an explanation the data is consistent
with rather than one it establishes.

What survives the correction is the genuine price of exclusivity, and it runs
from nothing in Paris to 33% in Sydney. The headline that a whole home costs
twice a private room is true and tells you almost nothing.

#### Market composition

Hong Kong is the only city where private rooms outnumber whole homes, at 54.9%
against 36.5%, and its 6.1% share of shared rooms is three times any other
market's. Paris sits at the opposite end with 85.7% whole homes and 11.6%
private rooms.

`property_type` adds little beyond this. Its top ten values cover 88.4% of
listings and 105 of its 144 categories hold fewer than 100 each. The two
dominant values, `Entire apartment` at 138,989 and `Private room in apartment`
at 47,322, are `room_type` with a building noun attached.

**Limitation.** Occupancy is taken from `accommodates`, the maximum the host
advertises, not from how many people actually stay. A whole home sleeping four
booked by a couple costs them the nightly rate, not the per-person figure. Both
columns are reported for that reason.

*Query: [`analysis/03_room_type_by_city.sql`](./analysis/03_room_type_by_city.sql) ·
Results: [`results/03_room_type_by_city.csv`](./results/03_room_type_by_city.csv)*

### 4. What does each additional guest add to the price?

**Nothing smooth. Price steps with the number of bedrooms, so an extra guest is
either almost free or expensive depending on whether a room comes with them.**

Whole homes only, since a private room sleeping four is a different product from
an apartment sleeping four.

| Guests | Listings | Median | Step | Per person | Modal bedrooms |
|---:|---:|---:|---:|---:|---|
| 1 | 2,939 | $57.85 | | $57.85 | 1 |
| 2 | 61,349 | $74.59 | +28.9% | $37.29 | 1 |
| 3 | 20,582 | $77.41 | **+3.8%** | $25.80 | 1 |
| 4 | 50,946 | $96.76 | +25.0% | $24.19 | **2** |
| 5 | 12,523 | $108.48 | **+12.1%** | $21.70 | 2 |
| 6 | 18,209 | $143.39 | +32.2% | $23.90 | **3** |
| 7 | 3,527 | $161.79 | **+12.8%** | $23.11 | 3 |
| 8 | 5,967 | $232.23 | +43.5% | $29.03 | **4+** |

Every large step lands where the modal bedroom count changes: three to four,
five to six, seven to eight. Every small step stays inside a tier.

Sleeping three costs 3.8% more than sleeping two because 78.9% of both are
one-bedroom flats with a sofa. Sleeping four costs 25% more because half of them
have become two-bedrooms. The unit being priced is the room, not the guest.

The listing counts point the same way. Even capacities dominate, 61,349 sleeping
two against 20,582 sleeping three, 50,946 sleeping four against 12,523 sleeping
five. Beds come in pairs, so an odd capacity is usually an even configuration
with something folded out.

**Method note: an average nearly buried this.** `AVG(bedrooms)` rises in smooth
increments of 0.34, 0.52, 0.41 and 0.45, which appears to rule bedrooms out as
the cause. It does not, because every capacity level is a blend of tiers and a
mean over a mixture slides even when the groups underneath it jump. Listings
sleeping five are 16.9% one-bedroom, 60.0% two-bedroom and 21.3% three-bedroom,
averaging 2.08 and looking like a midpoint.

The distribution shows what the mean concealed: 96.4% of two-guest listings are
one-bedroom, and by four guests 49.6% are two-bedroom. A mean is the wrong
instrument for detecting a step.

**Price per person is U-shaped, not falling.** It drops from $57.85 for a solo
place to $21.70 at five guests, then climbs back to $29.03 at eight. Economies
of scale run out around five. Above that, larger properties are a different
product rather than a bigger one.

#### Does it hold across cities?

Eight of ten confirm the pattern, comparing the small step against the large one
within each market separately.

| City | 2 to 3 | 3 to 4 |
|---|---:|---:|
| Cape Town | 4.7% | **62.5%** |
| Rio de Janeiro | 10.0% | 36.4% |
| Sydney | 7.2% | 34.3% |
| Bangkok | 5.6% | 28.1% |
| Mexico City | 0.1% | 24.9% |
| Paris | 14.3% | 23.8% |
| Rome | 0.0% | 20.0% |
| New York | 1.6% | 17.3% |
| Istanbul | 18.8% | 17.9% |
| Hong Kong | **43.3%** | 28.6% |

In Rome, Mexico City and New York, a third guest costs essentially nothing:
0.0%, 0.1% and 1.6%. Rome's two medians are identical at $72.32, the round
number clustering from finding 2 showing up again.

Istanbul is flat, 18.8 against 17.9, a gap too small to call.

**Hong Kong reverses**, and it fits everything else known about that market. It
is the densest in the dataset, the only one where private rooms outnumber whole
homes, with the smallest whole-home stock at 3.6 average occupancy. Where space
is scarcest there is no spare sofa, so a third guest needs real floor area. That
is a reading consistent with the other Hong Kong results rather than a
demonstrated mechanism.

**Limitations.** `bedrooms` is null for 29,435 listings, about 10.5%, and those
rows are excluded from the distribution query only. Capacity is capped at eight
because counts thin out above that. Median price per guest describes what is
advertised, not what anyone pays: a place sleeping four booked by a couple costs
them the nightly rate.

*Query: [`analysis/04_price_by_capacity.sql`](./analysis/04_price_by_capacity.sql) ·
Results: [`results/04_price_by_capacity.csv`](./results/04_price_by_capacity.csv),
[`results/04_bedroom_distribution.csv`](./results/04_bedroom_distribution.csv),
[`results/04_capacity_step_by_city.csv`](./results/04_capacity_step_by_city.csv)*

### 5. Do superhosts charge a premium?

**No. In nine of ten cities the badge earns nothing or costs money.**

Compared per person, then again within whole homes only, since a superhost
renting a house against a regular host renting a studio would show a premium
that is really about size.

| City | Superhost share | Ratio, all listings | Ratio, whole homes |
|---|---:|---:|---:|
| Paris | 12.6% | 1.17 | **1.17** |
| Mexico City | 31.9% | 1.01 | 1.04 |
| Cape Town | 24.1% | 0.98 | 1.00 |
| Hong Kong | 18.2% | 0.83 | **1.00** |
| Istanbul | 13.2% | 0.96 | 0.97 |
| Rome | 25.9% | 0.98 | 0.96 |
| Sydney | 12.1% | 1.00 | 0.95 |
| Bangkok | 20.1% | 0.83 | 0.89 |
| New York | 18.8% | 0.93 | **0.84** |
| Rio de Janeiro | 17.1% | 0.72 | **0.73** |

A ratio above 1 means superhosts charge more per person for comparable property.

Paris is the only market with a real premium at 17%. Four cities sit within a
few points of parity. Five show a discount, with Rio at 27% and New York at 16%.

**Two cities move when room type is controlled for.** Hong Kong's apparent 0.83
becomes exactly 1.00, so its superhosts were not undercutting anyone, they were
renting a different mix. New York's discount grows from 0.93 to 0.84, so its
pooled figure was hiding a real one.

The mix runs the opposite way to the obvious guess. Superhosts hold 70.9% whole
homes against 63.8% for regular hosts, and whole homes cost the same or slightly
more per person (finding 3), so composition should have made superhosts look
*more* expensive. That it did not strengthens the discount rather than
explaining it.

**A plausible reason is that the causality runs backwards.** Superhost status
requires a minimum number of completed stays as well as a high rating. Pricing
below the market is a direct route to that booking volume. On that reading the
badge does not let a host charge more; charging less helps a host earn the
badge.

This data cannot test that. There are no booking counts and no record of when a
host gained the status, so it is the obvious candidate explanation rather than a
finding.

#### The rating comparison is close to circular

| City | Superhost rating | Regular rating |
|---|---:|---:|
| Sydney | 97.4 | 92.4 |
| Cape Town | 97.4 | 93.0 |
| Mexico City | 97.3 | 93.1 |
| Rio de Janeiro | 97.3 | 93.7 |
| Paris | 96.9 | 92.3 |
| New York | 96.9 | 92.8 |
| Rome | 96.8 | 92.0 |
| Bangkok | 96.6 | 91.5 |
| Istanbul | 96.5 | 89.3 |
| Hong Kong | 95.8 | 88.4 |

Superhosts rate higher everywhere, by four to seven points. Airbnb awards the
status partly for maintaining a high rating, so this measures the eligibility
rule rather than host behaviour. It is worth reporting as confirmation that the
flag means what it claims, and worth not reporting as a discovery.

**Limitations.** Per-person pricing and the whole-home restriction control for
size and room type, not for location within a city or for property quality. A
superhost renting a comparable flat in a cheaper neighbourhood would still show
as a discount here. Superhost status is a snapshot with no date attached, so
nothing distinguishes a host who has held it for years from one who gained it
last month.

*Query: [`analysis/05_superhost_premium.sql`](./analysis/05_superhost_premium.sql) ·
Results: [`results/05_superhost_by_city.csv`](./results/05_superhost_by_city.csv),
[`results/05_superhost_room_mix.csv`](./results/05_superhost_room_mix.csv),
[`results/05_superhost_entire_only.csv`](./results/05_superhost_entire_only.csv)*

---

## Notes and assumptions

<!-- Record how outlier prices were handled, which listings were excluded and
     why, and the exchange rates used with the date they were taken. -->
