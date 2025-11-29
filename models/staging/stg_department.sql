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
        dept as DEPT,
        date as DATE,
        weekly_sales as WEEKLY_SALES,
        isholiday as ISHOLIDAY
    from source
)

select * from cleaned
