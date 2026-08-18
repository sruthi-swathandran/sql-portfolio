# Maven Fuzzy Factory: e-commerce funnel and channel analysis

Analysis of an online teddy bear retailer's first three years of trading, working
from raw website traffic logs through to order and refund data.

The business questions here are the ones an e-commerce analyst is actually asked:
where is traffic coming from, how much of it converts, which channels are worth
the spend, and did the new product launches work.

## Headline findings

- 37.9% of visitors who reach the billing page never complete the order, roughly $1.18M of abandoned purchases. [Finding 5](#5-where-do-users-drop-out-of-the-conversion-funnel)
- Mobile converts at a third of desktop's rate, worth about $477,000 in orders the site never received. [Finding 7](#7-do-mobile-and-desktop-visitors-convert-differently-and-has-the-gap-changed-over-time)
- Mr Fuzzy's refund rate tripled for exactly two months in 2014 and no other product moved, which points at a defective batch costing around $9,900. [Finding 10](#10-which-product-has-the-highest-refund-rate-and-does-any-product-show-a-quality-problem-in-a-specific-period)
- No product launch changed basket size. A cross-sell feature added in September 2013 did, once a cheap enough product existed to attach to. [Finding 6](#6-what-was-the-measurable-impact-of-each-new-product-launch)
- 61% of the brand campaign's apparent advantage over nonbrand is who it reaches rather than what it does. [Finding 8](#8-is-the-brand-campaign-worth-the-spend-compared-with-nonbrand)
- Only 1.86% of customers ever buy twice, and 90% of returning-visitor revenue is first purchases that took more than one visit to close. [Finding 9](#9-do-returning-visitors-convert-better-than-first-time-visitors-and-what-share-of-revenue-do-they-drive)

---

## Business questions

1. How have website sessions and order volume trended over time?
2. What is the session-to-order conversion rate, and how has it moved?
3. Which marketing channels drive the most traffic, and which drive the most *revenue*?
4. How have revenue per order and revenue per session evolved?
5. Where do users drop out of the conversion funnel?
6. What was the measurable impact of each new product launch?
7. Do mobile and desktop visitors convert differently, and has the gap changed over time?
8. Is the brand campaign worth the spend, compared with nonbrand?
9. Do returning visitors convert better than first-time visitors, and what share of revenue do they drive?
10. Which product has the highest refund rate, and does any product show a quality problem in a specific period?

---

## Data

**Source:** [Maven Analytics Data Playground](https://mavenanalytics.io/data-playground),
"Toy Store E-Commerce Database"
**Licence:** free for educational and portfolio use
**Period:** 19 March 2012 to 19 March 2015 (final month partial)

Download the archive and place the six CSVs in `data/`. They are not committed
to this repository.

### Tables

| Table | Rows | Description |
|-------|------|-------------|
| `website_sessions` | 472,871 | One row per visit, with UTM source/campaign/content, device type, and referrer |
| `website_pageviews` | 1,188,124 | One row per page viewed, linked to a session |
| `orders` | 32,313 | One row per order, linked to the session that produced it |
| `order_items` | 40,025 | One row per line item, with price and cost of goods |
| `order_item_refunds` | 1,731 | Refunds issued against individual line items |
| `products` | 4 | Product catalogue with launch dates |

### Model

`website_sessions` → `website_pageviews` on `website_session_id`
`website_sessions` → `orders` on `website_session_id`
`orders` → `order_items` on `order_id`
`order_items` → `order_item_refunds` on `order_item_id`
`order_items` → `products` on `product_id`

---

## Method

### Schema

Six tables with seven foreign keys, built to mirror the source files rather than
to denormalise for convenience. Identifiers are `INT UNSIGNED` rather than
`BIGINT`, which halves the storage on 1.7 million rows and matters because foreign
key columns must share the exact type of the key they reference. Money is
`DECIMAL(10,2)`, never `FLOAT`, since binary floating point cannot represent values
like 49.99 exactly and small errors accumulate across 40,025 line items.

The four UTM columns and `http_referer` in `website_sessions` are deliberately
nullable. 17.6% of sessions have no campaign tag, and that absence is the organic
and direct traffic, so it carries meaning and should not be filled with a
placeholder.

### Loading and verification

Tables load parent-first so foreign keys are satisfied at every step. Two traps in
the source files are worth recording because neither raises an error.

The CSVs store missing values as the four-character string `NULL` rather than as
empty fields, so `LOAD DATA` would store the literal text. Each affected column is
read into a user variable and passed through `NULLIF(@var, 'NULL')`.

`website_pageviews.csv` uses LF line endings while the other five use CRLF.
Loading it with `LINES TERMINATED BY '\r\n'` inserts zero rows and reports success.
That was caught only by counting rows afterwards.

`03_verify_load.sql` states the expected result above each check before running
it: row counts per table, the count of literal `NULL` strings remaining, and the
character length of every product name to confirm no trailing carriage returns
survived. A load that completes without erroring can still be wrong, and these are
the checks that catch it.

### Indexes

Eight indexes, created after loading rather than before, since maintaining them
during a 1.19 million row insert slows the load for no benefit. Columns with two
distinct values, `device_type` and `is_repeat_session`, are deliberately not
indexed: the optimiser will scan rather than use an index that matches half the
table. `idx_sessions_utm` is kept despite low cardinality because it supports
`GROUP BY` sorting rather than lookups.

### Analytical approach

Four habits recur through the findings and are worth naming, because each one
changed a conclusion at least once.

Partial periods are compared like for like. 2012 begins on 19 March and 2015 ends
on 19 March, so neither is a full year. Restricting every year to 1 January
through 19 March reversed the apparent decline in average order value in finding 4
and reversed the direction of mobile traffic share in finding 7.

Composition is separated from performance. When a group looks better on some
metric, the first question is whether it is composed differently rather than
performing differently. This removed 61% of brand's apparent advantage in
finding 8 and 90% of the apparent loyalty effect in finding 9.

Mechanically bounded metrics are preferred for attribution. Items per order cannot
exceed 1.000 while a single product is on sale, so trend and seasonality are
incapable of producing movement in it. That is what makes the September 2013
cross-sell finding defensible where a conversion-rate comparison would not have
been.

Events are dated by when they happened, not when they were recorded. Refunds are
keyed on order date rather than refund date, because a nine-day average lag
shifts a batch defect into the following month and points the investigation at the
wrong inventory.

---

## Findings

### 1. How have website sessions trended over time?

**Traffic grew across the whole period, with a strong Q4 seasonal peak.**

Sessions roughly doubled year over year in every month. January went from 6,401
in 2013 to 14,825 in 2014 to 25,337 in 2015.

A month-on-month view looks like decline after December 2014. It isn't. That is
the Q4 peak followed by a partial final month, since the data stops on
19 March 2015.

*Query: [`analysis/01_traffic_trends.sql`](./analysis/01_traffic_trends.sql) ·
Results: [`results/01_monthly_traffic.csv`](./results/01_monthly_traffic.csv)*

---

### 2. What is the session-to-order conversion rate, and how has it moved?

**Conversion improved 2.7 times, from about 3.2% to about 8.7%. That is a bigger
commercial win than the traffic growth.**

Overall conversion across the full period was 6.83% (32,313 orders from 472,871
sessions), but that average hides steady month-on-month improvement.

Traffic growth costs money in ad spend. Conversion improvement is free margin on
traffic already paid for. The two compound: roughly 13 times more traffic at
roughly 2.7 times better conversion took monthly orders from 60 to 2,068.

Unlike the traffic figures, the partial final month does not distort this. A rate
is a ratio, so 18 days of sessions over 18 days of orders is still valid.

*Query: [`analysis/02_conversion_rate.sql`](./analysis/02_conversion_rate.sql) ·
Results: [`results/02_monthly_conversion.csv`](./results/02_monthly_conversion.csv)*

---

### 3. Which marketing channels drive the most traffic, and which drive the most revenue?

**Paid ads bring 82% of traffic but the least value per session. Organic search
is worth 13% more per visit, and it costs nothing.**

| Channel | Sessions | Conversion | Revenue | Revenue/session |
|---|---:|---:|---:|---:|
| Paid | 389,543 (82%) | 6.72% | $1,567,077 | $4.02 |
| Organic search | 43,411 (9%) | 7.51% | $196,809 | $4.53 |
| Direct | 39,917 (8%) | 7.15% | $174,624 | $4.37 |

Two things stop this being a simple "spend less on ads" conclusion.

The free channels are small and cannot be bought. Organic and direct together are
17.6% of sessions. Organic traffic is earned through content and reputation over
years, not purchased. Paid acquired the other 82%, and without it this business is
a fifth of its size. A channel can be more efficient per visit and still be the
wrong one to concentrate on.

Last-touch attribution also undercredits paid. A visitor who sees an ad, leaves,
and returns later by typing the URL is recorded as Direct. The ad created that
session but gets no credit for it. Some share of the organic and direct traffic is
likely downstream of paid awareness, and this data cannot separate the two.

Limitation: the dataset contains no advertising cost, so return on ad spend cannot
be calculated. Revenue per session measures traffic quality, not profitability.

*Query: [`analysis/03_channel_performance.sql`](./analysis/03_channel_performance.sql) ·
Results: [`results/03_channel_performance.csv`](./results/03_channel_performance.csv)*

---

### 4. How have revenue per order and revenue per session evolved?

**Revenue per session grew 2.56 times, from $2.07 to $5.30. Most of that came from
better conversion, not bigger baskets.**

| Year | Sessions | Orders | Revenue/order | Revenue/session |
|---|---:|---:|---:|---:|
| 2012 | 62,470 | 2,586 | $49.99 | $2.07 |
| 2013 | 112,781 | 7,447 | $52.81 | $3.49 |
| 2014 | 233,422 | 16,860 | $63.80 | $4.61 |
| 2015 | 64,198 | 5,420 | $62.80 | $5.30 |

Revenue per session is the product of conversion rate and average order value.
Splitting the 2.56 times growth: conversion contributed 2.04, order value 1.26.
Persuading more visitors to buy mattered roughly twice as much as persuading
buyers to spend more. Conversion gains are also free, where order value gains
usually require new products or pricing changes.

2012's average order value of exactly $49.99 is a useful sanity check. That is the
price of The Original Mr. Fuzzy, the only product on sale that year, so every 2012
order was a single bear. Order value only starts rising after the second product
launches in January 2013, which points at cross-selling rather than pricing.

Neither 2012 nor 2015 is a full year, so the table above is not a straight
year-on-year comparison. Restricting each year to 1 January through 19 March, so
that all of them match 2015's coverage:

| Period | Conversion | Revenue/order | Revenue/session |
|---|---:|---:|---:|
| 2013 Q1 | 6.40% | $52.24 | $3.34 |
| 2014 Q1 | 6.53% | $61.84 | $4.04 |
| 2015 Q1 | 8.44% | $62.80 | $5.30 |

Like-for-like, revenue per session rose 31% between 2014 and 2015. That is larger
than the full-year table implies, because Q1 is seasonally weaker than the year as
a whole. Average order value also rose on this basis, from $61.84 to $62.80, where
the full-year comparison misleadingly showed a decline from $63.80.

2012 is excluded from the like-for-like table because the site launched on
19 March 2012, so its January to March window contains a single day of trading.

*Query: [`analysis/04_revenue_metrics.sql`](./analysis/04_revenue_metrics.sql) ·
Results: [`results/04_monthly_revenue_metrics.csv`](./results/04_monthly_revenue_metrics.csv)*

---

### 5. Where do users drop out of the conversion funnel?

**The checkout leaks hardest. 37.9% of visitors who reach the billing page never
complete the order, roughly $1.18M of abandoned purchases.**

| Step | Sessions | Step conversion | Lost here |
|---|---:|---:|---:|
| Landing page | 472,871 | n/a | n/a |
| Products page | 261,231 | 55.2% | 211,640 |
| Product detail | 210,214 | 80.5% | 51,017 |
| Cart | 94,953 | 45.2% | 115,261 |
| Shipping | 64,484 | 67.9% | 30,469 |
| Billing | 52,058 | 80.7% | 12,426 |
| Thank you | 32,313 | 62.1% | 19,745 |

Three steps have a claim to being the worst, depending on the measure. Product
detail → cart has the poorest conversion at 45.2%. Landing → products loses the
most people in absolute terms, 211,640. Billing → thank you loses the fewest of
the three, but the most valuable ones.

The billing step is the priority. Those 19,745 sessions had chosen a product,
entered shipping details, and reached payment. At the average order value of
$59.99 they represent about $1.18M of abandoned revenue, against $1.94M actually
earned.

The volume argument does not overturn this. One percentage point of improvement at
billing yields about 521 extra orders; one percentage point off landing-page
drop-off yields about 586, since only about 12.4% of product-page viewers
eventually order. The returns are comparable, but a point at checkout comes from
contained fixes like shorter forms, showing shipping costs earlier, and more
payment options. A point at the landing page needs better targeting and page
design across the whole acquisition funnel, which is far more work for the same
return.

Method note: each step counts distinct sessions that reached that page at any
point, not strict sequential progression. A session that revisited an earlier page
still counts once per step. The final step reproduces the order count exactly
(32,313), so the simplification does not distort the totals.

*Query: [`analysis/05_conversion_funnel.sql`](./analysis/05_conversion_funnel.sql) ·
Results: [`results/05_conversion_funnel.csv`](./results/05_conversion_funnel.csv)*

---

### 6. What was the measurable impact of each new product launch?

**Launching a product did almost nothing on its own. The change that mattered was
a cross-sell feature added in September 2013, which then needed a cheap product to
work against.**

Items per order sat at exactly 1.000 from March 2012 to August 2013. With one
product on sale that is mechanically guaranteed, but it stayed there for eight
months after a second product launched.

| Date | Items/order | Event |
|---|---:|---|
| Mar 2012 to Dec 2012 | 1.000 | Mr Fuzzy only |
| Jan 2013 | 1.000 | Forever Love Bear launches, no change |
| Feb to Aug 2013 | 1.000 | Two products, still nobody buys two |
| Sep 2013 | 1.010 | First movement. No product launched. |
| Oct to Dec 2013 | 1.042 → 1.089 | Attach rate builds |
| Feb 2014 | 1.131 → 1.320 | Hudson River Mini bear, $29.99 |
| Mar 2014 to Mar 2015 | ~1.350 | Stable at about 35% attach rate |

Orders here contain one or two items, never more, so items per order is really an
add-on attach rate. 1.000 means no order includes a second item; 2.000 would mean
every order does. The stable 1.350 is a 35% attach rate.

The January 2013 launch did nothing to basket size. Average order value rose from
$49.99 to $51.20, but purely through mix: some customers chose the more expensive
bear instead. Nobody bought two.

September 2013 is the change that isn't in the data. Items per order moves for the
first time in eighteen months, and no product launched that month. The capability
to add a second item must have appeared then. It is not recorded in `products`,
and it was not a discount, because every product sells at an identical price
whether it is the primary item or the add-on. The feature is visible only in its
effect.

February 2014 is when that feature met the right product.

| Product | Price | As primary | As add-on | % add-on |
|---|---:|---:|---:|---:|
| Hudson River Mini bear | $29.99 | 581 | 4,437 | 88.4% |
| Birthday Sugar Panda | $45.99 | 3,068 | 1,917 | 38.5% |
| Forever Love Bear | $59.99 | 4,803 | 993 | 17.1% |
| The Original Mr. Fuzzy | $49.99 | 23,861 | 365 | 1.5% |

The Hudson River bear sells 8 times more often as an add-on than as a main
purchase. It barely functions as a standalone product; it is the thing people tack
on. Among the three later products, the cheaper the item the more likely it is to
be an add-on. Mr Fuzzy is the exception because of its role rather than its price.
It is the destination product, 60% of all primary items, the thing customers
arrive intending to buy.

Why not a before/after comparison? Conversion rate rose after every launch, but
conversion was rising every month regardless, the Sugar Panda launched inside the
Q4 peak, and the Panda and Hudson River launches are only 55 days apart, so their
windows overlap. Items per order avoids all three problems: it cannot exceed 1.000
while a single product exists, so trend and seasonality are incapable of producing
the movement.

The before/after table demonstrates the problem it warns about:

| Launch | Window | Orders | Items/order | Avg order value |
|---|---|---:|---:|---:|
| Forever Love Bear | before | 1,495 | 1.000 | $49.99 |
| Forever Love Bear | after | 1,327 | 1.000 | $52.18 |
| Birthday Sugar Panda | before | 2,360 | 1.038 | $53.75 |
| Birthday Sugar Panda | after | 3,011 | 1.215 | $60.48 |
| Hudson River Mini bear | before | 2,894 | 1.096 | $56.15 |
| Hudson River Mini bear | after | 3,407 | 1.342 | $64.22 |

The Forever Love Bear shows fewer orders after launch, not because the product
failed but because its before window covers Christmas and its after window covers
January. Its items-per-order figure reads exactly 1.000 on both sides. That is the
one column seasonality cannot distort, and the one that answers the question. The
Sugar Panda's before window already reads 1.038, which confirms cross-selling had
begun ahead of that launch too.

*Query: [`analysis/06_product_launch_impact.sql`](./analysis/06_product_launch_impact.sql) ·
Results: [`results/06_monthly_items_per_order.csv`](./results/06_monthly_items_per_order.csv),
[`results/06_product_mix.csv`](./results/06_product_mix.csv),
[`results/06_launch_windows.csv`](./results/06_launch_windows.csv)*

---

### 7. Do mobile and desktop visitors convert differently, and has the gap changed over time?

**Mobile converts at roughly a third of desktop's rate, 3.09% against 8.50%. That
is worth about $477,000 in orders the site never received.**

| Device | Sessions | Share | Conversion | Avg order value | Revenue/session |
|---|---:|---:|---:|---:|---:|
| Desktop | 327,027 | 69.2% | 8.50% | $59.91 | $5.09 |
| Mobile | 145,844 | 30.8% | 3.09% | $60.50 | $1.87 |

Average order value is where this gets interesting. Mobile's is $60.50 against
desktop's $59.91, very slightly higher. Mobile visitors spend the same when they
buy. They just buy far less often.

That rules out one explanation. If mobile users were picking cheaper products, the
problem would be merchandising. They aren't, so it sits earlier: they leave before
purchasing at all, which points at the checkout and at usability on small screens.

#### Has the gap changed?

The two obvious ways to measure it disagree.

| Year | Desktop | Mobile | Gap (points) | Gap (ratio) |
|---|---:|---:|---:|---:|
| 2012 | 5.05% | 1.47% | 3.59 | 3.45× |
| 2013 | 8.02% | 3.12% | 4.90 | 2.57× |
| 2014 | 9.18% | 3.31% | 5.87 | 2.77× |
| 2015 | 10.59% | 3.50% | 7.10 | 3.03× |

In percentage points the gap nearly doubled. As a ratio it narrowed slightly. Both
readings are correct. Desktop conversion improved 2.10 times over the period and
mobile improved 2.38 times, so mobile improved faster, but from so far behind that
proportional gains still widen the absolute distance. Two people earning ₹100 and
₹1,000 who each get a 10% rise have improved equally, and the distance between
them has grown by ₹90.

So mobile has not been neglected. Whatever lifted conversion worked on both
devices, marginally better on mobile. But at this rate mobile never catches up,
because closing an absolute gap requires improving substantially faster, not
slightly faster.

#### Mobile's share of traffic is not rising steadily

Across the two complete years, mobile grew from 28.9% of sessions in 2013 to 33.4%
in 2014. Restricting every year to 1 January through 19 March, so all three are
comparable with 2015's coverage, gives a different picture.

| Q1 window | Total sessions | Mobile share |
|---|---:|---:|
| 2013 | 17,251 | 25.6% |
| 2014 | 41,291 | 39.8% |
| 2015 | 64,198 | 30.3% |

Mobile share climbed steeply into early 2014, then dropped 9.5 points by early
2015. Those windows hold 41,291 and 64,198 sessions, so the movement is not
sampling noise.

Q1 also turns out to be a high-mobile quarter rather than a low one. Q1 2014's
39.8% sits well above that year's 33.4% full-year figure. The dip visible in the
full-year series is therefore real, not an artefact of the shortened final window.

Nothing in this data explains why the reversal happened, and it does not change
the conclusion either way. At around 30% of traffic and a third of desktop's
conversion, mobile is a large and persistent problem whichever direction its share
is moving.

#### What it costs

At desktop's conversion rate, 145,844 mobile sessions would have produced about
12,400 orders rather than the 4,508 recorded. That is roughly 7,900 missing
orders, or about $477,000 at mobile's average order value.

Finding 5 put abandoned checkout at around $1.18M, so this is the smaller of the
two. They may also be the same problem counted twice: a checkout that works badly
on small screens would show up in both numbers.

#### Connection to finding 4

Q1 revenue per session runs below the full-year figure, and device mix explains
part of it. Applying 2014's device-level revenue per session ($5.86 desktop, $2.11
mobile) to Q1's 39.8% mobile mix instead of the year's 33.4% accounts for about
$0.24 of Q1 2014's $0.57 shortfall. The rest is lower conversion within each
device separately. Q1 is weaker partly because more of its traffic arrives on the
device that converts worst.

Limitation: `device_type` records only `desktop` or `mobile`. Tablets, if the
dataset contains any, are folded into one of those two and there is no way to tell
which. Operating system, screen size and browser are not recorded, so the analysis
cannot go past the binary split.

*Query: [`analysis/07_device_performance.sql`](./analysis/07_device_performance.sql) ·
Results: [`results/07_device_overall.csv`](./results/07_device_overall.csv),
[`results/07_device_by_year.csv`](./results/07_device_by_year.csv),
[`results/07_device_mix.csv`](./results/07_device_mix.csv),
[`results/07_device_mix_like_for_like.csv`](./results/07_device_mix_like_for_like.csv)*

---

### 8. Is the brand campaign worth the spend, compared with nonbrand?

**Brand converts better than nonbrand, but 61% of that advantage is who brand
reaches rather than what the campaign does.**

| Campaign | Sessions | Conversion | Revenue | Rev/session |
|---|---:|---:|---:|---:|
| nonbrand | 337,615 | 6.71% | $1,349,978 | $4.00 |
| organic + direct (untagged) | 83,328 | 7.34% | $371,433 | $4.46 |
| brand | 41,243 | 7.79% | $194,840 | $4.72 |
| desktop_targeted | 5,590 | 5.15% | $18,516 | $3.31 |
| pilot | 5,095 | 1.08% | $3,743 | $0.73 |

Brand is small. 41,243 sessions is 10.6% of paid traffic and 10.1% of revenue.
Nonbrand carries 87% of paid traffic and 70% of all revenue.

Brand also converts less well than expected. Industry convention is that brand
campaigns convert two to three times better than nonbrand, since those visitors
already know the business and have decided to buy. Here brand converts 1.16 times
better.

#### Most of that 1.16 times is composition, not campaign performance

Repeat-visitor share explains it:

| Campaign | Sessions | Repeat | Repeat % |
|---|---:|---:|---:|
| brand | 41,243 | 26,224 | 63.6% |
| organic + direct | 83,328 | 52,329 | 62.8% |
| nonbrand | 337,615 | 0 | 0.0% |
| desktop_targeted | 5,590 | 0 | 0.0% |
| pilot | 5,095 | 0 | 0.0% |

Nonbrand is entirely first-time visitors. Nobody who already knows the business
arrives through a generic search ad, which makes sense: once you know the name you
search the name or type the URL. Brand, by contrast, is two thirds returning
visitors.

Returning visitors convert better regardless of which ad they clicked, so brand's
headline rate is measuring its audience rather than its effectiveness. Comparing
first-time sessions only:

| Comparison | Brand | Nonbrand | Gap |
|---|---:|---:|---:|
| All sessions | 7.79% | 6.71% | 1.08 pts |
| First-time visitors only | 7.13% | 6.71% | 0.42 pts |

Of the 1.08-point gap, 0.66 points comes from brand being 64% returning visitors.
0.42 points survives a like-for-like comparison. Composition accounts for 61% of
the apparent advantage.

#### What survives is smaller than it looks

Those 15,019 first-time brand sessions are people who typed the company name into
a search engine having never visited the site. They heard about it somewhere:
word of mouth, an ad on another device, something offline. They arrive with
purchase intent that a nonbrand searcher does not have.

So even the like-for-like comparison is tilted in brand's favour, and brand still
manages only 7.13% against 6.71%. People actively searching the business by name
convert barely better than people searching "teddy bear gift."

Brand traffic also resembles the free traffic closely on both measures available:
63.6% returning against 62.8%, and 7.79% conversion against 7.34%. That is the
pattern you would expect if brand ads and organic search were intercepting the
same person at the same point in the same journey, with only one of the two
costing anything.

Two caveats keep this short of proof. Brand does beat the free traffic slightly in
both strata (7.13% against 6.81% for first-timers, 8.16% against 7.66% for
returners), so the two populations are similar rather than identical, and this
data does not explain the residual. More importantly, there is no period where
brand ads were switched off, so the counterfactual does not exist here. The
evidence is consistent with a weak incremental effect but does not establish one.

#### The two short campaigns were tests

| Campaign | Window | Days | Conversion |
|---|---|---:|---:|
| pilot | 12 Jan to 15 Mar 2014 | 62 | 1.08% |
| desktop_targeted | 17 Aug to 27 Dec 2014 | 132 | 5.15% |

Neither is ongoing spend. Both ran for a few months and stopped, which reads like
experiments that were run and then killed, though the data records when they
ended and not why.

Pilot returned 55 orders from 5,095 sessions. It ran in Q1, which question 4
established is a seasonally weak quarter, but seasonality moves conversion by
fractions of a point and pilot came in six times below nonbrand. Desktop_targeted
had the opposite advantage, running through the Q4 peak, and still finished below
nonbrand's full-period average.

#### A timeline detail

Nonbrand's first session is 19 March 2012, the launch date. Brand, organic and
direct all begin on 25 March, six days later. Nobody can search a company's name
or return to a site that nobody has visited yet. Nonbrand had to run first to
create the audience the other channels then harvested, which is the same
incrementality point the numbers above make, visible in the timeline.

Limitations: the dataset has no advertising cost, so return on spend cannot be
calculated for any campaign. Exactly zero repeat sessions across 337,615 nonbrand
visits is too clean for real traffic, where some users clear cookies or switch
devices, so that perfect zero is a property of how this simulated dataset was
generated rather than a number to carry into the real world. The method still
transfers.

*Query: [`analysis/08_brand_vs_nonbrand.sql`](./analysis/08_brand_vs_nonbrand.sql) ·
Results: [`results/08_campaign_volume.csv`](./results/08_campaign_volume.csv),
[`results/08_campaign_performance.csv`](./results/08_campaign_performance.csv),
[`results/08_repeat_share.csv`](./results/08_repeat_share.csv),
[`results/08_conversion_by_repeat_status.csv`](./results/08_conversion_by_repeat_status.csv),
[`results/08_campaign_date_ranges.csv`](./results/08_campaign_date_ranges.csv)*

---

### 9. Do returning visitors convert better than first-time visitors, and what share of revenue do they drive?

**Returning visitors convert 18% better and drive 19% of revenue, but almost none
of that is loyalty. Only 1.86% of customers ever buy twice.**

| | Sessions | % of sessions | Conversion | Revenue | % of revenue | Rev/session |
|---|---:|---:|---:|---:|---:|---:|
| First-time | 394,318 | 83.4% | 6.64% | $1,566,275 | 80.8% | $3.97 |
| Returning | 78,553 | 16.6% | 7.83% | $372,235 | 19.2% | $4.74 |

The conversion gap is 1.18 times. Convention holds that returning visitors convert
two to three times better, so this is a weak effect, and it is the third time in
this analysis that a supposedly large effect has turned out small. Brand versus
nonbrand behaved the same way in finding 8.

Average order value is $60.54 for returning visitors against $59.86 for
first-timers. Practically identical, the same pattern as mobile against desktop in
finding 7. Whatever advantage returning visitors have shows up as buying more
often, never as spending more per order.

#### Counting people instead of visits changes the question

Sessions treat a four-visit user as four observations. Counting users instead:

| Sessions per user | Users | % of users |
|---:|---:|---:|
| 1 | 343,048 | 87.00% |
| 2 | 37,386 | 9.48% |
| 3 | 485 | 0.12% |
| 4 | 13,399 | 3.40% |

87% of visitors come once. What matters commercially, though, is whether they buy
again.

| Orders per customer | Customers | % of customers | Revenue | % of revenue |
|---:|---:|---:|---:|---:|
| 1 | 31,105 | 98.14% | $1,864,153 | 96.2% |
| 2 | 565 | 1.78% | $69,687 | 3.6% |
| 3 | 26 | 0.08% | $4,669 | 0.2% |

Repeat purchases account for 3.8% of revenue. Of 394,318 visitors, 31,696 ever
bought anything (8.0%) and 591 ever bought twice (0.15%).

#### Reconciling the two views

Returning visitors produce 19.2% of revenue, but repeat purchase is 3.8% of it.
Both numbers are correct, and the gap between them is the finding.

Second-and-later orders total (565 × 1) + (26 × 2) = 617 out of 32,313 orders.
Returning sessions produced 6,149 orders. So of those 6,149:

- roughly 617 were genuine second purchases
- roughly 5,532 were people making their first purchase on a return visit

Ninety percent of "returning visitor" revenue is first purchases that took more
than one visit to close. Those are people finishing something they had already
started, rather than customers coming back for a second bear.

That explains the conversion gap without invoking loyalty at all. A return visit
is a late stage of one considered purchase. Someone who browses on Tuesday and
buys on Thursday appears in this data as a first-time visitor and then a returning
visitor, and only the second visit gets credited with the sale. It is the
attribution problem from finding 3, one level down.

That also fits the product, since a teddy bear is usually a gift and most people
do not need a second one.

#### What follows from it

Retention spend would be misdirected here. There is no meaningful repeat-purchase
behaviour to protect, and 96% of revenue comes from customers who buy exactly
once. The return visit matters as part of closing a first sale, which makes it a
remarketing and consideration problem rather than a loyalty one.

The corollary is that this business depends almost entirely on acquisition and on
first-visit conversion, which is where findings 3, 5 and 7 all point.

#### Data quality note

The sessions-per-user distribution is not credible as behaviour. Visit frequency
decays in every consumer dataset ever measured, yet this one has 27 times more
four-session users (13,399) than three-session users (485). Nothing about buying a
teddy bear produces that shape.

Read alongside the exactly zero repeat sessions in nonbrand traffic from finding 8,
it confirms the data is simulated rather than observed. The counts are internally
consistent and every total ties out, so the analysis holds, but the frequency
tiers are not interpreted as behaviour here. Only the split between visited once
and returned at least once is treated as meaningful.

Limitations: users are identified by `user_id`, which in practice would be
cookie-based, so anyone clearing cookies or switching devices appears as a new
person. Real repeat-purchase rates would therefore be somewhat higher than 1.86%.
The dataset also covers three years, and a customer who bought in March 2015 has
had no opportunity to return, which understates repeat purchase at the end of the
window.

*Query: [`analysis/09_repeat_visitors.sql`](./analysis/09_repeat_visitors.sql) ·
Results: [`results/09_repeat_vs_first_time.csv`](./results/09_repeat_vs_first_time.csv),
[`results/09_sessions_per_user.csv`](./results/09_sessions_per_user.csv),
[`results/09_orders_per_customer.csv`](./results/09_orders_per_customer.csv)*

---

### 10. Which product has the highest refund rate, and does any product show a quality problem in a specific period?

**Two different answers. Birthday Sugar Panda has the worst standing rate at
6.04%, while Mr Fuzzy had a two-month batch failure in 2014 that cost about
$9,900.**

| Product | Items sold | Refunded | Refund rate | Refunded value |
|---|---:|---:|---:|---:|
| The Birthday Sugar Panda | 4,985 | 301 | 6.04% | $13,843 |
| The Original Mr. Fuzzy | 24,226 | 1,237 | 5.11% | $61,838 |
| The Forever Love Bear | 5,796 | 129 | 2.23% | $7,739 |
| The Hudson River Mini bear | 5,018 | 64 | 1.28% | $1,919 |

Refunds total $85,339, or 4.4% of revenue.

Rate and cost point at different products. Panda has the worst rate, but Mr Fuzzy
accounts for 72% of the money refunded, so a single point of improvement there is
worth more than eliminating Panda's refunds entirely. A ranking by rate alone
would send someone at the wrong product.

Every refund in this dataset is a full-item refund. Dividing refunded value by
refund count gives $45.99, $49.99, $59.99 and $29.99, matching the four list
prices exactly. Refund count and refund value therefore carry identical
information, and only one of them needs analysing.

#### August and September 2014

Grouping by order month exposes a discrete event in Mr Fuzzy:

| Month | Items sold | Refunded | Rate |
|---|---:|---:|---:|
| Jun 2014 | 893 | 51 | 5.71% |
| Jul 2014 | 961 | 42 | 4.37% |
| Aug 2014 | 958 | 132 | 13.78% |
| Sep 2014 | 1,056 | 140 | 13.26% |
| Oct 2014 | 1,173 | 29 | 2.47% |
| Nov 2014 | 1,451 | 50 | 3.45% |

Excluding those two months, Mr Fuzzy's 2014 rate is 371 refunds on 10,106 items,
or 3.67%. At that rate August and September should have produced about 74 refunds.
They produced 272, so roughly 198 items were refunded that otherwise would not
have been, costing about $9,900 at $49.99 each. Replacement handling and any
reputational cost are not in this data.

Three checks separate this from a blip.

The spike is confined to one product. In the same two months Panda ran 6.80% and
6.62%, both inside its normal range, Hudson ran 0.66% and 1.22%, and Forever Love
ran 1.69% and 3.19%. A shipping partner, a returns policy change or a payment
processor problem would have moved every product. Only Mr Fuzzy moved, which
points at that product's stock.

The volume is ordinary. August sold 958 units and September 1,056, sitting between
July's 961 and October's 1,173. The rate is not distorted by an unusual
denominator or by a strange new cohort of buyers.

It starts and stops sharply. A drifting quality decline would ramp up over
several months. Two bad months returning immediately to 2.47%, the lowest month of
the year, looks like defective stock that entered inventory, sold through and was
replaced.

Worth noting that Mr Fuzzy ran 7% to 9% through 2012 and had settled near 3.5% by
late 2013, so this spike sits against a baseline that had been improving steadily
for two years.

#### Why the analysis keys on order date

Grouping refunds by when they were issued rather than when the item was ordered
produces a materially different picture:

| Month | Refunds by order date | Refunds by refund date |
|---|---:|---:|
| Aug 2014 | 132 | 65 |
| Sep 2014 | 140 | 213 |
| Oct 2014 | 29 | 26 |

By order date the two months are equally bad. By refund date, September looks
like a single catastrophic month and August looks only mildly elevated. An
analyst working from refund dates would investigate September's inventory and
conclude August was fine, when half the evidence for August was sitting in
September's row.

Average days from order to refund explains the mechanism and rules out an
alternative. That figure sits between 7.1 and 10.1 in all 36 months, including 7.8
in August and 9.8 in September. The returns process did not slow down under three
times the normal load, so the September pile-up is the arithmetic of a nine-day
lag crossing a month boundary rather than a support queue falling behind. Had the
lag stretched during the spike there would be a second finding here about returns
capacity, and there isn't.

The same distortion appears at Christmas, where December 2014 shows 75 refunds by
refund date against 59 by order date.

#### Does purchase role explain the ranking?

Hudson is 88% add-on and Mr Fuzzy is almost never one, so the product ranking
could be measuring willingness to bother returning a cheap extra rather than
product quality. Splitting each product by role tests that:

| Product | Add-on | Primary | Gap |
|---|---:|---:|---:|
| Birthday Sugar Panda | 5.74% | 6.23% | 0.49 |
| Forever Love Bear | 1.91% | 2.29% | 0.38 |
| Hudson River Mini bear | 1.28% | 1.20% | -0.08 |
| The Original Mr. Fuzzy | 2.19% | 5.15% | 2.96 |

Where volumes support it the effect is small, around 0.4 points, and Hudson shows
none at all despite being the product where it should be largest. The ranking in
the first table therefore reflects the products rather than how they get bought.

Mr Fuzzy's 2.96-point gap is the exception and does not survive scrutiny. It rests
on 365 add-on items producing 8 refunds. Cross-selling only became possible in
September 2013, so restricting both sides to that period was the obvious test; it
moved the gap to 2.52 points, meaning the period difference accounted for very
little of it. The remaining figure still contains the August batch, and removing
those months from the primary side alone brings it to 1.39 points, though that
comparison is unfair because the add-on items came from the same inventory.

With roughly 40 add-on items in the affected window there is not enough data to
settle it. The gap is somewhere between 1.4 and 2.5 points and may be a real role
effect, the batch event inflating the comparison, or noise.

Limitations: the dataset records no product cost beyond cost of goods and no
reason codes, so a refund for a faulty bear looks identical to one for a change of
mind. That makes the August spike a strong inference rather than a confirmed
manufacturing fault. Refunds also stop at 19 March 2015, so items ordered in the
final weeks have had less time to be returned and the last month's rate is
understated.

*Query: [`analysis/10_refund_analysis.sql`](./analysis/10_refund_analysis.sql) ·
Results: [`results/10_refund_rate_by_product.csv`](./results/10_refund_rate_by_product.csv),
[`results/10_monthly_refund_rate.csv`](./results/10_monthly_refund_rate.csv),
[`results/10_refunds_by_refund_date.csv`](./results/10_refunds_by_refund_date.csv),
[`results/10_refund_by_item_role.csv`](./results/10_refund_by_item_role.csv),
[`results/10_refund_by_item_role_post_sep2013.csv`](./results/10_refund_by_item_role_post_sep2013.csv)*

---

## Files

| File | Purpose |
|------|---------|
| `schema/01_create_tables.sql` | Table definitions with keys and types |
| `schema/02_load_data.sql` | CSV load statements |
| `schema/03_verify_load.sql` | Post-load checks with expected results |
| `schema/04_add_indexes.sql` | Indexes added after loading, with reasoning |
| `analysis/` | One numbered file per business question |
| `results/` | Query output saved as CSV |

---

## Notes and assumptions

Every judgement call made in the analysis, so that any figure here can be
reproduced or disputed.

**Converting session.** A session counts as converting if at least one row in
`orders` references it. Session-level queries use a `LEFT JOIN` so that
non-converting sessions stay in the denominator, and `COUNT(o.order_id)` rather
than `COUNT(*)` for the numerator, since `COUNT` on a column ignores the nulls the
left join produces.

**Revenue is gross.** Refunds are never netted off. Total revenue reads $1,938,510
throughout, against $85,339 refunded across the period. Net revenue would be
$1,853,171, and finding 10 is the only place refunds enter the arithmetic. Any
figure quoted from another finding is a gross figure.

**Channel definition.** Sessions with a `utm_source` are Paid. Sessions with no
`utm_source` but a `http_referer` are Organic Search. Sessions with neither are
Direct. This is last-touch attribution and it undercredits paid advertising, since
a visitor who sees an ad and returns later by typing the URL is recorded as
Direct. Finding 3 discusses the consequence.

**Funnel steps.** Finding 5 counts distinct sessions that reached each page at any
point in the session, not strict sequential progression. A session that revisited
an earlier page counts once per step. The final step reproduces the order count
exactly (32,313), which is the check that the simplification does not distort the
totals.

**Repeat sessions and users.** `is_repeat_session` is taken as given rather than
recomputed from `user_id`. Users are identified by `user_id`, which in practice
would be cookie-based, so anyone clearing cookies or switching devices appears as
a new person and repeat-purchase rates are understated.

**Product launch dates** come from `products.created_at`. Before and after windows
in finding 6 are 90 days either side of the launch date.

**Right-censoring.** The data stops on 19 March 2015. A customer who bought in
March 2015 has had no opportunity to return or to request a refund, so both
repeat-purchase rate and the final month's refund rate are understated.

**Rounding.** Percentages are reported to two decimal places and currency to the
nearest dollar in prose, with exact values preserved in the exported CSVs. Ratios
stated as "times better" are computed from unrounded values.

### The data is simulated

Three structural signals confirm this dataset was generated rather than observed,
and each one bounds what the analysis can claim.

Nonbrand traffic contains exactly zero repeat sessions across 337,615 visits. Real
traffic would show a handful from cookie clearing and device switching.

The sessions-per-user distribution does not decay. There are 27 times more
four-session users (13,399) than three-session users (485), which no consumer
website produces. Finding 9 therefore treats only the split between visiting once
and returning at least once as meaningful, and does not interpret the frequency
tiers.

Every refund is a full-item refund, matching the list price to the cent in all
four products. Real refund data contains partial refunds, restocking deductions
and shipping adjustments.

All counts are internally consistent and every total ties out, so the analytical
methods hold and transfer to real data. The specific behavioural numbers should
not be read as representative of a real business.
