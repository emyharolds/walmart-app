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
        store as STORE,
        date as DATE,
        temperature as TEMPERATURE,
        fuel_price as FUEL_PRICE,
        markdown1 as MARKDOWN1,
        markdown2 as MARKDOWN2,
        markdown3 as MARKDOWN3,
        markdown4 as MARKDOWN4,
        markdown5 as MARKDOWN5,
        cpi as CPI,
        unemployment as UNEMPLOYMENT,
        isholiday as ISHOLIDAY
    from source
)

select * from cleaned
