{{
    config(
        materialized='incremental',
        unique_key='supplier_key',
        incremental_strategy='merge',
        merge_update_columns=['supplier_name', 'contact_name', 'contact_email', 
                             'contact_phone', 'address', 'city', 'state', 
                             'country', 'is_active', 'updated_at']
    )
}}

{#
    Dimension: dim_supplier
    SCD Type: 1 (Overwrite)
    
    This dimension uses SCD Type 1 strategy where historical changes
    are not tracked. Supplier information is simply updated with the 
    latest values from the source.
#}

with source_data as (
    select
        supplier_id,
        supplier_name,
        contact_name,
        contact_email,
        contact_phone,
        address,
        city,
        state,
        country,
        is_active,
        updated_at as source_updated_at
    from {{ ref('stg_suppliers') }}
    
    {% if is_incremental() %}
    where updated_at > (select coalesce(max(updated_at), '1900-01-01') from {{ this }})
    {% endif %}
)

select
    {{ dbt_utils.generate_surrogate_key(['supplier_id']) }} as supplier_key,
    supplier_id,
    supplier_name,
    contact_name,
    contact_email,
    contact_phone,
    address,
    city,
    state,
    country,
    is_active,
    current_timestamp() as created_at,
    current_timestamp() as updated_at
from source_data
