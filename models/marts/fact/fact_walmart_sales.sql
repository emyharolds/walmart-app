{{
    config(
        materialized='incremental',
        unique_key=['store_id', 'dept_id', 'store_date'],
        incremental_strategy='merge'
    )
}}

{#
    Fact Table: fact_walmart_sales
    
    Weekly sales facts for Walmart stores and departments
    including various metrics and indicators.
#}

with fact_data as (
    select * from {{ ref('stg_fact') }}
),

date_dim as (
    select date_key, full_date from {{ ref('dim_date') }}
),

store_dim as (
    select store_key, store_id, dept_id from {{ ref('dim_store') }}
),

joined as (
    select
        s.store_key,
        f.store as store_id,
        f.dept as dept_id,
        f.store_date,
        d.date_key,
        f.weekly_sales,
        f.isholiday,
        f.temperature,
        f.fuel_price,
        f.markdown1,
        f.markdown2,
        f.markdown3,
        f.markdown4,
        f.markdown5,
        f.cpi,
        f.unemployment
    from fact_data f
    left join date_dim d on f.store_date = d.full_date
    left join store_dim s on f.store = s.store_id and f.dept = s.dept_id
    
    {% if is_incremental() %}
    where f.store_date > (select coalesce(max(store_date), '1900-01-01') from {{ this }})
    {% endif %}
)

select
    store_key,
    store_id,
    dept_id,
    store_date,
    date_key,
    weekly_sales,
    isholiday,
    temperature,
    fuel_price,
    markdown1,
    markdown2,
    markdown3,
    markdown4,
    markdown5,
    cpi,
    unemployment,
    current_timestamp() as created_at
from joined
