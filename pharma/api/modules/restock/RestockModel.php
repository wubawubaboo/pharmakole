<?php
class RestockModel {
    private $pdo;
    public function __construct($pdo) { $this->pdo = $pdo; }

    public function receiveStock($data) {
        $this->pdo->beginTransaction();
        try {
            $stmt = $this->pdo->prepare('INSERT INTO stock_receipts (supplier, invoice_number, created_at) VALUES (:supplier, :invoice, NOW())');
            $stmt->execute([
                ':supplier' => $data['supplier'],
                ':invoice' => $data['invoice_number'] ?? null
            ]);
            $receipt_id = $this->pdo->lastInsertId();

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
                  -- Earliest expiry date and supplier are updated separately
                WHERE id = :pid
            ');


            $earliestExpiryStmt = $this->pdo->prepare('
                SELECT MIN(expiry_date) FROM product_batches
                WHERE product_id = :pid AND quantity > 0 AND expiry_date IS NOT NULL
            ');
            $updateEarliestExpiryStmt = $this->pdo->prepare('
                UPDATE products SET earliest_expiry_date = :earliest_expiry WHERE id = :pid
            ');

            $supplierQuery = $this->pdo->prepare('
                SELECT sr.supplier
                FROM product_batches pb
                JOIN stock_receipt_items sri ON pb.stock_receipt_item_id = sri.id
                JOIN stock_receipts sr ON sri.receipt_id = sr.id
                WHERE pb.product_id = :pid
                  AND pb.quantity > 0
                  AND pb.expiry_date IS NOT NULL
                ORDER BY pb.expiry_date ASC
                LIMIT 1
            ');
            $updateSupplierStmt = $this->pdo->prepare('
                UPDATE products SET supplier = :supplier WHERE id = :pid
            ');

            $getNewTotalQtyStmt = $this->pdo->prepare('SELECT quantity FROM products WHERE id = :id');
            $logStmt = $this->pdo->prepare('INSERT INTO stock_adjustments (product_id, new_quantity, reason, created_at) VALUES (:id, :q, :r, NOW())');


            foreach ($data['items'] as $it) {
                $expiry_date = null;
                if (!empty($it['expiry_date'])) {
                    if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $it['expiry_date'])) {
                        $expiry_date = $it['expiry_date'];
                    } else {
                        throw new Exception("Invalid expiry date format for product ID {$it['product_id']}. Use YYYY-MM-DD.");
                    }
                }

                $receiptItemStmt->execute([
                    ':rid' => $receipt_id,
                    ':pid' => $it['product_id'],
                    ':qty' => $it['quantity'],
                    ':price' => $it['purchase_price']
                ]);
                $stock_receipt_item_id = $this->pdo->lastInsertId();

                $batchStmt->execute([
                    ':pid' => $it['product_id'],
                    ':qty' => $it['quantity'],
                    ':expiry' => $expiry_date,
                    ':price' => $it['purchase_price'],
                    ':sri_id' => $stock_receipt_item_id
                ]);


                $productUpdateStmt->execute([
                    ':qty_added' => $it['quantity'],
                    ':price' => $it['purchase_price'],
                    ':pid' => $it['product_id']
                ]);

                $getNewTotalQtyStmt->execute([':id' => $it['product_id']]);
                $new_quantity = $getNewTotalQtyStmt->fetchColumn();

                $logStmt->execute([
                    ':id' => $it['product_id'],
                    ':q' => ($new_quantity !== false ? $new_quantity : 0),
                    ':r' => 'Restock Receipt ID: ' . $receipt_id
                ]);


                $earliestExpiryStmt->execute([':pid' => $it['product_id']]);
                $earliest_expiry = $earliestExpiryStmt->fetchColumn();
                $updateEarliestExpiryStmt->execute([
                    ':earliest_expiry' => $earliest_expiry,
                    ':pid' => $it['product_id']
                ]);

                $supplierQuery->execute([':pid' => $it['product_id']]);
                $supplier_from_earliest_expiry = $supplierQuery->fetchColumn();

                if ($supplier_from_earliest_expiry) {
                    $updateSupplierStmt->execute([
                        ':supplier' => $supplier_from_earliest_expiry,
                        ':pid' => $it['product_id']
                    ]);
                }
            }

            $this->pdo->commit();
            return $receipt_id;

        } catch (Exception $e) {
            $this->pdo->rollBack();
            error_log("Restock Error: " . $e->getMessage());
            throw new Exception("Failed to receive stock. Please check data and try again. Details: " . $e->getMessage());
        }
    }
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
            
            $batchStmt = $this->pdo->prepare('SELECT * FROM product_batches WHERE stock_receipt_item_id = :sri_id');
            foreach($data['items'] as &$item) {
                $batchStmt->execute([':sri_id' => $item['id']]);
                $item['batch_details'] = $batchStmt->fetch(PDO::FETCH_ASSOC);
                unset($item);
            }
        }

        return $data;
    }

}
?>