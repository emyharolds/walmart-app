# Walmart Data Mart - dbt Project

A dbt project for building a Walmart sales data warehouse in Snowflake with proper dimensional modeling, including SCD Type 1 and Type 2 implementations.

## Project Overview

This project transforms raw Walmart sales data from S3 into a dimensional model with:
- **SCD Type 1** for date and store dimensions (upsert logic)
- **SCD Type 2** for fact table (historical versioning)

## Architecture

```
RAW Schema (Source)              →    MART Schema (Destination)
├── department.csv                    ├── walmart_date_dim (SCD1)
├── fact.csv                          ├── walmart_store_dim (SCD1)
└── stores.csv                        └── walmart_fact_table (SCD2)
```

## Project Structure

```
dbt_walmart/
├── models/
│   ├── sources.yml                    # Source definitions for RAW schema
│   ├── schema.yml                     # Tests and documentation
│   ├── staging/
│   │   ├── stg_department.sql        # Clean department data
│   │   ├── stg_fact.sql              # Clean fact data
│   │   └── stg_stores.sql            # Clean stores data
│   └── mart/
│       ├── dimensions/
│       │   ├── walmart_date_dim.sql  # Date dimension (SCD1)
│       │   └── walmart_store_dim.sql # Store dimension (SCD1)
│       └── facts/
│           └── walmart_fact_table.sql # Fact table (SCD2)
├── snapshots/
│   └── walmart_fact_snapshot.sql     # Alternative SCD2 using dbt snapshots
├── dbt_project.yml
└── profiles.yml (copy to ~/.dbt/)
```

## Prerequisites

1. **Snowflake Account** with:
   - `WALM_DATA` database created
   - `RAW` schema with tables loaded from S3 (via Snowpipe or manual COPY)
   - Appropriate warehouse and role permissions

2. **Python & dbt** installed:
   ```bash
   pip install dbt-snowflake
   ```

3. **dbt-utils** package:
   ```bash
   dbt deps
   ```

## Setup Instructions

### 1. Configure Snowflake Connection

Copy `profiles.yml` to your home directory:
```bash
# Windows
cp profiles.yml ~/.dbt/profiles.yml

# Update with your credentials
code ~/.dbt/profiles.yml
```

Update the following values:
- `account`: Your Snowflake account identifier
- `user`: Your username
- `password`: Your password (or use key-pair authentication)
- `role`: Your Snowflake role
- `warehouse`: Your compute warehouse
- `database`: `WALM_DATA`
- `schema`: `MART`

### 2. Install dbt Packages

Create `packages.yml` in project root:
```yaml
packages:
  - package: dbt-labs/dbt_utils
    version: 1.1.1
```

Then install:
```bash
cd dbt_walmart
dbt deps
```

### 3. Test Connection

```bash
dbt debug
```

### 4. Load RAW Data (One-time Setup)

Ensure your RAW schema tables are populated. You can use the Snowflake setup script to create Snowpipe:
```sql
-- Run the walmart_snowflake_setup.sql script first to:
-- 1. Create RAW tables
-- 2. Setup S3 integration
-- 3. Configure Snowpipe for automatic loading
```

Or manually load data:
```sql
COPY INTO RAW.DEPARTMENT FROM @RAW.WALMART_S3_STAGE/department.csv;
COPY INTO RAW.FACT FROM @RAW.WALMART_S3_STAGE/fact.csv;
COPY INTO RAW.STORES FROM @RAW.WALMART_S3_STAGE/stores.csv;
```

## Running the Project

### Run All Models (Full Refresh)
```bash
dbt run --full-refresh
```

### Run Incrementally (Daily Updates)
```bash
dbt run
```

### Run Specific Models
```bash
# Run only staging models
dbt run --select staging.*

# Run only dimension models
dbt run --select mart.dimensions.*

# Run only fact model
dbt run --select walmart_fact_table
```

### Run dbt Snapshots (Alternative SCD2 Approach)
If using the snapshot approach instead of the incremental fact model:
```bash
dbt snapshot
```

### Run Tests
```bash
dbt test
```

### Generate Documentation
```bash
dbt docs generate
dbt docs serve
```

## Model Details

### Staging Models
- **stg_department**: Clean and standardize department sales data
- **stg_fact**: Clean and standardize store-level metrics
- **stg_stores**: Clean and standardize store master data

### Dimension Models (SCD Type 1)

#### walmart_date_dim
- **Unique Key**: `store_date`
- **Logic**: Upserts dates from both department and fact sources
- **Updates**: Overwrites changed records (SCD1)

#### walmart_store_dim
- **Unique Key**: `store_id`, `dept_id` (composite)
- **Logic**: Combines store and department information
- **Updates**: Overwrites changed records (SCD1)

### Fact Model (SCD Type 2)

