{{
    config(
        materialized='incremental',
        unique_key=['STORE_ID', 'DEPT_ID', 'STORE_DATE'],
        incremental_strategy='merge'
    )
}}

{#
    Fact Table: fact_walmart_sales
    
    Weekly sales facts for Walmart stores and departments
    including various metrics and indicators.
#}

with fact_data as (
    select * from {{ ref('stg_fact') }}
),

date_dim as (
    select DATE_KEY, FULL_DATE from {{ ref('dim_date') }}
),

store_dim as (
    select STORE_KEY, STORE_ID, DEPT_ID from {{ ref('dim_store') }}
),

joined as (
    select
        s.STORE_KEY,
        f.STORE as STORE_ID,
        f.DEPT as DEPT_ID,
        f.STORE_DATE,
        d.DATE_KEY,
        f.WEEKLY_SALES,
        f.ISHOLIDAY,
        f.TEMPERATURE,
        f.FUEL_PRICE,
        f.MARKDOWN1,
        f.MARKDOWN2,
        f.MARKDOWN3,
        f.MARKDOWN4,
        f.MARKDOWN5,
        f.CPI,
        f.UNEMPLOYMENT
    from fact_data f
    left join date_dim d on f.STORE_DATE = d.FULL_DATE
    left join store_dim s on f.STORE = s.STORE_ID and f.DEPT = s.DEPT_ID
    
    {% if is_incremental() %}
    where f.STORE_DATE > (select coalesce(max(STORE_DATE), '1900-01-01') from {{ this }})
    {% endif %}
)

select
    STORE_KEY,
    STORE_ID,
    DEPT_ID,
    STORE_DATE,
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
