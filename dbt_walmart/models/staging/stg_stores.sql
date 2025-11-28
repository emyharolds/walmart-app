{{
    config(
        materialized='view'
    )
}}

with source as (
    select * from {{ source('raw', 'raw_stores') }}
),

renamed as (
    select
        store_id,
        trim(store_name) as store_name,
        trim(store_type) as store_type,
        trim(address) as address,
        trim(city) as city,
        upper(trim(state)) as state,
        trim(zip_code) as zip_code,
        upper(trim(country)) as country,
        trim(region) as region,
        trim(district) as district,
        trim(manager_name) as manager_name,
        open_date,
        square_footage,
        coalesce(is_active, true) as is_active,
        created_at,
        updated_at,
        _loaded_at
    from source
)

select * from renamed
