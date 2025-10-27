
# Mini E-Commerce Data Warehouse (Capstone)

## Overview
This is a mini end-to-end data warehouse project that simulates an e-commerce analytics pipeline.  
It demonstrates ELT (staging → transform → load), star-schema modeling, and analytical queries suitable for dashboards and ML feature extraction.

**Key features**
- Staging layer (`stg_*`) loaded from CSVs
- Dimension tables: `dim_customer`, `dim_product`, `dim_date`, `dim_region`, `dim_category`
- Fact table: `fact_sales` (order-line granularity, PK = `(order_id, product_id)`)
- Transformation encapsulated in `transformed_sales` view (optional `transformed_sales_mv` materialized view)
- Analytics queries (daily/monthly trends, top customers/products, rollups, basket analysis)

## Repo structure
```
mini_ecommerce_dw/
├── data/
│   ├── customers.csv
│   ├── products.csv
│   ├── orders.csv
│   └── order_items.csv
├── schema_and_staging.csv_load.sql
├── etl_load.sql
├── analytics_queries.sql
├── sample_outputs/
│   ├── daily_sales.csv
│   ├── top_products_by_revenue.csv
│   └── …
├── ER_diagram_ascii.txt
└── README.md
```

## How to run (quick)
1. Create a database (e.g., `ecommerce_dw`) and connect with psql/DBeaver.
2. Import CSVs into `customers`, `products`, `orders`, `order_items` (DBeaver Import or `\copy`).
3. Run `schema_and_staging.csv_load.sql` (to create staging and copy data).
4. Run `etl_load.sql` (creates dims, date table, transformed view, and `fact_sales`).
5. Run `analytics_queries.sql` to generate reports and export CSVs.

## Key SQL artifacts
- `schema_and_staging.csv_load.sql` — schema + staging + CSV load instructions.
- `etl_load.sql` — build dims + transformed view + load `fact_sales`.
- `analytics_queries.sql` — reports used for dashboards and insights.

## Quick sanity checks
- Compare OLTP totals:
  ```sql
  SELECT SUM(oi.quantity * p.price) FROM stg_order_items oi JOIN stg_products p ON oi.product_id = p.product_id;
  SELECT SUM(total_amount) FROM fact_sales;
  ```
-	Date coverage:
  ```
  SELECT MIN(full_date), MAX(full_date) FROM dim_date;
  ```
---

## 3) ER diagram (ASCII) — paste to `ER_diagram_ascii.txt`
                   +----------------+
                   |  dim_region    |
                   | region_id (PK) |
                   | region_name    |
                   +--------+-------+
                            |
                            |
+—————+       +—––v––––+      +–––––––+
| dim_customer  |       |   fact_sales   |      |  dim_product |
| customer_id PK|<——+ order_id       +—–>| product_id PK|
| customer_name |       | product_id PK  |      | product_name |
| email         |       | customer_id FK |      | category_id FK
| region_id FK  |       | date_id  FK    |      | price        |
+—————+       | total_amount   |      +–––––––+
| total_quantity |
+—––+––––+
|
|
+——v—––+
|   dim_date   |
| date_id (PK) |
| full_date    |
| day month yr |
+–––––––+

If you prefer a PNG: open draw.io / DBeaver ER export and export PNG, drop into repo as `ER_diagram.png`.

---

## 4) Git & GitHub — exact commands to publish
From your project root:
```bash
cd mini_ecommerce_dw
git init
git add .
git commit -m "mini ecommerce dw capstone: schema, etl, analytics"
# Create a repo on GitHub (via web), then:
git remote add origin git@github.com:<yourusername>/mini_ecommerce_dw.git
git branch -M main
git push -u origin main
```
