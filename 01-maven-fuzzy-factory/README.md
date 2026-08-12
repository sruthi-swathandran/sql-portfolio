# Maven Fuzzy Factory — E-Commerce Funnel & Channel Analysis

Analysis of an online teddy bear retailer's first three years of trading, working
from raw website traffic logs through to order and refund data.

The business questions here are the ones an e-commerce analyst is actually asked:
where is traffic coming from, how much of it converts, which channels are worth
the spend, and did the new product launches work.

---

## Business questions

1. How have website sessions and order volume trended over time?
2. What is the session-to-order conversion rate, and how has it moved?
3. Which marketing channels drive the most traffic, and which drive the most *revenue*?
4. How have revenue per order and revenue per session evolved?
5. Where do users drop out of the conversion funnel?
6. What was the measurable impact of each new product launch?

---

## Data

**Source:** [Maven Analytics Data Playground](https://mavenanalytics.io/data-playground)
— "Toy Store E-Commerce Database"
**Licence:** free for educational and portfolio use
**Period:** March 2012 – April 2015

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

<!-- Fill in as you go. Lead with the answer, then show the query that produced it.
     A reader should be able to skim this section and understand the business
     story without opening a single .sql file. -->

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
