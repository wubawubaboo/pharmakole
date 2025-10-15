CREATE DATABASE IF NOT EXISTS pharma_db;\nUSE pos_db;\n
CREATE TABLE users (
id INT AUTO_INCREMENT PRIMARY KEY,
username VARCHAR(100) UNIQUE,
password_hash VARCHAR(255),
role ENUM('staff','owner') DEFAULT 'staff',
full_name VARCHAR(255),
created_at DATETIME
);


CREATE TABLE products (
id INT AUTO_INCREMENT PRIMARY KEY,
name VARCHAR(255),
category VARCHAR(100),
quantity INT DEFAULT 0,
unit_price DECIMAL(10,2),
purchase_price DECIMAL(10,2),
supplier VARCHAR(255),
expiry_date DATE NULL,
created_at DATETIME
);


CREATE TABLE stock_adjustments (
id INT AUTO_INCREMENT PRIMARY KEY,
product_id INT,
new_quantity INT,
reason TEXT,
created_at DATETIME
);


CREATE TABLE sales (
id INT AUTO_INCREMENT PRIMARY KEY,
cashier_name VARCHAR(255),
total_amount DECIMAL(12,2),
tax_amount DECIMAL(12,2),
discount_amount DECIMAL(12,2),
senior_pwd TINYINT(1) DEFAULT 0,
created_at DATETIME
);


CREATE TABLE sale_items (
id INT AUTO_INCREMENT PRIMARY KEY,
sale_id INT,
product_id INT,
name VARCHAR(255),
quantity INT,
unit_price DECIMAL(10,2),
total_price DECIMAL(12,2)
);


CREATE TABLE inventory_receipts (
id INT AUTO_INCREMENT PRIMARY KEY,
supplier VARCHAR(255),
invoice_number VARCHAR(255),
created_at DATETIME
);

CREATE INDEX idx_products_name ON products(name);
CREATE INDEX idx_sales_created ON sales(created_at);