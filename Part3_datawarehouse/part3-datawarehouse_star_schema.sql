-- =============================================================================
-- star_schema.sql
-- Star Schema for retail_transactions.csv
-- Database: MySQL 8+ / PostgreSQL 14+  (ANSI-compatible)
--
-- SCHEMA OVERVIEW
-- ───────────────
-- Fact table  : fact_sales          (one row per transaction)
-- Dimensions  : dim_date            (date attributes for time intelligence)
--               dim_store           (store / location attributes)
--               dim_product         (product / category attributes)
--               dim_customer        (customer identity — bonus 4th dimension)
--
-- DATA CLEANING APPLIED (from raw retail_transactions.csv)
-- ─────────────────────────────────────────────────────────
-- Issue 1 – Inconsistent date formats
--   Raw values mixed three formats: YYYY-MM-DD, DD-MM-YYYY, DD/MM/YYYY
--   Fix: all dates normalised to ISO-8601 (YYYY-MM-DD) before insertion.
--   Examples:
--     "29/08/2023" → 2023-08-29
--     "12-12-2023" → 2023-12-12
--     "2023-02-05" → 2023-02-05  (already correct)
--
-- Issue 2 – Inconsistent category casing
--   Raw values: "electronics", "Electronics", "Grocery", "Groceries"
--   Fix: all categories title-cased; "Grocery" merged into "Groceries".
--   Final canonical values: Electronics | Clothing | Groceries
--
-- Issue 3 – NULL / empty store_city
--   19 rows had an empty store_city column.
--   Fix: city inferred deterministically from store_name, since each store
--   name maps to exactly one city (e.g., "Mumbai Central" → "Mumbai").
--   No city was ambiguous across stores.
-- =============================================================================


-- =============================================================================
-- DIMENSION: dim_date
-- =============================================================================
-- Surrogate key is an integer in YYYYMMDD format (date key pattern).
-- This avoids JOINs on VARCHAR dates and enables fast range predicates
-- (e.g., date_key BETWEEN 20230101 AND 20230331).
-- =============================================================================

CREATE TABLE dim_date (
    date_key        INT           PRIMARY KEY,   -- YYYYMMDD  e.g. 20230829
    full_date       DATE          NOT NULL UNIQUE,
    day_of_month    SMALLINT      NOT NULL,
    month_number    SMALLINT      NOT NULL,
    month_name      VARCHAR(12)   NOT NULL,
    year            SMALLINT      NOT NULL,
    week_of_year    SMALLINT      NOT NULL,
    quarter         SMALLINT      NOT NULL,      -- 1–4
    day_name        VARCHAR(12)   NOT NULL,
    is_weekend      BOOLEAN       NOT NULL       -- TRUE for Saturday / Sunday
);

-- 15 unique dates covering the 15 sample fact rows below
INSERT INTO dim_date
    (date_key, full_date, day_of_month, month_number, month_name, year, week_of_year, quarter, day_name, is_weekend)
VALUES
    (20230115, '2023-01-15',  15,  1, 'January',   2023,  2,  1, 'Sunday',    TRUE),
    (20230205, '2023-02-05',   5,  2, 'February',  2023,  5,  1, 'Sunday',    TRUE),
    (20230220, '2023-02-20',  20,  2, 'February',  2023,  8,  1, 'Monday',    FALSE),
    (20230331, '2023-03-31',  31,  3, 'March',     2023, 13,  1, 'Friday',    FALSE),
    (20230428, '2023-04-28',  28,  4, 'April',     2023, 17,  2, 'Friday',    FALSE),
    (20230521, '2023-05-21',  21,  5, 'May',       2023, 20,  2, 'Sunday',    TRUE),
    (20230604, '2023-06-04',   4,  6, 'June',      2023, 22,  2, 'Sunday',    TRUE),
    (20230809, '2023-08-09',   9,  8, 'August',    2023, 32,  3, 'Wednesday', FALSE),
    (20230815, '2023-08-15',  15,  8, 'August',    2023, 33,  3, 'Tuesday',   FALSE),
    (20230829, '2023-08-29',  29,  8, 'August',    2023, 35,  3, 'Tuesday',   FALSE),
    (20231020, '2023-10-20',  20, 10, 'October',   2023, 42,  4, 'Friday',    FALSE),
    (20231026, '2023-10-26',  26, 10, 'October',   2023, 43,  4, 'Thursday',  FALSE),
    (20231118, '2023-11-18',  18, 11, 'November',  2023, 46,  4, 'Saturday',  TRUE),
    (20231208, '2023-12-08',   8, 12, 'December',  2023, 49,  4, 'Friday',    FALSE),
    (20231212, '2023-12-12',  12, 12, 'December',  2023, 50,  4, 'Tuesday',   FALSE);


