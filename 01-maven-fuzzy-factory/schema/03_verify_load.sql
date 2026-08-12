/* =============================================================
   Maven Fuzzy Factory - Load Verification
   MySQL 8.0

   Run after 02_load_data.sql. Every check below has an expected
   result stated above it. All must match before the data is
   used for analysis.

   A load that completes without erroring can still be wrong:
   silently truncated strings, misparsed dates, or values stored
   as the text 'NULL' rather than as real nulls. None of those
   raise an error. These checks are how you catch them.
   ============================================================= */

USE mavenfuzzyfactory;

/* --- Check 1: row counts match the source files -------------
   Expected: 4, 472871, 1188124, 32313, 40025, 1731
   ---------------------------------------------------------- */

SELECT 'products' AS table_name, COUNT(*) AS rows_loaded FROM products
UNION ALL SELECT 'website_sessions',   COUNT(*) FROM website_sessions
UNION ALL SELECT 'website_pageviews',  COUNT(*) FROM website_pageviews
UNION ALL SELECT 'orders',             COUNT(*) FROM orders
UNION ALL SELECT 'order_items',        COUNT(*) FROM order_items
UNION ALL SELECT 'order_item_refunds', COUNT(*) FROM order_item_refunds;

/* --- Check 2: the 'NULL' string was converted to real nulls --
   Expected: total_rows 472871, literal_null_text 0,
             real_nulls 83328
   ---------------------------------------------------------- */
SELECT
    COUNT(*)                        AS total_rows,
    SUM(utm_source = 'NULL')        AS literal_null_text,
    SUM(utm_source IS NULL)         AS real_nulls
FROM website_sessions;

/* --- Check 3: no trailing carriage returns in text columns --
   Expected lengths: 22, 21, 24, 26
   ---------------------------------------------------------- */
SELECT product_name, CHAR_LENGTH(product_name) AS len
FROM products;
