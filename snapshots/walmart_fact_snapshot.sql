-- snapshots/walmart_fact_snapshot.sql
-- SCD Type 2 snapshot for fact table
-- This will track historical changes to all measures

{% snapshot walmart_fact_snapshot %}

{{
    config(
      target_schema='mart',
      target_database='WALM_DATA',
      unique_key='store_id || \'_\' || dept_id',
      strategy='check',
      check_cols='all',
      invalidate_hard_deletes=False
    )
}}

with fact_data as (
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
)

select * from fact_data

{% endsnapshot %}
