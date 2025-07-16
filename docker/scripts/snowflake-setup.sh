#!/bin/bash

# Snowflake Setup Script
# This script creates test tables and sample data in your Snowflake account
# 
# USAGE:
# 1. Start the SnowSQL client container: make snowflake-start
# 2. Copy this script to the container: docker cp docker/scripts/snowflake-setup.sh snowsql-client:/tmp/
# 3. Execute via SnowSQL: docker exec -it snowsql-client snowsql -c example -f /tmp/snowflake-setup.sh
#
# Or run individual SQL commands:
# docker exec -it snowsql-client snowsql -c example -q "CREATE DATABASE IF NOT EXISTS TESTDB"

echo "Starting Snowflake schema setup..."
echo "Note: This script contains SQL commands to be executed in SnowSQL"
echo ""

# The following SQL commands will set up test data in Snowflake
# You can run this entire file using: snowsql -c your_connection -f this_file.sql

cat << 'EOF'
-- ============================================
-- Snowflake Test Data Setup Script
-- ============================================

-- Create test database and schema
CREATE DATABASE IF NOT EXISTS TESTDB;
USE DATABASE TESTDB;
CREATE SCHEMA IF NOT EXISTS SNAPTEST;
USE SCHEMA SNAPTEST;

-- Create a warehouse if needed (requires appropriate privileges)
-- CREATE WAREHOUSE IF NOT EXISTS TEST_WH 
--   WITH WAREHOUSE_SIZE = 'XSMALL' 
--   AUTO_SUSPEND = 300 
--   AUTO_RESUME = TRUE;
-- USE WAREHOUSE TEST_WH;

-- ============================================
-- Create Tables
-- ============================================

