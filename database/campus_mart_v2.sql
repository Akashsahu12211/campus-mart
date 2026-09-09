-- =============================================
-- CAMPUS MART v2 - Updated Database Schema
-- Run this AFTER dropping old DB or use ddl-auto=update
-- =============================================

CREATE DATABASE IF NOT EXISTS campus_mart;
USE campus_mart;

-- Students
CREATE TABLE IF NOT EXISTS students (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    phone VARCHAR(15),
    branch VARCHAR(100),
    hostel VARCHAR(100),
    college_id VARCHAR(50),
    profile_pic LONGTEXT,
    bio TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Categories
CREATE TABLE IF NOT EXISTS categories (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    icon VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Items (v2 — condition, negotiable, view_count added)
CREATE TABLE IF NOT EXISTS items (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    status ENUM('AVAILABLE','SOLD','RESERVED') DEFAULT 'AVAILABLE',
    `condition` ENUM('NEW','LIKE_NEW','GOOD','FAIR','POOR') DEFAULT 'GOOD',
    negotiable BOOLEAN DEFAULT FALSE,
    view_count INT DEFAULT 0,
    category_id BIGINT,
    seller_id BIGINT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(id),
    FOREIGN KEY (seller_id) REFERENCES students(id)
);

-- Item Images (separate table for multiple images)
CREATE TABLE IF NOT EXISTS item_images (
    item_id BIGINT NOT NULL,
    image_url VARCHAR(500) NOT NULL,
    FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE
);

-- Transactions
CREATE TABLE IF NOT EXISTS transactions (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    item_id BIGINT NOT NULL,
    buyer_id BIGINT NOT NULL,
    seller_id BIGINT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (item_id) REFERENCES items(id),
    FOREIGN KEY (buyer_id) REFERENCES students(id),
    FOREIGN KEY (seller_id) REFERENCES students(id)
);

-- ── Seed Data ─────────────────────────────────────────────
INSERT IGNORE INTO categories (name, icon) VALUES
('Books & Notes', 'book'),
('Electronics', 'laptop'),
('Cycles & Vehicles', 'bicycle'),
('Room Items', 'home'),
('Clothes', 'shirt'),
('Sports', 'football'),
('Stationery', 'pen'),
('Other', 'box');

-- Sample Students (password stored as plain text — add hashing in production)
INSERT IGNORE INTO students (name, email, password, phone, branch, hostel, college_id) VALUES
('Rahul Sharma', 'rahul@college.edu', 'rahul123', '9876543210', 'Computer Science', 'Hostel A', 'CS2021001'),
('Priya Singh',  'priya@college.edu', 'priya123', '9876543211', 'Electronics',      'Hostel B', 'EC2021002'),
('Amit Kumar',   'amit@college.edu',  'amit123',  '9876543212', 'Mechanical',       'Hostel C', 'ME2021003');

-- Sample Items
INSERT IGNORE INTO items (title, description, price, status, `condition`, negotiable, category_id, seller_id) VALUES
('DBMS Textbook Navathe 7th Ed', 'Good condition, all chapters intact, few highlights only', 250.00, 'AVAILABLE', 'GOOD', TRUE, 1, 1),
('Casio fx-991ES Calculator', 'Works perfectly, used for 1 semester only', 850.00, 'AVAILABLE', 'LIKE_NEW', FALSE, 2, 2),
('Hero Sprint Bicycle', '2 years old, needs minor service, great for campus', 3200.00, 'AVAILABLE', 'FAIR', TRUE, 3, 3),
('Bajaj Table Fan 400mm', '1 year old, works fine, leaving hostel', 650.00, 'AVAILABLE', 'GOOD', FALSE, 4, 1);

-- ── Useful Queries for Viva/Demo ──────────────────────────

-- All available items with seller info
SELECT i.id, i.title, i.price, i.status, i.condition, i.negotiable,
       c.name AS category, s.name AS seller, s.phone, s.college_id
FROM items i
JOIN categories c ON i.category_id = c.id
JOIN students s ON i.seller_id = s.id
WHERE i.status = 'AVAILABLE'
ORDER BY i.created_at DESC;

-- Items count per category
SELECT c.name, COUNT(i.id) AS total, SUM(i.status='AVAILABLE') AS available
FROM categories c
LEFT JOIN items i ON c.id = i.category_id
GROUP BY c.id, c.name
ORDER BY total DESC;

-- Most viewed items
SELECT title, price, view_count, status FROM items ORDER BY view_count DESC LIMIT 5;
