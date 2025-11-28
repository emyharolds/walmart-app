# Walmart dbt Project - Quick Start Guide

## 🚀 Quick Setup (5 minutes)

### 1. Install dbt
```bash
pip install dbt-snowflake
```

### 2. Configure Connection
```bash
# Copy the profiles template
cp profiles.yml ~/.dbt/profiles.yml

# Edit with your Snowflake credentials
notepad ~/.dbt/profiles.yml
```

Update these fields:
```yaml
account: xy12345.us-east-1
user: YOUR_USERNAME
password: YOUR_PASSWORD
warehouse: COMPUTE_WH
```

### 3. Install Dependencies
```bash
cd dbt_walmart
dbt deps
```

### 4. Test Connection
```bash
dbt debug
```
✅ Should see "All checks passed!"

### 5. Run Initial Load
```bash
# First time - full load
dbt run --full-refresh

# Run tests
dbt test

# Generate docs
dbt docs generate
dbt docs serve
```

## 📊 Daily Operations

### Incremental Load (Default)
```bash
dbt run
```

### Run Specific Parts
```bash
# Just staging
dbt run --select staging.*

# Just dimensions
dbt run --select mart.dimensions.*

# Just fact table
dbt run --select walmart_fact_table
```

### Testing
```bash
# All tests
dbt test

# Specific model tests
dbt test --select walmart_fact_table
```

## 🔍 Key Commands Cheat Sheet

| Command | Description |
|---------|-------------|
| `dbt run` | Run all models incrementally |
| `dbt run --full-refresh` | Full reload of all models |
| `dbt test` | Run all data quality tests |
| `dbt docs generate` | Generate documentation |
| `dbt docs serve` | View documentation in browser |
| `dbt compile` | Compile models without running |
| `dbt debug` | Test connection and config |
| `dbt clean` | Clean target and dbt_packages |

## 📈 Checking Your Data

### View Current Records
```sql
SELECT COUNT(*) 
FROM MART.WALMART_FACT_TABLE 
WHERE IS_CURRENT = TRUE;
```

### View Historical Changes
```sql
SELECT 
    store_id, dept_id,
    store_weekly_sales,
    vrsn_start_date,
    vrsn_end_date,
    is_current
FROM MART.WALMART_FACT_TABLE
WHERE store_id = 1 AND dept_id = 1
ORDER BY vrsn_start_date DESC;
```

### Check All Table Counts
```sql
SELECT 'staging.stg_department' as table_name, COUNT(*) as rows 
FROM {{ ref('stg_department') }}
UNION ALL
SELECT 'mart.walmart_date_dim', COUNT(*) 
FROM {{ ref('walmart_date_dim') }}
UNION ALL
SELECT 'mart.walmart_store_dim', COUNT(*) 
FROM {{ ref('walmart_store_dim') }}
UNION ALL
SELECT 'mart.walmart_fact_table', COUNT(*) 
FROM {{ ref('walmart_fact_table') }};
```

## 🛠️ Troubleshooting

### Problem: "Database does not exist"
**Solution**: Run the Snowflake setup script first to create `WALM_DATA` database

### Problem: "No data in staging tables"
**Solution**: Load RAW tables using Snowpipe or manual COPY commands

### Problem: "Compilation error"
**Solution**: Run `dbt deps` to install required packages

### Problem: "Incremental not working"
**Solution**: Try `dbt run --full-refresh` once, then switch back to incremental

## 📅 Recommended Schedule

**Development:**
- Run: `dbt run` after each RAW data load
- Test: `dbt test` after each run

**Production:**
- **Daily 2 AM**: `dbt run` (incremental)
- **Daily 2:30 AM**: `dbt test`
- **Weekly Sunday**: `dbt run --full-refresh`
- **Monthly**: Review and archive old SCD2 versions

## 🎯 Next Steps

1. ✅ Set up Snowflake (run `walmart_snowflake_setup.sql`)
2. ✅ Configure dbt connection
3. ✅ Run initial load (`dbt run --full-refresh`)
4. ✅ Validate data (`dbt test`)
5. ⏭️ Schedule automated runs (Airflow/dbt Cloud/Snowflake Tasks)
6. ⏭️ Set up monitoring and alerts
7. ⏭️ Add custom business logic tests

Happy transforming! 🎉
