# Airbnb Listings & Reviews — Cross-City Market Analysis

Analysis of 250,000+ Airbnb listings across 10 major cities, joined to 5 million
historical reviews.

---

## Business questions

1. How do the Airbnb markets in these 10 cities differ from one another?
2. Which listing attributes have the biggest influence on price?
3. Are there identifiable trends or seasonality in the review data?
4. Which city offers the best value for travellers?

---

## Data

**Source:** [Maven Analytics Data Playground](https://mavenanalytics.io/data-playground) — "Airbnb Listings & Reviews"
**Rows:** 279,712 listings · 5,373,143 reviews
**Files:** `Listings.csv` (151 MB), `Reviews.csv` (244 MB)

Place both CSVs in `data/`. They are not committed to this repository.

---

## Data quality: prices are in local currency

The `price` column is denominated in each city's local currency, so a raw
cross-city price comparison is meaningless — a listing at 15,000 in Istanbul is
not more expensive than one at 200 in Paris.

All cross-city analysis converts to a single currency using a documented rate
table in `schema/03_currency_reference.sql`, with the rates and the date they
were taken recorded there.

---

## Method

<!-- Schema decisions, indexes, and how the reviews table was joined efficiently. -->

---

## Findings

<!-- Fill in as you build. -->

---

## Notes and assumptions

<!-- Record how outlier prices were handled, which listings were excluded and why. -->
