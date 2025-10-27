
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
