{{
    config(
        materialized='view'
    )
}}

with source as (
    select * from {{ source('raw', 'fact') }}
),

cleaned as (
    select
        store,
        dept,
        date as store_date,
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
        unemployment
    from source
)

select * from cleaned
