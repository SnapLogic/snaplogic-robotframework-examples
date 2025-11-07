-- ============================================
-- Snowflake Test Queries
-- ============================================
-- Sample queries to test your Snowflake connection and data

-- Test connection
SELECT CURRENT_VERSION() AS snowflake_version;
SELECT CURRENT_USER() AS connected_user;
SELECT CURRENT_DATABASE() AS current_database;
SELECT CURRENT_SCHEMA() AS current_schema;
SELECT CURRENT_WAREHOUSE() AS current_warehouse;

-- Use test database
USE DATABASE TESTDB;
USE SCHEMA SNAPTEST;

-- Show all tables
SHOW TABLES;

-- Query customers
SELECT * FROM CUSTOMERS LIMIT 5;

-- Query products
SELECT * FROM PRODUCTS WHERE CATEGORY = 'Electronics';

-- Join orders with customers
SELECT 
    c.FIRST_NAME || ' ' || c.LAST_NAME AS customer_name,
    o.ORDER_ID,
    o.ORDER_DATE,
    o.TOTAL_AMOUNT,
    o.STATUS
FROM ORDERS o
JOIN CUSTOMERS c ON o.CUSTOMER_ID = c.CUSTOMER_ID
ORDER BY o.ORDER_DATE DESC;

-- Aggregate query - revenue by product
SELECT 
    p.PRODUCT_NAME,
    p.CATEGORY,
    COUNT(DISTINCT oi.ORDER_ID) AS times_ordered,
    SUM(oi.QUANTITY) AS total_quantity,
    SUM(oi.QUANTITY * oi.UNIT_PRICE) AS total_revenue
FROM PRODUCTS p
LEFT JOIN ORDER_ITEMS oi ON p.PRODUCT_ID = oi.PRODUCT_ID
GROUP BY p.PRODUCT_NAME, p.CATEGORY
ORDER BY total_revenue DESC;

-- Time-based query - orders by date
SELECT 
    DATE_TRUNC('day', ORDER_DATE) AS order_day,
    COUNT(*) AS order_count,
    SUM(TOTAL_AMOUNT) AS daily_revenue
FROM ORDERS
GROUP BY DATE_TRUNC('day', ORDER_DATE)
ORDER BY order_day DESC;
