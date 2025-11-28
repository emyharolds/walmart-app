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
        STORE,
        DEPT,
        DATE as STORE_DATE,
        WEEKLY_SALES,
        ISHOLIDAY,
        TEMPERATURE,
        FUEL_PRICE,
        MARKDOWN1,
        MARKDOWN2,
        MARKDOWN3,
        MARKDOWN4,
        MARKDOWN5,
        CPI,
        UNEMPLOYMENT
    from source
)

select * from cleaned
