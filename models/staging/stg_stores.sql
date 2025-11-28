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
        STORE,
        TYPE as STORE_TYPE,
        SIZE as STORE_SIZE
    from source
)

select * from cleaned
