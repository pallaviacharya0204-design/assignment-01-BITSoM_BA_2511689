-- =============================================================================
-- schema_design.sql
-- Normalized schema for orders_flat.csv — Third Normal Form (3NF)
--
-- Decomposition rationale
-- -----------------------
-- The flat file has one row per order and embeds four distinct real-world
-- entities inside it, creating all three anomaly types identified in 1.1:
--
--   orders_flat columns          → Entity
--   ─────────────────────────────────────────────────────────────────────
--   customer_id … customer_city  → customers      (1NF→2NF: not dependent
--   product_id  … unit_price     → products        on the full PK)
--   sales_rep_id… office_address → sales_reps      (3NF: transitive deps)
--   category                     → categories      (transitive via product)
--   order_id, quantity,          → orders          (fact table)
--   order_date, FK refs
--
-- 1NF  : Every column is atomic; no repeating groups.
-- 2NF  : Every non-key column depends on the *whole* primary key of its
--        table.  In a single-column PK table this is automatically satisfied.
-- 3NF  : No non-key column depends transitively on the PK through another
--        non-key column.
--        • product_name, unit_price depend on product_id, not on order_id
--          → extracted to `products`.
--        • category_name depends on category_id, not on product_id
--          → extracted to `categories`.
--        • customer_name, email, city depend on customer_id, not order_id
--          → extracted to `customers`.
--        • sales_rep_name, email, office_address depend on sales_rep_id
--          → extracted to `sales_reps`.
--
-- This design eliminates:
--   Insert anomaly  : a new sales rep (or customer/product) can be inserted
--                     into its own table with no order required.
--   Update anomaly  : office_address for SR01 is stored exactly once in
--                     sales_reps; one UPDATE fixes it everywhere.
--   Delete anomaly  : deleting all of C007's orders does not touch the
--                     customers row for Arjun Nair.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- TABLE: categories
-- Stores product categories. Extracted to eliminate the transitive dependency
-- product_id → category → category_name that existed in the flat file.
-- -----------------------------------------------------------------------------
CREATE TABLE categories (
    category_id   SERIAL        PRIMARY KEY,
    category_name VARCHAR(100)  NOT NULL UNIQUE
);

-- -----------------------------------------------------------------------------
-- TABLE: products
-- Each product has exactly one category. unit_price is the catalogue price and
-- lives here — not in orders — so changing a price needs one row update.
-- -----------------------------------------------------------------------------
CREATE TABLE products (
    product_id   CHAR(4)         PRIMARY KEY,          -- e.g. P001
    product_name VARCHAR(150)    NOT NULL,
    category_id  INT             NOT NULL
                                 REFERENCES categories(category_id),
    unit_price   NUMERIC(10, 2)  NOT NULL CHECK (unit_price > 0)
);

-- -----------------------------------------------------------------------------
-- TABLE: customers
-- Extracted so that customer data survives independently of any orders.
-- Fixes the Delete Anomaly: deleting all orders for C007 no longer destroys
-- Arjun Nair's record.
-- -----------------------------------------------------------------------------
CREATE TABLE customers (
    customer_id    CHAR(4)       PRIMARY KEY,           -- e.g. C001
    customer_name  VARCHAR(150)  NOT NULL,
    customer_email VARCHAR(255)  NOT NULL UNIQUE,
    customer_city  VARCHAR(100)  NOT NULL
);

