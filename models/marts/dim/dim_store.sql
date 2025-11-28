{{
    config(
        materialized='incremental',
        unique_key='store_key',
        incremental_strategy='merge',
        merge_update_columns=['store_type', 'store_size', 'updated_at']
    )
}}

{#
    Dimension: dim_store
    SCD Type: 1 (Overwrite)
    
    This dimension combines store and department information
    for the Walmart dataset.
#}

with stores as (
    select * from {{ ref('stg_stores') }}
),

departments as (
    select * from {{ ref('stg_department') }}
),

combined as (
    select
        d.store,
        d.dept,
        d.dept_name,
        s.store_type,
        s.store_size
    from departments d
    left join stores s on d.store = s.store
)

select
    {{ dbt_utils.generate_surrogate_key(['store', 'dept']) }} as store_key,
    store as store_id,
    dept as dept_id,
    dept_name,
    store_type,
    store_size,
    current_timestamp() as created_at,
    current_timestamp() as updated_at
from combined
