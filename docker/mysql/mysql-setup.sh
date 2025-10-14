#!/bin/bash
# MySQL Setup Script
# This script initializes MySQL with databases, users, and sample data for testing

set -e

echo "========================================="
echo "MySQL Database Setup Script"
echo "========================================="

# MySQL connection parameters
MYSQL_HOST="${MYSQL_HOST:-mysql-db}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-snaplogic}"
MYSQL_DATABASE="${MYSQL_DATABASE:-TEST}"
MYSQL_USER="${MYSQL_USER:-testuser}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-snaplogic}"

# Wait for MySQL to be fully ready
echo "Waiting for MySQL to be ready..."
for i in {1..30}; do
    if mysql -h $MYSQL_HOST -u root -p$MYSQL_ROOT_PASSWORD -e "SELECT 1" > /dev/null 2>&1; then
        echo "MySQL is ready!"
        break
    fi
    echo "Waiting... ($i/30)"
    sleep 2
done

echo "Creating database and users..."

# Create the main test database (if not exists)
mysql -h $MYSQL_HOST -u root -p$MYSQL_ROOT_PASSWORD << EOF
-- Create database if not exists
CREATE DATABASE IF NOT EXISTS $MYSQL_DATABASE;
USE $MYSQL_DATABASE;

-- Create additional test databases
CREATE DATABASE IF NOT EXISTS snaplogic_test;
CREATE DATABASE IF NOT EXISTS integration_test;

-- Create users with different permission levels
CREATE USER IF NOT EXISTS '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';
CREATE USER IF NOT EXISTS 'readonly_user'@'%' IDENTIFIED BY 'readonly_pass';
CREATE USER IF NOT EXISTS 'admin_user'@'%' IDENTIFIED BY 'admin_pass';

-- Grant permissions
GRANT ALL PRIVILEGES ON $MYSQL_DATABASE.* TO '$MYSQL_USER'@'%';
GRANT ALL PRIVILEGES ON snaplogic_test.* TO '$MYSQL_USER'@'%';
GRANT ALL PRIVILEGES ON integration_test.* TO '$MYSQL_USER'@'%';

GRANT SELECT ON *.* TO 'readonly_user'@'%';
GRANT ALL PRIVILEGES ON *.* TO 'admin_user'@'%' WITH GRANT OPTION;

FLUSH PRIVILEGES;

-- Switch to test database
USE $MYSQL_DATABASE;

