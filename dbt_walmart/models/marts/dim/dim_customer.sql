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
        row_hash,
        valid_from
    from {{ this }}
    where is_current = true
),

-- Identify changed records
changed_records as (
    select
        c.customer_key,
        c.customer_id
    from current_records c
    inner join source_data s on c.customer_id = s.customer_id
    where c.row_hash != s.row_hash
),

-- Records to expire (set is_current = false)
records_to_expire as (
    select
        customer_key,
        customer_id,
        false as is_current,
        current_timestamp() as valid_to,
        current_timestamp() as updated_at
    from changed_records
),

-- New records (either completely new or new versions of changed records)
new_records as (
    -- Completely new customers
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
    
    union all
    
    -- New versions of changed customers
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
    inner join changed_records c on s.customer_id = c.customer_id
)

-- Combine: keep unchanged records, expire changed records, add new records
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
from new_records

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
