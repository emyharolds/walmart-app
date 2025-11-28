{#
    SCD Type 1 Macro - Overwrites existing data with new values
    
    This macro implements Slowly Changing Dimension Type 1 logic,
    where historical changes are not tracked. The dimension record
    is simply updated with the latest values from the source.
    
    Parameters:
    - source_relation: The source model/table to merge from
    - target_relation: The target dimension table
    - unique_key: The business key column(s) for matching records
    - update_columns: List of columns to update when a match is found
    - insert_columns: List of columns to insert for new records
#}

{% macro scd1_merge(source_relation, target_relation, unique_key, update_columns, insert_columns) %}

merge into {{ target_relation }} as target
using {{ source_relation }} as source
on {% if unique_key is string %}
    target.{{ unique_key }} = source.{{ unique_key }}
{% else %}
    {% for key in unique_key %}
        target.{{ key }} = source.{{ key }}{% if not loop.last %} and {% endif %}
    {% endfor %}
{% endif %}

when matched then
    update set
        {% for col in update_columns %}
            target.{{ col }} = source.{{ col }}{% if not loop.last %},{% endif %}
        {% endfor %},
        target.updated_at = current_timestamp()

when not matched then
    insert (
        {% for col in insert_columns %}
            {{ col }}{% if not loop.last %},{% endif %}
        {% endfor %},
        created_at,
        updated_at
    )
    values (
        {% for col in insert_columns %}
            source.{{ col }}{% if not loop.last %},{% endif %}
        {% endfor %},
        current_timestamp(),
        current_timestamp()
    )

{% endmacro %}


{#
    Generate SCD1 dimension model SQL
    
    This macro generates the full SQL for an SCD1 dimension table,
    including the incremental logic for dbt.
    
    Parameters:
    - source_model: The source staging model
    - unique_key: The business key column(s)
    - columns: List of dimension attribute columns
#}

{% macro generate_scd1_dimension(source_model, unique_key, columns) %}

{{
    config(
        materialized='incremental',
        unique_key=unique_key,
        incremental_strategy='merge',
        merge_update_columns=columns
    )
}}

with source_data as (
    select
        {% if unique_key is string %}
            {{ unique_key }},
        {% else %}
            {% for key in unique_key %}
                {{ key }},
            {% endfor %}
        {% endif %}
        {% for col in columns %}
            {{ col }}{% if not loop.last %},{% endif %}
        {% endfor %}
    from {{ ref(source_model) }}
    
    {% if is_incremental() %}
    where updated_at > (select coalesce(max(updated_at), '1900-01-01') from {{ this }})
    {% endif %}
)

select
    {% if unique_key is string %}
        {{ unique_key }},
    {% else %}
        {% for key in unique_key %}
            {{ key }},
        {% endfor %}
    {% endif %}
    {% for col in columns %}
        {{ col }}{% if not loop.last %},{% endif %}
    {% endfor %}
from source_data

{% endmacro %}
