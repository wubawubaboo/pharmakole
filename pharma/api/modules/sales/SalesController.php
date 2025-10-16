<?php
require_once __DIR__.'/../../helpers.php';
require_once __DIR__.'/../../auth.php'; // Ensures authentication is available

class SalesController {
    private $pdo;
    private $model;
    private $cfg;

    public function __construct() {
        $this->cfg = include __DIR__.'/../../../config/config.php';
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

            // --- FIX #2: Server-side recalculation of all totals ---
            // This ignores any totals sent from the client and recalculates them for security and accuracy.
            $subtotal = 0;
            foreach($data['items'] as &$it){
                $unit_price = floatval($it['unit_price']);
                $quantity = intval($it['quantity']);
                $it['total_price'] = $quantity * $unit_price;
                $subtotal += $it['total_price'];
            }

            // Start with a zero discount and apply it only if the flag is set.
            $discount = 0;
            $senior_flag = !empty($data['senior']) || !empty($data['pwd']); // Check for senior or PWD
            if($senior_flag) {
                $discount = $subtotal * $this->cfg['senior_pwd_discount'];
            }

            // Calculate tax and final total based on server-side values.
            $tax = ($subtotal - $discount) * $this->cfg['tax_rate'];
            $total = ($subtotal - $discount) + $tax;
            // --- End of recalculation fix ---

            $sale = [
                'cashier' => $data['cashier'] ?? 'Cashier',
                'total' => round($total, 2),
                'tax' => round($tax, 2),
                'discount' => round($discount, 2),
                'senior' => $senior_flag ? 1 : 0,
                'items' => $data['items']
            ];

            $sale_id = $this->model->createSale($sale);

            if ($sale_id) {
                 // generate receipt (simple HTML saved)
                $receiptPath = __DIR__.'/../../../../storage/receipts/receipt_'.$sale_id.'.html';
                $this->generateReceipt($sale_id, $sale, $receiptPath);
                jsonResponse(['success' => true, 'sale_id' => $sale_id, 'receipt' => basename($receiptPath)]);
            } else {
                jsonResponse(['error' => 'Failed to create sale in database.'], 500);
            }
        } else if($method === 'GET' && strpos($path, '/api/sales/search') !== false){
            $q = $_GET['q'] ?? '';
            $r = $this->model->searchTransactions($q);
            jsonResponse(['results'=>$r]);
        } else {
            jsonResponse(['error'=>'Endpoint not found'],404);
        }
    }

    private function generateReceipt($sale_id, $sale, $path){
        $items = $sale['items'];
        $html = "<html><body><h2>BIR Receipt (Sample)</h2>";
        $html .= "<div>Sale ID: {$sale_id}</div>";
        $html .= "<div>Cashier: {$sale['cashier']}</div>";
        $html .= "<table border='1' cellpadding='4'><tr><th>Item</th><th>Qty</th><th>Unit</th><th>Total</th></tr>";
        foreach($items as $it){
            $html .= "<tr><td>{$it['name']}</td><td>{$it['quantity']}</td><td>{$it['unit_price']}</td><td>{$it['total_price']}</td></tr>";
        }
        $html .= "</table>";
        $html .= "<div>Discount: {$sale['discount']}</div><div>Tax: {$sale['tax']}</div><div>Total: {$sale['total']}</div>";
        if($sale['senior']) $html .= "<div>Senior/PWD Discount Applied</div>";
        $html .= "</body></html>";
        file_put_contents($path, $html);
    }
}
