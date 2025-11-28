{{
    config(
        materialized='view'
    )
}}

with source as (
    select * from {{ source('raw', 'raw_order_items') }}
),

renamed as (
    select
        order_item_id,
        order_id,
        product_id,
        quantity,
        unit_price,
        coalesce(discount_percent, 0) as discount_percent,
        line_total,
        created_at,
        _loaded_at
    from source
)

select * from renamed
