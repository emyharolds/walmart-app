{{
    config(
        materialized='incremental',
        unique_key='store_key',
        incremental_strategy='merge',
        merge_update_columns=['store_name', 'store_type', 'address', 'city', 'state', 
                             'zip_code', 'country', 'region', 'district', 'manager_name',
                             'square_footage', 'is_active', 'updated_at']
    )
}}

{#
    Dimension: dim_store
    SCD Type: 1 (Overwrite)
    
    This dimension uses SCD Type 1 strategy where historical changes
    are not tracked. Store information is simply updated with the 
    latest values from the source.
#}

with source_data as (
    select
        store_id,
        store_name,
        store_type,
        address,
        city,
        state,
        zip_code,
        country,
        region,
        district,
        manager_name,
        open_date,
        square_footage,
        is_active,
        updated_at as source_updated_at
    from {{ ref('stg_stores') }}
    
    {% if is_incremental() %}
    where updated_at > (select coalesce(max(updated_at), '1900-01-01') from {{ this }})
    {% endif %}
)

select
    {{ dbt_utils.generate_surrogate_key(['store_id']) }} as store_key,
    store_id,
    store_name,
    store_type,
    address,
    city,
    state,
    zip_code,
    country,
    region,
    district,
    manager_name,
    open_date,
    square_footage,
    is_active,
    current_timestamp() as created_at,
    current_timestamp() as updated_at
from source_data
