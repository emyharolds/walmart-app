{{
    config(
        materialized='view'
    )
}}

with source as (
    select * from {{ source('raw', 'raw_customers') }}
),

renamed as (
    select
        customer_id,
        trim(first_name) as first_name,
        trim(last_name) as last_name,
        lower(trim(email)) as email,
        trim(phone) as phone,
        trim(address) as address,
        trim(city) as city,
        upper(trim(state)) as state,
        trim(zip_code) as zip_code,
        upper(trim(country)) as country,
        created_at,
        updated_at,
        _loaded_at
    from source
)

select * from renamed
