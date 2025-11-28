{#
    Common utility macros for the Walmart dbt project
#}

{#
    Generate a date dimension table
    
    Parameters:
    - start_date: Start date for the dimension
    - end_date: End date for the dimension
#}

{% macro generate_date_spine(start_date, end_date) %}
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('" ~ start_date ~ "' as date)",
        end_date="cast('" ~ end_date ~ "' as date)"
    ) }}
{% endmacro %}


{#
    Get the current timestamp in a consistent format
#}

{% macro get_current_timestamp() %}
    current_timestamp()
{% endmacro %}


{#
    Generate audit columns for dimension and fact tables
#}

{% macro audit_columns() %}
    {{ get_current_timestamp() }} as created_at,
    {{ get_current_timestamp() }} as updated_at,
    '{{ invocation_id }}' as dbt_run_id
{% endmacro %}


{#
    Safe division to avoid divide by zero errors
    
    Parameters:
    - numerator: The numerator of the division
    - denominator: The denominator of the division
    - default_value: Value to return if denominator is zero (default: 0)
#}

{% macro safe_divide(numerator, denominator, default_value=0) %}
    case 
        when {{ denominator }} = 0 or {{ denominator }} is null 
        then {{ default_value }}
        else {{ numerator }} / {{ denominator }}
    end
{% endmacro %}


{#
    Calculate percentage
    
    Parameters:
    - part: The part value
    - whole: The whole value
#}

{% macro calculate_percentage(part, whole) %}
    {{ safe_divide(part, whole, 0) }} * 100
{% endmacro %}
