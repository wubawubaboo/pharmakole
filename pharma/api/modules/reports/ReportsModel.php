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
public function listAdjustments(){
    $sql = "SELECT sa.*, p.name as product_name 
            FROM stock_adjustments sa
            LEFT JOIN products p ON p.id = sa.product_id
            ORDER BY sa.created_at DESC";
    $stmt = $this->pdo->prepare($sql);
    $stmt->execute();
    return $stmt->fetchAll(PDO::FETCH_ASSOC);
}

public function listActivityLogs(){
    $stmt = $this->pdo->prepare('SELECT * FROM activity_logs ORDER BY created_at DESC LIMIT 200');
    $stmt->execute();
    return $stmt->fetchAll(PDO::FETCH_ASSOC);
}

public function getSalesTransactions($start, $end, $product_id = null){
    $params = [':start' => $start, ':end' => $end];
    
    $sql = "SELECT s.created_at, s.cashier_name, si.total_price, si.quantity, p.name as product_name 
            FROM sales s 
            JOIN sale_items si ON s.id = si.sale_id 
            JOIN products p ON p.id = si.product_id 
            WHERE DATE(s.created_at) BETWEEN :start AND :end";
    
    if (!empty($product_id)) {
        $sql .= " AND si.product_id = :pid";
        $params[':pid'] = $product_id;
    }
    
    $sql .= " ORDER BY s.created_at DESC";
    
    $stmt = $this->pdo->prepare($sql);
    $stmt->execute($params);
    return $stmt->fetchAll(PDO::FETCH_ASSOC);
}
}