<?php
class InventoryModel {
private $pdo;
public function __construct($pdo){$this->pdo = $pdo; }

// --- NEW HELPER FUNCTION ---
// This centralizes the logic for updating the main product's totals
// after any change in the product_batches table.
private function recalculateProductTotals($product_id) {
    // 1. Update product's total quantity from batches
    $updateTotalQtyStmt = $this->pdo->prepare('UPDATE products SET quantity = (SELECT COALESCE(SUM(quantity), 0) FROM product_batches WHERE product_id = :pid) WHERE id = :pid');
    $updateTotalQtyStmt->execute([':pid' => $product_id]);
    
    // 2. Update product's earliest expiry
    $updateEarliestExpiryStmt = $this->pdo->prepare('UPDATE products SET earliest_expiry_date = (SELECT MIN(expiry_date) FROM product_batches WHERE product_id = :pid AND quantity > 0 AND expiry_date IS NOT NULL) WHERE id = :pid');
    $updateEarliestExpiryStmt->execute([':pid' => $product_id]);
    
    // 3. Get the new total quantity for logging
    $getNewTotalQtyStmt = $this->pdo->prepare('SELECT quantity FROM products WHERE id = :id');
    $getNewTotalQtyStmt->execute([':id' => $product_id]);
    return $getNewTotalQtyStmt->fetchColumn();
}
// --- END NEW HELPER ---


public function createProduct($data){
// Quantity defaults to 0, earliest_expiry_date is null. Stock is added via restock.
$sql = "INSERT INTO products (name, category, quantity, unit_price, purchase_price, supplier, earliest_expiry_date, created_at) VALUES (:name,:category, 0,:unit_price,:purchase_price,:supplier, NULL, NOW())";
$stmt = $this->pdo->prepare($sql);
$stmt->execute([
':name'=>$data['name'],
':category'=>$data['category'],
':unit_price'=>$data['unit_price'],
':purchase_price'=>$data['purchase_price'],
':supplier'=>$data['supplier']
]);
return $this->pdo->lastInsertId();
}

public function listProducts($query = ''){
    if (!empty($query)) {
        $stmt = $this->pdo->prepare('SELECT * FROM products WHERE name LIKE :q ORDER BY name');
        $stmt->execute([':q' => '%' . $query . '%']);
    } else {
        $stmt = $this->pdo->prepare('SELECT * FROM products ORDER BY name');
        $stmt->execute();
    }
    return $stmt->fetchAll(PDO::FETCH_ASSOC);
}

// --- NEW BATCH MANAGEMENT FUNCTION ---
public function listBatches($product_id) {
    $stmt = $this->pdo->prepare('SELECT * FROM product_batches WHERE product_id = :pid ORDER BY CASE WHEN expiry_date IS NULL THEN 1 ELSE 0 END, expiry_date ASC, received_at ASC');
    $stmt->execute([':pid' => $product_id]);
    return $stmt->fetchAll(PDO::FETCH_ASSOC);
}

// --- NEW BATCH MANAGEMENT FUNCTION ---
public function updateBatch($batch_id, $quantity, $expiry_date) {
    $this->pdo->beginTransaction();
    try {
        // 1. Get product_id before update (for recalculation)
        $pidStmt = $this->pdo->prepare('SELECT product_id FROM product_batches WHERE id = :bid');
        $pidStmt->execute([':bid' => $batch_id]);
        $product_id = $pidStmt->fetchColumn();
        if (!$product_id) {
            throw new Exception("Batch not found.");
        }
        
        // 2. Update the batch
        $stmt = $this->pdo->prepare('UPDATE product_batches SET quantity = :q, expiry_date = :exp WHERE id = :bid');
        $stmt->execute([
            ':q' => $quantity,
            ':exp' => empty($expiry_date) ? null : $expiry_date,
            ':bid' => $batch_id
        ]);
        
        // 3. Recalculate totals
        $this->recalculateProductTotals($product_id);
        
        $this->pdo->commit();
        return true;
    } catch (Exception $e) {
        $this->pdo->rollBack();
        throw $e;
    }
}

// --- NEW BATCH MANAGEMENT FUNCTION ---
public function deleteBatch($batch_id) {
     $this->pdo->beginTransaction();
    try {
        // 1. Get product_id before delete (for recalculation)
        $pidStmt = $this->pdo->prepare('SELECT product_id FROM product_batches WHERE id = :bid');
        $pidStmt->execute([':bid' => $batch_id]);
        $product_id = $pidStmt->fetchColumn();
        if (!$product_id) {
            throw new Exception("Batch not found.");
        }
        
        // 2. Delete the batch
        $stmt = $this->pdo->prepare('DELETE FROM product_batches WHERE id = :bid');
        $stmt->execute([':bid' => $batch_id]);
        
        // 3. Recalculate totals
        $this->recalculateProductTotals($product_id);
        
        $this->pdo->commit();
        return true;
    } catch (Exception $e) {
        $this->pdo->rollBack();
        throw $e;
    }
}
// --- END NEW FUNCTIONS ---

public function updateStockAfterSale($product_id, $qty_sold){
$sql = "UPDATE products SET quantity = quantity - :q WHERE id = :id";
$stmt = $this->pdo->prepare($sql);
$stmt->execute([':q'=>$qty_sold,':id'=>$product_id]);
}


// other CRUD
public function getProduct($id){
$stmt = $this->pdo->prepare('SELECT * FROM products WHERE id = :id');
$stmt->execute([':id'=>$id]);
return $stmt->fetch(PDO::FETCH_ASSOC);
}

public function updateProduct($id, $data){
    $sql = "UPDATE products SET 
                name = :name, 
                category = :category, 
                unit_price = :unit_price, 
                purchase_price = :purchase_price, 
                supplier = :supplier
            WHERE id = :id";
    $stmt = $this->pdo->prepare($sql);
    $stmt->execute([
        ':id' => $id,
        ':name'=>$data['name'],
        ':category'=>$data['category'],
        ':unit_price'=>$data['unit_price'],
        ':purchase_price'=>$data['purchase_price'],
        ':supplier'=>$data['supplier']
    ]);
    return $stmt->rowCount();
}

public function deleteProduct($id){
    $stmt = $this->pdo->prepare('DELETE FROM products WHERE id = :id');
    $stmt->execute([':id' => $id]);
    return $stmt->rowCount();
}


public function listLowStock($threshold = 5){
$stmt = $this->pdo->prepare('SELECT * FROM products WHERE quantity <= :t');
$stmt->execute([':t'=>$threshold]);
return $stmt->fetchAll(PDO::FETCH_ASSOC);
}


public function listNearExpiry($days = 30){
$stmt = $this->pdo->prepare('SELECT * FROM products WHERE earliest_expiry_date IS NOT NULL AND earliest_expiry_date <= DATE_ADD(CURDATE(), INTERVAL :d DAY)');
$stmt->execute([':d'=>$days]);
return $stmt->fetchAll(PDO::FETCH_ASSOC);
}

public function adjustStock($product_id, $adjustment_amount, $reason = ''){
    $adjustment_amount = (int)$adjustment_amount;
    if ($adjustment_amount == 0) {
        return; // Nothing to do
    }

    $this->pdo->beginTransaction();
    try {
        if ($adjustment_amount > 0) {
            // --- ADDING STOCK ---
            $prodStmt = $this->pdo->prepare('SELECT purchase_price FROM products WHERE id = :id');
            $prodStmt->execute([':id' => $product_id]);
            $purchase_price = $prodStmt->fetchColumn();
            if ($purchase_price === false) {
                throw new Exception("Product not found.");
            }

            $batchStmt = $this->pdo->prepare('
                INSERT INTO product_batches
                  (product_id, quantity, expiry_date, purchase_price_at_time, received_at, stock_receipt_item_id)
                VALUES
                  (:pid, :qty, NULL, :price, NOW(), NULL)
            ');
            $batchStmt->execute([
                ':pid' => $product_id,
                ':qty' => $adjustment_amount,
                ':price' => $purchase_price
            ]);
            
        } else {
            // --- REMOVING STOCK ---
            $quantity_to_remove = abs($adjustment_amount);
            $fefoSelectStmt = $this->pdo->prepare('
                SELECT * FROM product_batches 
                WHERE product_id = :pid AND quantity > 0 
                ORDER BY CASE WHEN expiry_date IS NULL THEN 1 ELSE 0 END, expiry_date ASC, received_at ASC
                FOR UPDATE
            ');
            $fefoSelectStmt->execute([':pid' => $product_id]);
            $batches = $fefoSelectStmt->fetchAll(PDO::FETCH_ASSOC);

            if (empty($batches)) {
                 throw new Exception("No stock batches found to remove from.");
            }
            
            $fefoUpdateBatchStmt = $this->pdo->prepare('UPDATE product_batches SET quantity = quantity - :qty_removed WHERE id = :batch_id');

            foreach ($batches as $batch) {
                if ($quantity_to_remove <= 0) break;
                $qty_from_this_batch = min($quantity_to_remove, (int)$batch['quantity']);
                $fefoUpdateBatchStmt->execute([
                    ':qty_removed' => $qty_from_this_batch,
                    ':batch_id' => $batch['id']
                ]);
                $quantity_to_remove -= $qty_from_this_batch;
            }

            if ($quantity_to_remove > 0) {
                throw new Exception("Insufficient stock to remove. Tried to remove $quantity_to_remove more than available.");
            }
        }
        
        // --- UPDATE TOTALS & LOG ---
        
        // 1. Recalculate totals and get new total
        $new_total_quantity = $this->recalculateProductTotals($product_id);

        // 2. Log this change
        $log = $this->pdo->prepare('INSERT INTO stock_adjustments (product_id, new_quantity, reason, created_at) VALUES (:id,:q,:r,NOW())');
        $log->execute([
            ':id' => $product_id, 
            ':q' => ($new_total_quantity !== false ? $new_total_quantity : 0), 
            ':r' => $reason
        ]);
        
        $this->pdo->commit();

    } catch (Exception $e) {
        $this->pdo->rollBack();
        throw $e;
    }
}
}