-- =============================================================================
-- DIMENSION: dim_store
-- =============================================================================
-- Stores physical retail locations.
-- region is a derived attribute (North / South / West) useful for
-- geo-level roll-ups in BI dashboards without needing an extra join.
-- =============================================================================

CREATE TABLE dim_store (
    store_key   SERIAL        PRIMARY KEY,
    store_id    VARCHAR(20)   NOT NULL UNIQUE,   -- business key  e.g. STR001
    store_name  VARCHAR(100)  NOT NULL,
    city        VARCHAR(100)  NOT NULL,
    state       VARCHAR(100)  NOT NULL,
    region      VARCHAR(50)   NOT NULL           -- North | South | West | East
);

INSERT INTO dim_store (store_id, store_name, city, state, region) VALUES
    ('STR001', 'Bangalore MG',  'Bangalore', 'Karnataka',   'South'),
    ('STR002', 'Chennai Anna',  'Chennai',   'Tamil Nadu',  'South'),
    ('STR003', 'Delhi South',   'Delhi',     'Delhi',       'North'),
    ('STR004', 'Mumbai Central','Mumbai',    'Maharashtra', 'West'),
    ('STR005', 'Pune FC Road',  'Pune',      'Maharashtra', 'West');


-- =============================================================================
-- DIMENSION: dim_product
-- =============================================================================
-- One row per distinct product. category is the cleaned, canonical value.
-- unit_price is the catalogue price at the time the warehouse was built;
-- the actual transacted price is stored in fact_sales.unit_price_at_sale
-- to preserve historical accuracy.
-- =============================================================================

CREATE TABLE dim_product (
    product_key     SERIAL        PRIMARY KEY,
    product_id      VARCHAR(20)   NOT NULL UNIQUE,   -- business key e.g. PRD001
    product_name    VARCHAR(150)  NOT NULL,
    category        VARCHAR(50)   NOT NULL,           -- Electronics | Clothing | Groceries
    catalogue_price NUMERIC(12,2) NOT NULL
);

-- 16 products, categories fully normalised
INSERT INTO dim_product (product_id, product_name, category, catalogue_price) VALUES
    ('PRD001', 'Atta 10kg',   'Groceries',   52464.00),
    ('PRD002', 'Biscuits',    'Groceries',   27469.99),
    ('PRD003', 'Headphones',  'Electronics', 39854.96),
    ('PRD004', 'Jacket',      'Clothing',    30187.24),
    ('PRD005', 'Jeans',       'Clothing',     2317.47),
    ('PRD006', 'Laptop',      'Electronics', 42343.15),
    ('PRD007', 'Milk 1L',     'Groceries',   43374.39),
    ('PRD008', 'Oil 1L',      'Groceries',   26474.34),
    ('PRD009', 'Phone',       'Electronics', 48703.39),
    ('PRD010', 'Pulses 1kg',  'Groceries',   31604.47),
    ('PRD011', 'Rice 5kg',    'Groceries',   52195.05),
    ('PRD012', 'Saree',       'Clothing',    35451.81),
    ('PRD013', 'Smartwatch',  'Electronics', 58851.01),
    ('PRD014', 'Speaker',     'Electronics', 49262.78),
    ('PRD015', 'T-Shirt',     'Clothing',    29770.19),
    ('PRD016', 'Tablet',      'Electronics', 23226.12);


-- =============================================================================
-- DIMENSION: dim_customer  (4th dimension — bonus)
-- =============================================================================
-- Captures the customer identifier from the raw data.
-- In a production DW the customer dimension would also carry demographic
-- attributes (age band, loyalty tier, etc.) sourced from a CRM system.
-- =============================================================================

