{#
    SCD Type 2 Macro - Tracks historical changes with versioning
    
    This macro implements Slowly Changing Dimension Type 2 logic,
    where historical changes are preserved by creating new records
    with effective dates and a current record flag.
    
    Key columns added for SCD2:
    - surrogate_key: Unique identifier for each version of a record
    - valid_from: Effective start date of the record version
    - valid_to: Effective end date of the record version
    - is_current: Flag indicating if this is the current version
#}

{% macro generate_surrogate_key(columns) %}
    {{ dbt_utils.generate_surrogate_key(columns) }}
{% endmacro %}


{#
    SCD2 Merge Statement Macro
    
    This macro generates a MERGE statement for SCD2 processing.
    It handles:
    1. Detecting changed records and expiring the old version
    2. Inserting new versions of changed records
    3. Inserting completely new records
    
    Parameters:
    - source_relation: The source model/table
    - target_relation: The target dimension table
    - unique_key: The business key column(s)
    - tracked_columns: Columns to track for changes
    - surrogate_key_col: Name of the surrogate key column
#}

{% macro scd2_merge(source_relation, target_relation, unique_key, tracked_columns, surrogate_key_col='dim_key') %}

-- Step 1: Identify records that have changed
with source_data as (
    select 
        *,
        {{ dbt_utils.generate_surrogate_key([unique_key] + tracked_columns) }} as row_hash
    from {{ source_relation }}
),

current_target as (
    select 
        *,
        {{ dbt_utils.generate_surrogate_key([unique_key] + tracked_columns) }} as row_hash
    from {{ target_relation }}
    where is_current = true
),

-- Records that exist in target but have changed
changed_records as (
    select 
        t.{{ surrogate_key_col }},
        t.{{ unique_key }}
    from current_target t
    inner join source_data s 
        on t.{{ unique_key }} = s.{{ unique_key }}
    where t.row_hash != s.row_hash
),

-- New records not in target
new_records as (
    select s.*
    from source_data s
    left join current_target t 
        on s.{{ unique_key }} = t.{{ unique_key }}
    where t.{{ unique_key }} is null
)

-- Update changed records (expire them)
update {{ target_relation }}
set 
    valid_to = current_timestamp(),
    is_current = false,
    updated_at = current_timestamp()
where {{ surrogate_key_col }} in (select {{ surrogate_key_col }} from changed_records);

-- Insert new versions of changed records
insert into {{ target_relation }}
select
    {{ dbt_utils.generate_surrogate_key([unique_key, 'current_timestamp()']) }} as {{ surrogate_key_col }},
    {% for col in tracked_columns %}
        s.{{ col }},
    {% endfor %}
    s.{{ unique_key }},
    current_timestamp() as valid_from,
    cast('{{ var("scd2_valid_to_default") }}' as timestamp) as valid_to,
    true as is_current,
    current_timestamp() as created_at,
    current_timestamp() as updated_at
from source_data s
inner join changed_records c 
    on s.{{ unique_key }} = c.{{ unique_key }};

-- Insert completely new records
insert into {{ target_relation }}
select
    {{ dbt_utils.generate_surrogate_key([unique_key, 'current_timestamp()']) }} as {{ surrogate_key_col }},
    {% for col in tracked_columns %}
        {{ col }},
    {% endfor %}
    {{ unique_key }},
    current_timestamp() as valid_from,
    cast('{{ var("scd2_valid_to_default") }}' as timestamp) as valid_to,
    true as is_current,
    current_timestamp() as created_at,
    current_timestamp() as updated_at
from new_records;

{% endmacro %}


{#
    Generate hash for change detection in SCD2
    
    Parameters:
    - columns: List of columns to include in the hash
#}

{% macro generate_change_hash(columns) %}
    md5(concat_ws('||',
        {% for col in columns %}
            coalesce(cast({{ col }} as varchar), ''){% if not loop.last %},{% endif %}
        {% endfor %}
    ))
{% endmacro %}
