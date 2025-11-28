# Walmart Data Warehouse

A comprehensive data warehouse solution for Walmart retail data, implementing a dimensional model with ETL procedures using dbt and Snowflake.

## Overview

This repository contains a dbt project that:

- **Loads data from S3** via Snowflake COPY/Snowpipe
- **Transforms raw data** through staging models
- **Creates dimension tables** using SCD Type 1 and SCD Type 2 strategies
- **Builds fact tables** with incremental loading

## Quick Start

1. Navigate to the dbt project:
   ```bash
   cd dbt_walmart
   ```

2. Set up environment variables (see [dbt_walmart/README.md](dbt_walmart/README.md))

3. Install dependencies:
   ```bash
   pip install dbt-snowflake
   dbt deps
   ```

4. Run the project:
   ```bash
   dbt run
   ```

## Project Structure

```
walmart-app/
└── dbt_walmart/           # dbt project
    ├── models/
    │   ├── staging/       # Staging models (views)
    │   └── marts/
    │       ├── dim/       # Dimension tables (SCD1/SCD2)
    │       └── fact/      # Fact tables (incremental)
    ├── macros/            # SCD1, SCD2, and utility macros
    ├── snapshots/         # dbt snapshots for SCD2
    └── analyses/          # Snowflake infrastructure setup
```

## Key Features

### SCD Type 1 (Overwrite)
- **dim_store**: Store information (no history)
- **dim_supplier**: Supplier information (no history)

### SCD Type 2 (Historical Tracking)
- **dim_customer**: Customer history with versioning
- **dim_product**: Product history including pricing changes

### Fact Tables
- **fact_sales**: Line item level transactions
- **fact_orders**: Order header level aggregations

## Documentation

For detailed documentation, see:
- [dbt Project README](dbt_walmart/README.md)
- [Snowflake Infrastructure Setup](dbt_walmart/analyses/snowflake_infrastructure_setup.sql)

## Data Architecture

```
S3 (Raw CSV/JSON) 
    ↓
Snowpipe/COPY
    ↓
Raw Tables (Snowflake)
    ↓
dbt Staging (Views)
    ↓
dbt Marts (Dim/Fact Tables)
```