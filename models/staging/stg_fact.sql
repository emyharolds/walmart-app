-- models/staging/stg_fact.sql
-- Staging model for fact data

with source as (
    select * from {{ source('raw_walmart', 'fact') }}
),

renamed as (
    select
        store,
        date as store_date,
        temperature,
        fuel_price,
        markdown1,
        markdown2,
        markdown3,
        markdown4,
        markdown5,
        cpi,
        unemployment,
        isholiday,
        load_timestamp
    from source
    where store is not null 
      and date is not null
)

select * from renamed