-- -----------------------------------------------------------------------------
-- TABLE: sales_reps
-- Extracted so that a new rep can be onboarded before handling any order
-- (fixes the Insert Anomaly), and so that office_address is stored in exactly
-- one place (fixes the Update Anomaly for SR01's abbreviated address).
-- -----------------------------------------------------------------------------
CREATE TABLE sales_reps (
    sales_rep_id    CHAR(4)       PRIMARY KEY,          -- e.g. SR01
    sales_rep_name  VARCHAR(150)  NOT NULL,
    sales_rep_email VARCHAR(255)  NOT NULL UNIQUE,
    office_address  VARCHAR(255)  NOT NULL
);

-- -----------------------------------------------------------------------------
-- TABLE: orders
-- Pure fact table. Every non-key column depends solely on order_id.
-- unit_price is captured at the time of order as order_unit_price to preserve
-- historical accuracy if the catalogue price changes later.
-- -----------------------------------------------------------------------------
CREATE TABLE orders (
    order_id         CHAR(7)        PRIMARY KEY,        -- e.g. ORD1027
    customer_id      CHAR(4)        NOT NULL
                                    REFERENCES customers(customer_id),
    product_id       CHAR(4)        NOT NULL
                                    REFERENCES products(product_id),
    sales_rep_id     CHAR(4)        NOT NULL
                                    REFERENCES sales_reps(sales_rep_id),
    quantity         INT            NOT NULL CHECK (quantity > 0),
    order_unit_price NUMERIC(10, 2) NOT NULL CHECK (order_unit_price > 0),
    order_date       DATE           NOT NULL
);


-- =============================================================================
-- SEED DATA
-- =============================================================================

-- ── categories ────────────────────────────────────────────────────────────────
INSERT INTO categories (category_name) VALUES
    ('Electronics'),   -- 1
    ('Stationery'),    -- 2
    ('Furniture');     -- 3

-- ── products ──────────────────────────────────────────────────────────────────
INSERT INTO products (product_id, product_name, category_id, unit_price) VALUES
    ('P001', 'Laptop',        1, 55000.00),
    ('P002', 'Mouse',         1,   800.00),
    ('P003', 'Desk Chair',    3,  8500.00),
    ('P004', 'Notebook',      2,   120.00),
    ('P005', 'Headphones',    1,  3200.00),
    ('P006', 'Standing Desk', 3, 22000.00),
    ('P007', 'Pen Set',       2,   250.00),
    ('P008', 'Webcam',        1,  2100.00);

-- ── customers ─────────────────────────────────────────────────────────────────
-- Canonical record for every customer — exists independently of any order.
-- C007 (Arjun Nair) is now safe: deleting his orders will not delete him.
INSERT INTO customers (customer_id, customer_name, customer_email, customer_city) VALUES
    ('C001', 'Rohan Mehta',  'rohan@gmail.com',  'Mumbai'),
    ('C002', 'Priya Sharma', 'priya@gmail.com',  'Delhi'),
    ('C003', 'Amit Verma',   'amit@gmail.com',   'Bangalore'),
    ('C004', 'Sneha Iyer',   'sneha@gmail.com',  'Chennai'),
    ('C005', 'Vikram Singh', 'vikram@gmail.com', 'Mumbai'),
    ('C006', 'Neha Gupta',   'neha@gmail.com',   'Delhi'),
    ('C007', 'Arjun Nair',   'arjun@gmail.com',  'Bangalore'),
    ('C008', 'Kavya Rao',    'kavya@gmail.com',  'Hyderabad');

-- ── sales_reps ────────────────────────────────────────────────────────────────
-- Single authoritative row per rep.
-- SR01's office_address is stored once with the canonical spelling, eliminating
-- the "Nariman Pt" vs "Nariman Point" inconsistency found across 6 flat rows.
-- SR04 is inserted here even though they have no orders yet — this was
-- impossible in the flat file (Insert Anomaly fixed).
INSERT INTO sales_reps (sales_rep_id, sales_rep_name, sales_rep_email, office_address) VALUES
    ('SR01', 'Deepak Joshi', 'deepak@corp.com', 'Mumbai HQ, Nariman Point, Mumbai - 400021'),
    ('SR02', 'Anita Desai',  'anita@corp.com',  'Delhi Office, Connaught Place, New Delhi - 110001'),
    ('SR03', 'Ravi Kumar',   'ravi@corp.com',   'South Zone, MG Road, Bangalore - 560001'),
    ('SR04', 'Meera Pillai', 'meera@corp.com',  'East Zone, Park Street, Kolkata - 700016');

-- ── orders ────────────────────────────────────────────────────────────────────
-- A representative sample drawn directly from orders_flat.csv.
-- order_unit_price is the price at the time of purchase (snapshot), which may
-- differ from the current catalogue price in products.unit_price.
INSERT INTO orders (order_id, customer_id, product_id, sales_rep_id, quantity, order_unit_price, order_date) VALUES
    ('ORD1027', 'C002', 'P004', 'SR02', 4,   120.00, '2023-11-02'),
    ('ORD1114', 'C001', 'P007', 'SR01', 2,   250.00, '2023-08-06'),
    ('ORD1002', 'C002', 'P005', 'SR02', 1,  3200.00, '2023-01-17'),
    ('ORD1075', 'C005', 'P003', 'SR03', 3,  8500.00, '2023-04-18'),
    ('ORD1061', 'C006', 'P001', 'SR01', 4, 55000.00, '2023-10-27'),
    ('ORD1098', 'C007', 'P001', 'SR03', 2, 55000.00, '2023-10-03'),
    ('ORD1131', 'C008', 'P001', 'SR02', 4, 55000.00, '2023-06-22'),
    ('ORD1076', 'C004', 'P006', 'SR03', 5, 22000.00, '2023-05-16'),
    ('ORD1185', 'C003', 'P008', 'SR03', 1,  2100.00, '2023-06-15'),
    ('ORD1091', 'C001', 'P006', 'SR01', 3, 22000.00, '2023-07-24');
