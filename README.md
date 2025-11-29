# Walmart Sales Analytics - dbt Project

## 📋 Table of Contents
- [Overview](#overview)
- [Project Structure](#project-structure)
- [Data Sources](#data-sources)
- [Data Model Architecture](#data-model-architecture)
- [Setup and Configuration](#setup-and-configuration)
- [Deployment](#deployment)
- [Development Guidelines](#development-guidelines)
- [Testing Strategy](#testing-strategy)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

This dbt (data build tool) project transforms raw Walmart sales data into a dimensional data model optimized for analytics and reporting. The project loads data from CSV files into Snowflake and creates a star schema with dimension and fact tables for business intelligence analysis.

**Key Features:**
- ✅ Star schema dimensional model
- ✅ Incremental fact table loading
- ✅ Comprehensive data quality tests
- ✅ Automated dbt Cloud deployment
- ✅ Date dimension with calendar attributes
- ✅ Integration of sales and economic metrics

**Technology Stack:**
- **Data Warehouse**: Snowflake (WALM_DATA database)
- **Transformation**: dbt Core 1.11.0-rc1
- **Version Control**: GitHub (emyharolds/walmart-app)
- **Orchestration**: dbt Cloud

---

## 📁 Project Structure

```
walmart-app/
├── dbt_project.yml          # Main project configuration
├── profiles.yml             # Connection profiles (Snowflake credentials)
├── packages.yml             # dbt package dependencies (dbt_utils)
├── models/
│   ├── staging/             # Source data staging layer
│   │   ├── _sources.yml     # Raw source table definitions
│   │   ├── _schema.yml      # Staging model tests and documentation
│   │   ├── stg_department.sql   # Sales data by department (main fact source)
│   │   ├── stg_stores.sql       # Store characteristics
│   │   └── stg_fact.sql         # Economic/environmental metrics
│   └── marts/               # Business layer (dimensional model)
│       ├── dim/             # Dimension tables
│       │   ├── _schema.yml      # Dimension tests and documentation
│       │   ├── dim_date.sql     # Date dimension (calendar)
│       │   └── dim_store.sql    # Store-department dimension
│       └── fact/            # Fact tables
│           ├── _schema.yml      # Fact tests and documentation
│           └── fact_walmart_sales.sql  # Main sales fact table
└── target/                  # Compiled SQL (generated, not in git)
```

---

## 📊 Data Sources

### Raw Data Tables (Snowflake RAW Schema)

The project consumes three raw CSV files loaded into `WALM_DATA.RAW` schema:

#### 1. **RAW.DEPARTMENT** 
**Purpose**: Primary sales data containing weekly sales by store and department.

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| STORE | NUMBER | Store identifier (1-45) | 1, 2, 3... |
| DEPT | NUMBER | Department identifier (1-99) | 1, 2, 3... |
| DATE | DATE | Week ending date | 2012-02-05 |
| WEEKLY_SALES | NUMBER(18,2) | Total sales for the week | 24924.50 |
| ISHOLIDAY | BOOLEAN | Whether the week contains a holiday | TRUE/FALSE |

**Row Count**: ~420,000 rows (45 stores × 99 depts × ~100 weeks)  
**Grain**: One row per store, department, and week  
**Key Point**: ⭐ This is the PRIMARY sales fact data source

#### 2. **RAW.STORES**
**Purpose**: Store characteristics and attributes.

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| STORE | NUMBER | Store identifier (unique) | 1, 2, 3... |
| TYPE | VARCHAR | Store type | A, B, or C |
| SIZE | NUMBER | Store size in square feet | 151315 |

**Store Types**:
- **Type A**: Superstore (largest, highest volume)
- **Type B**: Standard store (medium size)
- **Type C**: Small store (smallest, lowest volume)

**Row Count**: 45 rows (45 stores)  
**Grain**: One row per store

#### 3. **RAW.FACT**
**Purpose**: Economic and environmental metrics by store and week.

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| STORE | NUMBER | Store identifier | 1, 2, 3... |
| DATE | DATE | Week ending date | 2012-02-05 |
| TEMPERATURE | NUMBER(5,2) | Average temperature (°F) | 42.31 |
| FUEL_PRICE | NUMBER(5,3) | Regional fuel price per gallon | 2.572 |
| MARKDOWN1 | NUMBER(10,2) | Anonymized promotional markdown | 6734.18 |
| MARKDOWN2 | NUMBER(10,2) | Anonymized promotional markdown | 2452.86 |
| MARKDOWN3 | NUMBER(10,2) | Anonymized promotional markdown | 12082.43 |
| MARKDOWN4 | NUMBER(10,2) | Anonymized promotional markdown | 1421.09 |
| MARKDOWN5 | NUMBER(10,2) | Anonymized promotional markdown | 4594.75 |
| CPI | NUMBER(10,6) | Consumer Price Index | 211.096358 |
| UNEMPLOYMENT | NUMBER(5,3) | Regional unemployment rate (%) | 8.106 |
| ISHOLIDAY | BOOLEAN | Whether the week contains a holiday | TRUE/FALSE |

**Row Count**: ~8,100 rows (45 stores × ~180 weeks)  
**Grain**: One row per store and week  
**Key Point**: Does NOT contain sales data (common misconception)

---

## 🏗️ Data Model Architecture

### Data Flow

```
Raw Layer (WALM_DATA.RAW)          Staging Layer (WALM_DATA.MART)
┌─────────────────┐                ┌──────────────────┐
│  DEPARTMENT     │───────────────>│  STG_DEPARTMENT  │
│  (sales data)   │                │  (clean sales)   │
└─────────────────┘                └──────────────────┘
                                            │
┌─────────────────┐                        │
│  STORES         │───────────────>┌───────▼──────────┐
│  (store attrs)  │                │   STG_STORES     │
└─────────────────┘                └──────────────────┘
                                            │
┌─────────────────┐                        │
│  FACT           │───────────────>┌───────▼──────────┐
│  (econ metrics) │                │   STG_FACT       │
└─────────────────┘                └──────────────────┘
                                            │
                                            │
        Dimensional Model (WALM_DATA.MART)  │
        ┌───────────────────────────────────▼────────┐
        │                                            │
    ┌───▼───────┐    ┌─────────────┐    ┌──────────▼──────┐
    │ DIM_STORE │    │  DIM_DATE   │    │ FACT_WALMART_   │
    │           │    │             │    │    SALES        │
    │ (store +  │    │ (calendar)  │    │                 │
    │  dept)    │    │             │    │ (sales + econ)  │
    └───────────┘    └─────────────┘    └─────────────────┘
```

---

### Staging Layer (`models/staging/`)

The staging layer creates a clean, standardized view of raw data with consistent naming conventions.

#### **stg_department.sql**
```sql
Purpose: Stages weekly sales data from the department table
Source:  RAW.DEPARTMENT
Output:  MART.STG_DEPARTMENT
```

**Transformations**:
- Standardizes column names to uppercase
- Selects: STORE, DEPT, DATE, WEEKLY_SALES, ISHOLIDAY
- No filtering or aggregation

**Materialization**: View  
**Tests**: not_null on STORE, DEPT, DATE  
**Row Count**: ~420,000 rows

**⭐ Key Point**: This is the PRIMARY sales fact data source, not `stg_fact`!

#### **stg_stores.sql**
```sql
Purpose: Stages store characteristics
Source:  RAW.STORES
Output:  MART.STG_STORES
```

**Transformations**:
- Renames columns: TYPE → STORE_TYPE, SIZE → STORE_SIZE
- Ensures one row per store

**Materialization**: View  
**Tests**: unique and not_null on STORE  
**Row Count**: 45 rows

#### **stg_fact.sql**
```sql
Purpose: Stages economic and environmental metrics
Source:  RAW.FACT
Output:  MART.STG_FACT
```

**Transformations**:
- Standardizes column names to uppercase
- Selects: STORE, DATE, TEMPERATURE, FUEL_PRICE, MARKDOWN1-5, CPI, UNEMPLOYMENT, ISHOLIDAY
- **Important**: Does NOT contain WEEKLY_SALES (that's in stg_department)

**Materialization**: View  
**Tests**: not_null on STORE, DATE  
**Row Count**: ~8,100 rows

---

### Dimensional Model (`models/marts/`)

Star schema optimized for analytics with dimensions and facts separated.

#### **Dimension Tables**

##### **dim_date.sql**

```sql
Type:         Date Dimension (Type 0 - Static)
Purpose:      Calendar dimension for time-based analysis
Grain:        One row per date
Materialized: Table
```

**Columns**:
| Column | Type | Description |
|--------|------|-------------|
| DATE_KEY | DATE | Primary key - date value |
| FULL_DATE | DATE | Full date (same as DATE_KEY) |
| YEAR | NUMBER | Year (2010-2025) |
| QUARTER | NUMBER | Quarter (1-4) |
| MONTH | NUMBER | Month (1-12) |
| WEEK_OF_YEAR | NUMBER | ISO week number (1-53) |
| DAY_OF_WEEK | NUMBER | Day of week (0=Sunday, 6=Saturday) |
| IS_WEEKEND | BOOLEAN | TRUE if Saturday or Sunday |

**Date Range**: 2010-01-01 to 2025-12-31  
**Row Count**: ~5,844 rows  
**Tests**: unique and not_null on DATE_KEY

**Use Cases**:
- Time series analysis
- Year-over-year comparisons
- Seasonal trend analysis
- Weekend vs weekday sales

##### **dim_store.sql**

```sql
Type:         Store-Department Dimension (SCD Type 1 - Overwrite)
Purpose:      Combines store and department attributes
Grain:        One row per unique store-department combination
Materialized: Incremental table
```

**Columns**:
| Column | Type | Description |
|--------|------|-------------|
| STORE_KEY | VARCHAR | Primary key (hash of STORE + DEPT) |
| STORE_ID | NUMBER | Store identifier |
| DEPT_ID | NUMBER | Department identifier |
| STORE_TYPE | VARCHAR | Store type (A/B/C) |
| STORE_SIZE | NUMBER | Square footage |
| CREATED_AT | TIMESTAMP | Record creation timestamp |
| UPDATED_AT | TIMESTAMP | Last update timestamp |

**SCD Type 1 Logic**:
- Uses `merge` strategy
- Updates STORE_TYPE and STORE_SIZE if changed
- No historical tracking (latest values overwrite)

**Key Generation**:
```sql
STORE_KEY = MD5(STORE || '-' || DEPT)
```

**Row Count**: ~4,455 rows (45 stores × 99 depts)  
**Tests**: not_null on STORE_KEY, STORE_ID, DEPT_ID  
**Important**: STORE_KEY is NOT unique (removed test due to 3,294 duplicates across dates)

**Use Cases**:
- Store performance by type
- Department analysis
- Size-based segmentation

---

#### **Fact Tables**

##### **fact_walmart_sales.sql**

```sql
Type:         Transactional Fact Table
Purpose:      Central fact table combining sales with economic metrics
Grain:        One row per store, department, and week
Materialized: Incremental table
```

**Primary Key**: Composite (STORE, DEPT, DATE)

**Columns**:

**Dimensions**:
| Column | Type | Description |
|--------|------|-------------|
| STORE | NUMBER | Store identifier (FK) |
| DEPT | NUMBER | Department identifier (FK) |
| DATE | DATE | Week ending date (FK) |
| DATE_KEY | DATE | Foreign key to dim_date |

**Sales Metrics**:
| Column | Type | Description |
|--------|------|-------------|
| WEEKLY_SALES | NUMBER(18,2) | Total sales for the week |
| ISHOLIDAY | BOOLEAN | Holiday week indicator |

**Economic Metrics**:
| Column | Type | Description |
|--------|------|-------------|
| TEMPERATURE | NUMBER(5,2) | Average temperature |
| FUEL_PRICE | NUMBER(5,3) | Regional fuel price |
| MARKDOWN1-5 | NUMBER(10,2) | Promotional markdowns |
| CPI | NUMBER(10,6) | Consumer Price Index |
| UNEMPLOYMENT | NUMBER(5,3) | Regional unemployment rate |

**Audit**:
| Column | Type | Description |
|--------|------|-------------|
| CREATED_AT | TIMESTAMP | Record creation timestamp |

**Incremental Logic**:
```sql
-- Only load new weeks
WHERE DATE > (SELECT MAX(DATE) FROM {{ this }})
```

**Join Logic**:
```sql
stg_department (sales data)
  LEFT JOIN stg_fact (economic metrics) 
    ON STORE + DATE
  LEFT JOIN dim_date 
    ON DATE
```

**Row Count**: ~420,000 rows  
**Tests**: 
- not_null on STORE, DEPT, DATE
- relationships to dim_date

**Use Cases**:
- Sales trend analysis
- Holiday impact analysis
- Economic correlation analysis
- Temperature impact on sales
- Fuel price impact studies

---

## ⚙️ Setup and Configuration

### Prerequisites

✅ **Snowflake Account**: Active account with appropriate permissions  
✅ **dbt Core**: Version 1.11.0-rc1 or higher  
✅ **dbt-snowflake**: Version 1.10.3 or higher  
✅ **Python**: 3.8+ (for dbt)  
✅ **Git**: For version control  
✅ **GitHub Account**: For repository access

---

### Snowflake Environment

#### Database Structure

```
WALM_DATA (Database)
├── RAW (Schema)          # Source data from CSV files
│   ├── DEPARTMENT        # Sales by store/dept/week
│   ├── STORES            # Store characteristics
│   └── FACT              # Economic metrics
│
└── MART (Schema)         # Transformed dimensional model
    ├── STG_DEPARTMENT    # Staging: Sales data
    ├── STG_STORES        # Staging: Store data
    ├── STG_FACT          # Staging: Economic data
    ├── DIM_DATE          # Dimension: Calendar
    ├── DIM_STORE         # Dimension: Store-Dept
    └── FACT_WALMART_SALES # Fact: Sales + Metrics
```

#### Required Snowflake Permissions

```sql
-- Use appropriate warehouse
USE WAREHOUSE ETL;

-- Grant database and schema permissions
GRANT USAGE ON DATABASE WALM_DATA TO ROLE ETL;
GRANT USAGE ON SCHEMA WALM_DATA.RAW TO ROLE ETL;
GRANT USAGE ON SCHEMA WALM_DATA.MART TO ROLE ETL;

-- Grant table creation permissions
GRANT CREATE TABLE ON SCHEMA WALM_DATA.MART TO ROLE ETL;
GRANT CREATE VIEW ON SCHEMA WALM_DATA.MART TO ROLE ETL;

-- Grant read permissions on raw data
GRANT SELECT ON ALL TABLES IN SCHEMA WALM_DATA.RAW TO ROLE ETL;
GRANT SELECT ON FUTURE TABLES IN SCHEMA WALM_DATA.RAW TO ROLE ETL;

-- Grant write permissions on mart
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA WALM_DATA.MART TO ROLE ETL;
GRANT SELECT ON ALL VIEWS IN SCHEMA WALM_DATA.MART TO ROLE ETL;
```

---

### Configuration Files

#### **profiles.yml**

Connection configuration for Snowflake. Uses environment variables for security.

```yaml
dbt_walmart:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: "{{ env_var('DBT_SNOWFLAKE_ACCOUNT', 'HN07258.us-east-1') }}"
      user: "{{ env_var('DBT_SNOWFLAKE_USER', 'SVC_WHERESCAPE_TEST') }}"
      password: "{{ env_var('DBT_SNOWFLAKE_PASSWORD') }}"
      role: "{{ env_var('DBT_SNOWFLAKE_ROLE', 'ETL') }}"
      database: "{{ env_var('DBT_SNOWFLAKE_DATABASE', 'WALM_DATA') }}"
      warehouse: "{{ env_var('DBT_SNOWFLAKE_WAREHOUSE', 'ETL') }}"
      schema: mart
      threads: 4
      client_session_keep_alive: False
```

**Key Points**:
- Uses `env_var()` with defaults for local development
- All environment variables use `DBT_` prefix for dbt Cloud compatibility
- Target schema is `mart` (all models build here)
- 4 threads for parallel execution

#### **dbt_project.yml**

Project-level configurations and model settings.

```yaml
name: 'dbt_walmart'
version: '1.0.0'
config-version: 2

profile: 'dbt_walmart'

model-paths: ["models"]
analysis-paths: ["analyses"]
test-paths: ["tests"]
seed-paths: ["seeds"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]

target-path: "target"
clean-targets:
  - "target"
  - "dbt_packages"

models:
  dbt_walmart:
    staging:
      +materialized: view
      +schema: mart
    marts:
      dim:
        +materialized: table
        +schema: mart
      fact:
        +materialized: incremental
        +schema: mart
```

**Key Points**:
- All staging models are views (no storage)
- Dimension tables are full tables (better query performance)
- Fact tables are incremental (efficient loading)
- All models build in `mart` schema

#### **packages.yml**

dbt package dependencies.

```yaml
packages:
  - package: dbt-labs/dbt_utils
    version: 1.1.1
```

**Usage**: 
- `generate_surrogate_key()` macro for STORE_KEY generation
- Various utility functions

---

### Environment Variables

#### For Local Development

**Windows PowerShell**:
```powershell
$env:DBT_SNOWFLAKE_ACCOUNT = "HN07258.us-east-1"
$env:DBT_SNOWFLAKE_USER = "SVC_WHERESCAPE_TEST"
$env:DBT_SNOWFLAKE_PASSWORD = "your_password"
$env:DBT_SNOWFLAKE_ROLE = "ETL"
$env:DBT_SNOWFLAKE_DATABASE = "WALM_DATA"
$env:DBT_SNOWFLAKE_WAREHOUSE = "ETL"
```

**Linux/Mac Bash**:
```bash
export DBT_SNOWFLAKE_ACCOUNT="HN07258.us-east-1"
export DBT_SNOWFLAKE_USER="SVC_WHERESCAPE_TEST"
export DBT_SNOWFLAKE_PASSWORD="your_password"
export DBT_SNOWFLAKE_ROLE="ETL"
export DBT_SNOWFLAKE_DATABASE="WALM_DATA"
export DBT_SNOWFLAKE_WAREHOUSE="ETL"
```

#### For dbt Cloud

Set these in **Account Settings → Projects → walmart-app → Environment Variables**:

| Variable | Value | Required |
|----------|-------|----------|
| DBT_SNOWFLAKE_ACCOUNT | HN07258.us-east-1 | ✅ Yes |
| DBT_SNOWFLAKE_USER | SVC_WHERESCAPE_TEST | ✅ Yes |
| DBT_SNOWFLAKE_PASSWORD | [your_password] | ✅ Yes |
| DBT_SNOWFLAKE_ROLE | ETL | ✅ Yes |
| DBT_SNOWFLAKE_DATABASE | WALM_DATA | ✅ Yes |
| DBT_SNOWFLAKE_WAREHOUSE | ETL | ✅ Yes |

---

## 🚀 Deployment

### dbt Cloud Setup

#### Repository Configuration

1. **GitHub Repository**: `emyharolds/walmart-app`
2. **Branch Strategy**:
   - `main` - Production (dbt Cloud deployments)
   - `master` - Local development
   - Feature branches: `feature/<name>`

#### Environment Setup

**Step 1**: Navigate to dbt Cloud
- Go to **Account Settings** → **Projects** → **walmart-app**

**Step 2**: Configure Connection
- Click **Connection** → **Snowflake**
- Test connection with environment variables

**Step 3**: Set Environment Variables (see above section)

**Step 4**: Configure Repository
- Connect to GitHub
- Select repository: `emyharolds/walmart-app`
- Default branch: `main`

#### Job Configuration

Create a production job with these commands:

```bash
dbt deps          # Install dbt_utils package
dbt run           # Build all models
dbt test          # Run all tests
```

**Schedule**: Daily at 6:00 AM (after raw data loads at 5:00 AM)

**Alerts**: 
- ✅ On failure
- ✅ On first success after failure

---

### Local Development

#### Initial Setup

```bash
# 1. Clone repository
git clone https://github.com/emyharolds/walmart-app.git
cd walmart-app

# 2. Set environment variables (see above)

# 3. Install dbt dependencies
dbt deps

# 4. Test connection
dbt debug

# 5. Build all models
dbt run

# 6. Run tests
dbt test
```

#### Development Workflow

```bash
# Build specific model
dbt run --select stg_department

# Build model and all downstream dependencies
dbt run --select stg_department+

# Build model and all upstream dependencies
dbt run --select +fact_walmart_sales

# Build specific folder
dbt run --select staging
dbt run --select marts.dim
dbt run --select marts.fact

# Test specific model
dbt test --select dim_store

# Full refresh (rebuild incrementals from scratch)
dbt run --full-refresh

# Full refresh specific model
dbt run --select fact_walmart_sales --full-refresh

# Generate and serve documentation
dbt docs generate
dbt docs serve
```

#### Git Workflow

```bash
# Create feature branch
git checkout -b feature/add-new-metric

# Make changes, then stage and commit
git add models/marts/fact/fact_walmart_sales.sql
git commit -m "Add new metric to fact table"

# Push to GitHub
git push origin feature/add-new-metric

# Create pull request on GitHub
# After approval, merge to main
```

---

## 📝 Development Guidelines

### Naming Conventions

#### Models
| Type | Pattern | Example |
|------|---------|---------|
| Staging | `stg_<source_name>.sql` | `stg_department.sql` |
| Dimension | `dim_<dimension_name>.sql` | `dim_store.sql` |
| Fact | `fact_<fact_name>.sql` | `fact_walmart_sales.sql` |

#### Columns
| Type | Pattern | Example |
|------|---------|---------|
| All columns | UPPERCASE | `STORE`, `DEPT`, `DATE` |
| Primary keys | `<TABLE>_KEY` or `<TABLE>_ID` | `STORE_KEY`, `DATE_KEY` |
| Foreign keys | `<REFERENCED_TABLE>_KEY` | `DATE_KEY` (FK to dim_date) |
| Boolean flags | `IS_<CONDITION>` | `IS_WEEKEND`, `ISHOLIDAY` |
| Audit columns | `CREATED_AT`, `UPDATED_AT` | `CREATED_AT` |

#### CTEs
Use descriptive names in this order:
1. `source` - Direct reference to source/ref
2. `renamed` / `cleaned` - Column renaming
3. `filtered` - Row filtering
4. `joined` - Joins to other tables
5. `aggregated` - Aggregations
6. `final` - Final transformations

### Code Structure

**Standard model template**:

```sql
{{
    config(
        materialized='<view|table|incremental>',
        unique_key='<key_column>',  -- For incremental only
        incremental_strategy='merge'  -- For incremental only
    )
}}

{#
    Model: <model_name>
    Purpose: <brief description>
    Grain: <one row per...>
#}

with source as (
    select * from {{ source('schema', 'table') }}
    -- or --
    select * from {{ ref('upstream_model') }}
),

renamed as (
    select
        column1 as COLUMN1,
        column2 as COLUMN2
    from source
)

select * from renamed
```

### Incremental Models

For fact tables and large dimensions:

```sql
{{
    config(
        materialized='incremental',
        unique_key=['COLUMN1', 'COLUMN2'],  -- Composite key
        incremental_strategy='merge'
    )
}}

-- Model logic here

{% if is_incremental() %}
where date_column > (select coalesce(max(date_column), '1900-01-01') from {{ this }})
{% endif %}
```

### Testing Best Practices

1. **Always test**:
   - ✅ Primary keys (unique + not_null)
   - ✅ Foreign keys (relationships)
   - ✅ Critical business logic

2. **Use schema.yml files** for documentation and tests

3. **Custom tests** in `tests/` folder for complex business rules

4. **Test incrementally**:
   ```bash
   # Test as you develop
   dbt run --select my_model
   dbt test --select my_model
   ```

---

## 🧪 Testing Strategy

### Test Categories

#### 1. Source Tests (`models/staging/_sources.yml`)

```yaml
- name: department
  columns:
    - name: store
      tests:
        - not_null
    - name: dept
      tests:
        - not_null
```

**Purpose**: Validate data quality at ingestion point

#### 2. Staging Tests (`models/staging/_schema.yml`)

```yaml
- name: stg_stores
  columns:
    - name: STORE
      tests:
        - unique
        - not_null
```

**Purpose**: Ensure staging transformations preserve data quality

#### 3. Dimension Tests (`models/marts/dim/_schema.yml`)

```yaml
- name: dim_date
  columns:
    - name: DATE_KEY
      tests:
        - unique
        - not_null
```

**Purpose**: Ensure dimensional integrity

#### 4. Fact Tests (`models/marts/fact/_schema.yml`)

```yaml
- name: fact_walmart_sales
  columns:
    - name: DATE_KEY
      tests:
        - relationships:
            to: ref('dim_date')
            field: DATE_KEY
```

**Purpose**: Ensure referential integrity and fact completeness

### Running Tests

```bash
# Run all tests
dbt test

# Run tests for specific model
dbt test --select dim_store

# Run specific test type
dbt test --select test_type:unique
dbt test --select test_type:not_null
dbt test --select test_type:relationships

# Store test results in warehouse
dbt test --store-failures

# Run tests on modified models only
dbt test --select state:modified+
```

### Test Results

Tests create compiled SQL in `target/compiled/dbt_walmart/models/`:

Example: `not_null_dim_date_DATE_KEY.sql`
```sql
select count(*) 
from WALM_DATA.MART.DIM_DATE
where DATE_KEY is null
```

---

## 🔧 Troubleshooting

### Common Issues

#### Issue 1: "Invalid identifier 'COLUMN_NAME'"

**Symptom**: 
```
000904 (42000): SQL compilation error: error line 14 at position 7
invalid identifier 'STORE_DATE'
```

**Cause**: Column name mismatch between SQL model and schema.yml  
**Solution**: 
1. Check actual column names in model output
2. Update schema.yml to match exactly (case-sensitive)
3. Run `dbt run --select <model>` to verify

#### Issue 2: "Duplicate row detected during DML"

**Symptom**:
```
100090 (42P18): Duplicate row detected during DML action
```

**Cause**: Unique key constraint violation in incremental models  
**Solution**: 
1. Add `DISTINCT` in source CTEs
2. Verify `unique_key` configuration matches grain
3. Check if you need composite key: `unique_key=['COL1', 'COL2']`

#### Issue 3: Environment variables not recognized

**Symptom**:
```
Env var required but not provided: 'SNOWFLAKE_PASSWORD'
```

**Cause**: Missing `DBT_` prefix in dbt Cloud  
**Solution**: All environment variables must start with `DBT_` in dbt Cloud

#### Issue 4: "Database WALMART_DB does not exist"

**Symptom**:
```
Database 'WALMART_DB' does not exist or not authorized
```

**Cause**: Incorrect database name in configuration  
**Solution**: Use `WALM_DATA` (the actual database name)

#### Issue 5: Tests failing with "invalid identifier"

**Symptom**:
```
not_null_fact_walmart_sales_STORE_ID .... [ERROR]
```

**Cause**: Schema.yml references old column names  
**Solution**: 
1. Check model SQL for actual column names
2. Update schema.yml to match
3. Common fixes:
   - `STORE_ID` → `STORE`
   - `STORE_DATE` → `DATE`

#### Issue 6: Incremental model not loading new data

**Symptom**: No new rows added to fact table

**Cause**: Incremental filter excluding valid data  
**Solution**:
1. Check incremental filter logic
2. Verify max date in target table
3. Run `--full-refresh` to rebuild

---

## 📈 Data Refresh Schedule

### External Data Loading (Outside this project)

**Frequency**: Daily at 5:00 AM  
**Process**: Snowflake COPY command from S3/Azure Blob  
**Tables**: DEPARTMENT, STORES, FACT  
**Ownership**: Data Engineering Team

### dbt Transformation (This project)

**Frequency**: Daily at 6:00 AM (after raw data load)  
**Duration**: ~5-10 minutes  
**Process**:

| Step | Duration | Description |
|------|----------|-------------|
| 1. dbt deps | 5s | Install packages |
| 2. Staging views | 10s | Refresh all staging views |
| 3. dim_date | 15s | Update date dimension (if needed) |
| 4. dim_store | 30s | Merge new store-dept combinations |
| 5. fact_walmart_sales | 3-5m | Incrementally load new weeks |
| 6. dbt test | 1m | Run all data quality tests |

**Total**: ~5-10 minutes

---

## 📊 Key Metrics and Business Logic

### Sales Metrics

**WEEKLY_SALES**: Total sales for the week (in dollars)
- Grain: Store + Department + Week
- Source: RAW.DEPARTMENT
- Use for: Revenue analysis, trend analysis

**Holiday Impact**:
```sql
-- Compare holiday vs non-holiday weeks
SELECT 
  ISHOLIDAY,
  AVG(WEEKLY_SALES) as avg_weekly_sales,
  SUM(WEEKLY_SALES) as total_sales
FROM fact_walmart_sales
GROUP BY ISHOLIDAY;
```

### Store Segmentation

| Type | Description | Avg Size | Use Case |
|------|-------------|----------|----------|
| A | Superstore | 180,000+ sq ft | High-volume analysis |
| B | Standard | 130,000 sq ft | Mid-market analysis |
| C | Small | 40,000 sq ft | Small format analysis |

### Economic Indicators

**CPI (Consumer Price Index)**:
- Measures inflation
- Higher CPI = higher prices = potential lower sales volume
- Use for: Price elasticity analysis

**Unemployment Rate**:
- Regional unemployment percentage
- Higher unemployment = lower consumer spending
- Use for: Economic impact analysis

**Fuel Price**:
- Impacts transportation costs and consumer spending
- Higher fuel price = lower discretionary spending
- Use for: Cost correlation analysis

**Temperature**:
- Seasonal effects on sales
- Use for: Seasonal product planning, HVAC analysis

**Markdowns**:
- Promotional pricing data (anonymized)
- Use for: Promotion effectiveness analysis

---

## 📚 Additional Resources

### Documentation

**dbt Documentation**:
```bash
dbt docs generate
dbt docs serve  # Opens browser at localhost:8080
```

**View**:
- Model lineage DAG
- Column descriptions
- Test results
- Source freshness

### External Links

- [dbt Documentation](https://docs.getdbt.com)
- [dbt Best Practices](https://docs.getdbt.com/guides/best-practices)
- [Snowflake Documentation](https://docs.snowflake.com)
- [dbt Slack Community](https://www.getdbt.com/community/)

### Internal Contacts

- **Data Engineering Team**: [Add your contact]
- **Analytics Team**: [Add your contact]
- **dbt Administrator**: [Add your contact]

### Project Repository

- **GitHub**: [github.com/emyharolds/walmart-app](https://github.com/emyharolds/walmart-app)
- **Issues**: Report bugs and feature requests
- **Wiki**: Additional documentation

---

## 🎓 Onboarding Checklist for New Team Members

### Week 1: Setup & Access

- [ ] Request Snowflake access (role: ETL)
- [ ] Request GitHub repository access
- [ ] Request dbt Cloud access
- [ ] Clone repository locally
- [ ] Configure profiles.yml with credentials
- [ ] Run `dbt debug` successfully
- [ ] Run `dbt deps` to install packages
- [ ] Run `dbt run` to build all models
- [ ] Run `dbt test` to verify data quality
- [ ] Generate and review dbt docs

### Week 2: Understanding the Project

- [ ] Review this README thoroughly
- [ ] Explore raw data in Snowflake (RAW schema)
- [ ] Review all staging models (understand transformations)
- [ ] Review dimensional model (star schema)
- [ ] Understand fact_walmart_sales join logic
- [ ] Review all tests in schema.yml files
- [ ] Run individual models with `dbt run --select`
- [ ] Practice incremental model refresh

### Week 3: Making Changes

- [ ] Create a feature branch
- [ ] Add a new column to staging model
- [ ] Update tests and documentation
- [ ] Run and test changes locally
- [ ] Create pull request
- [ ] Review with senior team member
- [ ] Merge to main after approval

### Week 4: Advanced Topics

- [ ] Understand incremental loading strategies
- [ ] Learn about SCD Type 1 vs Type 2
- [ ] Practice debugging failed tests
- [ ] Review dbt Cloud job configurations
- [ ] Shadow a production deployment
- [ ] Independently resolve a ticket

---

## 📄 Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2025-11-29 | Initial dimensional model with staging, dims, and facts | Development Team |
| 1.0.1 | 2025-11-29 | Fixed data model structure (department = sales source) | Development Team |
| 1.0.2 | 2025-11-29 | Fixed duplicate rows in dim_store, updated fact schema | Development Team |

---

## 📞 Support

For questions or issues:

1. **Check this README** first
2. **Review dbt documentation** at `localhost:8080`
3. **Search GitHub issues** for similar problems
4. **Ask in team chat** or Slack
5. **Create GitHub issue** for bugs or feature requests

---

**Last Updated**: November 29, 2025  
**Project Status**: ✅ Production Ready  
**dbt Version**: 1.11.0-rc1  
**Snowflake Database**: WALM_DATA
