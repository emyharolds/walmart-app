# Snowflake SQL vs dbt Approach - Comparison

## Overview

This document compares the traditional Snowflake stored procedure approach with the dbt approach for the Walmart data warehouse.

## Approach Comparison

| Aspect | Snowflake SQL (Stored Procedures) | dbt |
|--------|-----------------------------------|-----|
| **Language** | SQL with procedural extensions | SQL with Jinja templating |
| **Version Control** | Manual | Git-native |
| **Testing** | Manual SQL queries | Built-in data quality tests |
| **Documentation** | Separate documents | Auto-generated from code |
| **Incremental Logic** | Manual MERGE statements | Built-in incremental materializations |
| **Dependencies** | Manual ordering | Automatic via `ref()` |
| **CI/CD** | Custom scripts needed | Native support |
| **Learning Curve** | Snowflake SQL knowledge | dbt + SQL knowledge |
| **Modularity** | Monolithic procedures | Small, reusable models |
| **Data Lineage** | Manual documentation | Automatic DAG visualization |

## Code Comparison

### SCD Type 1 (Date Dimension)

**Snowflake Stored Procedure:**
```sql
CREATE OR REPLACE PROCEDURE SP_LOAD_WALMART_DATE_DIM()
AS
$$
BEGIN
    MERGE INTO MART.WALMART_DATE_DIM AS TGT
    USING (
        SELECT DISTINCT DATE, ISHOLIDAY FROM RAW.DEPARTMENT
        UNION
        SELECT DISTINCT DATE, ISHOLIDAY FROM RAW.FACT
    ) AS SRC
    ON TGT.STORE_DATE = SRC.DATE
    WHEN MATCHED THEN UPDATE SET TGT.ISHOLIDAY = SRC.ISHOLIDAY
    WHEN NOT MATCHED THEN INSERT VALUES (...);
END;
$$;
```

**dbt Model:**
```sql
-- models/mart/dimensions/walmart_date_dim.sql
{{ config(materialized='incremental', unique_key='store_date') }}

with all_dates as (
    select distinct store_date, isholiday from {{ ref('stg_department') }}
    union
    select distinct store_date, isholiday from {{ ref('stg_fact') }}
)
select * from all_dates
{% if is_incremental() %}
where store_date not in (select store_date from {{ this }})
{% endif %}
```

### SCD Type 2 (Fact Table)

**Snowflake Stored Procedure:**
```sql
CREATE OR REPLACE PROCEDURE SP_LOAD_WALMART_FACT_TABLE()
AS
$$
BEGIN
    -- Step 1: Expire old records
    UPDATE MART.WALMART_FACT_TABLE
    SET VRSN_END_DATE = CURRENT_TIMESTAMP(), IS_CURRENT = FALSE
    WHERE IS_CURRENT = TRUE AND <changes detected>;
    
    -- Step 2: Insert new versions
    INSERT INTO MART.WALMART_FACT_TABLE (...)
    SELECT ... FROM staging WHERE <changed or new>;
END;
$$;
```

**dbt Snapshot (Option 1):**
```sql
-- snapshots/walmart_fact_snapshot.sql
{% snapshot walmart_fact_snapshot %}
{{
    config(
        strategy='check',
        unique_key='store_id || dept_id',
        check_cols='all'
    )
}}
select * from {{ ref('stg_fact_combined') }}
{% endsnapshot %}
```

**dbt Incremental Model (Option 2):**
```sql
-- models/mart/facts/walmart_fact_table.sql
{{ config(materialized='incremental') }}

{% if is_incremental() %}
    -- Expire old records and insert new versions
    with changed_records as (...)
{% else %}
    -- Initial load
{% endif %}
```

## Workflow Comparison

### Snowflake SQL Approach

```
1. Write stored procedures in Snowflake
2. Execute procedures manually or via scheduler
3. Check data manually
4. Document changes separately
5. Version control? (manual export to Git)
```

**Execution:**
```sql
CALL MART.SP_LOAD_WALMART_DATAMART();
```

### dbt Approach

```
1. Write models in dbt project
2. Test locally with dbt run
3. Commit to Git
4. CI/CD pipeline runs tests
5. Deploy to production
6. Auto-generated documentation
```

**Execution:**
```bash
dbt run
dbt test
dbt docs generate
```

## Feature Comparison

### ✅ Advantages of dbt

1. **Version Control**: Native Git integration
2. **Testing**: Built-in data quality tests
3. **Documentation**: Auto-generated, always up-to-date
4. **Modularity**: Small, reusable models
5. **Dependency Management**: Automatic with `ref()`
6. **Environment Management**: Easy dev/staging/prod separation
7. **Incremental Models**: Built-in, well-tested patterns
8. **Data Lineage**: Visual DAG of all transformations
9. **Community**: Large ecosystem of packages and patterns
10. **CI/CD**: Native integration with modern tools

### ✅ Advantages of Snowflake Stored Procedures

1. **Simplicity**: Pure SQL, no external tools
2. **Performance**: Can leverage Snowflake-specific optimizations
3. **Procedural Logic**: Full programming capabilities
4. **Scheduling**: Native Snowflake Tasks integration
5. **Error Handling**: Rich exception handling
6. **No Dependencies**: Everything in Snowflake

## When to Use Each

### Use Snowflake Stored Procedures When:
- Simple, one-off transformations
- Heavy procedural logic required
- Team is small and SQL-only
- No version control requirements
- Minimal documentation needs
- Complex error handling needed

### Use dbt When:
- Building data warehouse with multiple tables
- Team collaboration required
- Version control is important
- Testing and documentation are priorities
- Modern DataOps practices desired
- Complex dependency management
- Multiple environments (dev/staging/prod)

## Migration Path

If you want to migrate from stored procedures to dbt:

### Phase 1: Setup (Week 1)
1. Install dbt and configure connection
2. Create source definitions for RAW tables
3. Create staging models

### Phase 2: Dimensions (Week 2)
4. Migrate date dimension (SCD1)
5. Migrate store dimension (SCD1)
6. Add tests and documentation

### Phase 3: Facts (Week 3)
7. Migrate fact table (SCD2)
8. Validate against stored procedure results
9. Run parallel for 1 week

### Phase 4: Cutover (Week 4)
10. Disable stored procedures
11. Enable dbt in production
12. Monitor and adjust

## Hybrid Approach

You can also use both:

1. **Use Snowflake for**:
   - RAW data loading (Snowpipe, COPY)
   - Complex procedural logic
   - Admin tasks

2. **Use dbt for**:
   - Staging layer transformations
   - Dimensional model building
   - Business logic transformations
   - Testing and documentation

## Cost Comparison

**Snowflake SQL:**
- Compute: Same as dbt
- Development: Snowflake worksheet
- Total: Lower upfront, harder to maintain

**dbt:**
- Compute: Same as Snowflake SQL
- Development: dbt Cloud ($100+/user/month) or dbt Core (free)
- Total: Higher upfront, easier to maintain

## Recommendation for Walmart Project

### ✅ Choose dbt if:
- You have 3+ people working on this
- You plan to add more tables/models
- You want CI/CD and testing
- You care about documentation
- You want industry best practices

### ✅ Choose Snowflake SQL if:
- Single developer project
- Simple requirements, unlikely to change
- No need for version control
- Team is already expert in Snowflake SQL
- No budget for dbt Cloud

## Conclusion

Both approaches work! For the Walmart project:

- **Stored Procedures**: Good for quick prototypes and simple use cases
- **dbt**: Better for production, team collaboration, and long-term maintenance

The dbt approach provides better software engineering practices, while stored procedures offer simplicity. Choose based on your team's needs and future plans.
