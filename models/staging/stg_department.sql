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
        store,
        dept,
        trim(dept_name) as dept_name
    from source
)

select * from cleaned
