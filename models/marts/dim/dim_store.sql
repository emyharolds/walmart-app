{{
    config(
        materialized='incremental',
        unique_key='STORE_KEY',
        incremental_strategy='merge',
        merge_update_columns=['STORE_TYPE', 'STORE_SIZE', 'UPDATED_AT']
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
    select distinct STORE, DEPT from {{ ref('stg_department') }}
),

combined as (
    select
        d.STORE,
        d.DEPT,
        s.STORE_TYPE,
        s.STORE_SIZE
    from departments d
    left join stores s on d.STORE = s.STORE
)

select
    {{ dbt_utils.generate_surrogate_key(['STORE', 'DEPT']) }} as STORE_KEY,
    STORE as STORE_ID,
    DEPT as DEPT_ID,
    STORE_TYPE,
    STORE_SIZE,
    current_timestamp() as CREATED_AT,
    current_timestamp() as UPDATED_AT
from combined
