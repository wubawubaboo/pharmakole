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

// --- MODIFIED: Added search capability ---
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

// --- NEW: Update a product ---
public function updateProduct($id, $data){
    $sql = "UPDATE products SET 
                name = :name, 
                category = :category, 
                quantity = :quantity, 
                unit_price = :unit_price, 
                purchase_price = :purchase_price, 
                supplier = :supplier, 
                expiry_date = :expiry_date 
            WHERE id = :id";
    $stmt = $this->pdo->prepare($sql);
    $stmt->execute([
        ':id' => $id,
        ':name'=>$data['name'],
        ':category'=>$data['category'],
        ':quantity'=>$data['quantity'],
        ':unit_price'=>$data['unit_price'],
        ':purchase_price'=>$data['purchase_price'],
        ':supplier'=>$data['supplier'],
        ':expiry_date'=>$data['expiry_date']
    ]);
    return $stmt->rowCount();
}

// --- NEW: Delete a product ---
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
$stmt = $this->pdo->prepare('SELECT * FROM products WHERE expiry_date IS NOT NULL AND expiry_date <= DATE_ADD(CURDATE(), INTERVAL :d DAY)');
$stmt->execute([':d'=>$days]);
return $stmt->fetchAll(PDO::FETCH_ASSOC);
}


public function adjustStock($id, $newQty, $reason = ''){
$stmt = $this->pdo->prepare('UPDATE products SET quantity = :q WHERE id = :id');
$stmt->execute([':q'=>$newQty, ':id'=>$id]);

$log = $this->pdo->prepare('INSERT INTO stock_adjustments (product_id, new_quantity, reason, created_at) VALUES (:id,:q,:r,NOW())');
$log->execute([':id'=>$id,':q'=>$newQty,':r'=>$reason]);
}
}
