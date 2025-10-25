-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Oct 25, 2025 at 03:59 AM
-- Server version: 8.0.41
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `pharma_db`
--

-- --------------------------------------------------------

--
-- Table structure for table `activity_logs`
--

CREATE TABLE `activity_logs` (
  `id` int NOT NULL,
  `username` varchar(100) DEFAULT 'system',
  `action` varchar(255) NOT NULL,
  `details` text,
  `created_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `products`
--

CREATE TABLE `products` (
  `id` int NOT NULL,
  `name` varchar(255) DEFAULT NULL,
  `category` varchar(100) DEFAULT NULL,
  `quantity` int DEFAULT '0',
  `unit_price` decimal(10,2) DEFAULT NULL,
  `purchase_price` decimal(10,2) DEFAULT NULL,
  `supplier` varchar(255) DEFAULT NULL,
  `expiry_date` date DEFAULT NULL,
  `created_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `products`
--

INSERT INTO `products` (`id`, `name`, `category`, `quantity`, `unit_price`, `purchase_price`, `supplier`, `expiry_date`, `created_at`) VALUES
(1, 'Biogesic (Paracetamol) 500mg Tablet', 'Pain Relief', 200, 5.50, 4.00, 'Unilab, Inc.', '2027-12-31', '2025-10-16 14:58:48'),
(2, 'Advil (Ibuprofen) 200mg Capsule', 'Pain Relief', 236, 12.00, 9.50, 'Pfizer', '2026-10-31', '2025-10-16 14:58:48'),
(3, 'Saridon Triple Action Tablet', 'Pain Relief', 243, 7.00, 5.25, 'Bayer', '2027-08-31', '2025-10-16 14:58:48'),
(4, 'Tempra Forte (Paracetamol) 250mg/5ml Syrup 60ml', 'Fever Relief', 80, 135.00, 110.00, 'Taisho', '2026-05-31', '2025-10-16 14:58:48'),
(5, 'Solmux Forte (Carbocisteine) 500mg Capsule', 'Cough & Cold', 120, 15.00, 12.50, 'Unilab, Inc.', '2027-11-30', '2025-10-16 14:58:48'),
(6, 'Neozep Forte (Phenylephrine HCl) Tablet', 'Cough & Cold', 300, 8.00, 6.50, 'Unilab, Inc.', '2028-01-31', '2025-10-16 14:58:48'),
(7, 'Vicks Vaporub 25g', 'Cough & Cold', 90, 95.00, 80.00, 'Procter & Gamble', '2028-06-30', '2025-10-16 14:58:48'),
(8, 'Strepsils Honey & Lemon Lozenge', 'Cough & Cold', 180, 10.00, 8.00, 'Reckitt Benckiser', '2026-09-30', '2025-10-16 14:58:48'),
(9, 'Enervon C Tablet', 'Vitamins', 399, 7.50, 6.00, 'Unilab, Inc.', '2027-07-31', '2025-10-16 14:58:48'),
(10, 'Centrum Advance Multivitamins', 'Vitamins', 75, 18.00, 15.00, 'GSK', '2026-11-30', '2025-10-16 14:58:48'),
(11, 'Fern-C (Sodium Ascorbate) 500mg Capsule', 'Vitamins', 500, 9.00, 7.20, 'Fern, Inc.', '2027-04-30', '2025-10-16 14:58:48'),
(12, 'Appebon with Iron Capsule', 'Supplements', 119, 11.00, 9.00, 'Unilab, Inc.', '2026-08-31', '2025-10-16 14:58:48'),
(13, 'Betadine Antiseptic Solution 60ml', 'First Aid', 60, 150.00, 125.00, 'Mundipharma', '2028-02-29', '2025-10-16 14:58:48'),
(14, 'Band-Aid Assorted Strips (20s)', 'First Aid', 92, 45.00, 35.00, 'Johnson & Johnson', '2029-01-31', '2025-10-16 14:58:48'),
(15, 'Green Cross Isopropyl Alcohol 70% 250ml', 'First Aid', 110, 55.00, 45.00, 'Green Cross, Inc.', '2028-12-31', '2025-10-16 14:58:48'),
(16, 'Cotton Balls (150s)', 'First Aid', 85, 35.00, 28.00, 'Generic Supplier', '2030-01-01', '2025-10-16 14:58:48'),
(17, 'Cetaphil Gentle Skin Cleanser 250ml', 'Personal Care', 45, 450.00, 390.00, 'Galderma', '2027-06-30', '2025-10-16 14:58:48'),
(18, 'Colgate Total Toothpaste 150g', 'Personal Care', 95, 130.00, 110.00, 'Colgate-Palmolive', '2027-03-31', '2025-10-16 14:58:48'),
(19, 'Dove Bar Soap 100g', 'Personal Care', 150, 50.00, 42.00, 'Unilever', '2028-05-31', '2025-10-16 14:58:48'),
(20, 'Amoxicillin 500mg Capsule', 'Antibiotics', 104, 10.00, 8.00, 'Generic Supplier', '2026-04-30', '2025-10-16 14:58:48'),
(21, 'Losartan (Cozaar) 50mg Tablet', 'Hypertension', 55, 25.00, 20.00, 'MSD', '2027-09-30', '2025-10-16 14:58:48'),
(22, 'Metformin 500mg Tablet', 'Diabetes', 80, 5.00, 3.50, 'Generic Supplier', '2027-10-31', '2025-10-16 14:58:48');

-- --------------------------------------------------------

--
-- Table structure for table `sales`
--

CREATE TABLE `sales` (
  `id` int NOT NULL,
  `cashier_name` varchar(255) DEFAULT NULL,
  `total_amount` decimal(12,2) DEFAULT NULL,
  `tax_amount` decimal(12,2) DEFAULT NULL,
  `discount_amount` decimal(12,2) DEFAULT NULL,
  `senior_pwd` tinyint(1) DEFAULT '0',
  `created_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `sale_items`
--

CREATE TABLE `sale_items` (
  `id` int NOT NULL,
  `sale_id` int DEFAULT NULL,
  `product_id` int DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `quantity` int DEFAULT NULL,
  `unit_price` decimal(10,2) DEFAULT NULL,
  `total_price` decimal(12,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `stock_adjustments`
--

CREATE TABLE `stock_adjustments` (
  `id` int NOT NULL,
  `product_id` int DEFAULT NULL,
  `new_quantity` int DEFAULT NULL,
  `reason` text,
  `created_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `stock_receipts`
--

CREATE TABLE `stock_receipts` (
  `id` int NOT NULL,
  `supplier` varchar(255) DEFAULT NULL,
  `invoice_number` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `stock_receipt_items`
--

CREATE TABLE `stock_receipt_items` (
  `id` int NOT NULL,
  `receipt_id` int DEFAULT NULL,
  `product_id` int DEFAULT NULL,
  `quantity_received` int DEFAULT NULL,
  `purchase_price_at_time` decimal(10,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `suppliers`
--

CREATE TABLE `suppliers` (
  `id` int NOT NULL,
  `name` varchar(255) NOT NULL,
  `contact_person` varchar(255) DEFAULT NULL,
  `phone` varchar(50) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  `address` text,
  `created_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` int NOT NULL,
  `username` varchar(100) DEFAULT NULL,
  `password_hash` varchar(255) DEFAULT NULL,
  `role` enum('staff','owner') DEFAULT 'staff',
  `full_name` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `activity_logs`
--
ALTER TABLE `activity_logs`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_action_time` (`created_at`);

--
-- Indexes for table `products`
--
ALTER TABLE `products`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_products_name` (`name`);

--
-- Indexes for table `sales`
--
ALTER TABLE `sales`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_sales_created` (`created_at`);

--
-- Indexes for table `sale_items`
--
ALTER TABLE `sale_items`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `stock_adjustments`
--
ALTER TABLE `stock_adjustments`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `stock_receipts`
--
ALTER TABLE `stock_receipts`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `stock_receipt_items`
--
ALTER TABLE `stock_receipt_items`
  ADD PRIMARY KEY (`id`),
  ADD KEY `receipt_id` (`receipt_id`),
  ADD KEY `product_id` (`product_id`);

--
-- Indexes for table `suppliers`
--
ALTER TABLE `suppliers`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_suppliers_name` (`name`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `username` (`username`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `activity_logs`
--
ALTER TABLE `activity_logs`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `products`
--
ALTER TABLE `products`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=23;

--
-- AUTO_INCREMENT for table `sales`
--
ALTER TABLE `sales`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `sale_items`
--
ALTER TABLE `sale_items`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `stock_adjustments`
--
ALTER TABLE `stock_adjustments`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `stock_receipts`
--
ALTER TABLE `stock_receipts`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `stock_receipt_items`
--
ALTER TABLE `stock_receipt_items`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `suppliers`
--
ALTER TABLE `suppliers`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `stock_receipt_items`
--
ALTER TABLE `stock_receipt_items`
  ADD CONSTRAINT `stock_receipt_items_ibfk_1` FOREIGN KEY (`receipt_id`) REFERENCES `stock_receipts` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `stock_receipt_items_ibfk_2` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE SET NULL;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
