{{
    config(
        materialized='view'
    )
}}

with source as (
    select * from {{ source('raw', 'department') }}
),

cleaned as (
    select
        STORE,
        DEPT,
        trim(DEPT_NAME) as DEPT_NAME
    from source
)

select * from cleaned
