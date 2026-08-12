/* =============================================================
   Maven Fuzzy Factory - Data Load
   MySQL 8.0

   Loads six CSV files into the tables created by
   01_create_tables.sql. Run that script first.

   PREREQUISITES
   -------------
   1. Place the six CSVs in this project's data/ folder.

   2. Enable local file loading. Required in TWO places:

      Server:  SET GLOBAL local_infile = 1;

      Client:  Workbench home screen > right-click the connection
               > Edit Connection > Advanced tab > "Others:" box,
               add OPT_LOCAL_INFILE=1, then reopen the connection.

      Missing either gives: "Loading local data is disabled".

   3. Update the file paths below if the repository is not at
      D:/Projects. Use forward slashes even on Windows -
      backslash is SQL's escape character.

   NOTES
   -----
   Source files use Windows line endings (\r\n). Loading them as
   '\n' leaves a trailing carriage return on the last column of
   every row, which does not error but silently corrupts the data.

   Tables are loaded parent-first so the foreign key constraints
   are satisfied at every step.
   ============================================================= */

use mavenfuzzyfactory;

LOAD DATA LOCAL INFILE 'D:/Projects/sql-portfolio/01-maven-fuzzy-factory/data/products.csv'
INTO TABLE products
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'D:/Projects/sql-portfolio/01-maven-fuzzy-factory/data/website_sessions.csv'
INTO TABLE website_sessions
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(website_session_id, created_at, user_id, is_repeat_session,
 @utm_source, @utm_campaign, @utm_content, device_type, @http_referer)
SET
    utm_source   = NULLIF(@utm_source,   'NULL'),
    utm_campaign = NULLIF(@utm_campaign, 'NULL'),
    utm_content  = NULLIF(@utm_content,  'NULL'),
    http_referer = NULLIF(@http_referer, 'NULL');

-- NOTE: this file alone uses LF line endings; the other five use
-- CRLF. Loading it with '\r\n' silently loads 0 rows, no error.
LOAD DATA LOCAL INFILE 'D:/Projects/sql-portfolio/01-maven-fuzzy-factory/data/website_pageviews.csv'
INTO TABLE website_pageviews
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'D:/Projects/sql-portfolio/01-maven-fuzzy-factory/data/orders.csv'
INTO TABLE 	orders
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'D:/Projects/sql-portfolio/01-maven-fuzzy-factory/data/order_items.csv'
INTO TABLE 	order_items
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'D:/Projects/sql-portfolio/01-maven-fuzzy-factory/data/order_item_refunds.csv'
INTO TABLE 	order_item_refunds
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;