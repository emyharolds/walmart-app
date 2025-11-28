{{
    config(
        materialized='incremental',
        unique_key='customer_key',
        incremental_strategy='merge',
        merge_update_columns=['valid_to', 'is_current', 'updated_at']
    )
}}

{#
    Dimension: dim_customer
    SCD Type: 2 (Historical Tracking)
    
    This dimension uses SCD Type 2 strategy where historical changes
    are tracked by creating new records with versioning. Each change
    creates a new record with valid_from/valid_to dates and is_current flag.
    
    Tracked columns: first_name, last_name, email, phone, address, city, state, zip_code, country
    
    Incremental logic:
    1. For changed records: Output expired version (is_current=false) to update existing row via merge
    2. For changed records: Output new version (is_current=true) to insert new row
    3. For new records: Output new version (is_current=true) to insert new row
#}

{% set tracked_columns = ['first_name', 'last_name', 'email', 'phone', 'address', 'city', 'state', 'zip_code', 'country'] %}

with source_data as (
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
        updated_at as source_updated_at,
        -- Generate hash for change detection
        md5(concat_ws('||',
            coalesce(cast(first_name as varchar), ''),
            coalesce(cast(last_name as varchar), ''),
            coalesce(cast(email as varchar), ''),
            coalesce(cast(phone as varchar), ''),
            coalesce(cast(address as varchar), ''),
            coalesce(cast(city as varchar), ''),
            coalesce(cast(state as varchar), ''),
            coalesce(cast(zip_code as varchar), ''),
            coalesce(cast(country as varchar), '')
        )) as row_hash
    from {{ ref('stg_customers') }}
),

{% if is_incremental() %}

-- Get current records from target
current_records as (
    select
        customer_key,
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
        row_hash,
        valid_from,
        valid_to,
        is_current,
        created_at,
        updated_at
    from {{ this }}
    where is_current = true
),

-- Identify changed records (customers whose data has changed)
changed_records as (
    select
        c.customer_key,
        c.customer_id
    from current_records c
    inner join source_data s on c.customer_id = s.customer_id
    where c.row_hash != s.row_hash
),

-- Records to expire: output the existing record with is_current=false
-- This will be merged (updated) in the target table
expired_records as (
    select
        c.customer_key,
        c.customer_id,
        c.first_name,
        c.last_name,
        c.email,
        c.phone,
        c.address,
        c.city,
        c.state,
        c.zip_code,
        c.country,
        c.row_hash,
        c.valid_from,
        current_timestamp() as valid_to,
        false as is_current,
        c.created_at,
        current_timestamp() as updated_at
    from current_records c
    inner join changed_records ch on c.customer_key = ch.customer_key
),

-- New versions of changed customers (insert new rows)
new_versions as (
    select
        {{ dbt_utils.generate_surrogate_key(['s.customer_id', 'current_timestamp()']) }} as customer_key,
        s.customer_id,
        s.first_name,
        s.last_name,
        s.email,
        s.phone,
        s.address,
        s.city,
        s.state,
        s.zip_code,
        s.country,
        s.row_hash,
        current_timestamp() as valid_from,
        cast('{{ var("scd2_valid_to_default") }}' as timestamp) as valid_to,
        true as is_current,
        current_timestamp() as created_at,
        current_timestamp() as updated_at
    from source_data s
    inner join changed_records ch on s.customer_id = ch.customer_id
),

-- Completely new customers (not in target at all)
new_customers as (
    select
        {{ dbt_utils.generate_surrogate_key(['s.customer_id', 'current_timestamp()']) }} as customer_key,
        s.customer_id,
        s.first_name,
        s.last_name,
        s.email,
        s.phone,
        s.address,
        s.city,
        s.state,
        s.zip_code,
        s.country,
        s.row_hash,
        current_timestamp() as valid_from,
        cast('{{ var("scd2_valid_to_default") }}' as timestamp) as valid_to,
        true as is_current,
        current_timestamp() as created_at,
        current_timestamp() as updated_at
    from source_data s
    left join current_records c on s.customer_id = c.customer_id
    where c.customer_id is null
),

-- Combine all records:
-- 1. Expired records (will update existing rows via merge on customer_key)
-- 2. New versions (will insert new rows - customer_key doesn't exist)
-- 3. New customers (will insert new rows - customer_key doesn't exist)
all_records as (
    select * from expired_records
    union all
    select * from new_versions
    union all
    select * from new_customers
)

select
    customer_key,
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
        {{ dbt_utils.generate_surrogate_key(['customer_id', 'current_timestamp()']) }} as customer_key,
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
