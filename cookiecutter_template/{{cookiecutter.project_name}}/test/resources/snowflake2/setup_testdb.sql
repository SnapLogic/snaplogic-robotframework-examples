-- ============================================
-- Snowflake Test Data Setup Script
-- ============================================
-- This script creates test tables and sample data in Snowflake
-- 
-- Usage:
-- 1. Connect to Snowflake: docker exec -it snowsql-client snowsql -c example
-- 2. Run this script: !source /scripts/setup_testdb.sql
-- Or run directly: docker exec -it snowsql-client snowsql -c example -f /scripts/setup_testdb.sql

-- Create test database and schema
CREATE DATABASE IF NOT EXISTS TESTDB;
USE DATABASE TESTDB;
CREATE SCHEMA IF NOT EXISTS SNAPTEST;
USE SCHEMA SNAPTEST;

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

-- Order items table
CREATE OR REPLACE TABLE ORDER_ITEMS (
    ORDER_ITEM_ID NUMBER(38,0) NOT NULL PRIMARY KEY,
    ORDER_ID NUMBER(38,0),
    PRODUCT_ID NUMBER(38,0),
    QUANTITY NUMBER(38,0),
    UNIT_PRICE NUMBER(10,2),
    FOREIGN KEY (ORDER_ID) REFERENCES ORDERS(ORDER_ID),
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
    (5, 'Charlie', 'Brown', 'charlie.brown@example.com', '555-0105', '654 Maple Dr', 'Berkeley', 'CA', '94702');

-- Insert products
INSERT INTO PRODUCTS (PRODUCT_ID, PRODUCT_NAME, CATEGORY, PRICE, STOCK_QUANTITY)
VALUES 
    (1, 'Laptop Pro 15"', 'Electronics', 1299.99, 50),
    (2, 'Wireless Mouse', 'Electronics', 29.99, 200),
    (3, 'USB-C Hub', 'Electronics', 49.99, 150),
    (4, 'Mechanical Keyboard', 'Electronics', 89.99, 75),
    (5, 'HD Webcam', 'Electronics', 79.99, 100);

-- Insert orders
INSERT INTO ORDERS (ORDER_ID, CUSTOMER_ID, ORDER_DATE, TOTAL_AMOUNT, STATUS, SHIPPING_ADDRESS)
VALUES 
    (1001, 1, CURRENT_TIMESTAMP(), 1329.98, 'COMPLETED', '123 Main St, San Francisco, CA 94105'),
    (1002, 2, DATEADD(day, -1, CURRENT_TIMESTAMP()), 49.99, 'PROCESSING', '456 Oak Ave, San Jose, CA 95110'),
    (1003, 3, DATEADD(day, -2, CURRENT_TIMESTAMP()), 169.98, 'SHIPPED', '789 Pine Rd, Oakland, CA 94612');

-- Insert order items
INSERT INTO ORDER_ITEMS (ORDER_ITEM_ID, ORDER_ID, PRODUCT_ID, QUANTITY, UNIT_PRICE)
VALUES 
    (1, 1001, 1, 1, 1299.99),
    (2, 1001, 2, 1, 29.99),
    (3, 1002, 3, 1, 49.99),
    (4, 1003, 4, 1, 89.99),
    (5, 1003, 5, 1, 79.99);

-- ============================================
-- Verification
-- ============================================

-- Show row counts
SELECT 'Setup completed. Row counts:' AS message;
SELECT 'Customers: ' || COUNT(*) AS count FROM CUSTOMERS
UNION ALL
SELECT 'Products: ' || COUNT(*) FROM PRODUCTS
UNION ALL
SELECT 'Orders: ' || COUNT(*) FROM ORDERS
UNION ALL
SELECT 'Order Items: ' || COUNT(*) FROM ORDER_ITEMS;
