/*
    Snowflake Infrastructure Setup for S3 Data Ingestion
    
    This file contains the SQL statements to create the necessary
    Snowflake objects for loading data from S3 via Snowpipe.
    
    Prerequisites:
    - AWS S3 bucket with raw data files
    - AWS IAM role with appropriate permissions
    - Snowflake storage integration configured
    
    Run these statements manually in Snowflake before starting dbt.
*/

-- =============================================================================
-- STORAGE INTEGRATION (requires ACCOUNTADMIN role)
-- =============================================================================
-- This creates a secure connection between Snowflake and your S3 bucket.
-- Replace the values with your actual AWS account and S3 bucket details.

CREATE OR REPLACE STORAGE INTEGRATION walmart_s3_integration
    TYPE = EXTERNAL_STAGE
    STORAGE_PROVIDER = 'S3'
    ENABLED = TRUE
    STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::<your_aws_account_id>:role/snowflake_role'
    STORAGE_ALLOWED_LOCATIONS = ('s3://your-walmart-bucket/raw/');

-- Get the AWS IAM user ARN and external ID for trust policy configuration
DESC INTEGRATION walmart_s3_integration;


-- =============================================================================
-- FILE FORMATS
-- =============================================================================
-- Create file formats for different data file types

-- JSON file format
CREATE OR REPLACE FILE FORMAT walmart_json_format
    TYPE = 'JSON'
    COMPRESSION = 'AUTO'
    STRIP_OUTER_ARRAY = TRUE
    ENABLE_OCTAL = FALSE
    ALLOW_DUPLICATE = FALSE
    STRIP_NULL_VALUES = FALSE
    IGNORE_UTF8_ERRORS = FALSE;

-- CSV file format (comma-delimited with headers)
CREATE OR REPLACE FILE FORMAT walmart_csv_format
    TYPE = 'CSV'
    COMPRESSION = 'AUTO'
    FIELD_DELIMITER = ','
    RECORD_DELIMITER = '\n'
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
    ESCAPE = 'NONE'
    ESCAPE_UNENCLOSED_FIELD = '\134'
    DATE_FORMAT = 'AUTO'
    TIMESTAMP_FORMAT = 'AUTO'
    NULL_IF = ('NULL', 'null', '');

-- Parquet file format
CREATE OR REPLACE FILE FORMAT walmart_parquet_format
    TYPE = 'PARQUET'
    COMPRESSION = 'SNAPPY';


-- =============================================================================
-- EXTERNAL STAGES
-- =============================================================================
-- Create stages pointing to S3 bucket locations

CREATE OR REPLACE STAGE walmart_raw_stage
    STORAGE_INTEGRATION = walmart_s3_integration
    URL = 's3://your-walmart-bucket/raw/'
    FILE_FORMAT = walmart_csv_format;

-- List files in stage to verify connection
LIST @walmart_raw_stage;


-- =============================================================================
-- RAW TABLES
-- =============================================================================
-- Create raw tables to receive data from S3

