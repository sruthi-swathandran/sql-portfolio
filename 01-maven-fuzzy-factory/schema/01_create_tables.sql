/* =============================================================
   Maven Fuzzy Factory - Schema Definition
   MySQL 8.0

   Creates the database, six tables, and seven foreign keys.
   Run this before 02_load_data.sql.
   ============================================================= */
DROP DATABASE IF EXISTS mavenfuzzyfactory;
CREATE DATABASE mavenfuzzyfactory;
USE mavenfuzzyfactory;

create table products (
product_id          smallint unsigned,
created_at          datetime          not null,
product_name        varchar(50)      not null,

primary key (product_id)
) engine = InnoDB;


create table website_sessions (
website_session_id        int unsigned   not null,
created_at                datetime not null,
user_id                   int unsigned   not null,
is_repeat_session         tinyint(1)  not null,
utm_source                varchar(25)          ,
utm_campaign              varchar(25)          ,
utm_content               varchar(25)         ,
device_type               varchar(10) not null,
http_referer              varchar(50)          ,
primary key  (website_session_id)
) engine = InnoDB;


create table website_pageviews (
website_pageview_id         int unsigned not null,
created_at                  datetime     not null,
website_session_id          int unsigned   not null,
pageview_url                varchar(50)  not null        ,
primary key (website_pageview_id)
)engine = InnoDB;


create table orders (
order_id              int unsigned        not null,
created_at            datetime            not null,
website_session_id    int unsigned        not null,
user_id               int unsigned        not null,
primary_product_id    smallint unsigned   not null,
items_purchased       tinyint unsigned    not null,
price_usd             decimal(10,2)       not null,
cogs_usd              decimal(10,2)       not null,
primary key (order_id)
)engine = InnoDB;


create table order_items (
order_item_id         int unsigned        not null,
created_at            datetime            not null,
order_id              int unsigned        not null,
product_id            smallint unsigned   not null,
is_primary_item       tinyint(1)          not null,
price_usd             decimal(10,2)       not null,
cogs_usd              decimal(10,2)       not null,
primary key (order_item_id)

)engine = InnoDB;

create table order_item_refunds (
order_item_refund_id      smallint unsigned  not null,
created_at                datetime           not null,
order_item_id             int unsigned       not null,
order_id                  int unsigned       not null,
refund_amount_usd         decimal(10,2)      not null,
primary key (order_item_refund_id)
)engine=InnoDB;

-- =============================================================
-- Foreign key constraints
-- =============================================================
ALTER TABLE website_pageviews
ADD CONSTRAINT fk_pageviews_session
FOREIGN KEY (website_session_id)
REFERENCES website_sessions (website_session_id);

ALTER TABLE orders
ADD CONSTRAINT fk_orders_sessions
FOREIGN KEY (website_session_id)
REFERENCES website_sessions (website_session_id);

ALTER TABLE orders
ADD CONSTRAINT fk_orders_products
FOREIGN KEY (primary_product_id)
REFERENCES products (product_id);

ALTER TABLE order_items
ADD CONSTRAINT fk_items_orders
FOREIGN KEY (order_id)
REFERENCES orders (order_id);

ALTER TABLE order_items
ADD CONSTRAINT fk_items_products
FOREIGN KEY (product_id)
REFERENCES products (product_id);

ALTER TABLE order_item_refunds
ADD CONSTRAINT fk_refund_items
FOREIGN KEY (order_item_id)
REFERENCES order_items (order_item_id);

ALTER TABLE order_item_refunds
ADD CONSTRAINT fk_refund_orders
FOREIGN KEY (order_id)
REFERENCES orders (order_id);

