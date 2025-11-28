{{
    config(
        materialized='view'
    )
}}

with source as (
    select * from {{ source('raw', 'raw_orders') }}
),

renamed as (
    select
        order_id,
        customer_id,
        store_id,
        order_date,
        order_timestamp,
        upper(trim(order_status)) as order_status,
        upper(trim(payment_method)) as payment_method,
        total_amount,
        coalesce(discount_amount, 0) as discount_amount,
        coalesce(tax_amount, 0) as tax_amount,
        created_at,
        updated_at,
        _loaded_at
    from source
)

select * from renamed