CREATE TABLE dim_customer (
    customer_key  SERIAL       PRIMARY KEY,
    customer_id   VARCHAR(20)  NOT NULL UNIQUE   -- business key e.g. CUST045
);

-- All distinct customers referenced by the 15 sample fact rows
INSERT INTO dim_customer (customer_id) VALUES
    ('CUST004'),
    ('CUST007'),
    ('CUST015'),
    ('CUST019'),
    ('CUST020'),
    ('CUST021'),
    ('CUST025'),
    ('CUST027'),
    ('CUST030'),
    ('CUST031'),
    ('CUST041'),
    ('CUST042'),
    ('CUST044'),
    ('CUST045');


-- =============================================================================
-- FACT TABLE: fact_sales
-- =============================================================================
-- Grain: one row per retail transaction (one SKU per transaction).
-- Additive measures: units_sold, total_sale_amount, discount_amount.
-- Semi-additive: unit_price_at_sale (average across stores is meaningful;
--   sum is not).
--
-- Degenerate dimension: transaction_id — carries no dimension attributes of
-- its own, but is kept for lineage tracing back to the source system.
--
-- Foreign keys reference dimension surrogate keys (not business keys) for
-- join performance.
-- =============================================================================

CREATE TABLE fact_sales (
    sale_id              SERIAL         PRIMARY KEY,
    transaction_id       VARCHAR(20)    NOT NULL UNIQUE,  -- degenerate dimension
    date_key             INT            NOT NULL
                                        REFERENCES dim_date(date_key),
    store_key            INT            NOT NULL
                                        REFERENCES dim_store(store_key),
    product_key          INT            NOT NULL
                                        REFERENCES dim_product(product_key),
    customer_key         INT            NOT NULL
                                        REFERENCES dim_customer(customer_key),

    -- ── Measures ─────────────────────────────────────────────────────────────
    units_sold           INT            NOT NULL CHECK (units_sold > 0),
    unit_price_at_sale   NUMERIC(12,2)  NOT NULL CHECK (unit_price_at_sale > 0),
    total_sale_amount    NUMERIC(14,2)  NOT NULL,   -- units_sold × unit_price_at_sale
    discount_amount      NUMERIC(14,2)  NOT NULL DEFAULT 0.00
                                        CHECK (discount_amount >= 0),
    net_sale_amount      NUMERIC(14,2)  NOT NULL    -- total_sale_amount - discount_amount
);

-- =============================================================================
-- Helper view: resolve business keys to surrogate keys cleanly
-- =============================================================================
-- In production you would use a staging + MERGE/UPSERT pipeline.
-- For this exercise we use scalar subqueries inline in the INSERT.
-- =============================================================================

INSERT INTO fact_sales
    (transaction_id, date_key, store_key, product_key, customer_key,
     units_sold, unit_price_at_sale, total_sale_amount, discount_amount, net_sale_amount)
VALUES
-- ─────────────────────────────────────────────────────────────────────────────
-- Cleaning notes applied row by row:
--   date_key   : all dates normalised to YYYYMMDD integer key
--   store_key  : looked up from dim_store by store_name (city NULLs filled)
--   product_key: looked up from dim_product by product_name
--   category   : "electronics" → "Electronics"; "Grocery" → "Groceries"
--   city NULLs : inferred from store_name (store→city is 1-to-1)
-- ─────────────────────────────────────────────────────────────────────────────

-- TXN5000 | 29/08/2023 (DD/MM/YYYY → 2023-08-29) | Chennai Anna | Speaker | category "electronics" → "Electronics"
(
    'TXN5000', 20230829,
    (SELECT store_key   FROM dim_store    WHERE store_id    = 'STR002'),
    (SELECT product_key FROM dim_product  WHERE product_id  = 'PRD014'),
    (SELECT customer_key FROM dim_customer WHERE customer_id = 'CUST045'),
    3, 49262.78, 147788.34, 0.00, 147788.34
),

-- TXN5001 | 12-12-2023 (DD-MM-YYYY → 2023-12-12) | Chennai Anna | Tablet
(
    'TXN5001', 20231212,
    (SELECT store_key   FROM dim_store    WHERE store_id    = 'STR002'),
    (SELECT product_key FROM dim_product  WHERE product_id  = 'PRD016'),
    (SELECT customer_key FROM dim_customer WHERE customer_id = 'CUST021'),
    11, 23226.12, 255487.32, 0.00, 255487.32
),

