{{
    config(
        materialized='view'
    )
}}

with source as (
    select * from {{ source('raw', 'stores') }}
),

cleaned as (
    select
        store as STORE,
        type as STORE_TYPE,
        size as STORE_SIZE
    from source
)

select * from cleaned
