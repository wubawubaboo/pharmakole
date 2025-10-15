<?php
class InventoryModel {
private $pdo;
public function __construct($pdo){$this->pdo = $pdo; }


public function createProduct($data){
$sql = "INSERT INTO products (name, category, quantity, unit_price, purchase_price, supplier, expiry_date, created_at) VALUES (:name,:category,:quantity,:unit_price,:purchase_price,:supplier,:expiry_date,NOW())";
$stmt = $this->pdo->prepare($sql);
$stmt->execute([
':name'=>$data['name'],':category'=>$data['category'],':quantity'=>$data['quantity'],':unit_price'=>$data['unit_price'],':purchase_price'=>$data['purchase_price'],':supplier'=>$data['supplier'],':expiry_date'=>$data['expiry_date']
]);
return $this->pdo->lastInsertId();
}


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


public function listLowStock($threshold = 5){
$stmt = $this->pdo->prepare('SELECT * FROM products WHERE quantity <= :t');
$stmt->execute([':t'=>$threshold]);
return $stmt->fetchAll(PDO::FETCH_ASSOC);
}


public function listNearExpiry($days = 30){
$stmt = $this->pdo->prepare('SELECT * FROM products WHERE expiry_date IS NOT NULL AND expiry_date <= DATE_ADD(CURDATE(), INTERVAL :d DAY)');
$stmt->execute([':d'=>$days]);
return $stmt->fetchAll(PDO::FETCH_ASSOC);
}


public function adjustStock($id, $newQty, $reason = ''){
$stmt = $this->pdo->prepare('UPDATE products SET quantity = :q WHERE id = :id');
$stmt->execute([':q'=>$newQty, ':id'=>$id]);
// log adjustment
$log = $this->pdo->prepare('INSERT INTO stock_adjustments (product_id, new_quantity, reason, created_at) VALUES (:id,:q,:r,NOW())');
$log->execute([':id'=>$id,':q'=>$newQty,':r'=>$reason]);
}
}