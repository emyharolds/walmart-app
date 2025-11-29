{{
    config(
        materialized='incremental',
        unique_key=['STORE', 'DEPT', 'DATE'],
        incremental_strategy='merge'
    )
}}

{#
    Fact Table: fact_walmart_sales
    
    Weekly sales facts for Walmart stores by department
    including various economic and store metrics.
#}

with sales_data as (
    select * from {{ ref('stg_department') }}
),

fact_data as (
    select * from {{ ref('stg_fact') }}
),

date_dim as (
    select DATE_KEY, FULL_DATE from {{ ref('dim_date') }}
),

joined as (
    select
        s.STORE,
        s.DEPT,
        s.DATE,
        d.DATE_KEY,
        s.WEEKLY_SALES,
        s.ISHOLIDAY,
        f.TEMPERATURE,
        f.FUEL_PRICE,
        f.MARKDOWN1,
        f.MARKDOWN2,
        f.MARKDOWN3,
        f.MARKDOWN4,
        f.MARKDOWN5,
        f.CPI,
        f.UNEMPLOYMENT
    from sales_data s
    left join fact_data f 
        on s.STORE = f.STORE 
        and s.DATE = f.DATE
    left join date_dim d 
        on s.DATE = d.FULL_DATE
    
    {% if is_incremental() %}
    where s.DATE > (select coalesce(max(DATE), '1900-01-01') from {{ this }})
    {% endif %}
)

select
    STORE,
    DEPT,
    DATE,
    DATE_KEY,
    WEEKLY_SALES,
    ISHOLIDAY,
    TEMPERATURE,
    FUEL_PRICE,
    MARKDOWN1,
    MARKDOWN2,
    MARKDOWN3,
    MARKDOWN4,
    MARKDOWN5,
    CPI,
    UNEMPLOYMENT,
    current_timestamp() as CREATED_AT
from joined
