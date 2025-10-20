<?php
class SalesModel{
private $pdo;
public function __construct($pdo){ $this->pdo = $pdo; }


public function createSale($sale){

    $this->pdo->beginTransaction(); // Start transaction
    try {
        // Insert the main sale record
        $stmt = $this->pdo->prepare('INSERT INTO sales (cashier_name, total_amount, tax_amount, discount_amount, created_at, senior_pwd) VALUES (:cashier,:total,:tax,:discount,NOW(),:senior)');
        $stmt->execute([':cashier'=>$sale['cashier'],':total'=>$sale['total'],':tax'=>$sale['tax'],':discount'=>$sale['discount'],':senior'=>$sale['senior']]);
        $sale_id = $this->pdo->lastInsertId();
        
        // --- SOLUTION: Prepare all statements BEFORE the loop ---
        // This prevents the "unbuffered queries" conflict.
        $itemStmt = $this->pdo->prepare('INSERT INTO sale_items (sale_id, product_id, name, quantity, unit_price, total_price) VALUES (:sale,:pid,:name,:qty,:unit,:total)');
        $upd = $this->pdo->prepare('UPDATE products SET quantity = quantity - :q WHERE id = :id');
        $currStmt = $this->pdo->prepare('SELECT quantity FROM products WHERE id = :id');
        $log = $this->pdo->prepare('INSERT INTO stock_adjustments (product_id, new_quantity, reason, created_at) VALUES (:id,:q,:r,NOW())');
        // --- End of preparation ---

        foreach($sale['items'] as $it){
            // 1. Insert sale item
            $itemStmt->execute([':sale'=>$sale_id,':pid'=>$it['product_id'],':name'=>$it['name'],':qty'=>$it['quantity'],':unit'=>$it['unit_price'],':total'=>$it['total_price']]);

            // 2. Update product quantity
            $upd->execute([':q'=>$it['quantity'],':id'=>$it['product_id']]);

            // 3. Get the new quantity after the update
            $currStmt->execute([':id' => $it['product_id']]);
            $new_quantity = $currStmt->fetchColumn(); 
            // fetchColumn() also implicitly closes the cursor, which helps.
            
            // 4. Log this change to the adjustments table
            $log->execute([
                ':id' => $it['product_id'], 
                ':q' => ($new_quantity !== false ? $new_quantity : 0), // Handle if product was deleted
                ':r' => 'Sale ID: ' . $sale_id
            ]);
        }
        
        $this->pdo->commit(); // Commit transaction
        return $sale_id;

    } catch (Exception $e) {
        $this->pdo->rollBack(); // Roll back on any error
        throw $e; // Re-throw exception to be caught by global handler
    }
}

public function searchTransactions($q){
$stmt = $this->pdo->prepare('SELECT * FROM sales WHERE id = :id OR cashier_name LIKE :q OR created_at LIKE :q');
$stmt->execute([':id'=>$q,':q'=>'%'.$q.'%']);
return $stmt->fetchAll(PDO::FETCH_ASSOC);
}
}