-- Create test tables
CREATE TABLE IF NOT EXISTS customers (
    customer_id INT PRIMARY KEY AUTO_INCREMENT,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(20),
    address VARCHAR(200),
    city VARCHAR(50),
    state VARCHAR(2),
    zip_code VARCHAR(10),
    country VARCHAR(50) DEFAULT 'USA',
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS products (
    product_id INT PRIMARY KEY AUTO_INCREMENT,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50),
    description TEXT,
    price DECIMAL(10, 2),
    stock_quantity INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS orders (
    order_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'PENDING',
    total_amount DECIMAL(10, 2),
    shipping_address VARCHAR(200),
    notes TEXT,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE IF NOT EXISTS order_items (
    item_id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT,
    product_id INT,
    quantity INT NOT NULL,
    unit_price DECIMAL(10, 2),
    total_price DECIMAL(10, 2),
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- Create a table for testing data types
CREATE TABLE IF NOT EXISTS data_types_test (
    id INT PRIMARY KEY AUTO_INCREMENT,
    tiny_int_col TINYINT,
    small_int_col SMALLINT,
    medium_int_col MEDIUMINT,
    int_col INT,
    big_int_col BIGINT,
    decimal_col DECIMAL(10, 2),
    float_col FLOAT,
    double_col DOUBLE,
    bit_col BIT(8),
    boolean_col BOOLEAN,
    date_col DATE,
    time_col TIME,
    datetime_col DATETIME,
    timestamp_col TIMESTAMP,
    year_col YEAR,
    char_col CHAR(10),
    varchar_col VARCHAR(255),
    text_col TEXT,
    blob_col BLOB,
    json_col JSON,
    enum_col ENUM('small', 'medium', 'large'),
    set_col SET('read', 'write', 'execute')
);

-- Insert sample data
INSERT INTO customers (first_name, last_name, email, phone, address, city, state, zip_code) VALUES
('John', 'Doe', 'john.doe@example.com', '555-0101', '123 Main St', 'New York', 'NY', '10001'),
('Jane', 'Smith', 'jane.smith@example.com', '555-0102', '456 Oak Ave', 'Los Angeles', 'CA', '90001'),
('Robert', 'Johnson', 'robert.j@example.com', '555-0103', '789 Pine Rd', 'Chicago', 'IL', '60601'),
('Maria', 'Garcia', 'maria.g@example.com', '555-0104', '321 Elm St', 'Houston', 'TX', '77001'),
('William', 'Brown', 'william.b@example.com', '555-0105', '654 Maple Dr', 'Phoenix', 'AZ', '85001');

INSERT INTO products (product_name, category, description, price, stock_quantity) VALUES
('Laptop Pro', 'Electronics', 'High-performance laptop with 16GB RAM', 1299.99, 50),
('Wireless Mouse', 'Electronics', 'Ergonomic wireless mouse', 29.99, 200),
('Office Chair', 'Furniture', 'Comfortable ergonomic office chair', 349.99, 75),
('Desk Lamp', 'Furniture', 'LED desk lamp with adjustable brightness', 49.99, 150),
('Notebook Set', 'Stationery', 'Set of 5 premium notebooks', 24.99, 300),
('Coffee Maker', 'Appliances', 'Programmable coffee maker with timer', 89.99, 100),
('Monitor 27"', 'Electronics', '4K Ultra HD monitor', 449.99, 60),
('Keyboard Mechanical', 'Electronics', 'RGB mechanical keyboard', 119.99, 120),
('Standing Desk', 'Furniture', 'Height-adjustable standing desk', 599.99, 40),
('Headphones Pro', 'Electronics', 'Noise-canceling wireless headphones', 249.99, 80);

INSERT INTO orders (customer_id, status, total_amount, shipping_address) VALUES
(1, 'COMPLETED', 1329.98, '123 Main St, New York, NY 10001'),
(2, 'PENDING', 399.98, '456 Oak Ave, Los Angeles, CA 90001'),
(3, 'SHIPPED', 139.98, '789 Pine Rd, Chicago, IL 60601'),
(1, 'COMPLETED', 569.97, '123 Main St, New York, NY 10001'),
(4, 'PROCESSING', 299.99, '321 Elm St, Houston, TX 77001');

INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price) VALUES
(1, 1, 1, 1299.99, 1299.99),
(1, 2, 1, 29.99, 29.99),
(2, 3, 1, 349.99, 349.99),
(2, 4, 1, 49.99, 49.99),
(3, 5, 2, 24.99, 49.98),
(3, 6, 1, 89.99, 89.99),
(4, 7, 1, 449.99, 449.99),
(4, 8, 1, 119.99, 119.99),
(5, 10, 1, 249.99, 249.99);

-- Create stored procedures
DELIMITER //

CREATE PROCEDURE IF NOT EXISTS GetCustomerOrders(IN cust_id INT)
BEGIN
    SELECT o.order_id, o.order_date, o.status, o.total_amount,
           COUNT(oi.item_id) as item_count
    FROM orders o
    LEFT JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.customer_id = cust_id
    GROUP BY o.order_id;
END //

CREATE PROCEDURE IF NOT EXISTS UpdateProductStock(
    IN prod_id INT,
    IN quantity_change INT
)
BEGIN
    UPDATE products 
    SET stock_quantity = stock_quantity + quantity_change
    WHERE product_id = prod_id;
END //

DELIMITER ;

-- Create views
CREATE OR REPLACE VIEW customer_order_summary AS
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    COUNT(DISTINCT o.order_id) as total_orders,
    SUM(o.total_amount) as total_spent,
    MAX(o.order_date) as last_order_date
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id;

CREATE OR REPLACE VIEW product_sales_summary AS
SELECT 
    p.product_id,
    p.product_name,
    p.category,
    COUNT(DISTINCT oi.order_id) as times_ordered,
    SUM(oi.quantity) as total_quantity_sold,
    SUM(oi.total_price) as total_revenue
FROM products p
LEFT JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY p.product_id;

-- Create indexes for better performance
CREATE INDEX idx_customer_email ON customers(email);
CREATE INDEX idx_product_category ON products(category);
CREATE INDEX idx_order_customer ON orders(customer_id);
CREATE INDEX idx_order_status ON orders(status);

-- Display summary
SELECT 'Database setup completed successfully!' as message;
SELECT COUNT(*) as customer_count FROM customers;
SELECT COUNT(*) as product_count FROM products;
SELECT COUNT(*) as order_count FROM orders;

EOF

echo ""
echo "========================================="
echo "MySQL Setup Complete!"
echo "========================================="
echo ""
echo "Databases created:"
echo "  - $MYSQL_DATABASE (main test database)"
echo "  - snaplogic_test"
echo "  - integration_test"
echo ""
echo "Users created:"
echo "  - $MYSQL_USER / $MYSQL_PASSWORD (full access to test databases)"
echo "  - readonly_user / readonly_pass (read-only access)"
echo "  - admin_user / admin_pass (full admin access)"
echo ""
echo "Tables created:"
echo "  - customers (5 records)"
echo "  - products (10 records)"
echo "  - orders (5 records)"
echo "  - order_items (9 records)"
echo "  - data_types_test (for testing various MySQL data types)"
echo ""
echo "Stored procedures:"
echo "  - GetCustomerOrders"
echo "  - UpdateProductStock"
echo ""
echo "Views:"
echo "  - customer_order_summary"
echo "  - product_sales_summary"
echo ""
echo "Connection details:"
echo "  Host: localhost"
echo "  Port: 3306"
echo "  Database: $MYSQL_DATABASE"
echo ""