-- Raw Customers Table
CREATE OR REPLACE TABLE raw.raw_customers (
    customer_id VARCHAR(50),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(255),
    phone VARCHAR(50),
    address VARCHAR(500),
    city VARCHAR(100),
    state VARCHAR(50),
    zip_code VARCHAR(20),
    country VARCHAR(100),
    created_at TIMESTAMP_NTZ,
    updated_at TIMESTAMP_NTZ,
    _loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Raw Products Table
CREATE OR REPLACE TABLE raw.raw_products (
    product_id VARCHAR(50),
    product_name VARCHAR(255),
    description VARCHAR(2000),
    category VARCHAR(100),
    subcategory VARCHAR(100),
    brand VARCHAR(100),
    unit_price NUMBER(18,2),
    cost NUMBER(18,2),
    supplier_id VARCHAR(50),
    is_active BOOLEAN,
    created_at TIMESTAMP_NTZ,
    updated_at TIMESTAMP_NTZ,
    _loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Raw Stores Table
CREATE OR REPLACE TABLE raw.raw_stores (
    store_id VARCHAR(50),
    store_name VARCHAR(255),
    store_type VARCHAR(100),
    address VARCHAR(500),
    city VARCHAR(100),
    state VARCHAR(50),
    zip_code VARCHAR(20),
    country VARCHAR(100),
    region VARCHAR(100),
    district VARCHAR(100),
    manager_name VARCHAR(200),
    open_date DATE,
    square_footage INTEGER,
    is_active BOOLEAN,
    created_at TIMESTAMP_NTZ,
    updated_at TIMESTAMP_NTZ,
    _loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Raw Orders Table
CREATE OR REPLACE TABLE raw.raw_orders (
    order_id VARCHAR(50),
    customer_id VARCHAR(50),
    store_id VARCHAR(50),
    order_date DATE,
    order_timestamp TIMESTAMP_NTZ,
    order_status VARCHAR(50),
    payment_method VARCHAR(50),
    total_amount NUMBER(18,2),
    discount_amount NUMBER(18,2),
    tax_amount NUMBER(18,2),
    created_at TIMESTAMP_NTZ,
    updated_at TIMESTAMP_NTZ,
    _loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Raw Order Items Table
CREATE OR REPLACE TABLE raw.raw_order_items (
    order_item_id VARCHAR(50),
    order_id VARCHAR(50),
    product_id VARCHAR(50),
    quantity INTEGER,
    unit_price NUMBER(18,2),
    discount_percent NUMBER(5,2),
    line_total NUMBER(18,2),
    created_at TIMESTAMP_NTZ,
    _loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Raw Suppliers Table
CREATE OR REPLACE TABLE raw.raw_suppliers (
    supplier_id VARCHAR(50),
    supplier_name VARCHAR(255),
    contact_name VARCHAR(200),
    contact_email VARCHAR(255),
    contact_phone VARCHAR(50),
    address VARCHAR(500),
    city VARCHAR(100),
    state VARCHAR(50),
    country VARCHAR(100),
    is_active BOOLEAN,
    created_at TIMESTAMP_NTZ,
    updated_at TIMESTAMP_NTZ,
    _loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);


-- =============================================================================
-- SNOWPIPES
-- =============================================================================
-- Create Snowpipes for automatic data ingestion from S3

-- Snowpipe for Customers
CREATE OR REPLACE PIPE raw.pipe_customers
    AUTO_INGEST = TRUE
    AS
    COPY INTO raw.raw_customers (
        customer_id, first_name, last_name, email, phone,
        address, city, state, zip_code, country,
        created_at, updated_at
    )
    FROM @walmart_raw_stage/customers/
    FILE_FORMAT = walmart_csv_format
    ON_ERROR = 'CONTINUE';

-- Snowpipe for Products
CREATE OR REPLACE PIPE raw.pipe_products
    AUTO_INGEST = TRUE
    AS
    COPY INTO raw.raw_products (
        product_id, product_name, description, category, subcategory,
        brand, unit_price, cost, supplier_id, is_active,
        created_at, updated_at
    )
    FROM @walmart_raw_stage/products/
    FILE_FORMAT = walmart_csv_format
    ON_ERROR = 'CONTINUE';

-- Snowpipe for Stores
CREATE OR REPLACE PIPE raw.pipe_stores
    AUTO_INGEST = TRUE
    AS
    COPY INTO raw.raw_stores (
        store_id, store_name, store_type, address, city,
        state, zip_code, country, region, district,
        manager_name, open_date, square_footage, is_active,
        created_at, updated_at
    )
    FROM @walmart_raw_stage/stores/
    FILE_FORMAT = walmart_csv_format
    ON_ERROR = 'CONTINUE';

-- Snowpipe for Orders
CREATE OR REPLACE PIPE raw.pipe_orders
    AUTO_INGEST = TRUE
    AS
    COPY INTO raw.raw_orders (
        order_id, customer_id, store_id, order_date, order_timestamp,
        order_status, payment_method, total_amount, discount_amount, tax_amount,
        created_at, updated_at
    )
    FROM @walmart_raw_stage/orders/
    FILE_FORMAT = walmart_csv_format
    ON_ERROR = 'CONTINUE';

-- Snowpipe for Order Items
CREATE OR REPLACE PIPE raw.pipe_order_items
    AUTO_INGEST = TRUE
    AS
    COPY INTO raw.raw_order_items (
        order_item_id, order_id, product_id, quantity, unit_price,
        discount_percent, line_total, created_at
    )
    FROM @walmart_raw_stage/order_items/
    FILE_FORMAT = walmart_csv_format
    ON_ERROR = 'CONTINUE';

-- Snowpipe for Suppliers
CREATE OR REPLACE PIPE raw.pipe_suppliers
    AUTO_INGEST = TRUE
    AS
    COPY INTO raw.raw_suppliers (
        supplier_id, supplier_name, contact_name, contact_email, contact_phone,
        address, city, state, country, is_active,
        created_at, updated_at
    )
    FROM @walmart_raw_stage/suppliers/
    FILE_FORMAT = walmart_csv_format
    ON_ERROR = 'CONTINUE';


-- =============================================================================
-- GET SNOWPIPE NOTIFICATION CHANNEL ARN
-- =============================================================================
-- After creating pipes, get the SQS notification channel ARN
-- This needs to be configured in S3 bucket event notifications

SHOW PIPES IN raw;

-- For each pipe, get the notification channel:
SELECT SYSTEM$PIPE_STATUS('raw.pipe_customers');
SELECT SYSTEM$PIPE_STATUS('raw.pipe_products');
SELECT SYSTEM$PIPE_STATUS('raw.pipe_stores');
SELECT SYSTEM$PIPE_STATUS('raw.pipe_orders');
SELECT SYSTEM$PIPE_STATUS('raw.pipe_order_items');
SELECT SYSTEM$PIPE_STATUS('raw.pipe_suppliers');


-- =============================================================================
-- MANUAL COPY COMMANDS (Alternative to Snowpipe)
-- =============================================================================
-- Use these for one-time or manual data loads

/*
COPY INTO raw.raw_customers
FROM @walmart_raw_stage/customers/
FILE_FORMAT = walmart_csv_format
ON_ERROR = 'CONTINUE';

COPY INTO raw.raw_products
FROM @walmart_raw_stage/products/
FILE_FORMAT = walmart_csv_format
ON_ERROR = 'CONTINUE';

COPY INTO raw.raw_stores
FROM @walmart_raw_stage/stores/
FILE_FORMAT = walmart_csv_format
ON_ERROR = 'CONTINUE';

COPY INTO raw.raw_orders
FROM @walmart_raw_stage/orders/
FILE_FORMAT = walmart_csv_format
ON_ERROR = 'CONTINUE';

COPY INTO raw.raw_order_items
FROM @walmart_raw_stage/order_items/
FILE_FORMAT = walmart_csv_format
ON_ERROR = 'CONTINUE';

COPY INTO raw.raw_suppliers
FROM @walmart_raw_stage/suppliers/
FILE_FORMAT = walmart_csv_format
ON_ERROR = 'CONTINUE';
*/
