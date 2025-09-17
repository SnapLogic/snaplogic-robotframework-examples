#!/bin/bash
# SQL Server Setup Script
# This script initializes SQL Server with databases, schemas, and sample data for testing

set -e

echo "========================================="
echo "SQL Server Database Setup Script"
echo "========================================="

# SQL Server connection parameters
MSSQL_HOST="${MSSQL_HOST:-sqlserver-db}"
MSSQL_SA_PASSWORD="${MSSQL_SA_PASSWORD:-Snaplogic123!}"
MSSQL_DATABASE="${MSSQL_DATABASE:-SnapLogicTest}"

# Wait for SQL Server to be ready
echo "Waiting for SQL Server to be ready..."
for i in {1..30}; do
    if /opt/mssql-tools18/bin/sqlcmd -S $MSSQL_HOST -U sa -P "$MSSQL_SA_PASSWORD" -Q "SELECT 1" -b -C > /dev/null 2>&1; then
        echo "SQL Server is ready!"
        break
    fi
    echo "Waiting... ($i/30)"
    sleep 2
done

echo "Creating databases and users..."

# Create databases, users, and initial schema
/opt/mssql-tools18/bin/sqlcmd -S $MSSQL_HOST -U sa -P "$MSSQL_SA_PASSWORD" -C -i /dev/stdin << EOF
-- Create main test database
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = '$MSSQL_DATABASE')
BEGIN
    CREATE DATABASE [$MSSQL_DATABASE];
END
GO

-- Create additional test databases
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'IntegrationTest')
BEGIN
    CREATE DATABASE [IntegrationTest];
END
GO

IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'PerformanceTest')
BEGIN
    CREATE DATABASE [PerformanceTest];
END
GO

-- Switch to the main test database
USE [$MSSQL_DATABASE];
GO

-- Create logins if they don't exist
IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = 'testuser')
BEGIN
    CREATE LOGIN testuser WITH PASSWORD = 'TestUser123!';
END
GO

IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = 'readonly_user')
BEGIN
    CREATE LOGIN readonly_user WITH PASSWORD = 'ReadOnly123!';
END
GO

IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = 'admin_user')
BEGIN
    CREATE LOGIN admin_user WITH PASSWORD = 'AdminUser123!';
END
GO

-- Create database users
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'testuser')
BEGIN
    CREATE USER testuser FOR LOGIN testuser;
END
GO

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'readonly_user')
BEGIN
    CREATE USER readonly_user FOR LOGIN readonly_user;
END
GO

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'admin_user')
BEGIN
    CREATE USER admin_user FOR LOGIN admin_user;
END
GO

-- Grant permissions
ALTER ROLE db_datareader ADD MEMBER testuser;
ALTER ROLE db_datawriter ADD MEMBER testuser;
ALTER ROLE db_ddladmin ADD MEMBER testuser;

ALTER ROLE db_datareader ADD MEMBER readonly_user;

ALTER ROLE db_owner ADD MEMBER admin_user;
GO

-- Create schemas
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'snaplogic')
BEGIN
    EXEC('CREATE SCHEMA snaplogic');
END
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'test')
BEGIN
    EXEC('CREATE SCHEMA test');
END
GO

-- Create tables in dbo schema
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[customers]') AND type in (N'U'))
BEGIN
    CREATE TABLE dbo.customers (
        customer_id INT IDENTITY(1,1) PRIMARY KEY,
        first_name NVARCHAR(50) NOT NULL,
        last_name NVARCHAR(50) NOT NULL,
        email NVARCHAR(100) UNIQUE,
        phone NVARCHAR(20),
        address NVARCHAR(200),
        city NVARCHAR(50),
        state NVARCHAR(2),
        zip_code NVARCHAR(10),
        country NVARCHAR(50) DEFAULT 'USA',
        is_active BIT DEFAULT 1,
        created_date DATETIME2 DEFAULT GETDATE(),
        updated_date DATETIME2 DEFAULT GETDATE()
    );
END
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[products]') AND type in (N'U'))
BEGIN
    CREATE TABLE dbo.products (
        product_id INT IDENTITY(1,1) PRIMARY KEY,
        product_name NVARCHAR(100) NOT NULL,
        category NVARCHAR(50),
        description NVARCHAR(MAX),
        price DECIMAL(10, 2),
        stock_quantity INT DEFAULT 0,
        is_active BIT DEFAULT 1,
        created_date DATETIME2 DEFAULT GETDATE()
    );
