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
$stmt = $this->pdo->prepare('
    SELECT s.id, s.total_amount, SUM(si.total_cost) as cost 
    FROM sales s 
    JOIN sale_items si ON si.sale_id = s.id 
    WHERE DATE(s.created_at) BETWEEN :s AND :e 
    GROUP BY s.id
');
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

public function getFinancialSummary($start, $end, $product_id = null) {
    
    $revSql = 'SELECT SUM(s.total_amount) as total_revenue 
               FROM sales s
               WHERE DATE(s.created_at) BETWEEN :s AND :e';
    $revParams = [':s'=>$start, ':e'=>$end];

    if (!empty($product_id)) {
        $revSql = 'SELECT SUM(si.total_price) as total_revenue
                   FROM sales s
                   JOIN sale_items si ON s.id = si.sale_id
                   WHERE DATE(s.created_at) BETWEEN :s AND :e AND si.product_id = :pid';
        $revParams[':pid'] = $product_id;
    }

    $revStmt = $this->pdo->prepare($revSql);
    $revStmt->execute($revParams);
    $total_revenue = $revStmt->fetchColumn();

    $costStmt = $this->pdo->prepare('
        SELECT SUM(sri.quantity_received * sri.purchase_price_at_time) as total_cost 
        FROM stock_receipt_items sri 
        JOIN stock_receipts sr ON sri.receipt_id = sr.id 
        WHERE DATE(sr.created_at) BETWEEN :s AND :e
    ');
    $costStmt->execute([':s'=>$start, ':e'=>$end]);
    $total_cost = $costStmt->fetchColumn();

    return [
        'total_revenue' => (float)($total_revenue ?? 0.0),
        'total_restock_cost' => (float)($total_cost ?? 0.0)
    ];
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


public function getInventorySummary($low_stock_threshold = 5, $expiry_days = 30, $recent_adjustments = 5) {
    $lowStmt = $this->pdo->prepare('SELECT COUNT(*) as count FROM products WHERE quantity <= :t');
    $lowStmt->execute([':t' => $low_stock_threshold]);
    $low_stock_count = $lowStmt->fetchColumn();

    $expStmt = $this->pdo->prepare('SELECT COUNT(*) as count FROM products WHERE earliest_expiry_date IS NOT NULL AND earliest_expiry_date <= DATE_ADD(CURDATE(), INTERVAL :d DAY)');
    $expStmt->execute([':d' => $expiry_days]);
    $near_expiry_count = $expStmt->fetchColumn();
    
    $adjStmt = $this->pdo->prepare('SELECT sa.*, p.name as product_name 
                                    FROM stock_adjustments sa
                                    LEFT JOIN products p ON p.id = sa.product_id
                                    ORDER BY sa.created_at DESC
                                    LIMIT :lim');
    $adjStmt->bindParam(':lim', $recent_adjustments, PDO::PARAM_INT);
    $adjStmt->execute();
    $recent_adjustments_list = $adjStmt->fetchAll(PDO::FETCH_ASSOC);
    
    return [
        'low_stock_count' => (int)$low_stock_count,
        'near_expiry_count' => (int)$near_expiry_count,
        'recent_movements' => $recent_adjustments_list
    ];
}

}