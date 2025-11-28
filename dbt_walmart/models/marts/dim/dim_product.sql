{{
    config(
        materialized='incremental',
        unique_key='product_key',
        incremental_strategy='merge',
        merge_update_columns=['valid_to', 'is_current', 'updated_at']
    )
}}

{#
    Dimension: dim_product
    SCD Type: 2 (Historical Tracking)
    
    This dimension uses SCD Type 2 strategy where historical changes
    are tracked by creating new records with versioning. This is important
    for products as pricing changes should be tracked historically.
    
    Tracked columns: product_name, description, category, subcategory, brand, unit_price, cost, is_active
    
    Incremental logic:
    1. For changed records: Output expired version (is_current=false) to update existing row via merge
    2. For changed records: Output new version (is_current=true) to insert new row
    3. For new records: Output new version (is_current=true) to insert new row
#}

{% set tracked_columns = ['product_name', 'description', 'category', 'subcategory', 'brand', 'unit_price', 'cost', 'is_active'] %}

with source_data as (
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
        updated_at as source_updated_at,
        -- Generate hash for change detection
        md5(concat_ws('||',
            coalesce(cast(product_name as varchar), ''),
            coalesce(cast(description as varchar), ''),
            coalesce(cast(category as varchar), ''),
            coalesce(cast(subcategory as varchar), ''),
            coalesce(cast(brand as varchar), ''),
            coalesce(cast(unit_price as varchar), ''),
            coalesce(cast(cost as varchar), ''),
            coalesce(cast(is_active as varchar), '')
        )) as row_hash
    from {{ ref('stg_products') }}
),

{% if is_incremental() %}

-- Get current records from target
current_records as (
    select
        product_key,
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
        row_hash,
        valid_from,
        valid_to,
        is_current,
        created_at,
        updated_at
    from {{ this }}
    where is_current = true
),

-- Identify changed records (products whose data has changed)
changed_records as (
    select
        c.product_key,
        c.product_id
    from current_records c
    inner join source_data s on c.product_id = s.product_id
    where c.row_hash != s.row_hash
),

-- Records to expire: output the existing record with is_current=false
-- This will be merged (updated) in the target table
expired_records as (
    select
        c.product_key,
        c.product_id,
        c.product_name,
        c.description,
        c.category,
        c.subcategory,
        c.brand,
        c.unit_price,
        c.cost,
        c.supplier_id,
        c.is_active,
        c.row_hash,
        c.valid_from,
        current_timestamp() as valid_to,
        false as is_current,
        c.created_at,
        current_timestamp() as updated_at
    from current_records c
    inner join changed_records ch on c.product_key = ch.product_key
),

-- New versions of changed products (insert new rows)
new_versions as (
    select
        {{ dbt_utils.generate_surrogate_key(['s.product_id', 'current_timestamp()']) }} as product_key,
        s.product_id,
        s.product_name,
        s.description,
        s.category,
        s.subcategory,
        s.brand,
        s.unit_price,
        s.cost,
        s.supplier_id,
        s.is_active,
        s.row_hash,
        current_timestamp() as valid_from,
        cast('{{ var("scd2_valid_to_default") }}' as timestamp) as valid_to,
        true as is_current,
        current_timestamp() as created_at,
        current_timestamp() as updated_at
    from source_data s
    inner join changed_records ch on s.product_id = ch.product_id
),

-- Completely new products (not in target at all)
new_products as (
    select
        {{ dbt_utils.generate_surrogate_key(['s.product_id', 'current_timestamp()']) }} as product_key,
        s.product_id,
        s.product_name,
        s.description,
        s.category,
        s.subcategory,
        s.brand,
        s.unit_price,
        s.cost,
        s.supplier_id,
        s.is_active,
        s.row_hash,
        current_timestamp() as valid_from,
        cast('{{ var("scd2_valid_to_default") }}' as timestamp) as valid_to,
        true as is_current,
        current_timestamp() as created_at,
        current_timestamp() as updated_at
    from source_data s
    left join current_records c on s.product_id = c.product_id
    where c.product_id is null
),

-- Combine all records:
-- 1. Expired records (will update existing rows via merge on product_key)
-- 2. New versions (will insert new rows - product_key doesn't exist)
-- 3. New products (will insert new rows - product_key doesn't exist)
all_records as (
    select * from expired_records
    union all
    select * from new_versions
    union all
    select * from new_products
)

select
    product_key,
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
    row_hash,
    valid_from,
    valid_to,
    is_current,
    created_at,
    updated_at
from all_records

{% else %}

-- Initial load: all records are current
initial_load as (
    select
        {{ dbt_utils.generate_surrogate_key(['product_id', 'current_timestamp()']) }} as product_key,
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
        row_hash,
        current_timestamp() as valid_from,
        cast('{{ var("scd2_valid_to_default") }}' as timestamp) as valid_to,
        true as is_current,
        current_timestamp() as created_at,
        current_timestamp() as updated_at
    from source_data
)

select * from initial_load

{% endif %}
