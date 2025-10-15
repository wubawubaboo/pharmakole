<?php
class SalesModel{
private $pdo;
public function __construct($pdo){ $this->pdo = $pdo; }


public function createSale($sale){
// sale: cashier, total, tax, discount, items array
$this->pdo->beginTransaction();
$stmt = $this->pdo->prepare('INSERT INTO sales (cashier_name, total_amount, tax_amount, discount_amount, created_at, senior_pwd) VALUES (:cashier,:total,:tax,:discount,NOW(),:senior)');
$stmt->execute([':cashier'=>$sale['cashier'],':total'=>$sale['total'],':tax'=>$sale['tax'],':discount'=>$sale['discount'],':senior'=>$sale['senior']]);
$sale_id = $this->pdo->lastInsertId();
$itemStmt = $this->pdo->prepare('INSERT INTO sale_items (sale_id, product_id, name, quantity, unit_price, total_price) VALUES (:sale,:pid,:name,:qty,:unit,:total)');
foreach($sale['items'] as $it){
$itemStmt->execute([':sale'=>$sale_id,':pid'=>$it['product_id'],':name'=>$it['name'],':qty'=>$it['quantity'],':unit'=>$it['unit_price'],':total'=>$it['total_price']]);
// decrease stock
$upd = $this->pdo->prepare('UPDATE products SET quantity = quantity - :q WHERE id = :id');
$upd->execute([':q'=>$it['quantity'],':id'=>$it['product_id']]);
}
$this->pdo->commit();
return $sale_id;
}


public function searchTransactions($q){
$stmt = $this->pdo->prepare('SELECT * FROM sales WHERE id = :id OR cashier_name LIKE :q OR created_at LIKE :q');
$stmt->execute([':id'=>$q,':q'=>'%'.$q.'%']);
return $stmt->fetchAll(PDO::FETCH_ASSOC);
}
}