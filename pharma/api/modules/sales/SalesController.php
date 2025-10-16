<?php
class SalesController {
    private $pdo;
    private $model;
    private $cfg;

    public function __construct() {
        $this->cfg = include __DIR__ . '/../../../../config/config.php';
        $dsn = "mysql:host={$this->cfg['db']['host']};dbname={$this->cfg['db']['dbname']};charset=utf8mb4";
        $this->pdo = new PDO($dsn, $this->cfg['db']['user'], $this->cfg['db']['pass'], [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION
        ]);
        require_once __DIR__ . '/SalesModel.php';
        $this->model = new SalesModel($this->pdo);
    }


public function handle($method, $get, $post, $body){
authenticate();
$path = $_SERVER['REQUEST_URI'];
if($method === 'POST' && strpos($path, '/api/sales/create') !== false){
$data = json_decode($body, true);


// compute totals (ensure server-side)
$subtotal = 0; foreach($data['items'] as & $it){ $it['total_price'] = $it['quantity'] * $it['unit_price']; $subtotal += $it['total_price']; }
$discount = $data['discount'] ?? 0;


// apply senior/PWD discount flag
$senior_flag = $data['senior'] ? 1 : 0;
if($senior_flag) {
$discount += $subtotal * $this->cfg['senior_pwd_discount'];
}
$tax = ($subtotal - $discount) * $this->cfg['tax_rate'];
$total = ($subtotal - $discount) + $tax;


$sale = [
'cashier'=>$data['cashier'], 'total'=>round($total,2), 'tax'=>round($tax,2), 'discount'=>round($discount,2), 'senior'=>$senior_flag, 'items'=>$data['items']
];
$sale_id = $this->model->createSale($sale);


// generate receipt (simple HTML saved)
$receiptPath = __DIR__.'/../../../../storage/receipts/receipt_'.$sale_id.'.html';
$this->generateReceipt($sale_id, $sale, $receiptPath);


jsonResponse(['success'=>true,'sale_id'=>$sale_id,'receipt'=>basename($receiptPath)]);
}


if($method === 'GET' && strpos($path, '/api/sales/search') !== false){
$q = $_GET['q'] ?? '';
$r = $this->model->searchTransactions($q);
jsonResponse(['results'=>$r]);
}


jsonResponse(['error'=>'Endpoint not found'],404);
}


private function generateReceipt($sale_id, $sale, $path){
$stmt = $this->pdo->prepare('SELECT * FROM sale_items WHERE sale_id = :s');
$stmt->execute([':s'=>$sale_id]);$items = $stmt->fetchAll(PDO::FETCH_ASSOC);
$html = "<html><body><h2>BIR Receipt (Sample)</h2>";
$html .= "<div>Sale ID: {$sale_id}</div>";
$html .= "<div>Cashier: {$sale['cashier']}</div>";
$html .= "<table border='1' cellpadding='4'><tr><th>Item</th><th>Qty</th><th>Unit</th><th>Total</th></tr>";
foreach($items as $it){ $html .= "<tr><td>{$it['name']}</td><td>{$it['quantity']}</td><td>{$it['unit_price']}</td><td>{$it['total_price']}</td></tr>"; }
$html .= "</table>";
$html .= "<div>Discount: {$sale['discount']}</div><div>Tax: {$sale['tax']}</div><div>Total: {$sale['total']}</div>";
if($sale['senior']) $html .= "<div>Senior/PWD Discount Applied</div>";
$html .= "</body></html>";
file_put_contents($path, $html);
}
}