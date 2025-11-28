{{
    config(
        materialized='incremental',
        unique_key='sales_key',
        incremental_strategy='merge',
        partition_by={
            'field': 'order_date',
            'data_type': 'date',
            'granularity': 'month'
        }
    )
}}

{#
    Fact Table: fact_sales
    Grain: One row per order line item (order_item)
    
    This fact table captures sales transactions at the line item level,
    linking to dimension tables via surrogate keys. It uses incremental
    loading strategy to efficiently process new and changed records.
#}

with order_items as (
    select
        order_item_id,
        order_id,
        product_id,
        quantity,
        unit_price,
        discount_percent,
        line_total,
        created_at as order_item_created_at,
        _loaded_at
    from {{ ref('stg_order_items') }}
    
    {% if is_incremental() %}
    where _loaded_at > (select coalesce(max(loaded_at), '1900-01-01') from {{ this }})
    {% endif %}
),

orders as (
    select
        order_id,
        customer_id,
        store_id,
        order_date,
        order_timestamp,
        order_status,
        payment_method,
        total_amount,
        discount_amount,
        tax_amount
    from {{ ref('stg_orders') }}
),

-- Get current product dimension records for SCD2 lookup
dim_product_current as (
    select
        product_key,
        product_id,
        unit_price as dim_unit_price,
        cost as dim_cost,
        category,
        subcategory,
        brand
    from {{ ref('dim_product') }}
    where is_current = true
),

-- Get current customer dimension records for SCD2 lookup
dim_customer_current as (
    select
        customer_key,
        customer_id
    from {{ ref('dim_customer') }}
    where is_current = true
),

-- Get store dimension records (SCD1, no versioning)
dim_store_records as (
    select
        store_key,
        store_id,
        region,
        district
    from {{ ref('dim_store') }}
),

-- Join all sources together
fact_sales as (
    select
        -- Surrogate key for the fact record
        {{ dbt_utils.generate_surrogate_key(['oi.order_item_id', 'oi.order_id']) }} as sales_key,
        
        -- Dimension keys
        coalesce(dc.customer_key, 'UNKNOWN') as customer_key,
        coalesce(dp.product_key, 'UNKNOWN') as product_key,
        coalesce(ds.store_key, 'UNKNOWN') as store_key,
        cast(o.order_date as date) as date_key,
        
        -- Degenerate dimensions (transaction identifiers)
        oi.order_id,
        oi.order_item_id,
        o.order_status,
        o.payment_method,
        
        -- Measures
        oi.quantity,
        oi.unit_price,
        oi.discount_percent,
        oi.line_total,
        
        -- Calculated measures
        oi.quantity * oi.unit_price as gross_amount,
        oi.quantity * oi.unit_price * (oi.discount_percent / 100) as discount_amount,
        coalesce(dp.dim_cost, 0) * oi.quantity as cost_amount,
        oi.line_total - (coalesce(dp.dim_cost, 0) * oi.quantity) as profit_amount,
        
        -- Order level amounts (for reference, not aggregation)
        o.total_amount as order_total_amount,
        o.discount_amount as order_discount_amount,
        o.tax_amount as order_tax_amount,
        
        -- Dates
        o.order_date,
        o.order_timestamp,
        
        -- Audit columns
        oi._loaded_at as loaded_at,
        current_timestamp() as created_at,
        current_timestamp() as updated_at
        
    from order_items oi
    inner join orders o on oi.order_id = o.order_id
    left join dim_product_current dp on oi.product_id = dp.product_id
    left join dim_customer_current dc on o.customer_id = dc.customer_id
    left join dim_store_records ds on o.store_id = ds.store_id
)

select * from fact_sales
