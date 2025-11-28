{{
    config(
        materialized='incremental',
        unique_key='order_key',
        incremental_strategy='merge',
        partition_by={
            'field': 'order_date',
            'data_type': 'date',
            'granularity': 'month'
        }
    )
}}

{#
    Fact Table: fact_orders
    Grain: One row per order (header level)
    
    This fact table captures order-level metrics and serves as a summary
    of sales activity. It links to dimension tables and can be used for
    order-level analysis without needing line item detail.
#}

with orders as (
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
        tax_amount,
        created_at,
        updated_at,
        _loaded_at
    from {{ ref('stg_orders') }}
    
    {% if is_incremental() %}
    where _loaded_at > (select coalesce(max(loaded_at), '1900-01-01') from {{ this }})
    {% endif %}
),

-- Aggregate order items to get line item counts and quantities
order_items_agg as (
    select
        order_id,
        count(distinct product_id) as unique_products_count,
        count(*) as line_items_count,
        sum(quantity) as total_quantity,
        sum(line_total) as items_total
    from {{ ref('stg_order_items') }}
    group by order_id
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
fact_orders as (
    select
        -- Surrogate key for the fact record
        {{ dbt_utils.generate_surrogate_key(['o.order_id']) }} as order_key,
        
        -- Dimension keys
        coalesce(dc.customer_key, 'UNKNOWN') as customer_key,
        coalesce(ds.store_key, 'UNKNOWN') as store_key,
        cast(o.order_date as date) as date_key,
        
        -- Degenerate dimensions
        o.order_id,
        o.order_status,
        o.payment_method,
        
        -- Measures from order header
        o.total_amount,
        o.discount_amount,
        o.tax_amount,
        o.total_amount - o.discount_amount as net_amount,
        
        -- Measures from order items aggregation
        coalesce(oia.unique_products_count, 0) as unique_products_count,
        coalesce(oia.line_items_count, 0) as line_items_count,
        coalesce(oia.total_quantity, 0) as total_quantity,
        
        -- Calculated measures
        case 
            when coalesce(oia.line_items_count, 0) > 0 
            then o.total_amount / oia.line_items_count 
            else 0 
        end as avg_line_item_value,
        
        -- Dates
        o.order_date,
        o.order_timestamp,
        
        -- Time-based attributes (for analysis)
        extract(hour from o.order_timestamp) as order_hour,
        case 
            when extract(dayofweek from o.order_date) in (0, 6) then 'Weekend'
            else 'Weekday'
        end as order_day_type,
        
        -- Audit columns
        o._loaded_at as loaded_at,
        current_timestamp() as created_at,
        current_timestamp() as updated_at
        
    from orders o
    left join order_items_agg oia on o.order_id = oia.order_id
    left join dim_customer_current dc on o.customer_id = dc.customer_id
    left join dim_store_records ds on o.store_id = ds.store_id
)

select * from fact_orders
