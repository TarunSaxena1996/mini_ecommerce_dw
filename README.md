
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

## 3) ER diagram 
### Input data-
<img width="609" height="294" alt="image" src="https://github.com/user-attachments/assets/b7de7fe4-0a70-4367-8938-e1913d8f307b" />
### Staged tables and views
<img width="1029" height="200" alt="image" src="https://github.com/user-attachments/assets/760b34c5-5ab1-4b32-8326-7d921c65f0c8" />

### Star schema
<img width="625" height="570" alt="image" src="https://github.com/user-attachments/assets/22fb52a8-1500-4684-b1bb-239b8a4813bd" />


                            



