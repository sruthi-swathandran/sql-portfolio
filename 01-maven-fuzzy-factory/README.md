# Maven Fuzzy Factory — E-Commerce Funnel & Channel Analysis

Analysis of an online teddy bear retailer's first three years of trading, working
from raw website traffic logs through to order and refund data.

The business questions here are the ones an e-commerce analyst is actually asked:
where is traffic coming from, how much of it converts, which channels are worth
the spend, and did the new product launches work.

--------------------------------------------------------------------------------------------------------------------------------------

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

---------------------------------------------------------------------------------------------------------------------

## Data

**Source:** [Maven Analytics Data Playground](https://mavenanalytics.io/data-playground)
— "Toy Store E-Commerce Database"
**Licence:** free for educational and portfolio use
**Period:** 19 March 2012 – 19 March 2015 (final month partial)

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

<!-- Fill in as you build. Describe schema decisions, indexes added, and why. -->

---

## Findings

### 1. How have website sessions trended over time?

**Traffic grew continuously across the full period, with a strong Q4 seasonal peak.**

Sessions roughly doubled year-over-year in every month — January went from
6,401 (2013) to 14,825 (2014) to 25,337 (2015).

A month-on-month view appears to show decline after December 2014, but this is
a seasonal peak followed by a partial final month: the data ends 19 March 2015.

*Query: [`analysis/01_traffic_trends.sql`](./analysis/01_traffic_trends.sql) ·
Results: [`results/01_monthly_traffic.csv`](./results/01_monthly_traffic.csv)*

---

### 2. What is the session-to-order conversion rate, and how has it moved?
**Conversion improved 2.7×, from ~3.2% to ~8.7% — a bigger commercial win than
the traffic growth.**

Overall conversion across the full period was 6.83% (32,313 orders from 472,871
sessions), but that average hides steady month-on-month improvement.

Traffic growth costs money in ad spend; conversion improvement is free margin on
traffic already paid for. The two compound: ~13× more traffic at ~2.7× better
conversion took monthly orders from 60 to 2,068.

Unlike the traffic figures, the partial final month does not distort this — a
rate is a ratio, so 18 days of sessions over 18 days of orders remains valid.

*Query: [`analysis/02_conversion_rate.sql`](./analysis/02_conversion_rate.sql) ·
Results: [`results/02_monthly_conversion.csv`](./results/02_monthly_conversion.csv)*

---

### 3. Which marketing channels drive the most traffic, and which drive the most revenue?

**Paid ads bring 82% of traffic but the least value per session. Organic search
is worth 13% more per visit — and costs nothing.**

| Channel | Sessions | Conversion | Revenue | Revenue/session |
|---|---:|---:|---:|---:|
| Paid | 389,543 (82%) | 6.72% | $1,567,077 | $4.02 |
| Organic search | 43,411 (9%) | 7.51% | $196,809 | **$4.53** |
| Direct | 39,917 (8%) | 7.15% | $174,624 | $4.37 |

Two things stop this being a simple "spend less on ads" conclusion.

**The free channels are small and cannot be bought.** Organic and direct together
are 17.6% of sessions. Organic traffic is earned through content and reputation
over years, not purchased. Paid acquired the other 82% — without it this business
is a fifth of its size. A channel can be more efficient per visit and still be
the wrong one to concentrate on.

**Last-touch attribution undercredits paid.** A visitor who sees an ad, leaves,
and returns later by typing the URL is recorded as Direct. The ad created that
session but receives no credit for it. Some share of the organic and direct
traffic is likely downstream of paid awareness, and this data cannot separate the
two.

**Limitation:** the dataset contains no advertising cost, so return on ad spend
cannot be calculated. Revenue per session measures traffic quality, not
profitability.

*Query: [`analysis/03_channel_performance.sql`](./analysis/03_channel_performance.sql) ·
Results: [`results/03_channel_performance.csv`](./results/03_channel_performance.csv)*

---

### 4. How have revenue per order and revenue per session evolved?

**Revenue per session grew 2.56×, from $2.07 to $5.30. Most of that came from
better conversion, not bigger baskets.**

| Year | Sessions | Orders | Revenue/order | Revenue/session |
|---|---:|---:|---:|---:|
| 2012 | 62,470 | 2,586 | $49.99 | $2.07 |
| 2013 | 112,781 | 7,447 | $52.81 | $3.49 |
| 2014 | 233,422 | 16,860 | $63.80 | $4.61 |
| 2015 | 64,198 | 5,420 | $62.80 | $5.30 |

Revenue per session is the product of conversion rate and average order value.
Splitting the 2.56× growth: conversion contributed 2.04×, order value 1.26×.
Persuading more visitors to buy mattered roughly twice as much as persuading
buyers to spend more — and conversion gains are free, where order value gains
usually require new products or pricing changes.

2012's average order value of exactly **$49.99** is a useful sanity check: that is
the price of The Original Mr. Fuzzy, the only product on sale that year. Every
2012 order was a single bear. Order value only starts rising after the second
product launches in January 2013, which points at cross-selling rather than
pricing.

**Neither 2012 nor 2015 is a full year**, so the table above cannot be read as a
straight year-on-year comparison. On a like-for-like basis — 1 January to 19 March
in each year, matching 2015's coverage:

| Period | Conversion | Revenue/order | Revenue/session |
|---|---:|---:|---:|
| 2013 Q1 | 6.40% | $52.24 | $3.34 |
| 2014 Q1 | 6.53% | $61.84 | $4.04 |
| 2015 Q1 | 8.44% | $62.80 | $5.30 |

Like-for-like, revenue per session rose **31%** between 2014 and 2015 — *larger*
than the full-year table implies, because Q1 is seasonally weaker than the year as
a whole. Average order value also rose on this basis ($61.84 → $62.80), where the
full-year comparison misleadingly showed a decline from $63.80.

2012 is excluded from the like-for-like table: the site launched on 19 March 2012,
so its January–March window contains a single day of trading.

*Query: [`analysis/04_revenue_metrics.sql`](./analysis/04_revenue_metrics.sql) ·
Results: [`results/04_monthly_revenue_metrics.csv`](./results/04_monthly_revenue_metrics.csv)*

---

### 5. Where do users drop out of the conversion funnel?

**The checkout leaks hardest: 37.9% of visitors who reach the billing page never
complete the order — roughly $1.18M of abandoned purchases.**

| Step | Sessions | Step conversion | Lost here |
|---|---:|---:|---:|
| Landing page | 472,871 | — | — |
| Products page | 261,231 | 55.2% | 211,640 |
| Product detail | 210,214 | 80.5% | 51,017 |
| Cart | 94,953 | 45.2% | 115,261 |
| Shipping | 64,484 | 67.9% | 30,469 |
| Billing | 52,058 | 80.7% | 12,426 |
| Thank you | 32,313 | **62.1%** | **19,745** |

Three steps have a claim to being "worst", depending on the measure. Product
detail → cart has the poorest conversion (45.2%). Landing → products loses the
most people in absolute terms (211,640). Billing → thank you loses the fewest of
the three — but loses the most valuable ones.

**Priority: the billing step.** Those 19,745 sessions had chosen a product,
entered shipping details, and reached payment. At the average order value of
$59.99 they represent ~$1.18M of abandoned revenue, against $1.94M actually
earned.

The volume argument does not overturn this. One percentage point of improvement
at billing yields ~521 extra orders; one percentage point off landing-page
drop-off yields ~586, since only ~12.4% of product-page viewers eventually order.
The returns are comparable — but a point at checkout comes from contained fixes
(shorter forms, earlier shipping costs, more payment options), while a point at
the landing page requires better targeting and page design across the whole
acquisition funnel. Same return, far less effort.

**Method note:** each step counts distinct sessions that reached that page at any
point, not strict sequential progression. A session that revisited an earlier page
still counts once per step. Since the final step reproduces the order count
exactly (32,313), the simplification does not distort the totals.

*Query: [`analysis/05_conversion_funnel.sql`](./analysis/05_conversion_funnel.sql) ·
Results: [`results/05_conversion_funnel.csv`](./results/05_conversion_funnel.csv)*

---
### 6. What was the measurable impact of each new product launch?

**Launching a product did almost nothing on its own. The change that mattered was
a cross-sell feature added in September 2013 — which then needed a cheap product
to work against.**

Items per order sat at exactly **1.000** from March 2012 to August 2013. With one
product on sale that is mechanically guaranteed; but it stayed there for eight
months *after* a second product launched.

| Date | Items/order | Event |
|---|---:|---|
| Mar 2012 – Dec 2012 | 1.000 | Mr Fuzzy only |
| **Jan 2013** | **1.000** | **Forever Love Bear launches — no change** |
| Feb – Aug 2013 | 1.000 | Two products; still nobody buys two |
| **Sep 2013** | **1.010** | **First movement. No product launched.** |
| Oct – Dec 2013 | 1.042 → 1.089 | Attach rate builds |
| **Feb 2014** | **1.131 → 1.320** | **Hudson River Mini bear, $29.99** |
| Mar 2014 – Mar 2015 | ~1.350 | Stable at ~35% attach rate |

Orders here contain one or two items, never more, so items per order is really an
**add-on attach rate**: 1.000 means no order includes a second item, 2.000 would
mean every order does. The stable ~1.350 is a 35% attach rate.

**January 2013 — the launch that did nothing to basket size.** Average order value
rose from $49.99 to $51.20, but purely through mix: some customers chose the more
expensive bear instead. Nobody bought two.

**September 2013 — the change that isn't in the data.** Items per order moves for
the first time in eighteen months, and no product launched that month. The
capability to add a second item must have appeared then. It is not in `products`,
and it was not a discount — every product sells at an identical price whether it
is the primary item or the add-on. It is visible only in its effect.

**February 2014 — the feature meets the right product.**

| Product | Price | As primary | As add-on | % add-on |
|---|---:|---:|---:|---:|
| Hudson River Mini bear | $29.99 | 581 | 4,437 | **88.4%** |
| Birthday Sugar Panda | $45.99 | 3,068 | 1,917 | 38.5% |
| Forever Love Bear | $59.99 | 4,803 | 993 | 17.1% |
| The Original Mr. Fuzzy | $49.99 | 23,861 | 365 | 1.5% |

The Hudson River bear sells 8× more often as an add-on than as a main purchase.
It barely functions as a standalone product — it is what people tack on. Among the
three later products, the cheaper the item the more likely it is to be an add-on.
Mr Fuzzy is the exception because of its role rather than its price: it is the
destination product, 60% of all primary items, the thing customers arrive
intending to buy.

**Why not a before/after comparison?** Conversion rate rose after every launch —
but conversion was rising every month regardless, the Sugar Panda launched inside
the Q4 peak, and the Panda and Hudson River launches are only 55 days apart, so
their windows overlap. Items per order avoids all three problems: it cannot exceed
1.000 while a single product exists, so trend and seasonality are incapable of
producing the movement.

The before/after table demonstrates the problem it warns about:

| Launch | Window | Orders | Items/order | Avg order value |
|---|---|---:|---:|---:|
| Forever Love Bear | before | 1,495 | **1.000** | $49.99 |
| Forever Love Bear | after | 1,327 | **1.000** | $52.18 |
| Birthday Sugar Panda | before | 2,360 | 1.038 | $53.75 |
| Birthday Sugar Panda | after | 3,011 | 1.215 | $60.48 |
| Hudson River Mini bear | before | 2,894 | 1.096 | $56.15 |
| Hudson River Mini bear | after | 3,407 | 1.342 | $64.22 |

The Forever Love Bear shows *fewer* orders after launch — not because the product
failed, but because its "before" window covers Christmas and its "after" window
covers January. Its items-per-order figure, however, reads exactly 1.000 on both
sides: the one column seasonality cannot distort, and the one that answers the
question. The Sugar Panda's "before" window already reads 1.038, confirming
cross-selling had begun before that launch too.

*Query: [`analysis/06_product_launch_impact.sql`](./analysis/06_product_launch_impact.sql) ·
Results: [`results/06_monthly_items_per_order.csv`](./results/06_monthly_items_per_order.csv),
[`results/06_product_mix.csv`](./results/06_product_mix.csv),
[`results/06_launch_windows.csv`](./results/06_launch_windows.csv)*

---

### 7. Do mobile and desktop visitors convert differently, and has the gap changed over time?

**Mobile converts at a third of desktop's rate — 3.09% against 8.50% — worth
roughly $477,000 in missing orders.**

| Device | Sessions | Share | Conversion | Avg order value | Revenue/session |
|---|---:|---:|---:|---:|---:|
| Desktop | 327,027 | 69.2% | **8.50%** | $59.91 | **$5.09** |
| Mobile | 145,844 | 30.8% | **3.09%** | $60.50 | **$1.87** |

**The diagnosis is in the order values, not the conversion rates.** Mobile's
average order is $60.50 against desktop's $59.91 — marginally *higher*. Mobile
visitors spend the same when they buy. The entire gap is that they do not buy.

That distinction rules out one explanation and points at another. If mobile users
were choosing cheaper products, this would be a merchandising problem. They
aren't. They abandon before purchasing at all, which points at checkout and
usability on small screens.

#### Has the gap changed? The two obvious measures disagree.

| Year | Desktop | Mobile | Gap (points) | Gap (ratio) |
|---|---:|---:|---:|---:|
| 2012 | 5.05% | 1.47% | 3.59 | 3.45× |
| 2013 | 8.02% | 3.12% | 4.90 | 2.57× |
| 2014 | 9.18% | 3.31% | 5.87 | 2.77× |
| 2015 | 10.59% | 3.50% | **7.10** | **3.03×** |

In percentage points the gap nearly doubled. As a ratio it slightly narrowed.
Both are correct: desktop improved 2.10× over the period, mobile 2.38×.
**Mobile improved faster** — but from so far behind that proportional gains widen
the absolute gap anyway. Two people earning ₹100 and ₹1,000 who each receive a
10% rise have improved equally, and the distance between them has grown by ₹90.

The implication is that mobile has not been neglected. Whatever improved
conversion worked on both devices, slightly better on mobile. But at this rate
mobile will never close the gap, because closing an absolute gap requires
improving substantially faster, not marginally.

#### Mobile's share of traffic is not on a simple upward path.

Comparing the two complete years, mobile grew from 28.9% (2013) to 33.4% (2014).
But on a like-for-like basis — 1 January to 19 March in each year, matching 2015's
coverage — the picture changes:

| Q1 window | Total sessions | Mobile share |
|---|---:|---:|
| 2013 | 17,251 | 25.6% |
| 2014 | 41,291 | **39.8%** |
| 2015 | 64,198 | 30.3% |

Mobile share rose steeply into early 2014 and then fell **9.5 points** by early
2015. With 41,291 and 64,198 sessions in those windows, the movement is not noise.

Q1 also turns out to be a *high*-mobile quarter rather than a low one: Q1 2014's
39.8% sits well above that year's 33.4% full-year figure. So the dip visible in
the full-year series is not an artefact of the shortened window — it is real.

What caused the reversal cannot be answered from this data. It does not change the
conclusion: at ~30% of traffic and a third of desktop's conversion, mobile is a
large and persistent problem whichever way its share is moving.

#### The cost

At desktop's conversion rate, 145,844 mobile sessions would have produced about
**12,400 orders instead of 4,508** — roughly **7,900 missing orders**, or
**$477,000** at mobile's average order value.

That is a larger prize than the checkout abandonment in finding 5, and the two are
plausibly the same problem: a checkout that works poorly on small screens.

**Connection to finding 4.** Q1 revenue per session is consistently below the
full-year figure, and mobile mix explains part of it. Applying 2014's device-level
revenue per session ($5.86 desktop, $2.11 mobile) to Q1's 39.8% mobile mix rather
than the year's 33.4% accounts for roughly $0.24 of Q1 2014's $0.57 shortfall
against the full year. The remainder is lower conversion within each device.
Q1 is weaker partly because more of its traffic arrives on the device that
converts worst.

**Limitation:** `device_type` records only `desktop` or `mobile`. Tablets, if any,
are folded into one of those two, and the data does not say which. Operating
system, screen size and browser are not recorded, so the analysis cannot go
further than the binary split.

*Query: [`analysis/07_device_performance.sql`](./analysis/07_device_performance.sql) ·
Results: [`results/07_device_overall.csv`](./results/07_device_overall.csv),
[`results/07_device_by_year.csv`](./results/07_device_by_year.csv),
[`results/07_device_mix.csv`](./results/07_device_mix.csv),
[`results/07_device_mix_like_for_like.csv`](./results/07_device_mix_like_for_like.csv)*

---

## Files

| File | Purpose |
|------|---------|
| `schema/01_create_tables.sql` | Table definitions with keys, types, and indexes |
| `schema/02_load_data.sql` | CSV load statements |
| `analysis/` | One numbered file per business question |
| `results/` | Query output saved as CSV |

---

## Notes and assumptions

<!-- Record every judgement call here: how you defined a "converting session",
     whether refunds are netted off revenue, how you handled repeat sessions.
     Stating these is what separates analysis from a query dump. -->