END
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[orders]') AND type in (N'U'))
BEGIN
    CREATE TABLE dbo.orders (
        order_id INT IDENTITY(1,1) PRIMARY KEY,
        customer_id INT,
        order_date DATETIME2 DEFAULT GETDATE(),
        status NVARCHAR(20) DEFAULT 'PENDING',
        total_amount DECIMAL(10, 2),
        shipping_address NVARCHAR(200),
        notes NVARCHAR(MAX),
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
    );
END
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[order_items]') AND type in (N'U'))
BEGIN
    CREATE TABLE dbo.order_items (
        item_id INT IDENTITY(1,1) PRIMARY KEY,
        order_id INT,
        product_id INT,
        quantity INT NOT NULL,
        unit_price DECIMAL(10, 2),
        total_price DECIMAL(10, 2),
        FOREIGN KEY (order_id) REFERENCES orders(order_id),
        FOREIGN KEY (product_id) REFERENCES products(product_id)
    );
END
GO

-- Create a table for testing SQL Server specific data types
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[test].[data_types_test]') AND type in (N'U'))
BEGIN
    CREATE TABLE test.data_types_test (
        id INT IDENTITY(1,1) PRIMARY KEY,
        tiny_int_col TINYINT,
        small_int_col SMALLINT,
        int_col INT,
        big_int_col BIGINT,
        decimal_col DECIMAL(18, 4),
        numeric_col NUMERIC(10, 2),
        money_col MONEY,
        small_money_col SMALLMONEY,
        float_col FLOAT,
        real_col REAL,
        bit_col BIT,
        date_col DATE,
        time_col TIME,
        datetime_col DATETIME,
        datetime2_col DATETIME2,
        datetimeoffset_col DATETIMEOFFSET,
        char_col CHAR(10),
        varchar_col VARCHAR(255),
        nchar_col NCHAR(10),
        nvarchar_col NVARCHAR(255),
        text_col TEXT,
        ntext_col NTEXT,
        binary_col BINARY(8),
        varbinary_col VARBINARY(255),
        image_col IMAGE,
        uniqueidentifier_col UNIQUEIDENTIFIER DEFAULT NEWID(),
        xml_col XML,
        geography_col GEOGRAPHY,
        geometry_col GEOMETRY,
        hierarchyid_col HIERARCHYID,
        sql_variant_col SQL_VARIANT
    );
END
GO

-- Insert sample data
-- Clear existing data first (for idempotency)
DELETE FROM dbo.order_items;
DELETE FROM dbo.orders;
DELETE FROM dbo.products;
DELETE FROM dbo.customers;
GO

-- Reset identity seeds
DBCC CHECKIDENT ('dbo.customers', RESEED, 0);
DBCC CHECKIDENT ('dbo.products', RESEED, 0);
DBCC CHECKIDENT ('dbo.orders', RESEED, 0);
DBCC CHECKIDENT ('dbo.order_items', RESEED, 0);
GO

-- Insert customers
INSERT INTO dbo.customers (first_name, last_name, email, phone, address, city, state, zip_code) VALUES
('John', 'Doe', 'john.doe@example.com', '555-0101', '123 Main St', 'New York', 'NY', '10001'),
('Jane', 'Smith', 'jane.smith@example.com', '555-0102', '456 Oak Ave', 'Los Angeles', 'CA', '90001'),
('Robert', 'Johnson', 'robert.j@example.com', '555-0103', '789 Pine Rd', 'Chicago', 'IL', '60601'),
('Maria', 'Garcia', 'maria.g@example.com', '555-0104', '321 Elm St', 'Houston', 'TX', '77001'),
('William', 'Brown', 'william.b@example.com', '555-0105', '654 Maple Dr', 'Phoenix', 'AZ', '85001'),
('Emma', 'Wilson', 'emma.w@example.com', '555-0106', '987 Cedar Ln', 'Philadelphia', 'PA', '19019'),
('Michael', 'Davis', 'michael.d@example.com', '555-0107', '147 Birch St', 'San Antonio', 'TX', '78201');
GO

