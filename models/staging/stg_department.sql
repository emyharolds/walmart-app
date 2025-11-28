{{
    config(
        materialized='view'
    )
}}

with source as (
    select * from {{ source('raw', 'department') }}
),

cleaned as (
    select
        store as STORE,
        dept as DEPT
    from source
)

select * from cleaned
