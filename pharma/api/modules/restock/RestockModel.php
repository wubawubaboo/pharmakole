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
                ':invoice' => $data['invoice_number']
            ]);
            $receipt_id = $this->pdo->lastInsertId();

            $itemStmt = $this->pdo->prepare('INSERT INTO stock_receipt_items (receipt_id, product_id, quantity_received, purchase_price_at_time) VALUES (:rid, :pid, :qty, :price)');
            $productStmt = $this->pdo->prepare('UPDATE products SET quantity = quantity + :qty, purchase_price = :price WHERE id = :pid');

            $log = $this->pdo->prepare('INSERT INTO stock_adjustments (product_id, new_quantity, reason, created_at) VALUES (:id,:q,:r,NOW())');
            $currStmt = $this->pdo->prepare('SELECT quantity FROM products WHERE id = :id');

            foreach ($data['items'] as $it) {
                $itemStmt->execute([
                    ':rid' => $receipt_id,
                    ':pid' => $it['product_id'],
                    ':qty' => $it['quantity'],
                    ':price' => $it['purchase_price']
                ]);
                $productStmt->execute([
                    ':qty' => $it['quantity'],
                    ':price' => $it['purchase_price'],
                    ':pid' => $it['product_id']
                ]);

                $currStmt->execute([':id' => $it['product_id']]);
                $new_quantity = $currStmt->fetchColumn();

                // 3c. Log this change
                $log->execute([
                    ':id' => $it['product_id'],
                    ':q' => $new_quantity,
                    ':r' => 'Restock Receipt ID: ' . $receipt_id
                ]);
            }

            $this->pdo->commit();
            return $receipt_id;

        } catch (Exception $e) {
            $this->pdo->rollBack();
            throw $e;
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
            $items = $this->pdo->prepare('SELECT ri.*, p.name as product_name FROM stock_receipt_items ri LEFT JOIN products p ON p.id = ri.product_id WHERE ri.receipt_id = :id');
            $items->execute([':id' => $id]);
            $data['items'] = $items->fetchAll(PDO::FETCH_ASSOC);
        }
        
        return $data;
    }
}
?>