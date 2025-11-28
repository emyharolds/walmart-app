# Walmart dbt Project

This dbt project implements a data warehouse for Walmart retail data, loading data from S3 into Snowflake and transforming it into a dimensional model with fact and dimension tables.

## Project Overview

### Data Flow Architecture

```
S3 (Raw Files) --> Snowpipe/COPY --> Raw Tables --> dbt Staging --> dbt Marts (Dim/Fact)
```

### Key Features

- **S3 to Snowflake Ingestion**: Automated data loading via Snowpipe or manual COPY commands
- **SCD Type 1**: Dimension tables that overwrite historical data (dim_store, dim_supplier)
- **SCD Type 2**: Dimension tables that track historical changes (dim_customer, dim_product)
- **Incremental Loading**: Efficient fact table loading with incremental strategy
- **Date Dimension**: Conformed date dimension with fiscal calendar support

## Project Structure

```
dbt_walmart/
├── dbt_project.yml          # Project configuration
├── profiles.yml             # Connection profiles (use environment variables)
├── packages.yml             # dbt package dependencies
├── models/
│   ├── staging/             # Staging models (views over raw data)
│   │   ├── _sources.yml     # Source definitions
│   │   ├── _schema.yml      # Model documentation and tests
│   │   ├── stg_customers.sql
│   │   ├── stg_products.sql
│   │   ├── stg_stores.sql
│   │   ├── stg_orders.sql
│   │   ├── stg_order_items.sql
│   │   └── stg_suppliers.sql
│   └── marts/
│       ├── dim/             # Dimension tables
│       │   ├── _schema.yml
│       │   ├── dim_customer.sql   # SCD2
│       │   ├── dim_product.sql    # SCD2
│       │   ├── dim_store.sql      # SCD1
│       │   ├── dim_supplier.sql   # SCD1
│       │   └── dim_date.sql       # Static
│       └── fact/            # Fact tables
│           ├── _schema.yml
│           ├── fact_sales.sql     # Line item grain
│           └── fact_orders.sql    # Order header grain
├── macros/
│   ├── scd1.sql             # SCD Type 1 macros
│   ├── scd2.sql             # SCD Type 2 macros
│   └── utils.sql            # Utility macros
├── snapshots/               # dbt snapshots (alternative SCD2)
│   ├── snap_customers.sql
│   └── snap_products.sql
├── analyses/
│   └── snowflake_infrastructure_setup.sql  # Snowflake setup scripts
├── seeds/                   # Seed data (if any)
└── tests/                   # Custom tests
```

## Dimensional Model

### Dimension Tables

| Table | SCD Type | Description |
|-------|----------|-------------|
| dim_customer | SCD2 | Customer dimension with history tracking |
| dim_product | SCD2 | Product dimension with pricing history |
| dim_store | SCD1 | Store dimension (overwrites) |
| dim_supplier | SCD1 | Supplier dimension (overwrites) |
| dim_date | Static | Conformed date dimension |

### Fact Tables

| Table | Grain | Description |
|-------|-------|-------------|
| fact_sales | Order Line Item | Sales transactions at item level |
| fact_orders | Order Header | Order-level aggregations |

### SCD Type 1 vs SCD Type 2

**SCD Type 1 (Overwrite)**
- Used for: dim_store, dim_supplier
- No history tracking
- Latest values always overwrite previous values
- Use when historical changes are not important

**SCD Type 2 (Historical)**
- Used for: dim_customer, dim_product
- Full history tracking with versioning
- Columns: `valid_from`, `valid_to`, `is_current`
- Use when historical context is important (e.g., pricing, addresses)

## Setup Instructions

### Prerequisites

1. Snowflake account with appropriate privileges
2. AWS S3 bucket with raw data files
3. dbt Core or dbt Cloud
4. Python 3.8+

### Environment Variables

Set the following environment variables:

```bash
export SNOWFLAKE_ACCOUNT="your_account"
export SNOWFLAKE_USER="your_user"
export SNOWFLAKE_PASSWORD="your_password"
export SNOWFLAKE_ROLE="TRANSFORMER"
export SNOWFLAKE_DATABASE="WALMART_DB"
export SNOWFLAKE_WAREHOUSE="WALMART_WH"
```

### Installation

1. Install dbt with Snowflake adapter:
   ```bash
   pip install dbt-snowflake
   ```

2. Navigate to the project directory:
   ```bash
   cd dbt_walmart
   ```

3. Install dbt packages:
   ```bash
   dbt deps
   ```

4. Test connection:
   ```bash
   dbt debug
   ```

### Snowflake Infrastructure Setup

Before running dbt, set up the Snowflake infrastructure:

1. Review and customize `analyses/snowflake_infrastructure_setup.sql`
2. Run the SQL statements in Snowflake (requires ACCOUNTADMIN for storage integration)
3. Configure S3 bucket event notifications for Snowpipe

### Running the Project

```bash
# Run all models
dbt run

# Run with full refresh (rebuild all tables)
dbt run --full-refresh

# Run specific models
dbt run --select staging
dbt run --select marts.dim
dbt run --select marts.fact

# Run tests
dbt test

# Generate documentation
dbt docs generate
dbt docs serve

# Run snapshots (alternative SCD2)
dbt snapshot
```

## Model Dependencies

```
sources (raw)
    │
    ├── stg_customers ──┬── dim_customer (SCD2) ──┬── fact_sales
    │                   │                         │
    ├── stg_products ───┼── dim_product (SCD2) ───┤
    │                   │                         │
    ├── stg_stores ─────┼── dim_store (SCD1) ─────┤
    │                   │                         │
    ├── stg_suppliers ──┴── dim_supplier (SCD1)   │
    │                                             │
    ├── stg_orders ───────────────────────────────┼── fact_orders
    │                                             │
    └── stg_order_items ──────────────────────────┘
    
    dim_date (standalone)
```

## Incremental Loading Strategy

### Staging Models
- Materialized as views
- Always reflect current raw data

### Dimension Models (SCD1)
- Use `merge` strategy
- Update existing records based on business key
- Insert new records

### Dimension Models (SCD2)
- Detect changes via hash comparison
- Expire changed records (set `is_current = false`, update `valid_to`)
- Insert new versions with `is_current = true`

### Fact Tables
- Incremental loading based on `_loaded_at` timestamp
- Merge strategy to handle late-arriving data

## Testing

Run all tests:
```bash
dbt test
```

Test categories:
- **Schema tests**: Uniqueness, not null, relationships
- **Data tests**: Custom SQL tests in `/tests` directory

## Best Practices

1. **Always run staging before marts**: `dbt run --select staging+ marts`
2. **Use full refresh sparingly**: Only when schema changes or data issues require it
3. **Monitor Snowpipe**: Check pipe status regularly for ingestion issues
4. **Document changes**: Update schema.yml files when modifying models

## Troubleshooting

### Common Issues

1. **Snowpipe not loading data**
   - Check S3 event notifications
   - Verify storage integration permissions
   - Run `SELECT SYSTEM$PIPE_STATUS('pipe_name')`

2. **SCD2 not detecting changes**
   - Verify `updated_at` column is being updated in source
   - Check hash calculation includes all tracked columns

3. **Incremental models processing too much data**
   - Verify `_loaded_at` timestamp is accurate
   - Consider partitioning for large fact tables

## Contributing

1. Create a feature branch
2. Make changes and test locally
3. Update documentation
4. Submit pull request

## License

Internal use only - Walmart Corporation