#### walmart_fact_table
- **Unique Key**: `store_id`, `dept_id`, `vrsn_start_date`
- **Logic**: 
  - Detects changes in any measure
  - Expires old records by setting `vrsn_end_date` and `is_current = false`
  - Inserts new version with current timestamp as `vrsn_start_date`
- **Columns**:
  - `vrsn_start_date`: When version became active
  - `vrsn_end_date`: When version expired (9999-12-31 if current)
  - `is_current`: Boolean flag for active records

#### Alternative: walmart_fact_snapshot
Uses dbt's built-in snapshot functionality for SCD2. To use this instead:
1. Comment out `walmart_fact_table.sql` 
2. Run `dbt snapshot` instead of `dbt run --select walmart_fact_table`

## Execution Schedule

### Development
```bash
# Daily incremental load
dbt run

# Run tests after load
dbt test
```

### Production (Recommended Schedule)
1. **Daily at 2 AM**: Run incremental models
   ```bash
   dbt run --exclude walmart_fact_table
   dbt run --select walmart_fact_table
   ```

2. **After each run**: Run tests
   ```bash
   dbt test
   ```

3. **Weekly**: Full refresh to ensure data quality
   ```bash
   dbt run --full-refresh
   ```

## Monitoring & Troubleshooting

### Check Model Run Status
```bash
# See model execution details
dbt run --select walmart_fact_table --debug
```

### Validate Data
```sql
-- Check SCD2 history
SELECT 
    store_id, dept_id, 
    store_weekly_sales,
    vrsn_start_date, 
    vrsn_end_date, 
    is_current
FROM MART.WALMART_FACT_TABLE
WHERE store_id = 1 AND dept_id = 1
ORDER BY vrsn_start_date;

-- Count current vs historical records
SELECT 
    is_current,
    COUNT(*) as record_count
FROM MART.WALMART_FACT_TABLE
GROUP BY is_current;

-- Check for data quality issues
SELECT 
    COUNT(*) as total_records,
    COUNT(DISTINCT store_id || '_' || dept_id) as unique_combinations,
    SUM(CASE WHEN is_current THEN 1 ELSE 0 END) as current_records
FROM MART.WALMART_FACT_TABLE;
```

### Common Issues

**Issue**: Models fail with "object does not exist"
- **Solution**: Ensure RAW schema tables are created and populated

**Issue**: Incremental models not updating
- **Solution**: Use `--full-refresh` flag once, then run incrementally

**Issue**: SCD2 creating duplicate current records
- **Solution**: Check unique_key configuration and ensure proper merge logic

## Deployment

### Using dbt Cloud
1. Connect your Git repository
2. Configure Snowflake connection
3. Set up job schedules
4. Enable dbt docs

### Using Airflow
```python
from airflow.operators.bash import BashOperator

dbt_run = BashOperator(
    task_id='dbt_run',
    bash_command='cd /path/to/dbt_walmart && dbt run',
    dag=dag
)

dbt_test = BashOperator(
    task_id='dbt_test',
    bash_command='cd /path/to/dbt_walmart && dbt test',
    dag=dag
)

dbt_run >> dbt_test
```

### Using Snowflake Tasks
```sql
CREATE TASK dbt_daily_load
  WAREHOUSE = COMPUTE_WH
  SCHEDULE = 'USING CRON 0 2 * * * UTC'
AS
  CALL SYSTEM$EXTERNAL_PROCESS('dbt', 'run', '--project-dir', '/path/to/dbt_walmart');
```

## Data Lineage

```
department.csv  ──→  stg_department  ──→  walmart_date_dim (SCD1)
                                     └──→  walmart_store_dim (SCD1)
                                     └──→  walmart_fact_table (SCD2)
                                     
fact.csv  ──────→  stg_fact  ───────→  walmart_date_dim (SCD1)
                                     └──→  walmart_fact_table (SCD2)
                                     
stores.csv  ────→  stg_stores  ─────→  walmart_store_dim (SCD1)
```

## Best Practices

1. **Run staging models first**: Always ensure staging is up-to-date
2. **Test incrementally**: Run tests after each model execution
3. **Monitor snapshot tables**: Check for excessive history growth
4. **Archive old versions**: Consider archiving records with `vrsn_end_date < current_date - 2 years`
5. **Use full-refresh sparingly**: Only when necessary to fix data issues

## Resources

- [dbt Documentation](https://docs.getdbt.com/)
- [dbt Snowflake Adapter](https://docs.getdbt.com/reference/warehouse-setups/snowflake-setup)
- [dbt Snapshots (SCD2)](https://docs.getdbt.com/docs/build/snapshots)
- [dbt Incremental Models](https://docs.getdbt.com/docs/build/incremental-models)

## Support

For issues or questions:
1. Check dbt logs: `logs/dbt.log`
2. Review model compilation: `target/compiled/`
3. Validate SQL: `target/run/`
