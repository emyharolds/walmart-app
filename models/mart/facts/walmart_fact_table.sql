-- models/mart/facts/walmart_fact_table.sql
-- Fact table with SCD Type 2 using custom incremental logic
-- Alternative to snapshot approach for more control

{{
    config(
        materialized='incremental',
        unique_key=['store_id', 'dept_id', 'vrsn_start_date'],
        on_schema_change='append_new_columns'
    )
}}

with source_data as (
    select
        d.store as store_id,
        d.dept as dept_id,
        d.weekly_sales as store_weekly_sales,
        f.fuel_price,
        f.temperature as store_temperature,
        f.unemployment,
        f.cpi,
        f.markdown1,
        f.markdown2,
        f.markdown3,
        f.markdown4,
        f.markdown5
    from {{ ref('stg_department') }} d
    inner join {{ ref('stg_fact') }} f 
        on d.store = f.store 
        and d.store_date = f.store_date
    where d.store is not null 
      and d.dept is not null
),

{% if is_incremental() %}

-- Get current active records from the table
current_records as (
    select *
    from {{ this }}
    where is_current = true
),

-- Find records that have changed
changed_records as (
    select
        s.store_id,
        s.dept_id,
        s.store_weekly_sales,
        s.fuel_price,
        s.store_temperature,
        s.unemployment,
        s.cpi,
        s.markdown1,
        s.markdown2,
        s.markdown3,
        s.markdown4,
        s.markdown5,
        current_timestamp() as vrsn_start_date,
        to_timestamp('{{ var("far_future_date") }}') as vrsn_end_date,
        true as is_current,
        current_timestamp() as insert_date,
        current_timestamp() as update_date
    from source_data s
    left join current_records c
        on s.store_id = c.store_id
        and s.dept_id = c.dept_id
    where c.store_id is null  -- New records
       or (  -- Changed records
           coalesce(c.store_weekly_sales, -999) != coalesce(s.store_weekly_sales, -999) or
           coalesce(c.fuel_price, -999) != coalesce(s.fuel_price, -999) or
           coalesce(c.store_temperature, -999) != coalesce(s.store_temperature, -999) or
           coalesce(c.unemployment, -999) != coalesce(s.unemployment, -999) or
           coalesce(c.cpi, -999) != coalesce(s.cpi, -999) or
           coalesce(c.markdown1, -999) != coalesce(s.markdown1, -999) or
           coalesce(c.markdown2, -999) != coalesce(s.markdown2, -999) or
           coalesce(c.markdown3, -999) != coalesce(s.markdown3, -999) or
           coalesce(c.markdown4, -999) != coalesce(s.markdown4, -999) or
           coalesce(c.markdown5, -999) != coalesce(s.markdown5, -999)
       )
),

-- Records to expire (close out old versions)
records_to_expire as (
    select
        c.store_id,
        c.dept_id,
        c.store_weekly_sales,
        c.fuel_price,
        c.store_temperature,
        c.unemployment,
        c.cpi,
        c.markdown1,
        c.markdown2,
        c.markdown3,
        c.markdown4,
        c.markdown5,
        c.vrsn_start_date,
        current_timestamp() as vrsn_end_date,
        false as is_current,
        c.insert_date,
        current_timestamp() as update_date
    from current_records c
    inner join changed_records ch
        on c.store_id = ch.store_id
        and c.dept_id = ch.dept_id
),

final as (
    select * from changed_records
    union all
    select * from records_to_expire
)

select * from final

{% else %}

-- Initial load
final as (
    select
        store_id,
        dept_id,
        store_weekly_sales,
        fuel_price,
        store_temperature,
        unemployment,
        cpi,
        markdown1,
        markdown2,
        markdown3,
        markdown4,
        markdown5,
        current_timestamp() as vrsn_start_date,
        to_timestamp('{{ var("far_future_date") }}') as vrsn_end_date,
        true as is_current,
        current_timestamp() as insert_date,
        current_timestamp() as update_date
    from source_data
)

select * from final

{% endif %}
