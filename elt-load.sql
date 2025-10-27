-- etl_load.sql
BEGIN;

-- 1) Create dimension tables if not exists
CREATE TABLE IF NOT EXISTS dim_region (
  region_id SERIAL PRIMARY KEY,
  region_name VARCHAR(50) UNIQUE
);

CREATE TABLE IF NOT EXISTS dim_category (
  category_id SERIAL PRIMARY KEY,
  category_name VARCHAR(100) UNIQUE
);

CREATE TABLE IF NOT EXISTS dim_customer (
  customer_id INT PRIMARY KEY,
  customer_name VARCHAR(100),
  email VARCHAR(150),
  region_id INT REFERENCES dim_region(region_id)
);

CREATE TABLE IF NOT EXISTS dim_product (
  product_id INT PRIMARY KEY,
  product_name VARCHAR(200),
  category_id INT REFERENCES dim_category(category_id),
  price DECIMAL(10,2)
);

CREATE TABLE IF NOT EXISTS dim_date (
  date_id SERIAL PRIMARY KEY,
  full_date DATE UNIQUE,
  day INT,
  month INT,
  year INT,
  weekday INT
);

-- 2) Populate / upsert dim_region and dim_category (idempotent)
INSERT INTO dim_region (region_name)
SELECT r FROM (VALUES ('North'), ('South'), ('East'), ('West')) AS t(r) --here t is table with column name r
ON CONFLICT (region_name) DO NOTHING;

INSERT INTO dim_category (category_name)
SELECT c FROM (VALUES ('Accessories'), ('Peripherals'), ('Audio'), ('Hubs'), ('Storage'), ('Furniture'), ('Other')) AS t(c)
ON CONFLICT (category_name) DO NOTHING;

-- 3) Upsert dim_customer from staging
INSERT INTO dim_customer (customer_id, customer_name, email)
SELECT customer_id, name, email
FROM stg_customers
ON CONFLICT (customer_id) DO UPDATE
  SET customer_name = EXCLUDED.customer_name,
      email = EXCLUDED.email;

-- 4) Upsert dim_product from staging with heuristic category mapping
INSERT INTO dim_product (product_id, product_name, category_id, price)
SELECT p.product_id, p.name,
       COALESCE(
         (SELECT category_id FROM dim_category WHERE category_name =
            CASE
              WHEN p.name ILIKE '%mouse%' THEN 'Accessories'
              WHEN p.name ILIKE '%keyboard%' THEN 'Peripherals'
              WHEN p.name ILIKE '%headphone%' OR p.name ILIKE '%headset%' OR p.name ILIKE '%earbud%' THEN 'Audio'
              WHEN p.name ILIKE '%hub%' THEN 'Hubs'
              WHEN p.name ILIKE '%ssd%' OR p.name ILIKE '%hdd%' OR p.name ILIKE '%storage%' THEN 'Storage'
              WHEN p.name ILIKE '%chair%' OR p.name ILIKE '%desk%' THEN 'Furniture'
              ELSE 'Other'
            END
         ), (SELECT category_id FROM dim_category WHERE category_name = 'Other' LIMIT 1)
       ) AS category_id,
       p.price
FROM stg_products p
ON CONFLICT (product_id) DO UPDATE
  SET product_name = EXCLUDED.product_name,
      price = EXCLUDED.price,
      category_id = EXCLUDED.category_id;

-- 5) Populate dim_date from staging orders (idempotent)
INSERT INTO dim_date (full_date, day, month, year, weekday)
SELECT DISTINCT o.order_date::date,
       EXTRACT(DAY FROM o.order_date)::INT,
       EXTRACT(MONTH FROM o.order_date)::INT,
       EXTRACT(YEAR FROM o.order_date)::INT,
       EXTRACT(DOW FROM o.order_date)::INT
FROM stg_orders o
ON CONFLICT (full_date) DO NOTHING;

-- 6) OPTIONAL: Heuristic mapping of customers to regions (simple round-robin / hash)
-- Only set region_id if NULL to avoid overwriting deliberate mappings.
UPDATE dim_customer
SET region_id = sub.region_id
FROM (
  SELECT customer_id,
         CASE (customer_id % 4)
           WHEN 0 THEN (SELECT region_id FROM dim_region WHERE region_name = 'North' LIMIT 1)
           WHEN 1 THEN (SELECT region_id FROM dim_region WHERE region_name = 'South' LIMIT 1)
           WHEN 2 THEN (SELECT region_id FROM dim_region WHERE region_name = 'East' LIMIT 1)
           ELSE (SELECT region_id FROM dim_region WHERE region_name = 'West' LIMIT 1)
         END AS region_id
  FROM dim_customer
) AS sub
WHERE dim_customer.customer_id = sub.customer_id
  AND dim_customer.region_id IS NULL;

-- 7) Create transformed view (ELT transform) that aggregates order items per order+product
CREATE OR REPLACE VIEW transformed_sales AS
SELECT 
  o.order_id,
  o.customer_id,
  oi.product_id,
  o.order_date::date AS order_date,
  SUM(oi.quantity * p.price) AS total_amount,
  SUM(oi.quantity) AS total_quantity
FROM stg_orders o
JOIN stg_order_items oi ON o.order_id = oi.order_id
JOIN stg_products p ON oi.product_id = p.product_id
GROUP BY o.order_id, o.customer_id, oi.product_id, o.order_date;

-- 8) Create / refresh fact_sales table (idempotent)
CREATE TABLE IF NOT EXISTS fact_sales (
  order_id INT,
  product_id INT,
  customer_id INT,
  date_id INT REFERENCES dim_date(date_id),
  total_amount DECIMAL(12,2),
  total_quantity INT,
  PRIMARY KEY (order_id, product_id)
);

--drop table fact_sales;

-- Insert or update facts from the transformed view
INSERT INTO fact_sales (order_id, customer_id, product_id, date_id, total_amount, total_quantity)
SELECT 
  t.order_id,
  t.customer_id,
  t.product_id,
  d.date_id,
  t.total_amount,
  t.total_quantity
FROM transformed_sales t
JOIN dim_date d ON t.order_date = d.full_date
ON CONFLICT (order_id, product_id) DO UPDATE
  SET customer_id = EXCLUDED.customer_id,
      product_id = EXCLUDED.product_id,
      date_id = EXCLUDED.date_id,
      total_amount = EXCLUDED.total_amount,
      total_quantity = EXCLUDED.total_quantity;

-- 9) Indexes to speed up analytics
CREATE INDEX IF NOT EXISTS idx_fact_sales_date ON fact_sales(date_id);
CREATE INDEX IF NOT EXISTS idx_fact_sales_product ON fact_sales(product_id);
CREATE INDEX IF NOT EXISTS idx_fact_sales_customer ON fact_sales(customer_id);

-- 10) Sanity checks we will run
SELECT COUNT(*) FROM fact_sales;
SELECT SUM(total_amount) FROM fact_sales;
SELECT SUM(oi.quantity * p.price) FROM stg_order_items oi JOIN stg_products p ON oi.product_id = p.product_id;

COMMIT;