-- TXN5002 | 2023-02-05 (already ISO) | Chennai Anna | Phone
(
    'TXN5002', 20230205,
    (SELECT store_key   FROM dim_store    WHERE store_id    = 'STR002'),
    (SELECT product_key FROM dim_product  WHERE product_id  = 'PRD009'),
    (SELECT customer_key FROM dim_customer WHERE customer_id = 'CUST019'),
    20, 48703.39, 974067.80, 0.00, 974067.80
),

-- TXN5003 | 20-02-2023 (DD-MM-YYYY → 2023-02-20) | Delhi South | Tablet
(
    'TXN5003', 20230220,
    (SELECT store_key   FROM dim_store    WHERE store_id    = 'STR003'),
    (SELECT product_key FROM dim_product  WHERE product_id  = 'PRD016'),
    (SELECT customer_key FROM dim_customer WHERE customer_id = 'CUST007'),
    14, 23226.12, 325165.68, 0.00, 325165.68
),

-- TXN5004 | 2023-01-15 | Chennai Anna | Smartwatch | category "electronics" → "Electronics"
(
    'TXN5004', 20230115,
    (SELECT store_key   FROM dim_store    WHERE store_id    = 'STR002'),
    (SELECT product_key FROM dim_product  WHERE product_id  = 'PRD013'),
    (SELECT customer_key FROM dim_customer WHERE customer_id = 'CUST004'),
    10, 58851.01, 588510.10, 0.00, 588510.10
),

-- TXN5005 | 2023-08-09 | Bangalore MG | Atta 10kg | category "Grocery" → "Groceries"
(
    'TXN5005', 20230809,
    (SELECT store_key   FROM dim_store    WHERE store_id    = 'STR001'),
    (SELECT product_key FROM dim_product  WHERE product_id  = 'PRD001'),
    (SELECT customer_key FROM dim_customer WHERE customer_id = 'CUST027'),
    12, 52464.00, 629568.00, 0.00, 629568.00
),

-- TXN5006 | 2023-03-31 | Pune FC Road | Smartwatch | category "electronics" → "Electronics"
(
    'TXN5006', 20230331,
    (SELECT store_key   FROM dim_store    WHERE store_id    = 'STR005'),
    (SELECT product_key FROM dim_product  WHERE product_id  = 'PRD013'),
    (SELECT customer_key FROM dim_customer WHERE customer_id = 'CUST025'),
    6, 58851.01, 353106.06, 0.00, 353106.06
),

-- TXN5007 | 2023-10-26 | Pune FC Road | Jeans
(
    'TXN5007', 20231026,
    (SELECT store_key   FROM dim_store    WHERE store_id    = 'STR005'),
    (SELECT product_key FROM dim_product  WHERE product_id  = 'PRD005'),
    (SELECT customer_key FROM dim_customer WHERE customer_id = 'CUST041'),
    16, 2317.47, 37079.52, 0.00, 37079.52
),

-- TXN5008 | 2023-12-08 | Bangalore MG | Biscuits | category "Groceries" ✓
(
    'TXN5008', 20231208,
    (SELECT store_key   FROM dim_store    WHERE store_id    = 'STR001'),
    (SELECT product_key FROM dim_product  WHERE product_id  = 'PRD002'),
    (SELECT customer_key FROM dim_customer WHERE customer_id = 'CUST030'),
    9, 27469.99, 247229.91, 0.00, 247229.91
),

-- TXN5009 | 15/08/2023 (DD/MM/YYYY → 2023-08-15) | Bangalore MG | Smartwatch | "electronics" → "Electronics"
(
    'TXN5009', 20230815,
    (SELECT store_key   FROM dim_store    WHERE store_id    = 'STR001'),
    (SELECT product_key FROM dim_product  WHERE product_id  = 'PRD013'),
    (SELECT customer_key FROM dim_customer WHERE customer_id = 'CUST020'),
    3, 58851.01, 176553.03, 0.00, 176553.03
),

