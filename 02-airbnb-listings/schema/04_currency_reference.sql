/* =============================================================
   Airbnb Listings and Reviews - Currency Reference
   MySQL 8.0

   Run after 03_verify_load.sql.

   WHY THIS TABLE EXISTS
   ---------------------
   listings.price is denominated in each city's own currency.
   A raw cross-city comparison is therefore meaningless: the
   median listing is 1,100 in Bangkok and 99 in New York, which
   says nothing about which city is more expensive. Every
   cross-city question depends on converting first.

   RATE DATE
   ---------
   Rates are taken as at 2021-03-01, matching the snapshot the
   data represents: reviews end on that date and the source
   files were published in April 2021.

   Using current rates would be a serious error rather than an
   approximation. The Turkish lira was near 7.2 to the dollar in
   early 2021 and has moved a long way since, so converting 2021
   prices at today's rate would make Istanbul appear to be the
   cheapest market in the dataset purely as an artefact of the
   choice of date.

   DIRECTION
   ---------
   units_per_usd is the rate as quoted: how many units of the
   local currency one US dollar buys. To convert a listing:

       price_usd = listings.price / currency_rates.units_per_usd

   Storing the inverse would allow multiplication instead, which
   is marginally safer, but the quoted form can be checked
   against the cited source without arithmetic, and provenance
   matters more here than query convenience.

   KEY
   ---
   Keyed by city rather than by currency, so it joins directly to
   listings.city. The euro therefore appears twice, for Paris and
   Rome. At ten rows the duplication costs nothing and removes a
   second lookup table.

   LIMITATION
   ----------
   Market exchange rates are not purchasing power. A city that
   converts to a low dollar price may not be inexpensive relative
   to local wages, and this table cannot express that. It makes
   prices comparable in dollars, which is not the same as making
   them comparable in value.
   ============================================================= */

USE airbnb_listings;

DROP TABLE IF EXISTS currency_rates;

CREATE TABLE currency_rates (
    city          VARCHAR(100)  NOT NULL,
    currency_code CHAR(3)       NOT NULL,
    units_per_usd DECIMAL(12,6) NOT NULL,
    rate_date     DATE          NOT NULL,
    source        VARCHAR(200)  NOT NULL,
    PRIMARY KEY (city)
) ENGINE = InnoDB;

INSERT INTO currency_rates (city, currency_code, units_per_usd, rate_date, source) VALUES
    ('New York',       'USD',  1.000000, '2021-03-01', 'Base currency'),
    ('Paris',          'EUR',  0.829670, '2021-03-01', 'ECB reference rate via api.frankfurter.app'),
    ('Rome',           'EUR',  0.829670, '2021-03-01', 'ECB reference rate via api.frankfurter.app'),
    ('Sydney',         'AUD',  1.291800, '2021-03-01', 'ECB reference rate via api.frankfurter.app'),
    ('Rio de Janeiro', 'BRL',  5.579000, '2021-03-01', 'ECB reference rate via api.frankfurter.app'),
    ('Istanbul',       'TRY',  7.232600, '2021-03-01', 'ECB reference rate via api.frankfurter.app'),
    ('Mexico City',    'MXN', 20.768000, '2021-03-01', 'ECB reference rate via api.frankfurter.app'),
    ('Bangkok',        'THB', 30.230000, '2021-03-01', 'ECB reference rate via api.frankfurter.app'),
    ('Cape Town',      'ZAR', 15.058300, '2021-03-01', 'ECB reference rate via api.frankfurter.app'),
    ('Hong Kong',      'HKD',  7.757200, '2021-03-01', 'ECB reference rate via api.frankfurter.app');

/* --- Check: every city in listings has a rate --------------
   A missing rate would silently drop that city's listings from
   every inner join in the analysis, which is the kind of error
   that shows up as a city quietly absent from a chart rather
   than as an error message.

   Expected: 0 rows
   ---------------------------------------------------------- */

SELECT DISTINCT l.city AS city_without_rate
FROM listings l
LEFT JOIN currency_rates c ON l.city = c.city
WHERE c.city IS NULL;

/* --- Check: converted medians are plausible ----------------
   The point of the exercise. Local medians span 65 to 1,100 and
   mean nothing side by side; converted, they should fall into a
   believable range for a night's accommodation.
   ---------------------------------------------------------- */

SELECT l.city,
       c.currency_code,
       COUNT(*)                                          AS listings,
       ROUND(AVG(l.price), 0)                            AS mean_price_local,
       ROUND(AVG(l.price / c.units_per_usd), 2)          AS mean_price_usd
FROM listings l
JOIN currency_rates c ON l.city = c.city
GROUP BY l.city, c.currency_code
ORDER BY mean_price_usd DESC;
