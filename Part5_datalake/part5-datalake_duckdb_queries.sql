-- =============================================================================
-- duckdb_queries.sql
-- Cross-format analytical queries using DuckDB.
--
-- HOW TO RUN
-- ─────────────────────────────────────────────────────────────────────────────
-- Option A — interactive shell:
--   duckdb
--   .read duckdb_queries.sql
--
-- Option B — one-shot:
--   duckdb -c ".read duckdb_queries.sql"
--
-- Option C — Python:
--   import duckdb
--   duckdb.sql(open("duckdb_queries.sql").read())
--
-- All three files must be in the same directory as this script, OR replace
-- the bare filenames with absolute paths.
-- =============================================================================

-- =============================================================================
-- FILE SCHEMAS  (confirmed from file inspection)
-- =============================================================================
-- customers.csv   : customer_id, name, city, signup_date, email
--
-- orders.json     : order_id, customer_id, order_date, status,
--                   total_amount, num_items
--
-- products.parquet: line_item_id, order_id, product_id, product_name,
--                   category, quantity, unit_price, total_price
--
-- RELATIONSHIP MAP
--   customers.customer_id  →  orders.customer_id    (1 customer : many orders)
--   orders.order_id        →  products.order_id     (1 order    : many line items)
--
-- DuckDB reads each format natively — no ETL, no staging tables.
--   read_csv_auto()   auto-detects separator, header, and column types
--   read_json_auto()  flattens top-level JSON arrays into rows
--   read_parquet()    reads columnar binary directly from disk
-- =============================================================================


-- =============================================================================
-- Q1: List all customers along with the total number of orders they have placed
-- =============================================================================
-- Join path : customers (CSV) ← orders (JSON)
--
-- Design notes:
--   • LEFT JOIN from customers → orders so every customer appears in the
--     result, including those who have never placed an order (count = 0).
--     An INNER JOIN would silently drop zero-order customers.
--   • COUNT(o.order_id) counts non-NULL order_ids only; the LEFT JOIN
--     produces NULL for o.order_id when a customer has no orders, so
--     those customers correctly return 0 without needing COALESCE.
--   • Ordered by total_orders DESC so the most active customers surface
--     first, then alphabetically by name for ties.
-- =============================================================================

-- Q1: List all customers along with the total number of orders they have placed
SELECT
    c.customer_id,
    c.name                              AS customer_name,
    c.city,
    COUNT(o.order_id)                   AS total_orders
FROM
    read_csv_auto('customers.csv')      AS c
LEFT JOIN
    read_json_auto('orders.json')       AS o
    ON c.customer_id = o.customer_id
GROUP BY
    c.customer_id,
    c.name,
    c.city
ORDER BY
    total_orders DESC,
    c.name       ASC;


-- =============================================================================
-- Q2: Find the top 3 customers by total order value
-- =============================================================================
-- Join path : customers (CSV) ← orders (JSON)
--
-- Design notes:
--   • Uses total_amount stored directly in orders.json — this is the
--     authoritative order-level total, not recomputed from line items.
--   • INNER JOIN — customers with no orders have no revenue to rank,
--     so they are correctly excluded.
--   • Three supplementary metrics alongside total_order_value:
--       order_count     — volume (how many orders)
--       avg_order_value — efficiency (spend per visit)
--     Both help distinguish a high-value repeat buyer from a one-time
--     large spender, which has different business implications.
--   • LIMIT 3 handles the common case. For tie-safe top-3 use:
--       QUALIFY DENSE_RANK() OVER (ORDER BY SUM(o.total_amount) DESC) <= 3
-- =============================================================================

-- Q2: Find the top 3 customers by total order value
SELECT
    c.customer_id,
    c.name                              AS customer_name,
    c.city,
    COUNT(o.order_id)                   AS order_count,
    SUM(o.total_amount)                 AS total_order_value,
    ROUND(AVG(o.total_amount), 2)       AS avg_order_value
FROM
    read_csv_auto('customers.csv')      AS c
JOIN
    read_json_auto('orders.json')       AS o
    ON c.customer_id = o.customer_id
GROUP BY
    c.customer_id,
    c.name,
    c.city
ORDER BY
    total_order_value DESC
LIMIT 3;


-- =============================================================================
-- Q3: List all products purchased by customers from Bangalore
-- =============================================================================
-- Join path : customers (CSV) → orders (JSON) → products (Parquet)
--
-- This is the only query that spans all three file formats simultaneously.
--
-- Design notes:
--   • Three-way join: customer city filter pushes down early (DuckDB's
--     optimizer will evaluate WHERE c.city = 'Bangalore' before joining).
--   • products.parquet is a line-items table (one row per product per order),
--     joined to orders via order_id — NOT via customer_id directly.
--   • SELECT DISTINCT removes duplicate rows that arise when the same
--     product appears in multiple orders by the same Bangalore customer,
--     or when multiple Bangalore customers bought the same product.
--     The question asks "what products were purchased", not "how many times".
--   • unit_price and category are included to make the result a useful
--     product report, not just a list of names.
-- =============================================================================

-- Q3: List all products purchased by customers from Bangalore
SELECT DISTINCT
    c.name                              AS customer_name,
    c.city,
    p.product_id,
    p.product_name,
    p.category,
    p.unit_price
FROM
    read_csv_auto('customers.csv')      AS c
JOIN
    read_json_auto('orders.json')       AS o
    ON c.customer_id = o.customer_id
JOIN
    read_parquet('products.parquet')    AS p
    ON o.order_id = p.order_id
WHERE
    c.city = 'Bangalore'
ORDER BY
    c.name         ASC,
    p.product_name ASC;


-- =============================================================================
-- Q4: Join all three files to show:
--     customer name, order date, product name, and quantity
-- =============================================================================
-- Join path : customers (CSV) ← orders (JSON) → products (Parquet)
--
-- This is the canonical three-way cross-format join — the flagship
-- capability of DuckDB as a data lake query engine. In a traditional
-- warehouse this would require a full ETL pipeline to load all three
-- formats into a single system first. DuckDB eliminates that step entirely.
--
-- Design notes:
--   • Four required columns are shown first (customer_name, order_date,
--     product_name, quantity), followed by contextual columns that make
--     the result useful as a master order-line report.
--   • CAST(o.order_date AS DATE) ensures the date string from JSON is
--     typed correctly for date-aware sorting and downstream analytics.
--   • Ordered chronologically then by customer name, producing a readable
--     transaction log.
--   • DuckDB auto-detects the JSON array at the top level of orders.json
--     and flattens each object into a row — no manual UNNEST required.
-- =============================================================================

-- Q4: Join all three files to show: customer name, order date, product name, and quantity
SELECT
    -- Required four columns
    c.name                              AS customer_name,
    CAST(o.order_date AS DATE)          AS order_date,
    p.product_name,
    p.quantity,
    -- Additional context
    p.category,
    c.city,
    o.order_id,
    p.unit_price,
    p.total_price,
    o.status
FROM
    read_json_auto('orders.json')       AS o
JOIN
    read_csv_auto('customers.csv')      AS c
    ON o.customer_id = c.customer_id
JOIN
    read_parquet('products.parquet')    AS p
    ON o.order_id = p.order_id
ORDER BY
    order_date   ASC,
    c.name       ASC;
