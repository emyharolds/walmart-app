-- models/staging/stg_stores.sql
-- Staging model for stores data

with source as (
    select * from {{ source('raw_walmart', 'stores') }}
),

renamed as (
    select
        store,
        type as store_type,
        size as store_size,
        load_timestamp
    from source
    where store is not null
)

select * from renamed
