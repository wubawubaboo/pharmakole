<?php
class ReportsModel{
private $pdo; public function __construct($pdo){ $this->pdo = $pdo; }


public function dailySales($date){
$stmt = $this->pdo->prepare('SELECT * FROM sales WHERE DATE(created_at) = :d');$stmt->execute([':d'=>$date]);
return $stmt->fetchAll(PDO::FETCH_ASSOC);
}


public function salesSummary($start, $end){
$stmt = $this->pdo->prepare('SELECT DATE(created_at) as day, SUM(total_amount) as total FROM sales WHERE DATE(created_at) BETWEEN :s AND :e GROUP BY DATE(created_at)');
$stmt->execute([':s'=>$start,':e'=>$end]);
return $stmt->fetchAll(PDO::FETCH_ASSOC);
}


public function profitLoss($start, $end){
// example: compute sum(sales) - sum(purchase_price * qty sold)
$stmt = $this->pdo->prepare('SELECT s.id, s.total_amount, SUM(si.quantity * p.purchase_price) as cost FROM sales s JOIN sale_items si ON si.sale_id = s.id JOIN products p ON p.id = si.product_id WHERE DATE(s.created_at) BETWEEN :s AND :e GROUP BY s.id');
$stmt->execute([':s'=>$start,':e'=>$end]);
return $stmt->fetchAll(PDO::FETCH_ASSOC);
}
}