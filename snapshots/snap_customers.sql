{% snapshot snap_customers %}

{{
    config(
        target_database=env_var('DBT_SNOWFLAKE_DATABASE', 'WALM_DATA'),
        target_schema='snapshots',
        unique_key='customer_id',
        strategy='timestamp',
        updated_at='updated_at',
        invalidate_hard_deletes=True
    )
}}

/*
    Snapshot: snap_customers
    Strategy: Timestamp-based SCD Type 2
    
    This snapshot tracks changes to customer records over time using
    dbt's built-in snapshot functionality. It creates historical records
    with dbt_valid_from and dbt_valid_to columns.
    
    This is an alternative approach to the custom SCD2 implementation
    in the dim_customer model.
*/

select
    customer_id,
    first_name,
    last_name,
    email,
    phone,
    address,
    city,
    state,
    zip_code,
    country,
    created_at,
    updated_at
from {{ source('raw', 'raw_customers') }}

{% endsnapshot %}
