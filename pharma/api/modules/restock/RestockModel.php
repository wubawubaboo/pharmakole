<?php
class RestockModel {
    private $pdo;
    public function __construct($pdo) { $this->pdo = $pdo; }

    public function receiveStock($data) {
        $this->pdo->beginTransaction();
        try {
            // --- Insert Receipt (No Change) ---
            $stmt = $this->pdo->prepare('INSERT INTO stock_receipts (supplier, invoice_number, created_at) VALUES (:supplier, :invoice, NOW())');
            $stmt->execute([
                ':supplier' => $data['supplier'],
                ':invoice' => $data['invoice_number'] ?? null // Allow null invoice
            ]);
            $receipt_id = $this->pdo->lastInsertId();

            // --- Prepare statements for batch insertion and product total update ---
            $receiptItemStmt = $this->pdo->prepare('INSERT INTO stock_receipt_items (receipt_id, product_id, quantity_received, purchase_price_at_time) VALUES (:rid, :pid, :qty, :price)');
            $batchStmt = $this->pdo->prepare('
                INSERT INTO product_batches
                  (product_id, quantity, expiry_date, purchase_price_at_time, received_at, stock_receipt_item_id)
                VALUES
                  (:pid, :qty, :expiry, :price, NOW(), :sri_id)
            ');
            $productUpdateStmt = $this->pdo->prepare('
                UPDATE products
                SET
                  quantity = quantity + :qty_added,
                  -- Optionally update purchase_price with the latest price
                  purchase_price = :price
                  -- , earliest_expiry_date = (SELECT MIN(expiry_date) FROM product_batches WHERE product_id = :pid AND quantity > 0 AND expiry_date IS NOT NULL) -- Recalculate earliest expiry
                WHERE id = :pid
            ');
            // Statement to get the earliest expiry date after insertion (if using that field)
            $earliestExpiryStmt = $this->pdo->prepare('
                SELECT MIN(expiry_date) FROM product_batches
                WHERE product_id = :pid AND quantity > 0 AND expiry_date IS NOT NULL
            ');
            $updateEarliestExpiryStmt = $this->pdo->prepare('
                UPDATE products SET earliest_expiry_date = :earliest_expiry WHERE id = :pid
            ');

            // --- Process each item ---
            foreach ($data['items'] as $it) {
                // Validate expiry date format if provided
                $expiry_date = null;
                if (!empty($it['expiry_date'])) {
                    // Basic validation - you might want more robust validation
                    if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $it['expiry_date'])) {
                        $expiry_date = $it['expiry_date'];
                    } else {
                        // Handle invalid date format - maybe throw an exception or log an error
                        throw new Exception("Invalid expiry date format for product ID {$it['product_id']}. Use YYYY-MM-DD.");
                    }
                }

                // 1. Insert into stock_receipt_items
                $receiptItemStmt->execute([
                    ':rid' => $receipt_id,
                    ':pid' => $it['product_id'],
                    ':qty' => $it['quantity'],
                    ':price' => $it['purchase_price']
                ]);
                $stock_receipt_item_id = $this->pdo->lastInsertId(); // Get ID for linking

                // 2. Insert into product_batches
                $batchStmt->execute([
                    ':pid' => $it['product_id'],
                    ':qty' => $it['quantity'],
                    ':expiry' => $expiry_date, // Use validated date or null
                    ':price' => $it['purchase_price'],
                    ':sri_id' => $stock_receipt_item_id
                ]);

                // 3. Update total quantity in products table
                $productUpdateStmt->execute([
                    ':qty_added' => $it['quantity'],
                    ':price' => $it['purchase_price'], // Update latest purchase price
                    ':pid' => $it['product_id']
                    // Earliest expiry is updated below
                ]);

                 // 4. Update earliest_expiry_date in products (if using that field)
                $earliestExpiryStmt->execute([':pid' => $it['product_id']]);
                $earliest_expiry = $earliestExpiryStmt->fetchColumn();
                $updateEarliestExpiryStmt->execute([
                    ':earliest_expiry' => $earliest_expiry, // Could be null if no batches have expiry
                    ':pid' => $it['product_id']
                ]);

                // Stock adjustment log is now less critical here, as batches handle the detail.
                // You could log the batch creation if desired.
                // ActivityLogger::log('receive_stock_batch', "Received batch for product ID {$it['product_id']}, Qty: {$it['quantity']}, Expiry: {$expiry_date}");

            } // End foreach item

            $this->pdo->commit();
            return $receipt_id;

        } catch (Exception $e) {
            $this->pdo->rollBack();
            // Log the detailed error
            error_log("Restock Error: " . $e->getMessage());
            // Rethrow a more generic error or return false/null
            throw new Exception("Failed to receive stock. Please check data and try again. Details: " . $e->getMessage());
        }
    } // End receiveStock

    // listReceipts() and getReceiptDetails() remain the same

     public function listReceipts() {
        $stmt = $this->pdo->prepare('SELECT * FROM stock_receipts ORDER BY created_at DESC');
        $stmt->execute();
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    public function getReceiptDetails($id) {
        $receipt = $this->pdo->prepare('SELECT * FROM stock_receipts WHERE id = :id');
        $receipt->execute([':id' => $id]);
        $data['receipt'] = $receipt->fetch(PDO::FETCH_ASSOC);

        if ($data['receipt']) {
            $items = $this->pdo->prepare('
                SELECT ri.*, p.name as product_name
                FROM stock_receipt_items ri
                LEFT JOIN products p ON p.id = ri.product_id
                WHERE ri.receipt_id = :id
            ');
            $items->execute([':id' => $id]);
            $data['items'] = $items->fetchAll(PDO::FETCH_ASSOC);
             // Optionally fetch batch info linked to these receipt items
            $batchStmt = $this->pdo->prepare('SELECT * FROM product_batches WHERE stock_receipt_item_id = :sri_id');
            foreach($data['items'] as &$item) {
            $batchStmt->execute([':sri_id' => $item['id']]);
            $item['batch_details'] = $batchStmt->fetch(PDO::FETCH_ASSOC);
            }
        }

        return $data;
    }

} // End Class
?>