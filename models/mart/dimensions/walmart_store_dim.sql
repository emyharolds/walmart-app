-- models/mart/dimensions/walmart_store_dim.sql
-- Store dimension with SCD Type 1 (incremental upsert)

{{
    config(
        materialized='incremental',
        unique_key=['store_id', 'dept_id'],
        merge_update_columns=['store_type', 'store_size', 'update_date']
    )
}}

with store_dept_combo as (
    select distinct
        d.store as store_id,
        d.dept as dept_id,
        s.store_type,
        s.store_size
    from {{ ref('stg_department') }} d
    left join {{ ref('stg_stores') }} s 
        on d.store = s.store
    where d.store is not null 
      and d.dept is not null
),

final as (
    select
        store_id,
        dept_id,
        store_type,
        store_size,
        {% if is_incremental() %}
            current_timestamp() as update_date,
            coalesce(
                (select insert_date 
                 from {{ this }} 
                 where store_id = store_dept_combo.store_id 
                   and dept_id = store_dept_combo.dept_id),
                current_timestamp()
            ) as insert_date
        {% else %}
            current_timestamp() as insert_date,
            current_timestamp() as update_date
        {% endif %}
    from store_dept_combo
)

select * from final

{% if is_incremental() %}
where (store_id, dept_id) not in (
    select store_id, dept_id from {{ this }}
)
or exists (
    select 1 from {{ this }} t
    where t.store_id = final.store_id
      and t.dept_id = final.dept_id
      and (
          t.store_type != final.store_type
          or t.store_size != final.store_size
      )
)
{% endif %}
