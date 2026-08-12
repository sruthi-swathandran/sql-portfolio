/* =============================================================
   Maven Fuzzy Factory - Indexes
   MySQL 8.0

   Run after 02_load_data.sql. Indexes are created after loading
   rather than as part of the table definitions: an index has to
   be updated on every insert, so building them up front makes a
   1.19M-row load significantly slower. Creating them afterwards
   lets MySQL build each one in a single pass over data that is
   already in place.

   Primary keys and foreign keys are already indexed by MySQL
   automatically - those are defined in 01_create_tables.sql and
   are not repeated here.

   COLUMNS DELIBERATELY NOT INDEXED
   --------------------------------
   device_type (2 distinct values) and is_repeat_session (2) have
   cardinality too low to be useful. An index matching half the
   table costs more to read than a full scan, and the optimiser
   will usually ignore it.

   NOTE ON idx_sessions_utm
   ------------------------
   utm_source has only 3 distinct values and the campaign and
   content columns have 6 each, so this index is not selective
   enough to speed up lookups. It is here to support GROUP BY:
   channel attribution groups on all three columns, and the index
   supplies them pre-sorted, avoiding a sort of 472,871 rows.
   ============================================================= */

USE mavenfuzzyfactory;

-- website_pageviews ------------------------------------------
CREATE INDEX idx_pageviews_url 
ON website_pageviews (pageview_url);

CREATE INDEX idx_pageviews_session_time
ON website_pageviews (website_session_id, created_at);

-- website_sessions -------------------------------------------
CREATE INDEX idx_sessions_created_at 
ON website_sessions (created_at);

CREATE INDEX idx_sessions_utm
ON website_sessions (utm_source, utm_campaign, utm_content);

CREATE INDEX idx_sessions_user 
ON website_sessions (user_id);

-- orders -------------------------------------------
CREATE INDEX idx_orders_created_at 
ON orders (created_at);

CREATE INDEX idx_orders_user
ON orders (user_id);

-- order_item_refunds ------------------------------------------
CREATE INDEX idx_refunds_created_at
ON order_item_refunds (created_at);

-- =============================================================
-- Verification
-- =============================================================

-- Expected: 6 rows - PRIMARY, idx_sessions_created_at,
-- idx_sessions_utm (3 rows, Seq_in_index 1/2/3), idx_sessions_user
SHOW INDEX FROM website_sessions;

-- Expected: type 'ref', key 'idx_pageviews_url', ~62,000 rows,
-- Extra 'Using index'. Without the index this is a full scan of
-- 1.18M rows.
EXPLAIN SELECT COUNT(*) FROM website_pageviews
WHERE pageview_url = '/thank-you-for-your-order';