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
