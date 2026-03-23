-- =============================================================================
-- queries.sql
-- All queries run against the 3NF schema defined in schema_design.sql.
-- Tested on the seed data loaded by that file.
-- =============================================================================


-- Q1: List all customers from Mumbai along with their total order value
-- -----------------------------------------------------------------------------
-- Joins customers → orders to sum (quantity × order_unit_price) per customer.
-- Only customers whose city is 'Mumbai' are included.
-- Customers from Mumbai who have placed no orders still appear with a total of 0
-- thanks to the LEFT JOIN + COALESCE.
-- -----------------------------------------------------------------------------
SELECT
    c.customer_id,
    c.customer_name,
    c.customer_email,
    COALESCE(SUM(o.quantity * o.order_unit_price), 0) AS total_order_value
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE c.customer_city = 'Mumbai'
GROUP BY c.customer_id, c.customer_name, c.customer_email
ORDER BY total_order_value DESC;


-- Q2: Find the top 3 products by total quantity sold
-- -----------------------------------------------------------------------------
-- Aggregates total units sold per product across all orders.
-- Products with zero orders are excluded (they have never been sold).
-- Ties at position 3 are broken alphabetically by product name.
-- -----------------------------------------------------------------------------
SELECT
    p.product_id,
    p.product_name,
    SUM(o.quantity) AS total_quantity_sold
FROM products p
JOIN orders o ON p.product_id = o.product_id
GROUP BY p.product_id, p.product_name
ORDER BY total_quantity_sold DESC, p.product_name ASC
LIMIT 3;


-- Q3: List all sales representatives and the number of unique customers they have handled
-- -----------------------------------------------------------------------------
-- Uses COUNT(DISTINCT ...) so a customer who places multiple orders with the
-- same rep is counted only once.
-- All reps appear in the result — including SR04 who has no orders yet —
-- because of the LEFT JOIN. This is only possible because sales_reps is its
-- own table (the Insert Anomaly fix from 1.1).
-- -----------------------------------------------------------------------------
SELECT
    sr.sales_rep_id,
    sr.sales_rep_name,
    sr.sales_rep_email,
    COUNT(DISTINCT o.customer_id) AS unique_customers_handled
FROM sales_reps sr
LEFT JOIN orders o ON sr.sales_rep_id = o.sales_rep_id
GROUP BY sr.sales_rep_id, sr.sales_rep_name, sr.sales_rep_email
ORDER BY unique_customers_handled DESC, sr.sales_rep_name ASC;


-- Q4: Find all orders where the total value exceeds 10,000, sorted by value descending
-- -----------------------------------------------------------------------------
-- Total order value = quantity × order_unit_price (the price locked in at the
-- time of purchase, not the current catalogue price).
-- Joins to customers and products to make the output human-readable.
-- -----------------------------------------------------------------------------
SELECT
    o.order_id,
    o.order_date,
    c.customer_name,
    p.product_name,
    o.quantity,
    o.order_unit_price,
    (o.quantity * o.order_unit_price) AS order_total_value
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN products  p ON o.product_id  = p.product_id
WHERE (o.quantity * o.order_unit_price) > 10000
ORDER BY order_total_value DESC;


-- Q5: Identify any products that have never been ordered
-- -----------------------------------------------------------------------------
-- A LEFT JOIN from products to orders, then filters for rows where no
-- matching order exists (o.order_id IS NULL).
-- Equivalent subquery version shown in a comment for reference.
-- -----------------------------------------------------------------------------
SELECT
    p.product_id,
    p.product_name,
    c.category_name,
    p.unit_price
FROM products p
JOIN categories c ON p.category_id = c.category_id
LEFT JOIN orders o ON p.product_id = o.product_id
WHERE o.order_id IS NULL
ORDER BY p.product_id;

-- Equivalent using NOT EXISTS (same result, sometimes preferred for clarity):
-- SELECT p.product_id, p.product_name, p.unit_price
-- FROM   products p
-- WHERE  NOT EXISTS (
--            SELECT 1 FROM orders o WHERE o.product_id = p.product_id
--        );
