-- models/mart/dimensions/walmart_date_dim.sql
-- Date dimension with SCD Type 1 (incremental upsert)

{{
    config(
        materialized='incremental',
        unique_key='store_date',
        merge_update_columns=['isholiday', 'update_date']
    )
}}

with all_dates as (
    -- Get dates from department data
    select distinct 
        store_date,
        isholiday
    from {{ ref('stg_department') }}
    
    union
    
    -- Get dates from fact data
    select distinct 
        store_date,
        isholiday
    from {{ ref('stg_fact') }}
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['store_date']) }} as date_id,
        store_date,
        isholiday,
        {% if is_incremental() %}
            current_timestamp() as update_date,
            coalesce(
                (select insert_date from {{ this }} where store_date = all_dates.store_date),
                current_timestamp()
            ) as insert_date
        {% else %}
            current_timestamp() as insert_date,
            current_timestamp() as update_date
        {% endif %}
    from all_dates
)

select * from final

{% if is_incremental() %}
where store_date not in (select store_date from {{ this }})
   or (
       store_date in (select store_date from {{ this }})
       and isholiday != (select isholiday from {{ this }} where store_date = final.store_date)
   )
{% endif %}
