/* =============================================================
   Maven Fuzzy Factory - Conversion Funnel
   MySQL 8.0

   Business question 5: where do users drop out of the conversion
   funnel?

   SITE STRUCTURE
   --------------
   Landing (/home, /lander-1 .. /lander-5)
     -> /products
       -> product detail (/the-original-mr-fuzzy, etc.)
         -> /cart
           -> /shipping
             -> /billing or /billing-2
               -> /thank-you-for-your-order

   METHOD
   ------
   Counting pageviews would overstate every step, because a session
   that browses back and forth views a page more than once. The funnel
   must count DISTINCT SESSIONS that reached each step.

   That needs two levels of aggregation, which is what the CTE provides:
     Stage 1 - collapse each session's many pageview rows into one row
               of yes/no flags
     Stage 2 - sum those flags across all sessions

   MAX(condition) returns 1 if the condition was true on ANY row in the
   session - i.e. "did this session ever reach this page". Without an
   aggregate the query would be asking MySQL to fit many different
   values into one output row.

   SUM (not COUNT) in the outer query: the flags are 0 or 1, never null,
   and COUNT counts zeros. SUM adds only the ones.

   SIMPLIFICATION
   --------------
   This measures "ever reached", not strict sequential progression. A
   session that revisited an earlier page still counts once per step.
   Acceptable here because the final step reproduces the order count
   exactly, so the totals are undistorted.
   ============================================================= */

USE mavenfuzzyfactory;


/* Funnel: distinct sessions reaching each step.

   Expected results:
     sessions               472,871
     reached_products       261,231   55.2% of previous step
     reached_product_detail 210,214   80.5%
     reached_cart            94,953   45.2%  <- worst step conversion
     reached_shipping        64,484   67.9%
     reached_billing         52,058   80.7%
     reached_thankyou        32,313   62.1%  <- 19,745 lost at payment

   VERIFICATION: reached_thankyou must equal 32,313, the row count of
   the orders table. Everyone who reached the thank-you page ordered,
   and vice versa. This is what catches URL typos, which otherwise
   produce a plausible-looking but wrong funnel with no error.
*/

WITH session_steps AS (
SELECT website_session_id,
MAX(pageview_url = '/products')  AS saw_products,
-- LIKE with % matches all four product pages in one condition.
MAX(pageview_url LIKE '/the-%') AS saw_product_detail,
MAX(pageview_url = '/cart')      AS saw_cart,
MAX(pageview_url = '/shipping')  AS saw_shipping,
-- The site ran two billing pages: /billing (3,617 views, early
    -- version) and /billing-2 (48,441). Matching only /billing would
    -- capture 7% of the real figure.
MAX(pageview_url IN ('/billing', '/billing-2')) AS saw_billing,
MAX(pageview_url = '/thank-you-for-your-order')  AS saw_thankyou
FROM website_pageviews
GROUP BY website_session_id
)
SELECT COUNT(*)                  AS sessions,
SUM(saw_products)                AS reached_products,
SUM(saw_product_detail)          AS reached_product_detail,
SUM(saw_cart)                    AS reached_cart,
SUM(saw_shipping)                AS reached_shipping,
SUM(saw_billing)                 AS reached_billing,
SUM(saw_thankyou)                AS reached_thankyou
FROM session_steps;