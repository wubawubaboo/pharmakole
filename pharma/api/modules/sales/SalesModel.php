<?php
class SalesModel{
private $pdo;
public function __construct($pdo){ $this->pdo = $pdo; }


public function createSale($sale){

    $this->pdo->beginTransaction();
    try {
        $stmt = $this->pdo->prepare('INSERT INTO sales (cashier_name, total_amount, tax_amount, discount_amount, created_at, senior_pwd) VALUES (:cashier,:total,:tax,:discount,NOW(),:senior)');
        $stmt->execute([':cashier'=>$sale['cashier'],':total'=>$sale['total'],':tax'=>$sale['tax'],':discount'=>$sale['discount'],':senior'=>$sale['senior']]);
        $sale_id = $this->pdo->lastInsertId();
        
        $itemStmt = $this->pdo->prepare('INSERT INTO sale_items (sale_id, product_id, name, quantity, unit_price, total_price, total_cost) VALUES (:sale,:pid,:name,:qty,:unit,:total,:cost)');
        
        $fefoSelectStmt = $this->pdo->prepare('
            SELECT * FROM product_batches 
            WHERE product_id = :pid AND quantity > 0 
            ORDER BY CASE WHEN expiry_date IS NULL THEN 1 ELSE 0 END, expiry_date ASC, received_at ASC
            FOR UPDATE
        ');
        
        $fefoUpdateBatchStmt = $this->pdo->prepare('UPDATE product_batches SET quantity = quantity - :qty_removed WHERE id = :batch_id');
        
        $updateTotalQtyStmt = $this->pdo->prepare('UPDATE products SET quantity = (SELECT SUM(quantity) FROM product_batches WHERE product_id = :pid) WHERE id = :pid');
        
        $updateEarliestExpiryStmt = $this->pdo->prepare('UPDATE products SET earliest_expiry_date = (SELECT MIN(expiry_date) FROM product_batches WHERE product_id = :pid AND quantity > 0 AND expiry_date IS NOT NULL) WHERE id = :pid');
        $getNewTotalQtyStmt = $this->pdo->prepare('SELECT quantity FROM products WHERE id = :id');
        $log = $this->pdo->prepare('INSERT INTO stock_adjustments (product_id, new_quantity, reason, created_at) VALUES (:id,:q,:r,NOW())');


        foreach($sale['items'] as $it){
            $quantity_to_sell = (int)$it['quantity'];
            $product_id = $it['product_id'];
            $total_cost_for_this_item = 0;

            $fefoSelectStmt->execute([':pid' => $product_id]);
            $batches = $fefoSelectStmt->fetchAll(PDO::FETCH_ASSOC);

            if (empty($batches)) {
                 throw new Exception("No stock batches found for product ID: $product_id");
            }

            foreach ($batches as $batch) {
                if ($quantity_to_sell <= 0) break;

                $qty_from_this_batch = min($quantity_to_sell, (int)$batch['quantity']);
                
                $fefoUpdateBatchStmt->execute([
                    ':qty_removed' => $qty_from_this_batch,
                    ':batch_id' => $batch['id']
                ]);
                
                $total_cost_for_this_item += $qty_from_this_batch * (float)$batch['purchase_price_at_time'];
                
                $quantity_to_sell -= $qty_from_this_batch;
            }

            if ($quantity_to_sell > 0) {
                throw new Exception("Insufficient stock for product ID: $product_id. Needed $quantity_to_sell more.");
            }

            $itemStmt->execute([
                ':sale'=>$sale_id,
                ':pid'=>$product_id,
                ':name'=>$it['name'],
                ':qty'=>$it['quantity'],
                ':unit'=>$it['unit_price'],
                ':total'=>$it['total_price'],
                ':cost'=>$total_cost_for_this_item
            ]);

            $updateTotalQtyStmt->execute([':pid' => $product_id]);
            
            $updateEarliestExpiryStmt->execute([':pid' => $product_id]);

            $getNewTotalQtyStmt->execute([':id' => $product_id]);
            $new_quantity = $getNewTotalQtyStmt->fetchColumn(); 
            
            $log->execute([
                ':id' => $product_id, 
                ':q' => ($new_quantity !== false ? $new_quantity : 0),
                ':r' => 'Sale ID: ' . $sale_id
            ]);
        }
        
        $this->pdo->commit();
        return $sale_id;

    } catch (Exception $e) {
        $this->pdo->rollBack();
        throw $e;
    }
}

public function searchTransactions($q){
$stmt = $this->pdo->prepare('SELECT * FROM sales WHERE id = :id OR cashier_name LIKE :q OR created_at LIKE :q');
$stmt->execute([':id'=>$q,':q'=>'%'.$q.'%']);
return $stmt->fetchAll(PDO::FETCH_ASSOC);
}
}