-- Insert products
INSERT INTO dbo.products (product_name, category, description, price, stock_quantity) VALUES
('Laptop Pro', 'Electronics', 'High-performance laptop with 16GB RAM and 512GB SSD', 1299.99, 50),
('Wireless Mouse', 'Electronics', 'Ergonomic wireless mouse with precision tracking', 29.99, 200),
('Office Chair', 'Furniture', 'Comfortable ergonomic office chair with lumbar support', 349.99, 75),
('Desk Lamp', 'Furniture', 'LED desk lamp with adjustable brightness and color temperature', 49.99, 150),
('Notebook Set', 'Stationery', 'Set of 5 premium notebooks with hardcover', 24.99, 300),
('Coffee Maker', 'Appliances', 'Programmable coffee maker with thermal carafe', 89.99, 100),
('Monitor 27"', 'Electronics', '4K Ultra HD monitor with HDR support', 449.99, 60),
('Keyboard Mechanical', 'Electronics', 'RGB backlit mechanical keyboard', 119.99, 120),
('Standing Desk', 'Furniture', 'Electric height-adjustable standing desk', 599.99, 40),
('Headphones Pro', 'Electronics', 'Active noise-canceling wireless headphones', 249.99, 80),
('Webcam HD', 'Electronics', '1080p HD webcam with built-in microphone', 79.99, 90),
('USB Hub', 'Electronics', '7-port USB 3.0 hub with power adapter', 39.99, 110);
GO

-- Insert orders
INSERT INTO dbo.orders (customer_id, status, total_amount, shipping_address) VALUES
(1, 'COMPLETED', 1329.98, '123 Main St, New York, NY 10001'),
(2, 'PENDING', 399.98, '456 Oak Ave, Los Angeles, CA 90001'),
(3, 'SHIPPED', 139.98, '789 Pine Rd, Chicago, IL 60601'),
(1, 'COMPLETED', 569.97, '123 Main St, New York, NY 10001'),
(4, 'PROCESSING', 299.99, '321 Elm St, Houston, TX 77001'),
(5, 'COMPLETED', 1749.97, '654 Maple Dr, Phoenix, AZ 85001'),
(6, 'SHIPPED', 119.98, '987 Cedar Ln, Philadelphia, PA 19019');
GO

-- Insert order items
INSERT INTO dbo.order_items (order_id, product_id, quantity, unit_price, total_price) VALUES
(1, 1, 1, 1299.99, 1299.99),
(1, 2, 1, 29.99, 29.99),
(2, 3, 1, 349.99, 349.99),
(2, 4, 1, 49.99, 49.99),
(3, 5, 2, 24.99, 49.98),
(3, 6, 1, 89.99, 89.99),
(4, 7, 1, 449.99, 449.99),
(4, 8, 1, 119.99, 119.99),
(5, 10, 1, 249.99, 249.99),
(6, 1, 1, 1299.99, 1299.99),
(6, 7, 1, 449.99, 449.99),
(7, 11, 1, 79.99, 79.99),
(7, 12, 1, 39.99, 39.99);
GO

-- Create stored procedures
-- Drop if exists and recreate
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[GetCustomerOrders]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[GetCustomerOrders]
GO

CREATE PROCEDURE dbo.GetCustomerOrders
    @CustomerId INT
AS
BEGIN
    SELECT o.order_id, o.order_date, o.status, o.total_amount,
           COUNT(oi.item_id) as item_count
    FROM dbo.orders o
    LEFT JOIN dbo.order_items oi ON o.order_id = oi.order_id
    WHERE o.customer_id = @CustomerId
    GROUP BY o.order_id, o.order_date, o.status, o.total_amount;
END
GO

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[UpdateProductStock]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[UpdateProductStock]
GO

CREATE PROCEDURE dbo.UpdateProductStock
    @ProductId INT,
    @QuantityChange INT
AS
BEGIN
    UPDATE dbo.products 
    SET stock_quantity = stock_quantity + @QuantityChange
    WHERE product_id = @ProductId;
END
GO

-- Create views
IF EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[customer_order_summary]'))
    DROP VIEW dbo.customer_order_summary;
GO

