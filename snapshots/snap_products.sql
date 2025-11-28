{% snapshot snap_products %}

{{
    config(
        target_database=env_var('DBT_SNOWFLAKE_DATABASE', 'WALM_DATA'),
        target_schema='snapshots',
        unique_key='product_id',
        strategy='timestamp',
        updated_at='updated_at',
        invalidate_hard_deletes=True
    )
}}

/*
    Snapshot: snap_products
    Strategy: Timestamp-based SCD Type 2
    
    This snapshot tracks changes to product records over time using
    dbt's built-in snapshot functionality. It's particularly useful
    for tracking pricing changes over time.
    
    This is an alternative approach to the custom SCD2 implementation
    in the dim_product model.
*/

select
    product_id,
    product_name,
    description,
    category,
    subcategory,
    brand,
    unit_price,
    cost,
    supplier_id,
    is_active,
    created_at,
    updated_at
from {{ source('raw', 'raw_products') }}

{% endsnapshot %}