-- TXN5010 | 2023-06-04 | Chennai Anna | Jacket
(
    'TXN5010', 20230604,
    (SELECT store_key   FROM dim_store    WHERE store_id    = 'STR002'),
    (SELECT product_key FROM dim_product  WHERE product_id  = 'PRD004'),
    (SELECT customer_key FROM dim_customer WHERE customer_id = 'CUST031'),
    15, 30187.24, 452808.60, 0.00, 452808.60
),

-- TXN5011 | 20/10/2023 (DD/MM/YYYY → 2023-10-20) | Mumbai Central | Jeans
(
    'TXN5011', 20231020,
    (SELECT store_key   FROM dim_store    WHERE store_id    = 'STR004'),
    (SELECT product_key FROM dim_product  WHERE product_id  = 'PRD005'),
    (SELECT customer_key FROM dim_customer WHERE customer_id = 'CUST045'),
    13, 2317.47, 30127.11, 0.00, 30127.11
),

-- TXN5012 | 2023-05-21 | Bangalore MG | Laptop
(
    'TXN5012', 20230521,
    (SELECT store_key   FROM dim_store    WHERE store_id    = 'STR001'),
    (SELECT product_key FROM dim_product  WHERE product_id  = 'PRD006'),
    (SELECT customer_key FROM dim_customer WHERE customer_id = 'CUST044'),
    13, 42343.15, 550460.95, 0.00, 550460.95
),

-- TXN5013 | 28-04-2023 (DD-MM-YYYY → 2023-04-28) | Mumbai Central | Milk 1L | "Groceries" ✓
(
    'TXN5013', 20230428,
    (SELECT store_key   FROM dim_store    WHERE store_id    = 'STR004'),
    (SELECT product_key FROM dim_product  WHERE product_id  = 'PRD007'),
    (SELECT customer_key FROM dim_customer WHERE customer_id = 'CUST015'),
    10, 43374.39, 433743.90, 0.00, 433743.90
),

-- TXN5014 | 2023-11-18 | Delhi South | Jacket
(
    'TXN5014', 20231118,
    (SELECT store_key   FROM dim_store    WHERE store_id    = 'STR003'),
    (SELECT product_key FROM dim_product  WHERE product_id  = 'PRD004'),
    (SELECT customer_key FROM dim_customer WHERE customer_id = 'CUST042'),
    5, 30187.24, 150936.20, 0.00, 150936.20
);


-- =============================================================================
-- VERIFICATION QUERIES
-- Run these after loading to sanity-check the schema.
-- =============================================================================

-- Row counts per table
-- SELECT 'dim_date'     AS tbl, COUNT(*) AS rows FROM dim_date
-- UNION ALL
-- SELECT 'dim_store',           COUNT(*)          FROM dim_store
-- UNION ALL
-- SELECT 'dim_product',         COUNT(*)          FROM dim_product
-- UNION ALL
-- SELECT 'dim_customer',        COUNT(*)          FROM dim_customer
-- UNION ALL
-- SELECT 'fact_sales',          COUNT(*)          FROM fact_sales;

-- Total revenue by category (tests all four joins)
-- SELECT p.category,
--        SUM(f.total_sale_amount)  AS gross_revenue,
--        SUM(f.units_sold)         AS total_units
-- FROM   fact_sales f
-- JOIN   dim_product  p ON f.product_key  = p.product_key
-- GROUP  BY p.category
-- ORDER  BY gross_revenue DESC;

-- Monthly revenue (tests dim_date join)
-- SELECT d.year, d.month_name, d.month_number,
--        SUM(f.total_sale_amount) AS monthly_revenue
-- FROM   fact_sales f
-- JOIN   dim_date d ON f.date_key = d.date_key
-- GROUP  BY d.year, d.month_number, d.month_name
-- ORDER  BY d.year, d.month_number;

-- Revenue by store and region (tests dim_store join)
-- SELECT s.region, s.store_name, s.city,
--        SUM(f.total_sale_amount) AS store_revenue
-- FROM   fact_sales f
-- JOIN   dim_store s ON f.store_key = s.store_key
-- GROUP  BY s.region, s.store_name, s.city
-- ORDER  BY s.region, store_revenue DESC;
