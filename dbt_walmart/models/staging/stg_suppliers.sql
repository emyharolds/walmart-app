{{
    config(
        materialized='view'
    )
}}

with source as (
    select * from {{ source('raw', 'raw_suppliers') }}
),

renamed as (
    select
        supplier_id,
        trim(supplier_name) as supplier_name,
        trim(contact_name) as contact_name,
        lower(trim(contact_email)) as contact_email,
        trim(contact_phone) as contact_phone,
        trim(address) as address,
        trim(city) as city,
        upper(trim(state)) as state,
        upper(trim(country)) as country,
        coalesce(is_active, true) as is_active,
        created_at,
        updated_at,
        _loaded_at
    from source
)

select * from renamed