CREATE VIEW dbo.customer_order_summary AS
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    COUNT(DISTINCT o.order_id) as total_orders,
    SUM(o.total_amount) as total_spent,
    MAX(o.order_date) as last_order_date
FROM dbo.customers c
LEFT JOIN dbo.orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.email;
GO

IF EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[product_sales_summary]'))
    DROP VIEW dbo.product_sales_summary;
GO

CREATE VIEW dbo.product_sales_summary AS
SELECT 
    p.product_id,
    p.product_name,
    p.category,
    COUNT(DISTINCT oi.order_id) as times_ordered,
    SUM(oi.quantity) as total_quantity_sold,
    SUM(oi.total_price) as total_revenue
FROM dbo.products p
LEFT JOIN dbo.order_items oi ON p.product_id = oi.product_id
GROUP BY p.product_id, p.product_name, p.category;
GO

-- Create indexes for better performance
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_customer_email' AND object_id = OBJECT_ID('dbo.customers'))
    CREATE INDEX IX_customer_email ON dbo.customers(email);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_product_category' AND object_id = OBJECT_ID('dbo.products'))
    CREATE INDEX IX_product_category ON dbo.products(category);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_order_customer' AND object_id = OBJECT_ID('dbo.orders'))
    CREATE INDEX IX_order_customer ON dbo.orders(customer_id);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_order_status' AND object_id = OBJECT_ID('dbo.orders'))
    CREATE INDEX IX_order_status ON dbo.orders(status);
GO

-- Create a sample function
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CalculateDiscount]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
    DROP FUNCTION dbo.CalculateDiscount;
GO

CREATE FUNCTION dbo.CalculateDiscount(@Amount DECIMAL(10,2), @DiscountPercent INT)
RETURNS DECIMAL(10,2)
AS
BEGIN
    RETURN @Amount * (100 - @DiscountPercent) / 100.0;
END
GO

-- Display summary
PRINT 'Database setup completed successfully!';
SELECT COUNT(*) as customer_count FROM dbo.customers;
SELECT COUNT(*) as product_count FROM dbo.products;
SELECT COUNT(*) as order_count FROM dbo.orders;
SELECT COUNT(*) as order_item_count FROM dbo.order_items;

-- Show created objects
SELECT 'Tables' as ObjectType, COUNT(*) as Count FROM sys.tables WHERE schema_id = SCHEMA_ID('dbo');
SELECT 'Views' as ObjectType, COUNT(*) as Count FROM sys.views WHERE schema_id = SCHEMA_ID('dbo');
SELECT 'Procedures' as ObjectType, COUNT(*) as Count FROM sys.procedures WHERE schema_id = SCHEMA_ID('dbo');
SELECT 'Functions' as ObjectType, COUNT(*) as Count FROM sys.objects WHERE type IN ('FN', 'IF', 'TF', 'FS', 'FT') AND schema_id = SCHEMA_ID('dbo');
GO

EOF

echo ""
echo "========================================="
echo "SQL Server Setup Complete!"
echo "========================================="
echo ""
echo "Databases created:"
echo "  - $MSSQL_DATABASE (main test database)"
echo "  - IntegrationTest"
echo "  - PerformanceTest"
echo ""
echo "Schemas created:"
echo "  - dbo (default schema)"
echo "  - snaplogic"
echo "  - test"
echo ""
echo "Users created:"
echo "  - testuser / TestUser123! (read/write access)"
echo "  - readonly_user / ReadOnly123! (read-only access)"
echo "  - admin_user / AdminUser123! (full admin access)"
echo ""
echo "Tables created:"
echo "  - customers (7 records)"
echo "  - products (12 records)"
echo "  - orders (7 records)"
echo "  - order_items (13 records)"
echo "  - test.data_types_test (for testing SQL Server data types)"
echo ""
echo "Stored procedures:"
echo "  - GetCustomerOrders"
echo "  - UpdateProductStock"
echo ""
echo "Views:"
echo "  - customer_order_summary"
echo "  - product_sales_summary"
echo ""
echo "Functions:"
echo "  - CalculateDiscount"
echo ""
echo "Connection details:"
echo "  Host: localhost"
echo "  Port: 1433"
echo "  Database: $MSSQL_DATABASE"
echo "  Authentication: SQL Server Authentication"
echo ""
