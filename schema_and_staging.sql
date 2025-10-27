-- schema_and_staging.sql for CSV load
BEGIN;

CREATE TABLE IF NOT EXISTS customers (
  customer_id SERIAL PRIMARY KEY,
  name VARCHAR(100),
  email VARCHAR(150) UNIQUE
);
CREATE TABLE IF NOT EXISTS products (
  product_id SERIAL PRIMARY KEY,
  name VARCHAR(200),
  price DECIMAL(10,2)
);
CREATE TABLE IF NOT EXISTS orders (
  order_id SERIAL PRIMARY KEY,
  customer_id INT REFERENCES customers(customer_id),
  order_date DATE DEFAULT CURRENT_DATE
);
CREATE TABLE IF NOT EXISTS order_items (
  order_id INT REFERENCES orders(order_id),
  product_id INT REFERENCES products(product_id),
  quantity INT,
  PRIMARY KEY (order_id, product_id)
);

-- Import data manually using DBeaver or pgAdmin import wizard from /data/*.csv

CREATE TABLE IF NOT EXISTS stg_customers (LIKE customers INCLUDING ALL);
CREATE TABLE IF NOT EXISTS stg_products (LIKE products INCLUDING ALL);
CREATE TABLE IF NOT EXISTS stg_orders (LIKE orders INCLUDING ALL);
CREATE TABLE IF NOT EXISTS stg_order_items (LIKE order_items INCLUDING ALL);

TRUNCATE stg_customers, stg_products, stg_orders, stg_order_items;

INSERT INTO stg_customers SELECT * FROM customers;
INSERT INTO stg_products SELECT * FROM products;
INSERT INTO stg_orders SELECT * FROM orders;
INSERT INTO stg_order_items SELECT * FROM order_items;

COMMIT;
