-- =====================================================================
-- E-commerce Analytics Database : schema
-- Target: MySQL 8.0+  (also runs unchanged on SQLite 3.25+ for testing)
-- =====================================================================

-- Drop in child-first order so foreign keys never block the drops
DROP VIEW  IF EXISTS v_order_totals;
DROP VIEW  IF EXISTS v_revenue_orders;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    customer_id  INT           PRIMARY KEY,
    full_name    VARCHAR(100)  NOT NULL,
    email        VARCHAR(120)  NOT NULL UNIQUE,
    city         VARCHAR(50)   NOT NULL,
    signup_date  DATE          NOT NULL
);

CREATE TABLE categories (
    category_id    INT          PRIMARY KEY,
    category_name  VARCHAR(50)  NOT NULL UNIQUE
);

CREATE TABLE products (
    product_id    INT            PRIMARY KEY,
    product_name  VARCHAR(100)   NOT NULL,
    category_id   INT            NOT NULL,
    unit_price    DECIMAL(10,2)  NOT NULL CHECK (unit_price > 0),
    FOREIGN KEY (category_id) REFERENCES categories (category_id)
);

CREATE TABLE orders (
    order_id     INT          PRIMARY KEY,
    customer_id  INT          NOT NULL,
    order_date   DATE         NOT NULL,
    status       VARCHAR(20)  NOT NULL
                 CHECK (status IN ('DELIVERED', 'SHIPPED', 'CANCELLED', 'RETURNED')),
    FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
);

-- unit_price here is the price actually charged (may differ from products.unit_price
-- because of discounts or later price changes)
CREATE TABLE order_items (
    order_id    INT            NOT NULL,
    product_id  INT            NOT NULL,
    quantity    INT            NOT NULL CHECK (quantity > 0),
    unit_price  DECIMAL(10,2)  NOT NULL CHECK (unit_price > 0),
    PRIMARY KEY (order_id, product_id),
    FOREIGN KEY (order_id)   REFERENCES orders (order_id),
    FOREIGN KEY (product_id) REFERENCES products (product_id)
);

CREATE TABLE payments (
    payment_id  INT            PRIMARY KEY,
    order_id    INT            NOT NULL UNIQUE,
    method      VARCHAR(20)    NOT NULL
                CHECK (method IN ('UPI', 'CARD', 'NETBANKING', 'COD')),
    amount      DECIMAL(10,2)  NOT NULL,
    paid_on     DATE           NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders (order_id)
);

-- Indexes for the joins and filters the analytics queries use most
CREATE INDEX idx_orders_customer    ON orders (customer_id);
CREATE INDEX idx_orders_date        ON orders (order_date);
CREATE INDEX idx_items_product      ON order_items (product_id);
CREATE INDEX idx_products_category  ON products (category_id);

-- ---------------------------------------------------------------------
-- Views
-- ---------------------------------------------------------------------

-- One row per order with its computed total
CREATE VIEW v_order_totals AS
SELECT  o.order_id,
        o.customer_id,
        o.order_date,
        o.status,
        SUM(oi.quantity * oi.unit_price) AS order_total
FROM    orders o
JOIN    order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id, o.customer_id, o.order_date, o.status;

-- "Revenue" orders = money actually kept (not cancelled, not returned)
CREATE VIEW v_revenue_orders AS
SELECT  *
FROM    v_order_totals
WHERE   status IN ('DELIVERED', 'SHIPPED');
