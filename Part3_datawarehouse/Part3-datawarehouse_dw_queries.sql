-- =============================================================================
-- dw_queries.sql
-- Analytical queries against the star schema defined in star_schema.sql.
-- All queries follow the same pattern: fact_sales as the central table,
-- joined outward to dimension tables — the defining characteristic of a
-- star schema query.
--
-- Tested against the 15 seed fact rows loaded in star_schema.sql.
-- =============================================================================


-- =============================================================================
-- Q1: Total sales revenue by product category for each month
-- =============================================================================
-- Purpose: Shows which category drives the most revenue in each calendar month
--          — a classic slice-and-dice report in retail BI.
--
-- Join path : fact_sales → dim_date    (for year / month)
--             fact_sales → dim_product (for category)
--
-- Aggregation:
--   total_revenue  = SUM of total_sale_amount  (fully additive measure)
--   total_units    = SUM of units_sold          (additive; useful for context)
--   avg_order_size = average revenue per transaction in that month/category
--
-- Ordering: year → month number → revenue DESC so months run chronologically
--           and the highest-earning category sits at the top within each month.
--
-- Note on month_number: included in GROUP BY / ORDER BY but excluded from the
-- final SELECT column list — it drives sort order without cluttering output.
--   To include it, add d.month_number to the SELECT list.
-- =============================================================================

-- Q1: Total sales revenue by product category for each month
SELECT
    d.year,
    d.month_name,
    p.category,
    SUM(f.total_sale_amount)              AS total_revenue,
    SUM(f.units_sold)                     AS total_units_sold,
    ROUND(AVG(f.total_sale_amount), 2)    AS avg_transaction_value
FROM fact_sales     f
JOIN dim_date       d ON f.date_key     = d.date_key
JOIN dim_product    p ON f.product_key  = p.product_key
GROUP BY
    d.year,
    d.month_number,
    d.month_name,
    p.category
ORDER BY
    d.year          ASC,
    d.month_number  ASC,
    total_revenue   DESC;


-- =============================================================================
-- Q2: Top 2 performing stores by total revenue
-- =============================================================================
-- Purpose: Identifies the two stores contributing the most gross revenue —
--          useful for resource allocation, bonus calculations, and benchmarking.
--
-- Join path : fact_sales → dim_store (for store name, city, region)
--
-- Why LIMIT 2 vs RANK()?
--   LIMIT 2 is simpler and portable across MySQL/PostgreSQL/SQLite.
--   The window-function alternative (shown in the comment below) handles ties
--   correctly: if two stores share the 2nd-highest revenue they both appear.
--   Use the window version in production; LIMIT 2 is fine when ties are
--   unlikely (e.g., continuous revenue figures).
--
-- Additional measures included:
--   total_transactions — how busy the store is (volume vs value distinction)
--   avg_basket_value   — revenue per transaction (efficiency metric)
--   total_units_sold   — physical throughput
-- =============================================================================

-- Q2: Top 2 performing stores by total revenue
SELECT
    s.store_name,
    s.city,
    s.region,
    SUM(f.total_sale_amount)           AS total_revenue,
    COUNT(f.sale_id)                   AS total_transactions,
    ROUND(AVG(f.total_sale_amount), 2) AS avg_basket_value,
    SUM(f.units_sold)                  AS total_units_sold
FROM fact_sales  f
JOIN dim_store   s ON f.store_key = s.store_key
GROUP BY
    s.store_key,
    s.store_name,
    s.city,
    s.region
ORDER BY total_revenue DESC
LIMIT 2;

-- ── Alternative using window function (handles ties at rank 2) ───────────────
-- SELECT store_name, city, region, total_revenue, total_transactions
-- FROM (
--     SELECT
--         s.store_name,
--         s.city,
--         s.region,
--         SUM(f.total_sale_amount)  AS total_revenue,
--         COUNT(f.sale_id)          AS total_transactions,
--         RANK() OVER (ORDER BY SUM(f.total_sale_amount) DESC) AS revenue_rank
--     FROM fact_sales f
--     JOIN dim_store  s ON f.store_key = s.store_key
--     GROUP BY s.store_key, s.store_name, s.city, s.region
-- ) ranked
-- WHERE revenue_rank <= 2;


-- =============================================================================
-- Q3: Month-over-month sales trend across all stores
-- =============================================================================
-- Purpose: Shows how total revenue moves month by month, allowing the business
--          to spot growth, seasonality, and decline at a glance.
--
-- Join path : fact_sales → dim_date (for year / month)
--
-- Columns:
--   current_month_revenue  — this month's total revenue
--   prev_month_revenue     — previous month's total revenue (LAG window function)
--   mom_change_amount      — absolute change in INR
--   mom_change_pct         — percentage change, rounded to 2 dp
--
-- Window function LAG(revenue, 1):
--   Looks back exactly one row in the time-ordered partition.
--   Because there is only one year of data (2023) we do not need to PARTITION
--   BY year; if multi-year data were present, add PARTITION BY year to avoid
--   Jan of year N incorrectly comparing to Dec of year N-1.
--
-- NULLIF in the percentage formula prevents division-by-zero when the
-- previous month's revenue is 0.
--
-- The first month in the series always shows NULL for prev_month_revenue and
-- both change columns — this is correct and expected behaviour.
-- =============================================================================

-- Q3: Month-over-month sales trend across all stores
WITH monthly_revenue AS (
    SELECT
        d.year,
        d.month_number,
        d.month_name,
        SUM(f.total_sale_amount)  AS current_month_revenue,
        SUM(f.units_sold)         AS current_month_units
    FROM fact_sales  f
    JOIN dim_date    d ON f.date_key = d.date_key
    GROUP BY
        d.year,
        d.month_number,
        d.month_name
)
SELECT
    year,
    month_name,
    current_month_revenue,
    current_month_units,
    LAG(current_month_revenue, 1) OVER (
        ORDER BY year, month_number
    )                                                       AS prev_month_revenue,
    ROUND(
        current_month_revenue
        - LAG(current_month_revenue, 1) OVER (
            ORDER BY year, month_number
          ),
        2
    )                                                       AS mom_change_amount,
    ROUND(
        (
            current_month_revenue
            - LAG(current_month_revenue, 1) OVER (
                ORDER BY year, month_number
              )
        )
        / NULLIF(
            LAG(current_month_revenue, 1) OVER (
                ORDER BY year, month_number
            ),
            0
          ) * 100,
        2
    )                                                       AS mom_change_pct
FROM monthly_revenue
ORDER BY year ASC, month_number ASC;
