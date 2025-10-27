-- analytics_queries.sql
-- Run these queries after etl_load.sql. Export each result to CSV for your repo.

-- 1) Daily sales trend (time-series)
-- Output file suggestion: sample_outputs/daily_sales.csv
SELECT d.full_date,
       SUM(f.total_amount) AS daily_sales,
       SUM(f.total_quantity) AS daily_items_sold
FROM fact_sales f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY d.full_date
ORDER BY d.full_date;

-- 2) Monthly revenue (year, month)
-- Output file suggestion: sample_outputs/monthly_sales.csv
SELECT d.year,
       d.month,
       SUM(f.total_amount) AS monthly_sales,
       SUM(f.total_quantity) AS monthly_items
FROM fact_sales f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY d.year, d.month
ORDER BY d.year, d.month;

-- 3) Top 10 products by revenue
-- Output file suggestion: sample_outputs/top_products_by_revenue.csv
SELECT p.product_name,
       cat.category_name,
       SUM(f.total_amount) AS revenue,
       SUM(f.total_quantity) AS units_sold
FROM fact_sales f
JOIN dim_product p ON f.product_id = p.product_id
LEFT JOIN dim_category cat ON p.category_id = cat.category_id
GROUP BY p.product_name, cat.category_name
ORDER BY revenue DESC
LIMIT 10;

-- 4) Top 10 customers by lifetime spend (window + aggregation)
-- Output: sample_outputs/top_customers.csv
SELECT customer_name, total_spent
FROM (
  SELECT c.customer_name,
         SUM(f.total_amount) AS total_spent,
         RANK() OVER (ORDER BY SUM(f.total_amount) DESC) AS rnk
  FROM fact_sales f
  JOIN dim_customer c ON f.customer_id = c.customer_id
  GROUP BY c.customer_name
) t
WHERE rnk <= 10
ORDER BY total_spent DESC;

-- 5) Sales by category and region (two-dimensional) with ROLLUP for subtotals
-- Output: sample_outputs/sales_by_category_region_rollup.csv
SELECT
  COALESCE(r.region_name, 'ALL_REGIONS') AS region_name,
  COALESCE(cat.category_name, 'ALL_CATEGORIES') AS category_name,
  SUM(f.total_amount) AS total_sales
FROM fact_sales f
JOIN dim_product p ON f.product_id = p.product_id
LEFT JOIN dim_category cat ON p.category_id = cat.category_id
JOIN dim_customer c ON f.customer_id = c.customer_id
LEFT JOIN dim_region r ON c.region_id = r.region_id
GROUP BY ROLLUP (r.region_name, cat.category_name)
ORDER BY r.region_name NULLS LAST, total_sales DESC;

-- 6) Top 2 categories per region (window function + partition)
-- Output: sample_outputs/top2_categories_per_region.csv
WITH sales_by_region_cat AS (
  SELECT r.region_name, cat.category_name, SUM(f.total_amount) AS total_sales
  FROM fact_sales f
  JOIN dim_product p ON f.product_id = p.product_id
  JOIN dim_category cat ON p.category_id = cat.category_id
  JOIN dim_customer c ON f.customer_id = c.customer_id
  JOIN dim_region r ON c.region_id = r.region_id
  GROUP BY r.region_name, cat.category_name
),
numbering AS (
	(
  SELECT s.*, ROW_NUMBER() OVER (PARTITION BY region_name ORDER BY total_sales DESC) AS rn
  FROM sales_by_region_cat s
)
)
SELECT region_name, category_name, total_sales
FROM numbering t
WHERE rn <= 2
ORDER BY region_name, total_sales DESC;

-- 7) Year-over-Year (YOY) growth (requires multiple years in dim_date)
-- Output: sample_outputs/yoy_growth.csv
WITH yearly AS (
  SELECT d.year, SUM(f.total_amount) AS yearly_sales
  FROM fact_sales f
  JOIN dim_date d ON f.date_id = d.date_id
  GROUP BY d.year
)
SELECT year,
       yearly_sales,
       LAG(yearly_sales) OVER (ORDER BY year) AS prev_year_sales,
       CASE
         WHEN LAG(yearly_sales) OVER (ORDER BY year) IS NULL THEN NULL
         WHEN LAG(yearly_sales) OVER (ORDER BY year) = 0 THEN null  --divide by zero should be avoided in next line
         ELSE ROUND( (yearly_sales - LAG(yearly_sales) OVER (ORDER BY year)) 
                     / LAG(yearly_sales) OVER (ORDER BY year) * 100, 2)
       END AS yoy_pct
FROM yearly
ORDER BY year;

-- 8) Average items per order (simple funnel metric)
-- Output: sample_outputs/avg_items_per_order.csv
SELECT AVG(total_quantity) AS avg_items_per_order,
       COUNT(*) AS total_orders
FROM fact_sales;

-- 9) Basket analysis - product pairs (top co-occurring products)
-- This finds pairs of products that appear together in the same order.
-- Output: sample_outputs/top_product_pairs.csv
WITH order_products AS (
  SELECT order_id, product_id
  FROM fact_sales
  GROUP BY order_id, product_id
),
pairs AS (
  SELECT a.product_id AS p1, b.product_id AS p2, COUNT(*) AS cnt
  FROM order_products a
  JOIN order_products b ON a.order_id = b.order_id AND a.product_id < b.product_id
  GROUP BY a.product_id, b.product_id
)
SELECT p1_name.product_name AS product_1,
       p2_name.product_name AS product_2,
       cnt AS times_ordered_together
FROM pairs
JOIN dim_product p1_name ON pairs.p1 = p1_name.product_id
JOIN dim_product p2_name ON pairs.p2 = p2_name.product_id
ORDER BY times_ordered_together desc
LIMIT 20;

-- 10) Sales distribution by price bucket (helps spot where revenue concentrates)
-- Output: sample_outputs/sales_by_price_bucket.csv
WITH sale_with_price AS (
  SELECT f.*, p.price
  FROM fact_sales f
  JOIN dim_product p ON f.product_id = p.product_id
),
buckets AS (
  SELECT *,
         CASE
           WHEN price < 1000 THEN '<1000'
           WHEN price >= 1000 AND price < 3000 THEN '1000-2999'
           WHEN price >= 3000 AND price < 6000 THEN '3000-5999'
           WHEN price >= 6000 AND price < 10000 THEN '6000-9999'
           ELSE '10000+'
         END AS price_bucket
  FROM sale_with_price
)
SELECT price_bucket, SUM(total_amount) AS revenue, SUM(total_quantity) AS units_sold
FROM buckets
GROUP BY price_bucket
ORDER BY revenue DESC;

--or simply
WITH sale_with_price AS (
  SELECT f.*, p.price,
  					CASE
			           WHEN p.price < 1000 THEN '<1000'
			           WHEN p.price >= 1000 AND p.price < 3000 THEN '1000-2999'
			           WHEN p.price >= 3000 AND p.price < 6000 THEN '3000-5999'
			           WHEN p.price >= 6000 AND p.price < 10000 THEN '6000-9999'
			           ELSE '10000+'
			         END AS price_bucket
  FROM fact_sales f
  JOIN dim_product p ON f.product_id = p.product_id
)
SELECT price_bucket, SUM(total_amount) AS revenue, SUM(total_quantity) AS units_sold
FROM sale_with_price
GROUP BY price_bucket
ORDER BY revenue DESC;