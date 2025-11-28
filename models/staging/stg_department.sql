-- models/staging/stg_department.sql
-- Staging model for department data

with source as (
    select * from {{ source('raw_walmart', 'department') }}
),

renamed as (
    select
        store,
        dept,
        date as store_date,
        weekly_sales,
        isholiday,
        load_timestamp
    from source
    where store is not null 
      and dept is not null
      and date is not null
)

select * from renamed