-- Customers table
CREATE OR REPLACE TABLE CUSTOMERS (
    CUSTOMER_ID NUMBER(38,0) NOT NULL PRIMARY KEY,
    FIRST_NAME VARCHAR(50),
    LAST_NAME VARCHAR(50),
    EMAIL VARCHAR(100),
    PHONE VARCHAR(20),
    ADDRESS VARCHAR(200),
    CITY VARCHAR(50),
    STATE VARCHAR(2),
    ZIP_CODE VARCHAR(10),
    CREATED_DATE TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Products table
CREATE OR REPLACE TABLE PRODUCTS (
    PRODUCT_ID NUMBER(38,0) NOT NULL PRIMARY KEY,
    PRODUCT_NAME VARCHAR(100),
    CATEGORY VARCHAR(50),
    PRICE NUMBER(10,2),
    STOCK_QUANTITY NUMBER(38,0),
    LAST_UPDATED TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Orders table
CREATE OR REPLACE TABLE ORDERS (
    ORDER_ID NUMBER(38,0) NOT NULL PRIMARY KEY,
    CUSTOMER_ID NUMBER(38,0),
    ORDER_DATE TIMESTAMP_NTZ,
    TOTAL_AMOUNT NUMBER(10,2),
    STATUS VARCHAR(20),
    SHIPPING_ADDRESS VARCHAR(200),
    FOREIGN KEY (CUSTOMER_ID) REFERENCES CUSTOMERS(CUSTOMER_ID)
);

-- Order items table (for demonstrating joins)
CREATE OR REPLACE TABLE ORDER_ITEMS (
    ORDER_ITEM_ID NUMBER(38,0) NOT NULL PRIMARY KEY,
    ORDER_ID NUMBER(38,0),
    PRODUCT_ID NUMBER(38,0),
    QUANTITY NUMBER(38,0),
    UNIT_PRICE NUMBER(10,2),
    FOREIGN KEY (ORDER_ID) REFERENCES ORDERS(ORDER_ID),
    FOREIGN KEY (PRODUCT_ID) REFERENCES PRODUCTS(PRODUCT_ID)
);

-- Sales time series table (for demonstrating Snowflake time-based features)
CREATE OR REPLACE TABLE SALES_TIMESERIES (
    SALE_ID NUMBER(38,0) NOT NULL PRIMARY KEY,
    PRODUCT_ID NUMBER(38,0),
    SALE_DATE DATE,
    SALE_TIME TIMESTAMP_NTZ,
    QUANTITY_SOLD NUMBER(38,0),
    REVENUE NUMBER(12,2),
    REGION VARCHAR(50),
    FOREIGN KEY (PRODUCT_ID) REFERENCES PRODUCTS(PRODUCT_ID)
);

-- ============================================
-- Insert Sample Data
-- ============================================

-- Insert customers
INSERT INTO CUSTOMERS (CUSTOMER_ID, FIRST_NAME, LAST_NAME, EMAIL, PHONE, ADDRESS, CITY, STATE, ZIP_CODE)
VALUES 
    (1, 'John', 'Doe', 'john.doe@example.com', '555-0101', '123 Main St', 'San Francisco', 'CA', '94105'),
    (2, 'Jane', 'Smith', 'jane.smith@example.com', '555-0102', '456 Oak Ave', 'San Jose', 'CA', '95110'),
    (3, 'Bob', 'Johnson', 'bob.johnson@example.com', '555-0103', '789 Pine Rd', 'Oakland', 'CA', '94612'),
    (4, 'Alice', 'Williams', 'alice.williams@example.com', '555-0104', '321 Elm St', 'Palo Alto', 'CA', '94301'),
    (5, 'Charlie', 'Brown', 'charlie.brown@example.com', '555-0105', '654 Maple Dr', 'Berkeley', 'CA', '94702'),
    (6, 'Diana', 'Davis', 'diana.davis@example.com', '555-0106', '987 Cedar Ln', 'Fremont', 'CA', '94538'),
    (7, 'Edward', 'Miller', 'edward.miller@example.com', '555-0107', '147 Birch Way', 'San Mateo', 'CA', '94401'),
    (8, 'Fiona', 'Garcia', 'fiona.garcia@example.com', '555-0108', '258 Spruce Ct', 'Redwood City', 'CA', '94061');

-- Insert products
INSERT INTO PRODUCTS (PRODUCT_ID, PRODUCT_NAME, CATEGORY, PRICE, STOCK_QUANTITY)
VALUES 
    (1, 'Laptop Pro 15"', 'Electronics', 1299.99, 50),
    (2, 'Wireless Mouse', 'Electronics', 29.99, 200),
    (3, 'USB-C Hub', 'Electronics', 49.99, 150),
    (4, 'Mechanical Keyboard', 'Electronics', 89.99, 75),
    (5, 'HD Webcam', 'Electronics', 79.99, 100),
    (6, 'Desk Lamp LED', 'Office', 34.99, 120),
    (7, 'Ergonomic Chair', 'Office', 299.99, 30),
    (8, 'Standing Desk', 'Office', 449.99, 25),
    (9, 'Notebook Set', 'Office', 19.99, 300),
    (10, 'Coffee Maker', 'Appliances', 89.99, 60);

-- Insert orders
INSERT INTO ORDERS (ORDER_ID, CUSTOMER_ID, ORDER_DATE, TOTAL_AMOUNT, STATUS, SHIPPING_ADDRESS)
VALUES 
    (1001, 1, CURRENT_TIMESTAMP(), 1329.98, 'COMPLETED', '123 Main St, San Francisco, CA 94105'),
    (1002, 2, DATEADD(day, -1, CURRENT_TIMESTAMP()), 49.99, 'PROCESSING', '456 Oak Ave, San Jose, CA 95110'),
    (1003, 3, DATEADD(day, -2, CURRENT_TIMESTAMP()), 169.98, 'SHIPPED', '789 Pine Rd, Oakland, CA 94612'),
    (1004, 4, DATEADD(day, -3, CURRENT_TIMESTAMP()), 384.98, 'COMPLETED', '321 Elm St, Palo Alto, CA 94301'),
    (1005, 5, DATEADD(day, -4, CURRENT_TIMESTAMP()), 89.99, 'PROCESSING', '654 Maple Dr, Berkeley, CA 94702'),
    (1006, 1, DATEADD(day, -5, CURRENT_TIMESTAMP()), 299.99, 'COMPLETED', '123 Main St, San Francisco, CA 94105'),
    (1007, 6, DATEADD(day, -6, CURRENT_TIMESTAMP()), 534.97, 'SHIPPED', '987 Cedar Ln, Fremont, CA 94538'),
    (1008, 7, DATEADD(day, -7, CURRENT_TIMESTAMP()), 119.98, 'COMPLETED', '147 Birch Way, San Mateo, CA 94401');

-- Insert order items
INSERT INTO ORDER_ITEMS (ORDER_ITEM_ID, ORDER_ID, PRODUCT_ID, QUANTITY, UNIT_PRICE)
VALUES 
    (1, 1001, 1, 1, 1299.99),
    (2, 1001, 2, 1, 29.99),
    (3, 1002, 3, 1, 49.99),
    (4, 1003, 4, 1, 89.99),
    (5, 1003, 5, 1, 79.99),
    (6, 1004, 6, 1, 34.99),
    (7, 1004, 7, 1, 299.99),
    (8, 1004, 3, 1, 49.99),
    (9, 1005, 10, 1, 89.99),
    (10, 1006, 7, 1, 299.99),
    (11, 1007, 8, 1, 449.99),
    (12, 1007, 6, 1, 34.99),
    (13, 1007, 3, 1, 49.99),
    (14, 1008, 2, 2, 29.99),
    (15, 1008, 9, 3, 19.99);

-- Insert sales time series data (last 30 days)
INSERT INTO SALES_TIMESERIES (SALE_ID, PRODUCT_ID, SALE_DATE, SALE_TIME, QUANTITY_SOLD, REVENUE, REGION)
SELECT 
    ROW_NUMBER() OVER (ORDER BY sale_date, product_id) AS SALE_ID,
    product_id,
    sale_date,
    DATEADD(hour, UNIFORM(0, 23, RANDOM()), sale_date) AS sale_time,
    UNIFORM(1, 10, RANDOM()) AS quantity_sold,
    ROUND(UNIFORM(1, 10, RANDOM()) * price, 2) AS revenue,
    CASE UNIFORM(1, 4, RANDOM())
        WHEN 1 THEN 'North'
        WHEN 2 THEN 'South'
        WHEN 3 THEN 'East'
        WHEN 4 THEN 'West'
    END AS region
FROM (
    SELECT 
        p.product_id,
        p.price,
        DATEADD(day, -seq.n, CURRENT_DATE()) AS sale_date
    FROM PRODUCTS p
    CROSS JOIN (
        SELECT SEQ4() AS n 
        FROM TABLE(GENERATOR(ROWCOUNT => 30))
    ) seq
    WHERE seq.n < 30
);

-- ============================================
-- Create Views for Common Queries
-- ============================================

-- Customer order summary view
CREATE OR REPLACE VIEW CUSTOMER_ORDER_SUMMARY AS
SELECT 
    c.CUSTOMER_ID,
    c.FIRST_NAME,
    c.LAST_NAME,
    c.EMAIL,
    COUNT(DISTINCT o.ORDER_ID) AS TOTAL_ORDERS,
    SUM(o.TOTAL_AMOUNT) AS LIFETIME_VALUE,
    MAX(o.ORDER_DATE) AS LAST_ORDER_DATE
FROM CUSTOMERS c
LEFT JOIN ORDERS o ON c.CUSTOMER_ID = o.CUSTOMER_ID
GROUP BY c.CUSTOMER_ID, c.FIRST_NAME, c.LAST_NAME, c.EMAIL;

-- Product sales summary view
CREATE OR REPLACE VIEW PRODUCT_SALES_SUMMARY AS
SELECT 
    p.PRODUCT_ID,
    p.PRODUCT_NAME,
    p.CATEGORY,
    COUNT(DISTINCT oi.ORDER_ID) AS TIMES_ORDERED,
    SUM(oi.QUANTITY) AS TOTAL_QUANTITY_SOLD,
    SUM(oi.QUANTITY * oi.UNIT_PRICE) AS TOTAL_REVENUE
FROM PRODUCTS p
LEFT JOIN ORDER_ITEMS oi ON p.PRODUCT_ID = oi.PRODUCT_ID
GROUP BY p.PRODUCT_ID, p.PRODUCT_NAME, p.CATEGORY;

-- ============================================
-- Create Stored Procedures (Snowflake Specific)
-- ============================================

-- Procedure to get customer order history
CREATE OR REPLACE PROCEDURE GET_CUSTOMER_ORDERS(CUSTOMER_ID_PARAM NUMBER)
RETURNS TABLE (ORDER_ID NUMBER, ORDER_DATE TIMESTAMP_NTZ, TOTAL_AMOUNT NUMBER, STATUS VARCHAR)
LANGUAGE SQL
AS
$$
    SELECT ORDER_ID, ORDER_DATE, TOTAL_AMOUNT, STATUS
    FROM ORDERS
    WHERE CUSTOMER_ID = CUSTOMER_ID_PARAM
    ORDER BY ORDER_DATE DESC
$$;

-- ============================================
-- Demonstrate Snowflake-Specific Features
-- ============================================

-- Create a table with Snowflake VARIANT type for semi-structured data
CREATE OR REPLACE TABLE PRODUCT_METADATA (
    PRODUCT_ID NUMBER(38,0) PRIMARY KEY,
    METADATA VARIANT,
    FOREIGN KEY (PRODUCT_ID) REFERENCES PRODUCTS(PRODUCT_ID)
);

-- Insert JSON data into VARIANT column
INSERT INTO PRODUCT_METADATA (PRODUCT_ID, METADATA)
SELECT 
    PRODUCT_ID,
    PARSE_JSON(
        CASE CATEGORY
            WHEN 'Electronics' THEN '{"warranty_months": 12, "specifications": {"weight": "2.5kg", "dimensions": "30x20x5cm"}, "features": ["wireless", "bluetooth"]}'
            WHEN 'Office' THEN '{"assembly_required": true, "materials": ["wood", "metal"], "color_options": ["black", "white", "brown"]}'
            WHEN 'Appliances' THEN '{"power_consumption": "800W", "capacity": "1.5L", "safety_features": ["auto-shutoff", "overheat-protection"]}'
        END
    )
FROM PRODUCTS;

-- ============================================
-- Grant Permissions (if running as ACCOUNTADMIN)
-- ============================================

-- Create a test role and user (uncomment if you have permissions)
-- CREATE ROLE IF NOT EXISTS TEST_ROLE;
-- GRANT USAGE ON DATABASE TESTDB TO ROLE TEST_ROLE;
-- GRANT USAGE ON SCHEMA SNAPTEST TO ROLE TEST_ROLE;
-- GRANT SELECT ON ALL TABLES IN SCHEMA SNAPTEST TO ROLE TEST_ROLE;
-- GRANT SELECT ON ALL VIEWS IN SCHEMA SNAPTEST TO ROLE TEST_ROLE;

-- ============================================
-- Verification Queries
-- ============================================

-- Show all created objects
SHOW TABLES IN SCHEMA SNAPTEST;
SHOW VIEWS IN SCHEMA SNAPTEST;
SHOW PROCEDURES IN SCHEMA SNAPTEST;

-- Sample queries to verify data
SELECT 'Customers' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM CUSTOMERS
UNION ALL
SELECT 'Products', COUNT(*) FROM PRODUCTS
UNION ALL
SELECT 'Orders', COUNT(*) FROM ORDERS
UNION ALL
SELECT 'Order Items', COUNT(*) FROM ORDER_ITEMS
UNION ALL
SELECT 'Sales TimeSeries', COUNT(*) FROM SALES_TIMESERIES;

-- Example of querying semi-structured data
SELECT 
    p.PRODUCT_NAME,
    pm.METADATA:warranty_months::NUMBER AS WARRANTY_MONTHS,
    pm.METADATA:specifications.weight::STRING AS WEIGHT
FROM PRODUCTS p
JOIN PRODUCT_METADATA pm ON p.PRODUCT_ID = pm.PRODUCT_ID
WHERE p.CATEGORY = 'Electronics';

-- Time Travel example (Snowflake-specific feature)
-- SELECT * FROM ORDERS AT(OFFSET => -60*5); -- Data from 5 minutes ago

ECHO 'Snowflake test data setup completed successfully!';
EOF

echo ""
echo "Setup script generated. To use it:"
echo "1. Ensure your SnowSQL client is running: make snowflake-start"
echo "2. Execute the SQL commands using one of these methods:"
echo "   a. Save SQL to a file and run: docker exec -it snowsql-client snowsql -c example -f /path/to/file.sql"
echo "   b. Copy and paste the SQL commands into an interactive SnowSQL session"
echo "   c. Run individual commands: docker exec -it snowsql-client snowsql -c example -q \"CREATE DATABASE IF NOT EXISTS TESTDB\""
