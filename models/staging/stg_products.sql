{{
    config(
        materialized='view'
    )
}}

with source as (
    select * from {{ source('raw', 'raw_products') }}
),

renamed as (
    select
        product_id,
        trim(product_name) as product_name,
        trim(description) as description,
        trim(category) as category,
        trim(subcategory) as subcategory,
        trim(brand) as brand,
        unit_price,
        cost,
        supplier_id,
        coalesce(is_active, true) as is_active,
        created_at,
        updated_at,
        _loaded_at
    from source
)

select * from renamed
