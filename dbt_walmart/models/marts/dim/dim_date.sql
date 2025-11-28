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
        extract(dayofweek from date_day) as day_of_week,
        extract(dayofyear from date_day) as day_of_year,
        extract(day from date_day) as day_of_month,
        
        -- Formatted strings
        to_char(date_day, 'YYYY') as year_name,
        to_char(date_day, 'YYYY-MM') as year_month,
        to_char(date_day, 'Mon') as month_name_short,
        to_char(date_day, 'Month') as month_name_long,
        to_char(date_day, 'Dy') as day_name_short,
        to_char(date_day, 'Day') as day_name_long,
        
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
        
        -- Quarter names
        'Q' || extract(quarter from date_day)::varchar as quarter_name,
        extract(year from date_day)::varchar || '-Q' || extract(quarter from date_day)::varchar as year_quarter,
        
        -- Weekend/Weekday flags
        case 
            when extract(dayofweek from date_day) in (0, 6) then true 
            else false 
        end as is_weekend,
        
        case 
            when extract(dayofweek from date_day) not in (0, 6) then true 
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
