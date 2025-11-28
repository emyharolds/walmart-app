{{
    config(
        materialized='table'
    )
}}

{#
    Dimension: dim_date
    Type: Static/Conformed Dimension
    
    A date dimension table containing various date attributes for reporting
    and analysis. This is a conformed dimension used across all fact tables.
    
    Note: This dimension uses Snowflake-specific date functions.
    In Snowflake, dayofweek returns 0=Sunday through 6=Saturday.
#}

with date_spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2020-01-01' as date)",
        end_date="cast('2030-12-31' as date)"
    ) }}
),

date_dimension as (
    select
        cast(date_day as date) as date_key,
        date_day as full_date,
        extract(year from date_day) as year,
        extract(quarter from date_day) as quarter,
        extract(month from date_day) as month,
        extract(week from date_day) as week_of_year,
        dayofweek(date_day) as day_of_week,  -- Snowflake: 0=Sunday, 6=Saturday
        extract(dayofyear from date_day) as day_of_year,
        extract(day from date_day) as day_of_month,
        
        -- Formatted strings (Snowflake-compatible)
        cast(year(date_day) as varchar) as year_name,
        cast(year(date_day) as varchar) || '-' || lpad(cast(month(date_day) as varchar), 2, '0') as year_month,
        monthname(date_day) as month_name_short,
        case month(date_day)
            when 1 then 'January'
            when 2 then 'February'
            when 3 then 'March'
            when 4 then 'April'
            when 5 then 'May'
            when 6 then 'June'
            when 7 then 'July'
            when 8 then 'August'
            when 9 then 'September'
            when 10 then 'October'
            when 11 then 'November'
            when 12 then 'December'
        end as month_name_long,
        dayname(date_day) as day_name_short,
        case dayofweek(date_day)
            when 0 then 'Sunday'
            when 1 then 'Monday'
            when 2 then 'Tuesday'
            when 3 then 'Wednesday'
            when 4 then 'Thursday'
            when 5 then 'Friday'
            when 6 then 'Saturday'
        end as day_name_long,
        
        -- Fiscal year (assuming fiscal year starts in February)
        case 
            when extract(month from date_day) >= 2 
            then extract(year from date_day)
            else extract(year from date_day) - 1
        end as fiscal_year,
        
        case 
            when extract(month from date_day) >= 2 
            then extract(month from date_day) - 1
            else extract(month from date_day) + 11
        end as fiscal_month,
        
        -- Quarter names (Snowflake-compatible cast)
        'Q' || cast(extract(quarter from date_day) as varchar) as quarter_name,
        cast(extract(year from date_day) as varchar) || '-Q' || cast(extract(quarter from date_day) as varchar) as year_quarter,
        
        -- Weekend/Weekday flags (Snowflake: 0=Sunday, 6=Saturday)
        case 
            when dayofweek(date_day) in (0, 6) then true 
            else false 
        end as is_weekend,
        
        case 
            when dayofweek(date_day) not in (0, 6) then true 
            else false 
        end as is_weekday,
        
        -- Month start/end flags
        case 
            when date_day = date_trunc('month', date_day) then true 
            else false 
        end as is_month_start,
        
        case 
            when date_day = last_day(date_day) then true 
            else false 
        end as is_month_end,
        
        -- Year start/end flags
        case 
            when date_day = date_trunc('year', date_day) then true 
            else false 
        end as is_year_start,
        
        case 
            when date_day = dateadd(day, -1, dateadd(year, 1, date_trunc('year', date_day))) then true 
            else false 
        end as is_year_end,
        
        current_timestamp() as created_at
        
    from date_spine
)

select * from date_dimension
